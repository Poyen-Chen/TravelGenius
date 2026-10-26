// 本機資料（瀏覽器 localStorage）。行程與常備用品直接用雲端 payload version 1 的形狀，
// 和 iOS 的 CloudTrip／CloudLibraryItem 欄位相同，同步時不需要轉換。
const KEY = 'packsmart.app.v1';
const empty = () => ({ trips: [], library: [], prefs: { packingStyle: 'normal', devices: ['phone'], needs: [] }, checks: {}, mode: 'image', onboarded: false });

export let store = load();
function load() {
  try { const value = JSON.parse(localStorage.getItem(KEY) || 'null'); if (value?.trips) return { ...empty(), ...value }; } catch {}
  return empty();
}
export function save() {
  try { localStorage.setItem(KEY, JSON.stringify(store)); return true; } catch { return false; }
}
export function replaceStore(next) { store = next; save(); }

export const uuid = () => crypto.randomUUID().toUpperCase();
export const essentials = () => store.library.filter(i => i.isEssential).sort((a, b) => a.sortIndex - b.sortIndex);
export const normalized = name => name.trim().toLowerCase().replace(/\s+/g, ' ');
export const trip = id => store.trips.find(t => t.id === id);
export const sortedItems = t => [...t.packingItems].sort((a, b) => a.sortIndex - b.sortIndex || a.name.localeCompare(b.name, 'zh-Hant'));
export const progress = t => { const total = t.packingItems.length, packed = t.packingItems.filter(i => i.isPacked).length; return { total, packed, remaining: total - packed }; };

/// 沒有值的欄位省略，和 Swift 的 Codable 輸出一致。
export function compact(object) {
  const out = {};
  for (const [k, v] of Object.entries(object)) if (v !== null && v !== undefined) out[k] = v;
  return out;
}
