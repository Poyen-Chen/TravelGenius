// 對「本機」Supabase（supabase start）做一次完整的實測：建立測試帳號，用各自的 token 走一遍
// 同步、使用者隔離、健康類同意、管理員 MFA 與稽核、刪除帳號。跑完可以打開 Studio 看資料。
//
//   cd ~/Desktop/PackSmart && supabase start
//   cd supabase/tests && npm install && npm run smoke
//
// 這個腳本會刪除並重建 @smoke.packsmart.test 的帳號，所以只允許連到本機。
import { createClient } from '@supabase/supabase-js';
import { execSync } from 'node:child_process';
import { createHmac, randomUUID } from 'node:crypto';

// --- 連線設定：預設從 `supabase status -o env` 讀取 ---
function localSettings() {
  let output = '';
  try {
    output = execSync('supabase status -o env', { cwd: new URL('../..', import.meta.url), stdio: ['ignore', 'pipe', 'ignore'] }).toString();
  } catch {
    console.error('讀不到本機 Supabase。請先在 repo 根目錄執行 `supabase start`。');
    process.exit(1);
  }
  const env = Object.fromEntries(output.split('\n').map(line => line.match(/^([A-Z_]+)="?(.*?)"?$/)).filter(Boolean).map(m => [m[1], m[2]]));
  return {
    url: process.env.SUPABASE_URL ?? env.API_URL,
    publicKey: process.env.SUPABASE_PUBLISHABLE_KEY ?? env.PUBLISHABLE_KEY ?? env.ANON_KEY,
    secretKey: process.env.SUPABASE_SECRET_KEY ?? env.SECRET_KEY ?? env.SERVICE_ROLE_KEY,
    studio: env.STUDIO_URL ?? 'http://127.0.0.1:54323',
  };
}
const settings = localSettings();
const host = new URL(settings.url).hostname;
if (!['127.0.0.1', 'localhost', '::1'].includes(host)) {
  console.error(`拒絕執行：${settings.url} 不是本機。這個腳本會刪除測試帳號，只能對 supabase start 的本機環境使用。`);
  process.exit(1);
}
const options = { auth: { persistSession: false, autoRefreshToken: false } };
const service = createClient(settings.url, settings.secretKey, options); // 只在本機測試用，用來建立帳號與管理員名單

// --- 結果輸出 ---
let failures = 0;
function check(ok, label, detail = '') {
  console.log(`${ok ? '✔' : '✘'} ${label}${!ok && detail ? `\n    ${detail}` : ''}`);
  if (!ok) failures += 1;
}
const errorText = error => error ? `${error.code ?? ''} ${error.message ?? ''}`.trim() : '沒有錯誤';

// --- TOTP（RFC 6238），模擬管理員的驗證器 App ---
function totp(base32Secret) {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const char of base32Secret.replace(/=+$/, '').toUpperCase()) bits += alphabet.indexOf(char).toString(2).padStart(5, '0');
  const key = Buffer.from(bits.match(/.{8}/g).map(byte => parseInt(byte, 2)));
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(Date.now() / 30000)));
  const hmac = createHmac('sha1', key).update(counter).digest();
  const offset = hmac[hmac.length - 1] & 0xf;
  return String((hmac.readUInt32BE(offset) & 0x7fffffff) % 1_000_000).padStart(6, '0');
}

// --- 測試帳號 ---
const domain = 'smoke.packsmart.test';
const password = `Smoke-${randomUUID()}`;
const { data: existing } = await service.auth.admin.listUsers({ perPage: 1000 });
for (const user of existing?.users ?? []) {
  if (user.email?.endsWith(`@${domain}`)) await service.auth.admin.deleteUser(user.id);
}
async function createUser(name) {
  const { data, error } = await service.auth.admin.createUser({ email: `${name}@${domain}`, password, email_confirm: true });
  if (error) throw new Error(`建立 ${name} 失敗：${error.message}`);
  const client = createClient(settings.url, settings.publicKey, options);
  const { error: signInError } = await client.auth.signInWithPassword({ email: `${name}@${domain}`, password });
  if (signInError) throw new Error(`${name} 登入失敗：${signInError.message}`);
  return { id: data.user.id, client };
}
const alice = await createUser('alice');
const bob = await createUser('bob');
const support = await createUser('support');
console.log(`建立測試帳號：alice、bob、support（@${domain}）\n`);

