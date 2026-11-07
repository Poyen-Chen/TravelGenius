// 帳號與雲端同步：移植自 iOS 的 SupabaseClient／CloudSyncEngine（PD-062）。
// 使用同一個 Supabase、同一個 payload version 1，所以 iPhone 與網頁版讀寫同一趟行程。
import { CONFIG } from './config.js';
import { store, save, compact } from './store.js';
import { appleIdTokenRequest, appleErrorKey, APPLE_MESSAGES } from './auth.js';
export { accountLabel } from './auth.js';

const SESSION_KEY = 'packsmart.session';
const STATE_KEY = 'packsmart.cloud.state';
const SYNC_KEY = 'packsmart.cloud.sync';
const read = key => { try { return JSON.parse(localStorage.getItem(key) || 'null'); } catch { return null; } };
const write = (key, value) => { try { value == null ? localStorage.removeItem(key) : localStorage.setItem(key, JSON.stringify(value)); } catch {} };

export const configured = () => Boolean(CONFIG?.url && CONFIG?.publishableKey && !CONFIG.publishableKey.startsWith('sb_secret_'));
/// Apple 登入按鈕：要設定 Services ID 才顯示（PD-068）。網址還沒確定前保持空白。
export const appleEnabled = () => configured() && typeof CONFIG.appleServicesID === 'string' && CONFIG.appleServicesID.length > 0;
export let session = read(SESSION_KEY);
export const syncEnabled = () => read(SYNC_KEY) === true;
export const setSyncEnabled = value => write(SYNC_KEY, value);

export class CloudError extends Error {}
const messages = { ...APPLE_MESSAGES, offline: '目前沒有網路連線，資料先保存在這台裝置。', notSignedIn: '請先登入。', invalidCode: '驗證碼錯誤或已過期，請重新輸入或重新寄送。',
  rateLimited: '寄送太頻繁，請稍後再試。', differentAccount: '這台裝置的資料已經和另一個帳號同步過。第一版不支援切換帳號，請用原本的帳號登入。' };
const makeError = (code, status) => { const e = new CloudError(messages[code] || `雲端服務暫時無法使用（${status}），請稍後再試。`); e.code = code; return e; };
const fail = (code, status) => { throw makeError(code, status); };

async function request(path, { method = 'POST', json, authorized = false } = {}) {
  const headers = { apikey: CONFIG.publishableKey, 'Content-Type': 'application/json' };
  if (authorized) headers.Authorization = `Bearer ${await accessToken()}`;
  let response;
  try { response = await fetch(`${CONFIG.url}/${path}`, { method, headers, body: method === 'GET' ? undefined : JSON.stringify(json ?? {}), signal: AbortSignal.timeout(20000) }); }
  catch { fail('offline'); }
  const text = await response.text();
  if (response.status === 429) { const e = makeError('rateLimited', 429); e.status = 429; throw e; }
  if (!response.ok) {
    // 保留 error_code，才分得出「Email 已有帳號」和「Apple 設定錯誤」；內容本身不顯示給使用者。
    let body = null; try { body = JSON.parse(text); } catch {}
    const e = new CloudError(`雲端服務暫時無法使用（${response.status}），請稍後再試。`);
    e.status = response.status; e.errorCode = body?.error_code ?? body?.code ?? null; e.msg = body?.msg ?? body?.message ?? null;
    throw e;
  }
  return text ? JSON.parse(text) : null;
}

function storeSession(value, email) {
  session = { accessToken: value.access_token, refreshToken: value.refresh_token, expiresAt: Date.now() + value.expires_in * 1000,
    userID: value.user.id, email: value.user.email || email || session?.email || '' };
  write(SESSION_KEY, session);
}
async function accessToken() {
  if (!session) fail('notSignedIn');
  if (session.expiresAt > Date.now() + 60000) return session.accessToken;
  try { storeSession(await request('auth/v1/token?grant_type=refresh_token', { json: { refresh_token: session.refreshToken } })); }
  catch (e) { if (e.status >= 400 && e.status < 500) { session = null; write(SESSION_KEY, null); fail('notSignedIn'); } throw e; }
  return session.accessToken;
}

