// Sign in with Apple 的純函式（PD-068）：不讀設定、不碰網路，方便測試。
// 網頁版沒有本機解鎖：瀏覽器存的登入狀態沒辦法綁到 Secure Enclave，做一個只遮畫面的按鈕是假的。

/// Supabase id_token grant 的請求。link=true 時是把 Apple 綁到目前登入的帳號（帶目前的 token）。
export function appleIdTokenRequest({ idToken, nonce, link = false }) {
  const json = { provider: 'apple', id_token: idToken, nonce };
  if (link) json.link_identity = true;
  return { path: 'auth/v1/token?grant_type=id_token', authorized: Boolean(link), json };
}

/// Apple 的轉寄地址或空白顯示成「Apple 帳號」。
export function accountLabel(email) {
  if (!email || email.toLowerCase().endsWith('@privaterelay.appleid.com')) return 'Apple 帳號';
  return email;
}

export async function sha256Hex(text) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, '0')).join('');
}

/// raw 送給 Supabase，hashed 交給 Apple；兩者對調會讓每次登入都失敗。每次登入都用新的一組。
export async function makeAppleNonce() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const raw = btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  return { raw, hashed: await sha256Hex(raw) };
}

export const APPLE_MESSAGES = {
  appleFailed: 'Apple 登入沒有成功，請再試一次。',
  appleRateLimited: '登入太頻繁，請稍後再試。',
  emailAlreadyUsed: '這個 Email 已經有 PackSmart 帳號，請改用驗證碼登入。',
  appleIdentityTaken: '這個 Apple 帳號已經綁在另一個 PackSmart 帳號上。',
  linkingUnavailable: '暫時無法綁定 Apple。',
  appleIncomplete: 'Apple 登入沒有完成，請改用 Email。',
  linked: '已可以用 Apple 登入這個帳號。',
};

/// Supabase Auth 的錯誤（status、error_code、msg）對應到一句話的代號；5xx 回傳 null，沿用一般的雲端錯誤句子。
export function appleErrorKey({ status, errorCode, msg }, linking = false) {
  if (status === 429 || errorCode === 'over_request_rate_limit') return 'appleRateLimited';
  if (errorCode === 'email_exists' || (status === 500 && /multiple accounts with the same email/i.test(msg || ''))) return 'emailAlreadyUsed';
  if (linking && errorCode === 'identity_already_exists') return 'appleIdentityTaken';
  if (linking && errorCode === 'manual_linking_disabled') return 'linkingUnavailable';
  if (status >= 400 && status < 500) return 'appleFailed';
  return null;
}