const tripID = randomUUID();
const socks = { id: randomUUID(), name: '襪子', catalogItemID: 'socks', categoryRaw: 'clothing', quantity: 5, isPacked: false };
const medicine = { id: randomUUID(), name: '常備藥', catalogItemID: null, categoryRaw: 'health', quantity: 1, isPacked: false };
const trip = (name, items, extra = {}) => ({ version: 1, trip: { id: tripID, name, countryCode: 'JP', packingItems: items }, ...extra });
const sync = (who, kind, id, revision, payload, mutation = randomUUID(), deleted = false) =>
  who.client.rpc('sync_document', { p_kind: kind, p_id: id, p_expected_revision: revision, p_payload: payload, p_deleted: deleted, p_mutation_id: mutation });

console.log('【同步】');
const first = randomUUID();
let r = await sync(alice, 'trip', tripID, 0, trip('東京 5 天', [socks]), first);
check(r.data?.status === 'applied' && r.data.document.revision === 1, 'Alice 上傳一趟行程（revision 1）', errorText(r.error));
r = await sync(alice, 'trip', tripID, 0, trip('東京 5 天', [socks]), first);
check(r.data?.document?.revision === 1, '網路重試同一筆修改，revision 不增加', errorText(r.error));
r = await sync(alice, 'trip', tripID, 1, trip('東京 5 天（改）', [socks]));
check(r.data?.document?.revision === 2, '修改後 revision 變 2', errorText(r.error));
r = await sync(alice, 'trip', tripID, 1, trip('另一台手機的舊版', [socks]));
check(r.data?.status === 'conflict', '用舊版本修改 → 回傳衝突，不覆蓋', JSON.stringify(r.data ?? r.error));

console.log('\n【健康類物品】');
r = await sync(alice, 'trip', tripID, 2, trip('東京 5 天（改）', [socks, medicine]));
check(Boolean(r.error), '沒有同意就上傳藥品 → 被資料庫擋下', '應該失敗卻成功了');
r = await sync(alice, 'trip', tripID, 2, trip('東京 5 天（改）', [socks, medicine], { healthSyncConsent: true }));
check(r.data?.document?.revision === 3, '使用者同意後可以上傳', errorText(r.error));
const libraryID = randomUUID();
r = await sync(alice, 'library', libraryID, 0, { version: 1, library: { id: libraryID, name: '眼罩', categoryRaw: 'other' } });
check(r.data?.status === 'applied', 'Alice 上傳一個常備用品', errorText(r.error));

console.log('\n【使用者隔離】');
let q = await bob.client.from('user_documents').select('*');
check(!q.error && q.data.length === 0, 'Bob 看不到 Alice 的資料', errorText(q.error));
q = await bob.client.from('user_documents').update({ deleted: true }).eq('owner_id', alice.id).select();
check(Boolean(q.error) || q.data?.length === 0, 'Bob 不能直接改資料表', JSON.stringify(q.data));
q = await alice.client.from('user_documents').select('*');
check(q.data?.length === 2, 'Alice 只看得到自己的 2 份資料', errorText(q.error));
q = await alice.client.from('admin_users').select('*');
check(Boolean(q.error) || q.data?.length === 0, '一般使用者讀不到管理員名單', JSON.stringify(q.data));
q = await alice.client.from('admin_audit_log').select('*');
check(Boolean(q.error) || q.data?.length === 0, '一般使用者讀不到稽核紀錄', JSON.stringify(q.data));
const anon = createClient(settings.url, settings.publicKey, options);
q = await anon.from('user_documents').select('*');
check(Boolean(q.error) || q.data?.length === 0, '未登入讀不到任何資料', JSON.stringify(q.data));

