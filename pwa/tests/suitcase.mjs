// 行李箱格子規則：node pwa/tests/suitcase.mjs
import assert from 'node:assert/strict';
import { suitcaseSlots } from '../js/suitcase.js';

const make = n => Array.from({ length: n }, (_, i) => ({ id: `i${i}`, isPacked: false }));

// 20 件：打亂順序逐一勾選，剛勾的一定出現，填滿格數不減少。
{
  const items = make(20), packedAt = {}, order = [7, 0, 19, 3, 12, 5, 18, 1, 9, 14, 2, 16, 4, 11, 8, 6, 17, 10, 13, 15];
  let previous = 0;
  order.forEach((index, step) => {
    const item = items[index]; item.isPacked = true; packedAt[item.id] = step;
    const { slots, shown, overflow } = suitcaseSlots(items, packedAt);
    const used = shown.length + (overflow ? 1 : 0);
    assert.equal(slots, 12);
    assert.ok(shown.at(-1) === item, `第 ${step + 1} 件（${item.id}）應該出現在行李箱最後一格`);
    assert.ok(used >= previous, '已填格數不應變少');
    const packed = step + 1;
    if (packed <= 11) assert.deepEqual([shown.length, overflow], [packed, 0], '11 件以內一件一格');
    else if (packed < 20) assert.deepEqual([shown.length, overflow], [11, packed - 11], '之後放 11 件＋「+K」');
    else assert.deepEqual([shown.length, overflow], [12, 0], '全部打包完 12 格全滿');
    previous = used;
  });
}
// 8 件：一件一格，格數等於件數。
{
  const items = make(8);
  items[5].isPacked = true; items[2].isPacked = true;
  const { slots, shown, overflow } = suitcaseSlots(items, { i5: 1, i2: 2 });
  assert.deepEqual([slots, shown.map(i => i.id), overflow], [8, ['i5', 'i2'], 0]);
}
// 沒有勾選時間（例如從雲端同步來的）照清單順序。
{
  const items = make(5); items[3].isPacked = true; items[1].isPacked = true;
  assert.deepEqual(suitcaseSlots(items).shown.map(i => i.id), ['i1', 'i3']);
}
console.log('行李箱規則：剛勾的一定出現、格數不減少、+K 與全滿：PASS');
