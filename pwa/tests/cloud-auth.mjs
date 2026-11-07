// Sign in with Apple 的純函式與網頁版的邊界（PD-068）。執行：node pwa/tests/cloud-auth.mjs
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { appleIdTokenRequest, accountLabel, makeAppleNonce, sha256Hex, appleErrorKey } from '../js/auth.js';

const root = new URL('../', import.meta.url);

// 登入與綁定的請求內容
const signIn = appleIdTokenRequest({ idToken: 'tok', nonce: 'raw' });
assert.equal(signIn.path, 'auth/v1/token?grant_type=id_token');
assert.equal(signIn.authorized, false);
assert.deepEqual(Object.keys(signIn.json).sort(), ['id_token', 'nonce', 'provider']);
assert.equal(signIn.json.provider, 'apple');
const link = appleIdTokenRequest({ idToken: 'tok', nonce: 'raw', link: true });
assert.equal(link.authorized, true);
assert.equal(link.json.link_identity, true);
assert.equal(link.json.access_token, undefined, '目前的 token 放在 Authorization，不放在 JSON');
for (const request of [signIn, link]) for (const key of ['secret', 'client_secret', 'key']) assert.ok(!(key in request.json), `沒有 ${key}`);

// nonce：Apple 收到 hash，Supabase 收到 raw；每次不同。
assert.equal(await sha256Hex('abc'), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
const a = await makeAppleNonce(), b = await makeAppleNonce();
assert.match(a.raw, /^[A-Za-z0-9_-]+$/);
assert.equal(a.hashed, await sha256Hex(a.raw));
assert.notEqual(a.raw, b.raw);

// 顯示名稱
assert.equal(accountLabel('x@privaterelay.appleid.com'), 'Apple 帳號');
assert.equal(accountLabel('X@PrivateRelay.AppleID.com'), 'Apple 帳號');
assert.equal(accountLabel(''), 'Apple 帳號');
assert.equal(accountLabel('alice@example.com'), 'alice@example.com');

// 錯誤代號：綁定衝突與未開啟手動綁定只用在綁定時。
assert.equal(appleErrorKey({ status: 422, errorCode: 'email_exists' }), 'emailAlreadyUsed');
assert.equal(appleErrorKey({ status: 500, errorCode: 'email_exists' }), 'emailAlreadyUsed');
assert.equal(appleErrorKey({ status: 422, errorCode: 'identity_already_exists' }, true), 'appleIdentityTaken');
assert.equal(appleErrorKey({ status: 422, errorCode: 'identity_already_exists' }, false), 'appleFailed');
assert.equal(appleErrorKey({ status: 422, errorCode: 'manual_linking_disabled' }, true), 'linkingUnavailable');
assert.equal(appleErrorKey({ status: 429 }), 'appleRateLimited');
assert.equal(appleErrorKey({ status: 400, errorCode: 'bad_jwt' }), 'appleFailed');
assert.equal(appleErrorKey({ status: 503 }), null);

// 網頁版沒有 Face ID／生物辨識控制項。
const sources = [...readdirSync(new URL('js/', root)).filter(f => f.endsWith('.js')).map(f => `js/${f}`), 'index.html'];
for (const file of sources) {
  const text = readFileSync(new URL(file, root), 'utf8');
  for (const word of ['Face ID', 'Touch ID', '生物辨識', 'PublicKeyCredential']) assert.ok(!text.includes(word), `${file} 不應出現 ${word}`);
}

// Apple 的網域驗證檔不被快取、也不退回 index.html：要在任何快取處理之前直接放行。
const sw = readFileSync(new URL('sw.js', root), 'utf8');
const fetchHandler = sw.slice(sw.indexOf("addEventListener('fetch'"));
const bypass = fetchHandler.indexOf('apple-developer-domain-association.txt');
assert.ok(bypass > 0, 'service worker 要處理 Apple 網域驗證檔');
assert.ok(bypass < fetchHandler.indexOf("caches.match('index.html')") && bypass < fetchHandler.indexOf('caches.open'), '在快取與 index.html 退回之前放行');
assert.ok(!readFileSync(new URL('precache.json', root), 'utf8').includes('.well-known'), '不放進離線快取清單');

console.log('Apple 登入請求、nonce、顯示名稱、錯誤代號、沒有 Face ID、網域驗證檔不快取：PASS');
