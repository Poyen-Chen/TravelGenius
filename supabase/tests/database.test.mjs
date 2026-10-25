// 用 PGlite 在本機跑真正的 PostgreSQL，載入 migrations，驗證權限、同步、健康類同意與管理員函式。
// 不會連到任何 Supabase 專案。
import { PGlite } from '@electric-sql/pglite';
import assert from 'node:assert/strict';
import { readdir, readFile } from 'node:fs/promises';

const db = new PGlite();
// 模擬 Supabase 提供的角色與 auth schema。
await db.exec(`
  create role anon; create role authenticated;
  create schema auth;
  create table auth.users(id uuid primary key, email text unique, created_at timestamptz not null default now());
  create function auth.jwt() returns jsonb language sql stable as
    $$ select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb $$;
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(auth.jwt()->>'sub', '')::uuid $$;
  grant usage on schema public, auth to anon, authenticated;
  grant execute on function auth.uid(), auth.jwt() to anon, authenticated;
`);
const migrations = new URL('../migrations/', import.meta.url);
for (const file of (await readdir(migrations)).sort()) {
  await db.exec(await readFile(new URL(file, migrations), 'utf8'));
}

const alice = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
const bob = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
const support = 'cccccccc-cccc-cccc-cccc-cccccccccccc';
await db.query(`insert into auth.users(id, email) values ($1, 'alice@example.com'), ($2, 'bob@example.com'), ($3, 'support@example.com')`,
  [alice, bob, support]);

const tripID = 'dddddddd-dddd-dddd-dddd-dddddddddddd';
const libraryID = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';
const m = n => `${String(n).repeat(8)}-${String(n).repeat(4)}-${String(n).repeat(4)}-${String(n).repeat(4)}-${String(n).repeat(12)}`;
const trip = (name, items = []) => ({ version: 1, trip: { id: tripID.toUpperCase(), name, packingItems: items } });
const socks = { id: m(9), name: '襪子', catalogItemID: 'socks', categoryRaw: 'clothing', quantity: 5, isPacked: false };
const medicine = { id: m(8), name: '常備藥', catalogItemID: null, categoryRaw: 'health', quantity: 1, isPacked: false };

async function login(user, { role = 'authenticated', aal = 'aal1' } = {}) {
  await db.exec('reset role');
  await db.query("select set_config('request.jwt.claims', $1, false)", [user ? JSON.stringify({ sub: user, aal }) : '']);
  await db.exec(`set role ${role}`);
}
async function sync(kind, id, revision, payload, deleted, mutation) {
  const { rows } = await db.query('select public.sync_document($1,$2,$3,$4,$5,$6) as r',
    [kind, id, revision, payload === null ? null : JSON.stringify(payload), deleted, mutation]);
  return rows[0].r;
}
const rows = async (sql, params = []) => (await db.query(sql, params)).rows;
const asAdmin = () => db.exec('reset role');

// --- 同步：建立、重試、衝突、tombstone ---
await login(alice);
let r = await sync('trip', tripID, 0, trip('東京', [socks]), false, m(1));
assert.equal(r.status, 'applied'); assert.equal(r.document.revision, 1);
r = await sync('trip', tripID, 0, trip('東京', [socks]), false, m(1));
assert.equal(r.document.revision, 1, '網路重試不能增加 revision');
await assert.rejects(sync('trip', tripID, 0, trip('大阪'), false, m(1)), '同一個 mutation_id 換內容必須拒絕');
r = await sync('trip', tripID, 1, trip('東京 5 天', [socks]), false, m(2));
assert.equal(r.status, 'applied'); assert.equal(r.document.revision, 2);
r = await sync('trip', tripID, 1, trip('舊版'), false, m(3));
assert.equal(r.status, 'conflict', '舊版本必須回傳衝突'); assert.equal(r.document.payload.trip.name, '東京 5 天');
await assert.rejects(db.query('update public.user_documents set deleted = true'), '不能繞過 sync_document 直接寫表');
await assert.rejects(sync('trip', tripID, 2, { version: 1 }, false, m(3)), '缺少 trip 的 payload 必須拒絕');
await assert.rejects(sync('trip', tripID, 2, { version: 1, trip: { id: libraryID } }, false, m(3)), 'ID 不一致必須拒絕');

// --- 健康類物品：沒有同意就不能上傳 ---
await assert.rejects(sync('trip', tripID, 2, trip('東京', [socks, medicine]), false, m(3)), '未同意卻上傳健康類物品');
r = await sync('trip', tripID, 2, { ...trip('東京', [socks, medicine]), healthSyncConsent: true }, false, m(3));
assert.equal(r.document.revision, 3, '同意後可以上傳健康類物品');
await assert.rejects(sync('library', libraryID, 0, { version: 1, library: { id: libraryID, name: '常備藥', categoryRaw: 'health' } }, false, m(4)),
  '常備用品的健康類也需要同意');
r = await sync('library', libraryID, 0, { version: 1, library: { id: libraryID, name: '眼罩', categoryRaw: 'other' } }, false, m(4));
assert.equal(r.status, 'applied');