console.log('\n【管理員】');
const reason = 'smoke test：使用者回報清單錯誤';
r = await alice.client.rpc('admin_list_documents', { p_user: alice.id, p_reason: reason });
check(Boolean(r.error), '不在管理員名單 → 拒絕', '應該失敗卻成功了');
const { error: addAdminError } = await service.from('admin_users').insert({ user_id: support.id });
check(!addAdminError, '把 support 加進管理員名單', errorText(addAdminError));
r = await support.client.rpc('admin_list_documents', { p_user: alice.id, p_reason: reason });
check(Boolean(r.error) && /mfa/i.test(r.error.message), '管理員還沒通過 MFA → 拒絕', errorText(r.error));

const { data: factor, error: enrollError } = await support.client.auth.mfa.enroll({ factorType: 'totp' });
check(!enrollError, 'support 設定 TOTP 兩步驟驗證', errorText(enrollError));
const { error: verifyError } = factor
  ? await support.client.auth.mfa.challengeAndVerify({ factorId: factor.id, code: totp(factor.totp.secret) })
  : { error: enrollError };
check(!verifyError, 'support 輸入驗證碼，登入升級為 aal2', errorText(verifyError));

r = await support.client.rpc('admin_list_documents', { p_user: alice.id, p_reason: '  ' });
check(Boolean(r.error), '沒填原因 → 拒絕', '應該失敗卻成功了');
r = await support.client.rpc('admin_find_user', { p_email: `ALICE@${domain}`, p_reason: reason });
check(r.data?.[0]?.user_id === alice.id && Number(r.data[0].trip_count) === 1, '用 Email 找到 Alice（1 趟行程）', errorText(r.error));
r = await support.client.rpc('admin_list_documents', { p_user: alice.id, p_reason: reason });
check(r.data?.length === 2, '管理員查看 Alice 的 2 份資料', errorText(r.error));
r = await support.client.rpc('admin_update_document', {
  p_user: alice.id, p_kind: 'trip', p_id: tripID, p_expected_revision: 3,
  p_payload: trip('東京 5 天（管理員修正）', [socks, medicine], { healthSyncConsent: true }), p_deleted: false, p_reason: reason,
});
check(r.data?.status === 'applied' && r.data.document.revision === 4, '管理員修正 Alice 的行程（revision 4）', errorText(r.error));
q = await alice.client.from('user_documents').select('revision, payload').eq('kind', 'trip');
check(q.data?.[0]?.payload?.trip?.name === '東京 5 天（管理員修正）', 'Alice 同步時拿到修正後的版本', JSON.stringify(q.data ?? q.error));

console.log('\n【刪除帳號（Edge Function）】');
const call = async (client, name, body) => {
  const { data: { session } } = await client.auth.getSession();
  try {
    const response = await fetch(`${settings.url}/functions/v1/${name}`, {
      method: 'POST', headers: { Authorization: `Bearer ${session.access_token}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body),
    });
    return response.status;
  } catch { return 0; }
};
let status = await call(alice.client, 'admin-delete-user', { user_id: bob.id, reason });
if (status === 0 || status === 404) {
  console.log('- 跳過：Edge Functions 沒有在跑。另開一個終端機執行 `supabase functions serve` 後再跑一次。');
} else {
  check(status === 403, '一般使用者呼叫 admin-delete-user → 403', `HTTP ${status}`);
  status = await call(support.client, 'admin-delete-user', { user_id: bob.id, reason });
  check(status === 200, '管理員刪除 Bob 的帳號', `HTTP ${status}`);
  const { data: gone } = await service.auth.admin.getUserById(bob.id);
  check(!gone?.user, 'Bob 的帳號確實被刪除');
}

const { data: audit, error: auditError } = await service.from('admin_audit_log')
  .select('action, target_user_id, reason').eq('actor_id', support.id).order('id');
check(!auditError && audit.length >= 4, `稽核紀錄寫入 ${audit?.length ?? 0} 筆：${(audit ?? []).map(a => a.action).join('、')}`, errorText(auditError));

console.log(`\n${failures === 0 ? '全部通過' : `${failures} 項失敗`}。`);
console.log(`打開 Studio 看資料：${settings.studio}`);
console.log('  Table Editor → user_documents（Alice 的行程與常備用品）、admin_audit_log（support 的操作紀錄）');
console.log('  Authentication → alice、support（bob 若刪除成功就不在了）');
process.exit(failures === 0 ? 0 : 1);
