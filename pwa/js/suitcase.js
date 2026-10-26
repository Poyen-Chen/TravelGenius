// 行李箱格子規則（PD-061，與 iOS SuitcaseProgressView 相同）：
// - 最多 12 格；物品不超過 12 件時一件一格。
// - 超過 12 件時，打包 11 件以內一件一格；之後放最近勾的 11 件，最後一格顯示「+K」；全部打包完才 12 格全滿。
// - 依勾選時間排列，最新的在最後，所以剛勾的那件一定看得到。
export const SLOT_LIMIT = 12;

/// items：行程的打包項目；packedAt：{ 物品ID: 勾選時間 }（沒有紀錄的照清單順序排在前面）。
/// 回傳 { slots, shown: [物品], overflow: K }。
export function suitcaseSlots(items, packedAt = {}) {
  const slots = Math.max(1, Math.min(items.length, SLOT_LIMIT));
  const packed = items.map((item, index) => ({ item, index })).filter(x => x.item.isPacked)
    .sort((a, b) => (packedAt[a.item.id] ?? -1) - (packedAt[b.item.id] ?? -1) || a.index - b.index)
    .map(x => x.item);
  const allPacked = packed.length === items.length;
  if (items.length <= SLOT_LIMIT || packed.length < slots || allPacked) return { slots, shown: packed.slice(-slots), overflow: 0 };
  const shown = packed.slice(-(slots - 1));
  return { slots, shown, overflow: packed.length - shown.length };
}