// --- 使用者隔離 ---
await login(bob);
assert.equal((await rows('select * from public.user_documents')).length, 0, 'Bob 看得到 Alice 的資料');
r = await sync('trip', tripID, 0, trip('Bob 的行程'), false, m(1));
assert.equal(r.document.owner_id, bob, '相同 UUID 也要分開擁有者');
await login(null, { role: 'anon' });
await assert.rejects(db.query('select * from public.user_documents'), '未登入不能讀取');
await assert.rejects(sync('trip', tripID, 0, trip('x'), false, m(5)), '未登入不能寫入');
await login(alice);
await assert.rejects(db.query('select * from public.admin_users'), 'App 不能讀管理員名單');
await assert.rejects(db.query('select * from public.admin_audit_log'), 'App 不能讀稽核紀錄');
await assert.rejects(db.query('select private.require_admin($1,$2,$3,$4,$5)', ['view_documents', bob, null, null, '測試原因']));

// --- 管理員函式：名單、MFA、原因、稽核 ---
const reason = '使用者回報清單錯誤 #12';
await assert.rejects(db.query('select * from public.admin_list_documents($1,$2)', [alice, reason]), '非管理員必須被拒絕');
await asAdmin(); await db.query('insert into public.admin_users(user_id) values ($1)', [support]);
await login(support, { aal: 'aal1' });
await assert.rejects(db.query('select * from public.admin_list_documents($1,$2)', [alice, reason]), '沒有 MFA 必須被拒絕');
await login(support, { aal: 'aal2' });
await assert.rejects(db.query('select * from public.admin_list_documents($1,$2)', [alice, '  ']), '必須填寫原因');
const found = await rows('select * from public.admin_find_user($1,$2)', [' ALICE@example.com ', reason]);
assert.equal(found.length, 1); assert.equal(found[0].user_id, alice);
assert.equal(Number(found[0].trip_count), 1); assert.equal(Number(found[0].library_count), 1);
const docs = await rows('select * from public.admin_list_documents($1,$2)', [alice, reason]);
assert.equal(docs.length, 2, '管理員看得到該使用者的資料');
assert.ok(docs.every(d => d.owner_id === alice), '不能混到其他使用者的資料');
r = (await rows('select public.admin_update_document($1,$2,$3,$4,$5,$6,$7) as r',
  [alice, 'trip', tripID, 1, JSON.stringify(trip('過期')), false, reason]))[0].r;
assert.equal(r.status, 'conflict', '管理員也要比對 revision');
r = (await rows('select public.admin_update_document($1,$2,$3,$4,$5,$6,$7) as r',
  [alice, 'trip', tripID, 3, JSON.stringify({ ...trip('東京（已修正）', [socks, medicine]), healthSyncConsent: true }), false, reason]))[0].r;
assert.equal(r.status, 'applied'); assert.equal(r.document.revision, 4);
r = (await rows('select public.admin_update_document($1,$2,$3,$4,$5,$6,$7) as r',
  [alice, 'library', libraryID, 1, null, true, reason]))[0].r;
assert.equal(r.document.deleted, true); assert.equal(r.document.payload, null);
await assert.rejects(db.query('select public.admin_authorize_user_deletion($1,$2)', [support, reason]), '不能刪除管理員帳號');
await db.query('select public.admin_authorize_user_deletion($1,$2)', [bob, reason]);

await asAdmin();
const audit = await rows('select actor_id, target_user_id, action, document_kind, reason from public.admin_audit_log order by id');
assert.deepEqual(audit.map(a => a.action),
  ['find_user', 'view_documents', 'update_document', 'update_document', 'delete_document', 'delete_user'],
  '每次通過授權的操作都要留紀錄（含因版本衝突沒改成的嘗試）；被拒絕的不留');
assert.ok(audit.every(a => a.actor_id === support && a.reason === reason));
assert.equal(audit[3].document_kind, 'trip');

// 使用者自己看得到管理員修正後的版本，下一次同步會拿到新 revision。
await login(alice);
const mine = await rows('select revision, payload from public.user_documents where kind = $1', ['trip']);
assert.equal(mine[0].revision, 4); assert.equal(mine[0].payload.trip.name, '東京（已修正）');

// --- 刪除帳號：cascade，且不影響其他人與稽核紀錄 ---
await asAdmin();
await db.query('delete from auth.users where id = $1', [alice]);
assert.equal((await rows('select * from public.user_documents where owner_id = $1', [alice])).length, 0, '刪除帳號要一併刪除資料');
assert.equal((await rows('select * from public.user_documents where owner_id = $1', [bob])).length, 1, '刪除帳號影響到其他人');
assert.equal((await rows('select * from public.admin_audit_log')).length, 6, '稽核紀錄必須保留');

await db.close();
console.log('schema、RLS 隔離、CAS 衝突、冪等重試、payload 驗證、健康類同意、管理員名單／MFA／原因／稽核、刪除 cascade：PASS');
