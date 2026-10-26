// 以 iOS 的 2,916 組情境（scripts/PackingCompatibility.swift）比對網頁版引擎輸出。
// 用法：node pwa/tests/engine-parity.mjs <Swift 產生的 actual.json>
import { readFile } from 'node:fs/promises';
import assert from 'node:assert/strict';
const root = new URL('../', import.meta.url);
globalThis.fetch = async url => ({ json: async () => JSON.parse(await readFile(new URL(url, root), 'utf8')) });
const { loadData, generate, DEVICES, NEEDS } = await import('../js/engine.js');
await loadData();
const expected = JSON.parse(await readFile(process.argv[2], 'utf8'));
const acts = ['water', 'outdoors', 'snow', 'skiing', 'exercise', 'business', 'formal', 'driving'];
const rows = [];
for (const country of ['JP', 'KR', 'US']) for (const month of [1, 6, 10]) for (const days of [1, 5, 12])
  for (const style of ['light', 'normal', 'full']) for (const activities of [[], acts, [...acts].reverse()]) for (const laundry of ['unknown', 'yes', 'no']) {
    const start = new Date(2026, month - 1, 1), end = new Date(2026, month - 1, days);
    const trip = { countryCode: country, originCountryCode: 'TW', city: '', startDate: start.toISOString(), endDate: end.toISOString(),
      packingPreferencesRaw: JSON.stringify({ packingStyle: style, devices: Object.keys(DEVICES), needs: Object.keys(NEEDS) }),
      packingContextRaw: JSON.stringify({ activities, stays: ['hostel'], laundry }), packingWeatherRaw: '' };
    for (const weather of [[], ['hot'], ['cold', 'rain'], ['mild', 'rain']])
      rows.push(generate(trip, { weatherTags: new Set(weather) }).map(i => `${i.id}|${i.name}|${i.category}|${i.quantity}|${i.reason}|${i.sortIndex}`));
  }
assert.equal(rows.length, expected.length, 'scenario count');
let mismatch = 0;
rows.forEach((r, n) => { if (JSON.stringify(r) !== JSON.stringify(expected[n])) { if (mismatch++ < 3) console.log('case', n, '\n js:', r, '\n ios:', expected[n]); } });
assert.equal(mismatch, 0, `${mismatch} 組與 iOS 不同`);
console.log(`網頁版引擎與 iOS 一致：${rows.length} 組情境：PASS`);
