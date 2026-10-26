// 與 iOS 共用的推薦引擎：移植自 PackingRuleEngine.swift 與 PackingListGenerator.swift。
// 資料直接讀 App 的 SeedData（scripts/build_pwa_assets.sh 複製到 pwa/data/）。

export const CATEGORIES = {
  clothing: ['衣物', 'shirt'], electronics: ['電子', 'plug'], documents: ['證件', 'id-card'],
  toiletries: ['盥洗', 'droplet'], health: ['健康', 'heart-pulse'], other: ['其他', 'package'],
};
export const STYLES = { light: ['輕便', '只帶必需品，行李越輕越好'], normal: ['一般', '基本用品優先，依天數準備換洗'], full: ['準備齊全', '寧可多帶，不想到了才缺東西'] };
export const DEVICES = { phone: '手機', laptop: '筆電', tablet: '平板／電子閱讀器', camera: '相機', watch: '智慧手錶', headphones: '耳機' };
export const NEEDS = { skincare: '保養用品', period: '生理用品', 'document-backup': '旅行文件備份' };
export const ACTIVITIES = { water: '玩水／游泳', outdoors: '健行／登山', snow: '賞雪', skiing: '滑雪／單板', exercise: '運動／健身', business: '工作／商務', formal: '正式場合', driving: '自駕' };
export const STAYS = { hostel: '青旅／背包客棧' };
export const LAUNDRY = { unknown: '還不確定', yes: '途中會洗衣', no: '不會洗衣' };
export const CUSTOM_REASON = '自訂';
export const STAPLE_REASON = '我的常備用品';
export const CUSTOM_SORT = 1_000_000;

