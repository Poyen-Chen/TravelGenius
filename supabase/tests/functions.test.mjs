// 以模擬的 Supabase 與 Deno 執行真正的 Edge Function 程式碼，不會送出任何請求。
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const environment = { SUPABASE_URL: 'https://test.invalid', SUPABASE_ANON_KEY: 'public', SUPABASE_SERVICE_ROLE_KEY: 'server-only' };

async function load(name, clients) {
  const source = (await readFile(new URL(`../functions/${name}/index.ts`, import.meta.url), 'utf8'))
    .replace(/^import .*;\n/m, '');
  let handler;
  vm.runInNewContext(source, {
    Response,
    Deno: { serve: fn => { handler = fn; }, env: { get: key => environment[key] } },
    createClient: (_url, key, options) => clients(key, options),
  });
  return handler;
}
const request = (method = 'POST', token, body) => new Request('https://test.invalid/fn', {
  method, headers: token ? { Authorization: `Bearer ${token}` } : {}, body: body === undefined ? undefined : JSON.stringify(body),
});

// --- delete-account：只刪驗證過的本人 ---
{
  let valid = true, fails = false; const deleted = [];
  const handler = await load('delete-account', key => ({
    auth: key === 'public'
      ? { getUser: async () => ({ data: { user: valid ? { id: 'verified-user' } : null }, error: valid ? null : new Error('invalid') }) }
      : { admin: { deleteUser: async id => { deleted.push(id); return { error: fails ? new Error('x') : null }; } } },
  }));
  assert.equal((await handler(request('GET'))).status, 405);
  assert.equal((await handler(request())).status, 401);
  valid = false;
  assert.equal((await handler(request('POST', 'bad'))).status, 401);
  valid = true;
  const ok = await handler(request('POST', 'good', { user_id: 'someone-else' }));
  assert.equal(ok.status, 200); assert.deepEqual(await ok.json(), { deleted: true });
  assert.deepEqual(deleted, ['verified-user'], '不能刪除請求指定的其他帳號');
  assert.equal(ok.headers.get('Cache-Control'), 'no-store');
  fails = true;
  assert.equal((await handler(request('POST', 'good'))).status, 500);
}

// --- admin-delete-user：資料庫授權通過才刪除 ---
{
  let rpcError = null; const deleted = [], rpcCalls = [];
  const handler = await load('admin-delete-user', (key, options) => key === 'public'
    ? { rpc: async (name, args) => { rpcCalls.push({ name, args, auth: options.global.headers.Authorization }); return { error: rpcError }; } }
    : { auth: { admin: { deleteUser: async id => { deleted.push(id); return { error: null }; } } } });
  assert.equal((await handler(request('POST'))).status, 401);
  assert.equal((await handler(request('POST', 'admin-token', { user_id: 'u1' }))).status, 400, '缺少原因');
  rpcError = { code: '42501' };
  assert.equal((await handler(request('POST', 'user-token', { user_id: 'u1', reason: '使用者要求刪除' }))).status, 403);
  rpcError = { code: 'P0002' };
  assert.equal((await handler(request('POST', 'admin-token', { user_id: 'missing', reason: '使用者要求刪除' }))).status, 404);
  assert.equal(deleted.length, 0, '授權失敗不能刪除');
  rpcError = null;
  const ok = await handler(request('POST', 'admin-token', { user_id: 'u1', reason: '使用者要求刪除' }));
  assert.equal(ok.status, 200); assert.deepEqual(deleted, ['u1']);
  assert.deepEqual(JSON.parse(JSON.stringify(rpcCalls.at(-1))), { name: 'admin_authorize_user_deletion', args: { p_user: 'u1', p_reason: '使用者要求刪除' }, auth: 'Bearer admin-token' },
    '必須以管理員自己的 token 呼叫資料庫授權');
  delete environment.SUPABASE_SERVICE_ROLE_KEY;
  assert.equal((await handler(request('POST', 'admin-token', { user_id: 'u1', reason: '使用者要求刪除' }))).status, 503);
}

console.log('delete-account 只刪本人、admin-delete-user 授權失敗不刪除且以呼叫者身分授權：PASS');