export const sendCode = email => request('auth/v1/otp', { json: { email, create_user: true } });
export async function verify(email, code) {
  try { storeSession(await request('auth/v1/verify', { json: { type: 'email', email, token: code } }), email); }
  catch (e) { if ([400, 401, 403, 422].includes(e.status)) fail('invalidCode'); throw e; }
}
/// Sign in with Apple：identity token 由 Supabase 驗證；瀏覽器只送 provider、id_token、nonce。
export async function signInWithApple({ idToken, nonce }) {
  const { path, json } = appleIdTokenRequest({ idToken, nonce });
  try { storeSession(await request(path, { json })); }
  catch (e) { const key = e.code === 'offline' ? null : appleErrorKey(e, false); if (key) fail(key); throw e; }
}
/// 把 Apple 綁到目前登入的帳號：同一個 user id，雲端資料的 owner 不變；失敗不登出、不刪帳號。
export async function linkApple({ idToken, nonce }) {
  if (!session) fail('notSignedIn');
  const { path, json } = appleIdTokenRequest({ idToken, nonce, link: true });
  let value;
  try { value = await request(path, { json, authorized: true }); }
  catch (e) { const key = e.code === 'offline' || e.code === 'notSignedIn' ? null : appleErrorKey(e, true); if (key) fail(key); throw e; }
  if (value?.access_token && value.user?.id === session?.userID) storeSession(value);
}
/// 帳號已經綁定的登入方式，例如 ['email', 'apple']。
export async function linkedProviders() {
  const user = await request('auth/v1/user', { method: 'GET', authorized: true });
  return new Set((user?.identities || []).map(i => i.provider));
}
export async function signOut() {
  if (session) await request('auth/v1/logout', { authorized: true }).catch(() => {});
  session = null; write(SESSION_KEY, null); setSyncEnabled(false);
}
export async function deleteAccount() {
  await request('functions/v1/delete-account', { authorized: true });
  session = null; write(SESSION_KEY, null); write(STATE_KEY, null); setSyncEnabled(false);
}
/// 健康類的同意存在帳號上，每台裝置讀同一個值（與 iOS 相同的理由）。
export async function healthConsent() { const user = await request('auth/v1/user', { method: 'GET', authorized: true }); return user?.user_metadata?.health_sync_consent === true; }
export const setHealthConsent = value => request('auth/v1/user', { method: 'PUT', json: { data: { health_sync_consent: value } }, authorized: true });

// ---------- 文件格式 ----------
const HEALTH = 'health';
function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') return `{${Object.keys(value).sort().map(k => `${JSON.stringify(k)}:${canonical(value[k])}`).join(',')}}`;
  return JSON.stringify(value);
}
async function hash(payload) {
  const { healthSyncConsent, ...content } = payload; // 同意旗標不算內容
  const bytes = new TextEncoder().encode(canonical(content));
  return [...new Uint8Array(await crypto.subtle.digest('SHA-256', bytes))].map(b => b.toString(16).padStart(2, '0')).join('');
}
const tripFields = ['id', 'name', 'countryCode', 'city', 'originCountryCode', 'originCity', 'startDate', 'endDate', 'homeCurrencyCode', 'localCurrencyCode',
  'tripTypeRaw', 'isClosed', 'startedAt', 'completedAt', 'hasReviewedTravelRules', 'excludedPackingNamesRaw', 'excludedPackingIDsRaw',
  'packingPreferencesRaw', 'packingWeatherRaw', 'packingContextRaw', 'packingReviewPending', 'createdAt'];
const itemFields = ['id', 'name', 'catalogItemID', 'categoryRaw', 'reasonKey', 'quantity', 'unitWeightKg', 'isPacked', 'isCustom', 'sortIndex'];
const libraryFields = ['id', 'name', 'categoryRaw', 'quantity', 'unitWeightKg', 'isEssential', 'sortIndex', 'useCount', 'lastUsedAt'];
const pick = (object, fields) => compact(Object.fromEntries(fields.map(f => [f, object[f]])));
const key = (kind, id) => `${kind}:${id.toLowerCase()}`;

function localDocuments(includeHealth) {
  const docs = new Map();
  for (const t of store.trips) {
    const items = t.packingItems.map(i => pick(i, itemFields)).filter(i => includeHealth || i.categoryRaw !== HEALTH).sort((a, b) => a.id < b.id ? -1 : 1);
    const omitted = t.packingItems.length - items.length;
    docs.set(key('trip', t.id), compact({ version: 1, trip: { ...pick(t, tripFields), packingItems: items }, healthSyncConsent: includeHealth || null, omittedPrivateCount: omitted || null }));
  }
  for (const item of store.library) if (includeHealth || item.categoryRaw !== HEALTH)
    docs.set(key('library', item.id), compact({ version: 1, library: pick(item, libraryFields), healthSyncConsent: includeHealth || null }));
  return docs;
}