export const DATA = {};
export async function loadData() {
  const names = ['countries', 'cities', 'packing_items', 'packing_rules', 'seasonal_weather', 'border_rules', 'aviation_rules', 'prohibited_items', 'etiquette'];
  const loaded = await Promise.all(names.map(n => fetch(`data/${n}.json`).then(r => r.json())));
  names.forEach((n, i) => { DATA[n] = loaded[i]; });
  DATA.items = DATA.packing_items.items;
  DATA.itemsByID = new Map(DATA.items.map(i => [i.id, i]));
  const byNeed = new Map();
  for (const item of DATA.items) for (const need of item.satisfies || []) {
    if (!byNeed.has(need)) byNeed.set(need, []);
    byNeed.get(need).push(item);
  }
  for (const list of byNeed.values()) list.sort((a, b) => (a.priority ?? 10) - (b.priority ?? 10) || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  DATA.candidatesByNeed = byNeed;
}

export const country = code => DATA.countries.find(c => c.code === code);
export const citiesOf = code => DATA.cities.filter(c => c.countryCode === code);
export const defaultCity = code => citiesOf(code).find(c => c.isDefault) || citiesOf(code)[0];
export const artwork = id => { const item = DATA.itemsByID.get(id); return item ? `art/${item.artworkKey || item.id}.png` : null; };
export const itemByName = name => DATA.items.find(i => i.nameZh === name || (i.legacyNames || []).includes(name));

// 同一套 all／any／none 條件。
export function matches(condition, tags) {
  if (!condition) return true;
  const { all, any, none } = condition;
  return (!all || all.every(t => tags.has(t))) && (!any || any.some(t => tags.has(t))) && (!none || none.every(t => !tags.has(t)));
}

function resolveQuantity(q, days, laundry) {
  if (!q) return 1;
  const divisor = q.perDays ?? 1;
  let value = q.fixed ?? Math.floor((days * (q.multiplier ?? 1) + divisor - 1) / divisor);
  if (q.maximum != null) value = Math.min(value, q.maximum);
  if (laundry && q.laundryMaximum != null) value = Math.min(value, q.laundryMaximum);
  return Math.max(1, Math.min(99, value));
}

// PD-061：原因分類依規則與需求測試的標籤類別（none 條件不算調整）。
export const REASON_KINDS = { weather: ['天氣', 'cloud-sun', 'var(--weather)'], trip: ['這趟安排', 'footprints', 'var(--olive)'], personal: ['你的設定', 'user', 'var(--accent)'], destination: ['目的地', 'globe-2', 'var(--plum)'], staple: ['常備', 'star', 'var(--gold)'] };
function kindsOf(conditions) {
  const kinds = new Set();
  for (const c of conditions) for (const tag of [...(c?.all || []), ...(c?.any || [])]) {
    const family = tag.split(':')[0];
    if (family === 'weather') kinds.add('weather');
    else if (['activity', 'stay', 'laundry'].includes(family)) kinds.add('trip');
    else if (['device', 'need', 'style'].includes(family)) kinds.add('personal');
    else if (['plug', 'country'].includes(family)) kinds.add('destination');
  }
  return [...kinds];
}

function runRules(tags, orderedTags, days, style, replacements) {
  const order = new Map();
  orderedTags.forEach((t, i) => { if (!order.has(t)) order.set(t, i); });
  const rules = DATA.packing_rules.rules.map((rule, offset) => ({ rule, offset }))
    .sort((a, b) => a.rule.phase - b.rule.phase
      || (order.get(a.rule.orderTag) ?? 0) - (order.get(b.rule.orderTag) ?? 0) || a.offset - b.offset);
  const seen = new Set(), results = [], sequences = new Map();
  const expand = text => Object.entries(replacements).reduce((s, [k, v]) => s.replaceAll(`{${k}}`, v), text);
  for (const { rule } of rules) {
    if (!matches(rule.when, tags)) continue;
    for (const need of rule.needs) {
      if (!matches(need.when, tags)) continue;
      const item = need.itemId ? DATA.itemsByID.get(need.itemId)
        : (DATA.candidatesByNeed.get(need.need) || []).find(c => matches(c.when, tags));
      let sortIndex;
      if (need.sortIndex != null) sortIndex = need.sortIndex;
      else if (rule.sortBase != null) { const n = sequences.get(rule.sortBase) ?? 0; sortIndex = rule.sortBase + n; sequences.set(rule.sortBase, n + 1); }
      else sortIndex = 5000 + results.length;
      if (!item || !matches(item.when, tags) || seen.has(item.id)) continue;
      seen.add(item.id);
      const quantity = need.quantityByStyle?.[style] ?? need.quantity;
      results.push({ id: item.id, name: expand(need.nameZh ?? item.nameZh), category: item.category,
        quantity: resolveQuantity(quantity, days, tags.has('laundry:yes')), reason: expand(need.reasonZh ?? rule.reasonZh),
        sortIndex, kinds: kindsOf([rule.when, need.when]) });
    }
  }
  return results;
}

// ---------- 天氣（與 WeatherPlanning.swift 相同的門檻） ----------
export const dayTags = d => { const t = new Set(); if (d.high >= 30) t.add('hot'); if (d.low <= 10) t.add('cold'); if (d.high < 30 && d.low > 10) t.add('mild'); if (d.rainChance >= 0.5) t.add('rain'); return t; };
export function seasonalTags(profile, month) {
  const t = new Set();
  if (!profile) return t;
  if (profile.hot.includes(month)) t.add('hot');
  if (profile.cold.includes(month)) t.add('cold');
  if (!profile.hot.includes(month) && !profile.cold.includes(month)) t.add('mild');
  if (profile.rain.includes(month)) t.add('rain');
  return t;
}
export const datesBetween = (start, end) => { const out = []; const d = new Date(start + 'T00:00:00Z'), e = new Date(end + 'T00:00:00Z'); while (d <= e && out.length < 400) { out.push(d.toISOString().slice(0, 10)); d.setUTCDate(d.getUTCDate() + 1); } return out; };
export function weatherSummary(w) {
  if (!w) return null;
  const forecast = new Set(), seasonal = new Set();
  w.days.forEach(d => dayTags(d).forEach(t => forecast.add(t)));
  const missing = datesBetween(w.request.start, w.request.end).filter(d => !w.days.some(x => x.date === d));
  new Set(missing.map(d => +d.slice(5, 7))).forEach(m => seasonalTags(w.seasonal, m).forEach(t => seasonal.add(t)));
  const tags = new Set([...forecast, ...seasonal]);
  const reason = list => { const f = list.some(t => forecast.has(t)), s = list.some(t => seasonal.has(t)); return f && s ? '依部分日期預報與當地季節參考' : f ? '依旅行日期預報' : '依當地季節參考（非預報）'; };
  const coverage = !w.days.length ? (w.seasonal ? '季節參考・非預報' : '暫無天氣資料') : !missing.length ? `完整 ${w.days.length} 天預報` : `僅 ${w.days.length}/${w.days.length + missing.length} 天有預報`;
  const items = [];
  if (tags.has('cold')) items.push('保暖衣物'); if (tags.has('hot')) items.push('防曬用品'); if (tags.has('rain')) items.push('雨具');
  return { tags, reason, coverage, reminder: items.length ? items.join('、') + '記得確認' : '出發前再確認天氣',
    low: w.days.length ? Math.round(Math.min(...w.days.map(d => d.low))) : null, high: w.days.length ? Math.round(Math.max(...w.days.map(d => d.high))) : null,
    rainDays: w.days.filter(d => d.rainChance >= 0.5).length };
}

const totalDays = (start, end) => Math.max(1, Math.round((new Date(end) - new Date(start)) / 86400000) + 1);
const localDay = iso => { const d = new Date(iso); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; };

/// 與 PackingListGenerator.generate 相同的標籤組合。trip 為雲端 payload 形狀（CloudTrip）。
export function generate(trip, { weatherTags: forcedWeather } = {}) {
  const prefs = trip.packingPreferencesRaw ? JSON.parse(trip.packingPreferencesRaw) : { packingStyle: 'normal', devices: ['phone'], needs: [] };
  const context = trip.packingContextRaw ? JSON.parse(trip.packingContextRaw) : { activities: [], stays: [], laundry: 'unknown' };
  const weather = trip.packingWeatherRaw ? JSON.parse(trip.packingWeatherRaw) : null;
  const start = localDay(trip.startDate), month = +start.slice(5, 7);
  const summary = weatherSummary(weather);
  const cityName = trip.city || defaultCity(trip.countryCode)?.cityZh;
  const profile = DATA.seasonal_weather.find(p => p.cityID === `${trip.countryCode}-${cityName}`);
  const weatherTags = forcedWeather ?? (summary ? summary.tags : seasonalTags(profile, month));
  const days = Math.max(1, Math.min(totalDays(trip.startDate, trip.endDate), 99));
  const tags = new Set([`country:${trip.countryCode}`, `origin:${trip.originCountryCode}`, `month:${month}`, `days:${days}`,
    `duration:${days <= 3 ? 'short' : days <= 7 ? 'medium' : 'long'}`, `style:${prefs.packingStyle}`, `laundry:${context.laundry}`,
    weather?.days?.length ? 'forecast:live' : 'forecast:estimated']);
  weatherTags.forEach(t => tags.add(`weather:${t}`));
  prefs.devices.filter(d => DEVICES[d]).forEach(d => tags.add(`device:${d}`));
  prefs.needs.filter(n => NEEDS[n]).forEach(n => tags.add(`need:${n}`));
  const ordered = context.activities.map(a => `activity:${a}`);
  ordered.forEach(t => tags.add(t));
  context.stays.forEach(s => tags.add(`stay:${s}`));
  const dest = country(trip.countryCode), origin = country(trip.originCountryCode);
  if (dest && origin) tags.add(origin.plugTypes.every(p => dest.plugTypes.includes(p)) ? 'plug:compatible' : 'plug:incompatible');
  return runRules(tags, ordered, days, prefs.packingStyle, {
    originCountry: origin?.nameZh ?? trip.originCountryCode, destinationCountry: dest?.nameZh ?? trip.countryCode,
    plugTypes: dest?.plugTypes.join('/') ?? '', days: String(days),
    weatherSource: summary && !forcedWeather ? summary.reason([...weatherTags]) : '依目的地月份的季節參考' });
}

/// 打包頁的原因徽章：重新以這趟保存的快照計算；自訂且非常備的物品沒有徽章。
export function reasonKindsFor(trip, staples) {
  const kinds = new Map(generate(trip).map(g => [g.id, g.kinds]));
  const stapleNames = new Set(staples.filter(s => s.isEssential).map(s => s.name.trim().toLowerCase()));
  return item => {
    const list = [...(item.catalogItemID ? kinds.get(item.catalogItemID) || [] : [])];
    if (stapleNames.has(item.name.trim().toLowerCase()) || item.reasonKey === STAPLE_REASON) list.push('staple');
    return list;
  };
}