function applyRemote(kind, id, payload, includeHealth) {
  if (kind === 'trip') {
    const remote = payload.trip, index = store.trips.findIndex(t => t.id.toLowerCase() === id);
    const local = index >= 0 ? store.trips[index] : null;
    const kept = !includeHealth && local ? local.packingItems.filter(i => i.categoryRaw === HEALTH && !remote.packingItems.some(r => r.id === i.id)) : [];
    const next = { ...(local || {}), ...remote, packingItems: [...remote.packingItems, ...kept] };
    if (index >= 0) store.trips[index] = next; else store.trips.push(next);
  } else {
    const remote = payload.library;
    // 兩台裝置離線各自新增同名用品時保留雲端那一份；本機那份已上傳的話，下次同步會送出刪除。
    store.library = store.library.filter(i => i.id.toLowerCase() === id || i.name.trim().toLowerCase() !== remote.name.trim().toLowerCase());
    const index = store.library.findIndex(i => i.id.toLowerCase() === id);
    if (index >= 0) store.library[index] = { ...remote }; else store.library.push({ ...remote });
  }
}
function deleteLocal(kind, id, includeHealth) {
  if (kind === 'trip') store.trips = store.trips.filter(t => t.id.toLowerCase() !== id);
  else store.library = store.library.filter(i => i.id.toLowerCase() !== id || (!includeHealth && i.categoryRaw === HEALTH));
}

// ---------- 同步 ----------
const realm = () => `${new URL(CONFIG.url).host}|${session.userID.toLowerCase()}`;
async function write_(kind, id, payload, expected) {
  return request('rest/v1/rpc/sync_document', { authorized: true, json: { p_kind: kind, p_id: id, p_expected_revision: expected, p_payload: payload ?? null, p_deleted: !payload, p_mutation_id: crypto.randomUUID() } });
}

export async function synchronize() {
  if (!session) fail('notSignedIn');
  const includeHealth = await healthConsent();
  const state = read(STATE_KEY) || { realm: null, records: {} };
  if (state.realm && state.realm !== realm()) fail('differentAccount');
  const remoteList = await request('rest/v1/user_documents?select=kind,id,revision,payload,deleted', { method: 'GET', authorized: true });
  const remote = new Map(remoteList.map(d => [key(d.kind, d.id), d]));
  const local = localDocuments(includeHealth);
  const keys = new Set([...local.keys(), ...remote.keys(), ...Object.keys(state.records)]);
  const summary = { uploaded: 0, downloaded: 0, deleted: 0, conflicts: [] };

  for (const k of [...keys].sort()) {
    const [kind, id] = k.split(':');
    const L = local.get(k) ?? null, R = remote.get(k) ?? null, rec = state.records[k];
    const localHash = L ? await hash(L) : 'deleted';
    const localChanged = rec ? rec.hash !== localHash : L !== null;
    const remoteChanged = rec ? (R ? R.revision !== rec.revision : false) : R !== null;
    if (!localChanged && !remoteChanged) continue;
    if (localChanged && !remoteChanged) {
      if (!R && !L) { delete state.records[k]; continue; }
      const result = await write_(kind, id, L, R ? (rec?.revision ?? 0) : 0);
      if (result.status === 'applied') { state.records[k] = { revision: result.document.revision, hash: localHash }; summary.uploaded++; }
      else summary.conflicts.push({ key: k, kind, id, title: L ? (L.trip?.name ?? L.library?.name) : null, remote: result.document });
    } else if (!localChanged && remoteChanged) {
      if (R.deleted || !R.payload) { deleteLocal(kind, id, includeHealth); state.records[k] = { revision: R.revision, hash: 'deleted' }; summary.deleted++; }
      else { applyRemote(kind, id, R.payload, includeHealth); const after = localDocuments(includeHealth).get(k); state.records[k] = { revision: R.revision, hash: after ? await hash(after) : 'deleted' }; summary.downloaded++; }
    } else {
      const remoteHash = R.deleted ? 'deleted' : await hash(R.payload);
      if (remoteHash === localHash) state.records[k] = { revision: R.revision, hash: localHash };
      else summary.conflicts.push({ key: k, kind, id, title: L ? (L.trip?.name ?? L.library?.name) : null, remote: R });
    }
  }
  state.realm = realm();
  save(); write(STATE_KEY, state); write('packsmart.cloud.last', Date.now());
  return summary;
}

/// 使用者選擇保留哪一版；保留本機版本時以雲端目前的 revision 為基準。
export async function resolve(conflict, keepLocal) {
  const includeHealth = await healthConsent();
  const state = read(STATE_KEY) || { realm: realm(), records: {} };
  if (keepLocal) {
    const L = localDocuments(includeHealth).get(conflict.key) ?? null;
    const result = await write_(conflict.kind, conflict.id, L, conflict.remote.revision);
    if (result.status === 'applied') state.records[conflict.key] = { revision: result.document.revision, hash: L ? await hash(L) : 'deleted' };
  } else {
    const R = conflict.remote;
    if (R.deleted || !R.payload) { deleteLocal(conflict.kind, conflict.id, includeHealth); state.records[conflict.key] = { revision: R.revision, hash: 'deleted' }; }
    else { applyRemote(conflict.kind, conflict.id, R.payload, includeHealth); const after = localDocuments(includeHealth).get(conflict.key); state.records[conflict.key] = { revision: R.revision, hash: await hash(after) }; }
  }
  save(); write(STATE_KEY, state);
}
export const lastSynced = () => read('packsmart.cloud.last');
