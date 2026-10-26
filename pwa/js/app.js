// PackSmart PWA：iOS App 的網頁版（同一份規則、資料與雲端同步）。
import { DATA, loadData, generate, reasonKindsFor, weatherSummary, country, citiesOf, defaultCity, artwork, itemByName, datesBetween,
  CATEGORIES, STYLES, DEVICES, NEEDS, ACTIVITIES, STAYS, LAUNDRY, REASON_KINDS, CUSTOM_REASON, STAPLE_REASON, CUSTOM_SORT } from './engine.js';
import { weatherRequest, fetchWeather, FAILURE } from './weather.js';
import { store, save, uuid, essentials, normalized, trip as findTrip, sortedItems, progress, compact } from './store.js';
import * as cloud from './cloud.js';

// ---------- 小工具 ----------
const $ = s => document.querySelector(s);
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const PATHS = {
  luggage: '<rect x="6" y="7" width="12" height="13" rx="2"/><path d="M9 7V4h6v3M10 11v5M14 11v5M8 20v1M16 20v1"/>',
  search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-4-4"/>', book: '<path d="M4 5a2 2 0 0 1 2-2h13v16H6a2 2 0 0 0-2 2z"/><path d="M8 7h7M8 11h7"/>',
  user: '<circle cx="12" cy="8" r="4"/><path d="M4 21c0-4 4-6 8-6s8 2 8 6"/>', plus: '<path d="M12 5v14M5 12h14"/>', back: '<path d="m15 18-6-6 6-6"/>',
  chev: '<path d="m9 18 6-6-6-6"/>', check: '<path d="M5 12.5 9.5 17 19 7"/>', more: '<circle cx="5" cy="12" r="1.4"/><circle cx="12" cy="12" r="1.4"/><circle cx="19" cy="12" r="1.4"/>',
  cloud: '<path d="M7 18a4.5 4.5 0 0 1-.6-8.96A6 6 0 0 1 17.6 8a4 4 0 0 1 .4 8H7"/>', star: '<path d="m12 3 2.7 5.6 6.1.8-4.5 4.2 1.1 6.1L12 16.8 6.6 19.7l1.1-6.1L3.2 9.4l6.1-.8z"/>',
  'cloud-sun': '<path d="M12 2v2M4.9 4.9l1.4 1.4M2 12h2M16 8a4 4 0 0 0-7.7-1.5"/><path d="M9 20a4 4 0 0 1-.5-8 5 5 0 0 1 9.5 1.5A3.3 3.3 0 0 1 17.5 20z"/>',
  footprints: '<path d="M4 16v-2.4C4 11.5 3 10.5 3 8c0-2.7 1.5-6 4.5-6C9.4 2 11 3.8 11 6.5c0 2.5-2 5-2 7.5V16zM20 20v-2.4c0-2.1 1-3.1 1-5.6 0-2.7-1.5-6-4.5-6C14.6 6 13 7.8 13 10.5c0 2.5 2 5 2 7.5V20zM4 16h5M15 20h5"/>',
  'globe-2': '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a14 14 0 0 1 0 18M12 3a14 14 0 0 0 0 18"/>', trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/>',
  shirt: '<path d="m8 3-5 3 2 4 2-1v12h10V9l2 1 2-4-5-3a4 4 0 0 1-8 0z"/>', plug: '<path d="M9 2v6M15 2v6M6 8h12v4a6 6 0 0 1-12 0zM12 18v4"/>',
  'id-card': '<rect x="3" y="5" width="18" height="14" rx="2"/><circle cx="9" cy="12" r="2"/><path d="M14 10h4M14 14h4"/>', droplet: '<path d="M12 3s6 6.5 6 11a6 6 0 0 1-12 0c0-4.5 6-11 6-11z"/>',
  'heart-pulse': '<path d="M20.8 6.6a5 5 0 0 0-8.8-2.8 5 5 0 0 0-8.8 2.8C3 13 12 20 12 20s9-7 8.8-13.4z"/><path d="M3.5 12H8l2-3 3 6 2-3h5.5"/>', package: '<path d="m3 7 9-4 9 4v10l-9 4-9-4z"/><path d="m3 7 9 4 9-4M12 11v10"/>',
  umbrella: '<path d="M3 12a9 9 0 0 1 18 0zM12 12v6a2 2 0 0 0 4 0"/>', refresh: '<path d="M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7"/>', x: '<path d="M6 6l12 12M18 6 6 18"/>',
};
const icon = (name, cls = 'icon') => `<svg class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${PATHS[name] || PATHS.package}</svg>`;
const CHECK = `<svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12.5 9.5 17 19 7"/></svg>`;
const badge = k => `<span class="badge" style="background:${REASON_KINDS[k][2]}" title="${REASON_KINDS[k][0]}">${icon(REASON_KINDS[k][1])}</span>`;
const localISO = day => new Date(day + 'T00:00:00').toISOString();
const dayOf = iso => { const d = new Date(iso); return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`; };
const today = () => dayOf(new Date().toISOString());
const addDays = (day, n) => { const d = new Date(day + 'T00:00:00'); d.setDate(d.getDate() + n); return dayOf(d.toISOString()); };
const md = iso => { const d = new Date(iso); return `${d.getMonth() + 1}/${d.getDate()}`; };
const daysUntil = iso => Math.round((new Date(dayOf(iso) + 'T00:00:00') - new Date(today() + 'T00:00:00')) / 86400000);
const tripDays = t => datesBetween(dayOf(t.startDate), dayOf(t.endDate)).length;
const status = t => { if (t.completedAt || t.isClosed) return '已完成'; const d = daysUntil(t.startDate); if (d > 0) return `還有 ${d} 天`; if (daysUntil(t.endDate) < 0) return '已結束'; return d === 0 ? '今天出發' : '旅途中'; };

let toastTimer;
function toast(text) { $('#toast')?.remove(); const el = document.createElement('div'); el.id = 'toast'; el.className = 'toast'; el.setAttribute('role', 'status'); el.textContent = text; document.body.append(el); clearTimeout(toastTimer); toastTimer = setTimeout(() => el.remove(), 2600); }
function sheet(html) { closeSheet(); const el = document.createElement('div'); el.className = 'overlay'; el.id = 'overlay'; el.innerHTML = `<div class="sheet" role="dialog" aria-modal="true">${html}</div>`; el.addEventListener('click', e => { if (e.target === el) closeSheet(); }); document.body.append(el); el.querySelector('button, input')?.focus(); }
const closeSheet = () => $('#overlay')?.remove();
const confirmSheet = (title, message, ok, action, danger = false) => sheet(`<h3>${esc(title)}</h3><p>${esc(message)}</p><div class="row" style="justify-content:flex-end"><button class="btn ghost" data-act="close">取消</button><button class="btn${danger ? ' danger' : ''}" data-act="${action}">${esc(ok)}</button></div>`);
const commit = () => { save(); render(); scheduleSync(); };

// ---------- 路由 ----------
let route = { page: 'trips' };
let ui = { seg: 'pack', filter: null, step: 'destinationArrival', query: '', queryDest: 'JP', lastPacked: null, knowledgeCountry: 'JP' };
function parse() {
  const [page = 'trips', a, b] = location.hash.slice(1).split('/');
  if (page === 'trip' && findTrip(a)) { if (route.id !== a) ui.filter = null; route = { page, id: a }; ui.seg = b || ui.seg; }
  else if (['new', 'search', 'knowledge', 'me'].includes(page)) route = { page, sub: a };
  else route = { page: 'trips' };
}
const go = hash => { if (location.hash === '#' + hash) render(); else location.hash = hash; };
window.addEventListener('hashchange', () => { parse(); render(); window.scrollTo(0, 0); });

// ---------- 首頁 ----------
function homeView() {
  const trips = [...store.trips].sort((a, b) => a.startDate.localeCompare(b.startDate));
  const active = trips.find(t => !t.completedAt && daysUntil(t.endDate) >= 0) || trips.at(-1);
  const others = trips.filter(t => t !== active);
  const quick = `<h2>不用建立行程也能用</h2><div class="stack">
    ${row('#search', 'search', '能不能帶？', '查海關與航空限制')}${row('#knowledge', 'book', '禮儀圖鑑', '先看當地眉角')}${row('#me/staples', 'luggage', '常備用品', '設定每次旅行都會帶的用品')}</div>`;
  const onboard = !store.onboarded ? `<a class="listrow" href="#me/prefs" style="margin-bottom:12px"><img class="mascot" src="art/mascot.png" alt=""><span><div class="t">先認識你的打包習慣</div><div class="s">選平常會帶的設備與用品，每趟不必重填</div></span><span class="chev">${icon('chev')}</span></a>` : '';
  if (!active) return `<div class="row between"><h1>我的行程</h1><a class="btn" href="#new">${icon('plus')}新行程</a></div>${onboard}
    <div class="card empty"><img class="mascot" src="art/mascot.png" alt=""><h2 style="margin:6px 0">還沒有行程</h2><p class="sub">查詢與圖鑑照樣能用，建立行程後我才開始準備清單。</p><a class="btn block" href="#new">建立第一個行程</a></div>${quick}`;
  const p = progress(active);
  return `<div class="row between"><h1>我的行程</h1><a class="btn" href="#new">${icon('plus')}新行程</a></div>${onboard}
  <a class="hero" href="#trip/${active.id}/overview" style="display:block;color:inherit;text-decoration:none">
    <div class="row between"><span class="chip">${status(active)}</span><span class="eyebrow">${p.remaining} 項待確認</span></div>
    <div style="font-size:30px;font-weight:900;margin:12px 0 4px">${esc(active.name)}</div>
    <div class="sub" style="margin:0 0 12px">${md(active.startDate)}–${md(active.endDate)}・${tripDays(active)} 天</div>
    <div class="bar"><i style="width:${p.total ? p.packed / p.total * 100 : 0}%"></i></div>
    <div class="row between muted" style="margin-top:10px;font-weight:700"><span>打包進度 ${p.packed}/${p.total}</span>${icon('chev')}</div>
    <div class="card row" style="margin-top:12px"><img class="mascot" src="art/mascot.png" alt=""><b style="line-height:1.5">${p.remaining ? `還有 ${p.remaining} 件待確認，點進去繼續打包` : '全部裝好了！出發吧'}</b></div>
  </a>
  ${others.length ? `<h2>最近行程</h2><div class="stack">${others.map(t => row(`#trip/${t.id}/overview`, 'luggage', `${country(t.countryCode)?.nameZh ?? ''}・${t.name}`, `${md(t.startDate)}–${md(t.endDate)}・${tripDays(t)} 天・${status(t)}`)).join('')}</div>` : ''}
  ${quick}`;
}
const row = (href, ic, t, s) => `<a class="listrow" href="${href}"><span class="ico">${icon(ic)}</span><span class="grow"><div class="t">${esc(t)}</div><div class="s">${esc(s)}</div></span><span class="chev">${icon('chev')}</span></a>`;

// ---------- 建立行程 ----------
let draft = null;
function newDraft() {
  const start = addDays(today(), 7);
  draft = { step: 1, country: '', city: '', origin: 'TW', name: '', start, end: addDays(start, 4),
    prefs: structuredClone(store.prefs), context: { activities: [], stays: [], laundry: 'unknown' }, weather: null, weatherKey: '',
    excluded: new Set(), custom: essentials().map(s => ({ id: s.id, name: s.name, category: s.categoryRaw, quantity: s.quantity, unitWeightKg: s.unitWeightKg, staple: true, include: true })) };
}
const destinations = () => DATA.countries.filter(c => c.code !== draft.origin && citiesOf(c.code).length);
function draftTrip() {
  return { countryCode: draft.country, city: draft.city, originCountryCode: draft.origin, startDate: localISO(draft.start), endDate: localISO(draft.end),
    packingPreferencesRaw: JSON.stringify({ packingStyle: draft.prefs.packingStyle, devices: draft.prefs.devices, needs: draft.prefs.needs }),
    packingContextRaw: JSON.stringify(draft.context), packingWeatherRaw: draft.weather ? JSON.stringify(draft.weather) : '' };
}
async function refreshDraftWeather() {
  if (!draft.country || !draft.city || draft.end < draft.start) return;
  const request = weatherRequest(draft.country, draft.city, draft.start, draft.end);
  const key = JSON.stringify(request);
  if (!request || key === draft.weatherKey) return;
  draft.weatherKey = key; draft.weather = null; draft.loadingWeather = true; render();
  const value = await fetchWeather(request);
  if (draft && draft.weatherKey === key) { draft.weather = value; draft.loadingWeather = false; render(); }
}
function recommendations() {
  const staples = new Set(draft.custom.filter(c => c.include).map(c => normalized(c.name)));
  return generate(draftTrip()).filter(g => !staples.has(normalized(g.name)));
}
const pressed = v => `aria-pressed="${!!v}"`;
function newView() {
  if (!draft) newDraft();
  const ready = draft.country && draft.city && draft.start && draft.end >= draft.start;
  const head = `<div class="row between"><button class="icon-btn" data-act="cancel-new" aria-label="關閉">${icon('x')}</button><b>新行程</b><span style="width:42px"></span></div>
    <div class="steps">步驟 ${draft.step} / 2・${draft.step === 1 ? '基本資訊' : '確認推薦清單'}</div><div class="stepbar"><i style="width:${draft.step * 50}%"></i></div>`;
  if (draft.step === 1) {
    const w = weatherSummary(draft.weather);
    return `${head}<h1 style="font-size:24px">想去哪裡？</h1><p class="sub">先選國家／地區，再選一個城市</p>
    <span class="label">1. 國家／地區</span><div class="chips">${destinations().map(c => `<button class="opt" data-country="${c.code}" ${pressed(draft.country === c.code)}>${esc(c.nameZh)}</button>`).join('')}</div>
    ${draft.country ? `<span class="label">2. 城市</span><div class="chips">${citiesOf(draft.country).map(c => `<button class="opt" data-city="${esc(c.cityZh)}" ${pressed(draft.city === c.cityZh)}>${esc(c.cityZh)}</button>`).join('')}</div>` : ''}
    <span class="label">什麼時候出發？</span><div class="dates"><label>出發<input class="field" type="date" id="d-start" value="${draft.start}"></label><label>回程<input class="field" type="date" id="d-end" value="${draft.end}" min="${draft.start}"></label></div>
    <p class="sub" style="margin-top:8px">共 ${draft.end >= draft.start ? datesBetween(draft.start, draft.end).length : 0} 天</p>
    ${draft.city ? `<div class="card">${draft.loadingWeather ? '<b>查詢天氣預報中…</b>' : w ? `<b>${icon('umbrella')} ${esc(w.reminder)}</b><div class="sub" style="margin:6px 0 0">${w.low != null ? `${w.low}–${w.high}°C・${w.rainDays} 天降雨機率較高・` : ''}${esc(w.coverage)}${draft.weather.failure && draft.weather.failure !== 'incomplete' ? `<br>${esc(FAILURE[draft.weather.failure] || '')}` : ''}</div><div class="src">天氣資料：Open-Meteo・CC BY 4.0</div>` : '<span class="muted">這個城市沒有天氣資料，會依季節推薦。</span>'}</div>` : ''}
    <h2>這趟怎麼準備？</h2><p class="sub">先沿用你的打包需求；這裡的調整只影響這趟行程</p>
    <span class="label">出發地</span><select class="field" id="d-origin">${DATA.countries.map(c => `<option value="${c.code}" ${c.code === draft.origin ? 'selected' : ''}>${esc(c.nameZh)}</option>`).join('')}</select>
    <span class="label">行程名稱</span><input class="field" id="d-name" placeholder="留空使用城市名" value="${esc(draft.name)}" maxlength="40">
    <span class="label">打包風格</span><div class="seg">${Object.entries(STYLES).map(([k, [l]]) => `<button data-style="${k}" ${pressed(draft.prefs.packingStyle === k)}>${l}</button>`).join('')}</div>
    <span class="label">這趟會帶的設備</span><div class="chips">${Object.entries(DEVICES).map(([k, l]) => `<button class="opt" data-device="${k}" ${pressed(draft.prefs.devices.includes(k))}>${l}</button>`).join('')}</div>
    <span class="label">常備需求</span><div class="chips">${Object.entries(NEEDS).map(([k, l]) => `<button class="opt" data-need="${k}" ${pressed(draft.prefs.needs.includes(k))}>${l}</button>`).join('')}</div>
    <span class="label">這趟的活動</span><div class="chips">${Object.entries(ACTIVITIES).map(([k, l]) => `<button class="opt" data-activity="${k}" ${pressed(draft.context.activities.includes(k))}>${l}</button>`).join('')}</div>
    <span class="label">住宿</span><div class="chips">${Object.entries(STAYS).map(([k, l]) => `<button class="opt" data-stay="${k}" ${pressed(draft.context.stays.includes(k))}>${l}</button>`).join('')}</div>
    <span class="label">洗衣</span><div class="seg">${Object.entries(LAUNDRY).map(([k, l]) => `<button data-laundry="${k}" ${pressed(draft.context.laundry === k)}>${l}</button>`).join('')}</div>
    <div style="height:18px"></div><button class="btn block" data-act="next-step" ${ready && !draft.loadingWeather ? '' : 'disabled'}>下一步：確認清單</button>`;
  }
  const recs = recommendations();
  return `${head}<h1 style="font-size:24px">${esc(draft.name || draft.city)}</h1><p class="sub">${esc(country(draft.country)?.nameZh)}・${md(localISO(draft.start))}–${md(localISO(draft.end))}・依目的地、天氣與你的設定推薦。關掉不需要的項目。</p>
    <div class="group">${recs.map(g => `<div class="toggle-row"><div class="grow"><b>${esc(g.name)} ×${g.quantity}</b><div class="sub" style="margin:2px 0 0;font-size:12px">${esc(g.reason)}</div></div><div class="row" style="gap:2px">${g.kinds.slice(0, 2).map(badge).join('')}</div><button class="switch" role="switch" aria-checked="${!draft.excluded.has(g.id)}" aria-label="${esc(g.name)}" data-rec="${g.id}"></button></div>`).join('')}</div>
    <h2>常備與自訂用品</h2><p class="sub">常備用品只複製到這趟行程；在這裡移除不會更改常備清單。</p>
    ${draft.custom.length ? `<div class="group">${draft.custom.map((c, n) => `<div class="toggle-row"><div class="grow"><b>${esc(c.name)} ×${c.quantity}</b><div class="sub" style="margin:2px 0 0;font-size:12px">${c.staple ? '我的常備用品' : '自訂'}</div></div><button class="switch" role="switch" aria-checked="${c.include}" aria-label="${esc(c.name)}" data-custom="${n}"></button></div>`).join('')}</div>` : ''}
    <button class="btn soft" style="margin-top:10px" data-act="draft-add">${icon('plus')}新增自訂用品</button>
    <div style="height:18px"></div><div class="row"><button class="btn ghost" data-act="prev-step">上一步</button><button class="btn block grow" data-act="create">建立行程</button></div>`;
}
function createTrip() {
  const recs = recommendations(), dest = country(draft.country), now = new Date().toISOString();
  const excluded = recs.filter(g => draft.excluded.has(g.id));
  const t = { id: uuid(), name: draft.name.trim() || draft.city, countryCode: draft.country, city: draft.city, originCountryCode: draft.origin, originCity: '',
    startDate: localISO(draft.start), endDate: localISO(draft.end), homeCurrencyCode: 'TWD', localCurrencyCode: dest?.currencyCode || 'TWD', tripTypeRaw: 'leisure',
    isClosed: false, hasReviewedTravelRules: true, excludedPackingNamesRaw: excluded.map(g => g.name).sort().join('\n'), excludedPackingIDsRaw: excluded.map(g => g.id).sort().join('\n'),
    ...(({ packingPreferencesRaw, packingContextRaw, packingWeatherRaw }) => ({ packingPreferencesRaw, packingContextRaw, packingWeatherRaw }))(draftTrip()),
    packingReviewPending: false, createdAt: now,
    packingItems: [
      ...recs.filter(g => !draft.excluded.has(g.id)).map(g => ({ id: uuid(), name: g.name, catalogItemID: g.id, categoryRaw: g.category, reasonKey: g.reason, quantity: g.quantity, isPacked: false, isCustom: false, sortIndex: g.sortIndex })),
      ...draft.custom.filter(c => c.include).map(c => compact({ id: uuid(), name: c.name, catalogItemID: c.staple ? itemByName(c.name)?.id : null, categoryRaw: c.category,
        reasonKey: c.staple ? STAPLE_REASON : CUSTOM_REASON, quantity: c.quantity, unitWeightKg: c.unitWeightKg, isPacked: false, isCustom: true, sortIndex: CUSTOM_SORT })),
    ] };
  store.trips.push(t); draft = null; ui.seg = 'pack';
  save(); scheduleSync(); toast('行程建立好了，一起準備吧！'); go(`trip/${t.id}/pack`);
}

// ---------- 行程內容 ----------
function tripView(t) {
  const segs = [['overview', '總覽'], ['pack', '打包'], ['customs', '通關'], ['knowledge', '知識']];
  const prefs = t.packingPreferencesRaw ? JSON.parse(t.packingPreferencesRaw) : { packingStyle: 'normal', devices: ['phone'], needs: [] };
  return `<div class="row between"><a class="icon-btn" href="#trips" aria-label="返回">${icon('back')}</a><b>我的行程</b><button class="icon-btn" data-act="trip-menu" aria-label="行程操作">${icon('more')}</button></div>
  <div class="eyebrow" style="margin-top:12px">${status(t)}・${new Date(t.startDate).getMonth() + 1} 月 ${new Date(t.startDate).getDate()} 日出發</div>
  <h1>${esc(t.name)}</h1><p class="sub">此行程設定：${prefs.devices.length} 項設備・${prefs.needs.length} 項需求・${STYLES[prefs.packingStyle]?.[0] ?? '一般'}</p>
  <div class="seg tabs-seg" role="group" aria-label="行程內容">${segs.map(([k, l]) => `<button data-seg="${k}" ${pressed(ui.seg === k)}>${l}</button>`).join('')}</div>
  ${ui.seg === 'overview' ? overviewView(t) : ui.seg === 'customs' ? customsView(t) : ui.seg === 'knowledge' ? etiquetteList(t.countryCode, t.city) : packView(t)}`;
}

function overviewView(t) {
  const p = progress(t), weather = t.packingWeatherRaw ? JSON.parse(t.packingWeatherRaw) : null, w = weatherSummary(weather);
  return `<div class="card"><div class="row between"><b style="font-size:18px">打包進度</b><b style="font-size:26px;color:var(--olive);font-variant-numeric:tabular-nums">${p.packed}/${p.total}</b></div>
    <div class="bar" style="margin:12px 0 8px"><i style="width:${p.total ? p.packed / p.total * 100 : 0}%"></i></div><div class="sub" style="margin:0">還有 ${p.remaining} 件要確認</div></div>
  ${w ? `<div class="card" style="margin-top:12px"><b style="font-size:17px">${icon('umbrella')} ${esc(w.reminder)}</b>
    <div class="sub" style="margin:8px 0 0">${w.low != null ? `${w.low}–${w.high}°C・${w.rainDays} 天降雨機率較高・` : ''}建立時參考・${esc(w.coverage)}</div>
    ${weather.days.length ? `<div class="wx">${weather.days.map(d => `<div>${+d.date.slice(5, 7)}/${+d.date.slice(8)}<b>${Math.round(d.high)}°</b>${Math.round(d.low)}°<br><span class="rain">${Math.round(d.rainChance * 100)}%</span></div>`).join('')}</div>` : ''}
    <div class="src">天氣資料：${weather.days.length ? 'Open-Meteo・CC BY 4.0' : esc(weather.seasonal?.sourceName ?? '季節參考')}</div></div>` : ''}
  <button class="btn block" style="margin-top:14px" data-seg="pack">繼續打包</button>`;
}

function packView(t) {
  const p = progress(t), items = sortedItems(t), kindsOf = reasonKindsFor(t, store.library);
  const kinds = new Map(items.map(i => [i.id, kindsOf(i)]));
  const slots = 12, filled = p.total ? Math.round(p.packed / p.total * slots) : 0, shown = items.filter(i => i.isPacked).slice(-filled);
  const d = daysUntil(t.startDate), lid = !p.remaining && p.total ? '全部裝好了！' : d > 0 ? `還有 ${d} 天出發` : d === 0 ? '今天出發' : '旅途中';
  const counts = Object.keys(REASON_KINDS).map(k => [k, items.filter(i => kinds.get(i.id).includes(k)).length]).filter(([, n]) => n);
  const tailored = items.filter(i => kinds.get(i.id).length).length;
  const dim = i => ui.filter && !kinds.get(i.id).includes(ui.filter);
  const badges = i => kinds.get(i.id).slice(0, 2).map(badge).join('');
  const label = i => `aria-label="${esc(i.name)}，${i.isPacked ? '已打包，取消' : '標記已打包'}"`;
  const fallback = i => `<span class="fallback">${icon(CATEGORIES[i.categoryRaw]?.[1])}分類示意</span>`;
  const art = i => { const src = i.catalogItemID && artwork(i.catalogItemID); return src ? `<img src="${src}" alt="" loading="lazy">` : fallback(i); };
  const card = i => `<article class="item${i.isPacked ? ' packed' : ''}${dim(i) ? ' dim' : ''}">
      <div class="top"><button class="check" data-pack="${i.id}" ${pressed(i.isPacked)} ${label(i)}>${i.isPacked ? CHECK : ''}</button><button class="more" data-item="${i.id}" aria-label="${esc(i.name)}的操作">${icon('more')}</button></div>
      <div class="art">${art(i)}<div class="badges" ${kinds.get(i.id).length ? `role="img" aria-label="調整原因：${kinds.get(i.id).slice(0, 2).map(k => REASON_KINDS[k][0]).join('、')}"` : ''}>${badges(i)}</div></div>
      <div class="name"><span>${esc(i.name)}</span><button class="qty" data-qty="${i.id}" aria-label="${esc(i.name)}數量，${i.quantity} 件，修改">×${i.quantity}</button></div></article>`;
  const rowText = i => `<div class="trow${dim(i) ? ' dim' : ''}"><button class="check" data-pack="${i.id}" ${pressed(i.isPacked)} ${label(i)}>${i.isPacked ? CHECK : ''}</button>
      <div class="grow"><div class="tt${i.isPacked ? ' done' : ''}">${esc(i.name)}</div></div><div class="tb">${badges(i)}<button class="qty" data-qty="${i.id}">×${i.quantity}</button><button class="more" data-item="${i.id}" aria-label="${esc(i.name)}的操作">${icon('more')}</button></div></div>`;
  const groups = items.reduce((g, i) => ((g[i.reasonKey] ??= []).push(i), g), {});
  return `${store.mode === 'image' ? `<div class="suitcase" role="img" aria-label="行李箱：已打包 ${p.packed} / ${p.total} 件，${lid}"><div class="handle"></div><div class="lid"><span>${lid}</span><b>${p.packed} / ${p.total}</b></div>
    <div class="base"><div class="slots">${Array.from({ length: slots }, (_, n) => { const i = shown[n]; if (!i) return '<div class="slot"></div>'; const src = i.catalogItemID && artwork(i.catalogItemID);
      return `<div class="slot full${i.id === ui.lastPacked ? ' pop' : ''}">${src ? `<img src="${src}" alt="">` : icon(CATEGORIES[i.categoryRaw]?.[1])}</div>`; }).join('')}</div></div></div>`
    : `<div class="card" style="margin-bottom:12px"><b>${p.packed} / ${p.total} 項已打包</b><div class="bar" style="margin-top:10px"><i style="width:${p.total ? p.packed / p.total * 100 : 0}%"></i></div></div>`}
  <div class="row"><div class="seg grow" role="group" aria-label="顯示方式"><button data-mode="text" ${pressed(store.mode === 'text')}>文字</button><button data-mode="image" ${pressed(store.mode === 'image')}>圖片</button></div>
    <button class="btn soft" data-act="add-item">${icon('plus')}新增</button></div>
  ${counts.length ? `<h2 style="font-size:16px;margin:16px 0 0">這趟為你調整了 ${tailored} 件</h2><div class="filters">${counts.map(([k, n]) => `<button class="filter" data-filter="${k}" ${pressed(ui.filter === k)}>${badge(k)}${REASON_KINDS[k][0]}<small>${n}</small></button>`).join('')}</div>` : '<div style="height:12px"></div>'}
  ${!items.length ? '<div class="card empty"><p class="sub">還沒有物品，按「新增」加入吧。</p></div>'
    : store.mode === 'image' ? `<div class="grid">${items.map(card).join('')}</div>`
    : Object.entries(groups).map(([reason, list]) => `<div class="group-title">${esc(reason)}・${list.length} 項</div><div class="tlist">${list.map(rowText).join('')}</div>`).join('')}`;
}

// ---------- 通關 ----------
const CHECKPOINTS = [['originDeparture', '去程', '出境'], ['destinationArrival', '去程', '入境'], ['destinationDeparture', '回程', '出境'], ['originArrival', '回程', '入境']];
const AUTH = { customs: '海關', quarantine: '檢疫', aviation: '航空安檢', immigration: '移民' };
const STATUS = { prepare: '待完成', declare: '需申報', review: '需確認', banned: '禁止', permit: '需許可', limited: '有限制', carryOnOnly: '僅限隨身', checkedOnly: '僅限託運' };
const applies = (r, day) => (!r.effectiveFrom || day >= r.effectiveFrom) && (!r.effectiveUntil || day <= r.effectiveUntil);
function checkpointEntries(origin, dest, cp, day) {
  const code = cp.startsWith('origin') ? origin : dest;
  const border = DATA.border_rules.filter(r => r.countryCode === code && r.checkpoint === cp && applies(r, day))
    .map(r => ({ id: r.id, title: r.actionZh || r.titleZh, name: r.titleZh, authority: r.authority, status: r.status, detail: r.detailZh, source: r.sourceName, verified: r.lastVerified, priority: r.priority ?? 100 }));
  const extra = cp.endsWith('Arrival')
    ? DATA.prohibited_items.filter(r => r.countryCode === code).map((r, n) => ({ id: `p-${code}-${n}`, title: r.actionZh || r.itemZh, name: r.itemZh, authority: r.authority || 'customs', status: r.severity, detail: r.reasonZh, source: r.sourceName, verified: r.lastVerified, priority: r.priority ?? 50 }))
    : DATA.aviation_rules.filter(r => r.departureCountries?.includes(code)).map((r, n) => ({ id: `a-${code}-${n}`, title: r.itemZh, name: r.itemZh, authority: 'aviation', status: r.restriction, detail: r.detailZh, source: r.sourceName, verified: r.lastVerified, priority: 60 }));
  return [...border, ...extra].sort((a, b) => a.priority - b.priority);
}
function customsView(t) {
  const checks = store.checks[t.id] ||= {};
  const day = ui.step.startsWith('destinationDeparture') || ui.step === 'originArrival' ? dayOf(t.endDate) : dayOf(t.startDate);
  const entries = checkpointEntries(t.originCountryCode, t.countryCode, ui.step, day), open = entries.filter(e => !checks[e.id]).length;
  const name = cp => `${country(cp.startsWith('origin') ? t.originCountryCode : t.countryCode)?.nameZh ?? ''}${CHECKPOINTS.find(c => c[0] === cp)[2]}`;
  return `<div class="row" style="align-items:baseline"><b style="font-size:22px;font-weight:900">通關檢查</b><span class="chip">官方資料</span></div>
  <p class="sub" style="margin-top:4px">依照旅程順序，只顯示這一關要做的事。</p>
  <div class="card"><div class="checkpoints"><div class="grp">去程</div><div class="grp">回程</div>
    ${CHECKPOINTS.map(([cp], n) => `<button class="cp" data-cp="${cp}" ${pressed(ui.step === cp)}><div class="dot">${n + 1}</div><div class="l">${esc(name(cp))}</div></button>`).join('')}</div></div>
  <div class="hero" style="margin-top:12px"><b style="font-size:24px;font-weight:900">${esc(name(ui.step))}</b>
    <div class="eyebrow" style="margin:8px 0 6px;font-size:16px">${!entries.length ? '這一關目前沒有特別要確認的事' : open ? `有 ${open} 件事需要確認` : '這一關都確認好了'}</div>
    ${entries.length ? `<div class="card" style="padding:4px 14px">${entries.map(e => `<div class="rule"><button class="check" data-rule="${esc(e.id)}" ${pressed(checks[e.id])} aria-label="${esc(e.title)}">${checks[e.id] ? CHECK : ''}</button>
      <div class="grow"><div class="rt${checks[e.id] ? ' done' : ''}">${esc(e.title)}</div><div class="rd"><span class="sev sev-${e.status}">${AUTH[e.authority] || '規定'}・${STATUS[e.status] || '需確認'}</span><br>${esc(e.detail)}</div>
      <div class="src">來源：${esc(e.source)}・查證 ${esc(e.verified)}</div></div></div>`).join('')}</div>` : ''}</div>`;
}
const etiquetteList = (code, city) => { const cards = DATA.etiquette.filter(e => e.countryCode === code && (!e.cityZh || !city || e.cityZh === city));
  return cards.length ? `<div class="stack">${cards.map(e => `<div class="card"><b style="font-size:16px">${esc(e.titleZh)}${e.cityZh ? `<span class="chip" style="margin-left:6px">${esc(e.cityZh)}</span>` : ''}</b><div class="sub" style="margin:6px 0 0">${esc(e.bodyZh)}</div></div>`).join('')}</div>` : '<p class="sub">這個地區還沒有禮儀資料。</p>'; };

// ---------- 查詢與知識 ----------
const canon = s => String(s).toLowerCase().replaceAll('菸', '煙').replaceAll('臺', '台').trim();
function searchView() {
  const q = canon(ui.query), dests = DATA.countries.filter(c => c.code !== 'TW' && citiesOf(c.code).length);
  const hits = q ? CHECKPOINTS.flatMap(([cp]) => checkpointEntries('TW', ui.queryDest, cp, today()).map(e => ({ ...e, cp })))
    .filter((e, n, all) => all.findIndex(x => x.id === e.id) === n)
    .filter(e => { const raw = [...DATA.border_rules, ...DATA.prohibited_items, ...DATA.aviation_rules].find(r => r.id === e.id || r.itemZh === e.name || r.titleZh === e.name) || {};
      if ((raw.exclusions || []).some(x => q.includes(canon(x)))) return false;
      return [e.name, e.title, ...(raw.aliases || []), ...(raw.keywords || [])].some(x => canon(x).includes(q) || (q.length >= 2 && q.includes(canon(x)))); }) : [];
  const where = cp => `${country(cp.startsWith('origin') ? 'TW' : ui.queryDest)?.nameZh}${CHECKPOINTS.find(c => c[0] === cp)[2]}`;
  return `<h1>能不能帶？</h1><p class="sub">輸入物品名稱，查台灣出入境與目的地的海關、檢疫與航空規定。</p>
  <div class="row"><select class="field" id="q-dest" style="width:auto">${dests.map(c => `<option value="${c.code}" ${c.code === ui.queryDest ? 'selected' : ''}>台灣 ⇄ ${esc(c.nameZh)}</option>`).join('')}</select></div>
  <input class="field" id="q" type="search" style="margin-top:10px" placeholder="例如：肉鬆、行動電源、藥品" value="${esc(ui.query)}" aria-label="物品名稱">
  <div class="chips" style="margin:10px 0">${['肉鬆', '行動電源', '藥品', '水果', '現金'].map(s => `<button class="opt" data-q="${s}">${s}</button>`).join('')}</div>
  ${q ? (hits.length ? `<div class="card" style="padding:4px 14px">${hits.map(e => `<div class="rule"><div class="grow"><div class="row between" style="align-items:flex-start"><div class="rt">${esc(e.name)}</div><span class="sev sev-${e.status}">${STATUS[e.status] || '需確認'}</span></div>
    <div class="rd">${esc(where(e.cp))}・${AUTH[e.authority] || '規定'}<br>${esc(e.detail)}</div><div class="src">來源：${esc(e.source)}・查證 ${esc(e.verified)}</div></div></div>`).join('')}</div>`
    : '<div class="card"><p class="sub" style="margin:0">找不到相符的規定。試試更短的關鍵字，或查詢官方網站；沒有列出不代表可以攜帶。</p></div>') : ''}`;
}
function knowledgeView() {
  const codes = [...new Set(DATA.etiquette.map(e => e.countryCode))];
  return `<h1>禮儀圖鑑</h1><p class="sub">出發前看一眼當地的眉角。</p>
  <div class="chips" style="margin-bottom:14px">${codes.map(c => `<button class="opt" data-kc="${c}" ${pressed(ui.knowledgeCountry === c)}>${esc(country(c)?.nameZh ?? c)}</button>`).join('')}</div>${etiquetteList(ui.knowledgeCountry, '')}`;
}

// ---------- 我的 ----------
function meView() {
  if (route.sub === 'staples') return staplesView();
  if (route.sub === 'prefs') return prefsView();
  if (route.sub === 'account') return accountView();
  const signed = cloud.session, sync = signed && cloud.syncEnabled();
  return `<h1>我的</h1><p class="sub">讓清單，更懂你的旅行習慣。</p>
  <div class="row" style="margin:6px 0 16px"><img class="mascot" src="art/mascot.png" alt=""><div><b style="font-size:17px">和 Packmon 一起出發</b><div class="sub" style="margin:4px 0 0">${store.trips.length} 趟行程・${essentials().length} 項常備用品</div></div></div>
  <div class="stack">${row('#me/staples', 'luggage', '常備清單', '每次新行程，都幫你一起帶上')}${row('#me/prefs', 'user', '個人打包需求', `${store.prefs.devices.length} 項設備・${store.prefs.needs.length} 項需求・${STYLES[store.prefs.packingStyle][0]}`)}
  ${row('#me/account', 'cloud', '帳號與同步', !cloud.configured() ? '這個版本尚未提供' : signed ? `${signed.email}・${sync ? '同步中' : '同步未開啟'}` : '登入後可以和 iPhone 共用行程')}</div>
  <p class="sub" style="margin-top:14px">${sync ? '行程與常備用品會同步到雲端' : '行程與設定保存在這個瀏覽器'}</p>
  <p class="src">天氣：Open-Meteo（CC BY 4.0）。通關與禁帶資料附官方來源與查證日期，出發前仍請以官方公告為準。</p>`;
}
const backBar = title => `<div class="row between"><a class="icon-btn" href="#me" aria-label="返回">${icon('back')}</a><b>${esc(title)}</b><span style="width:42px"></span></div>`;
function staplesView() {
  const list = essentials();
  return `${backBar('常備清單')}<h1>常備清單</h1><p class="sub">每次建立新行程，都會自動加進清單；同名的推薦會讓給常備用品。</p>
  ${list.length ? `<div class="group">${list.map(s => `<div class="toggle-row"><div class="grow"><b>${esc(s.name)} ×${s.quantity}</b><div class="sub" style="margin:2px 0 0;font-size:12px">${CATEGORIES[s.categoryRaw]?.[0] ?? '其他'}</div></div><button class="icon-btn" data-unstaple="${s.id}" aria-label="移除 ${esc(s.name)}">${icon('trash')}</button></div>`).join('')}</div>` : '<div class="card"><p class="sub" style="margin:0">還沒有常備用品。在打包頁的物品選單按「加入常備」，或在這裡新增。</p></div>'}
  <button class="btn soft" style="margin-top:12px" data-act="add-staple">${icon('plus')}新增常備用品</button>`;
}
function prefsView() {
  const p = store.prefs;
  return `${backBar('個人打包需求')}<h1>個人打包需求</h1><p class="sub">這些是新行程的預設值，每趟都能另外調整；已建立的行程不會被改動。</p>
  <span class="label">你習慣怎麼打包？</span><div class="stack">${Object.entries(STYLES).map(([k, [l, d]]) => `<button class="listrow" data-pstyle="${k}" ${pressed(p.packingStyle === k)} style="${p.packingStyle === k ? 'border-color:var(--accent)' : ''}"><span class="grow"><div class="t">${l}</div><div class="s">${d}</div></span>${p.packingStyle === k ? `<span style="color:var(--accent)">${icon('check')}</span>` : ''}</button>`).join('')}</div>
  <span class="label">我的常用設備</span><div class="chips">${Object.entries(DEVICES).map(([k, l]) => `<button class="opt" data-pdevice="${k}" ${pressed(p.devices.includes(k))}>${l}</button>`).join('')}</div>
  <span class="label">我的常備需求</span><div class="chips">${Object.entries(NEEDS).map(([k, l]) => `<button class="opt" data-pneed="${k}" ${pressed(p.needs.includes(k))}>${l}</button>`).join('')}</div>
  <p class="sub" style="margin-top:12px">藥品由你自行決定品項，不會依年齡推測用藥。其他用品可到「常備清單」加入。</p>
  <button class="btn block" data-act="save-prefs">儲存個人需求</button>`;
}

// ---------- 帳號與同步 ----------
let account = { email: '', awaiting: false, busy: false, message: '', conflicts: [], health: null };
function accountView() {
  if (!cloud.configured()) return `${backBar('帳號與同步')}<h1>帳號與同步</h1><div class="card"><p class="sub" style="margin:0">這個版本尚未設定雲端服務，資料只存在這個瀏覽器。</p></div>`;
  const s = cloud.session, sync = cloud.syncEnabled(), last = cloud.lastSynced();
  let body;
  if (!s && !account.awaiting) body = `<div class="gh">帳號</div><div class="group"><div style="padding:10px"><input class="field" id="email" type="email" autocomplete="email" placeholder="Email" value="${esc(account.email)}" aria-label="Email" style="border:0;background:transparent"></div>
    <button class="gbtn" data-act="send-code" ${account.busy ? 'disabled' : ''}>寄送驗證碼</button></div><div class="foot">不需要密碼。登入不會自動上傳資料，開啟同步後才會上傳。</div>`;
  else if (!s) body = `<div class="gh">帳號</div><div class="group"><div class="gline muted">輸入寄到 ${esc(account.email)} 的 6 位數驗證碼</div>
    <div style="padding:10px"><input class="field" id="code" inputmode="numeric" autocomplete="one-time-code" maxlength="6" placeholder="驗證碼" aria-label="驗證碼" style="border:0;background:transparent"></div>
    <button class="gbtn" data-act="verify" ${account.busy ? 'disabled' : ''}>登入</button><button class="gbtn" data-act="send-code" ${account.busy ? 'disabled' : ''}>重新寄送</button><button class="gbtn" data-act="change-email">改用其他 Email</button></div>`;
  else body = `<div class="gh">帳號</div><div class="group"><div class="gline"><span>已登入</span><span class="v">${esc(s.email)}</span></div><button class="gbtn" data-act="sign-out">登出</button></div>
    <div class="gh">同步</div><div class="group">
      <div class="gline"><span>雲端同步</span><button class="switch" role="switch" aria-checked="${sync}" aria-label="雲端同步" data-act="toggle-sync" ${account.busy ? 'disabled' : ''}></button></div>
      <div class="gline"><span>同步「健康」分類的物品</span><button class="switch" role="switch" aria-checked="${account.health === true}" aria-label="同步健康類物品" data-act="toggle-health" ${sync && !account.busy ? '' : 'disabled'}></button></div>
      <button class="gbtn" data-act="sync-now" ${sync && !account.busy ? '' : 'disabled'}>${account.busy ? '同步中…' : '立即同步'}</button>
      ${last ? `<div class="gline"><span>上次同步</span><span class="v">${new Date(last).toLocaleString('zh-TW', { dateStyle: 'medium', timeStyle: 'short' })}</span></div>` : ''}</div>
    <div class="foot">開啟網頁、回到網頁時會自動同步。沒有網路時先存在這裡，下次同步補上。</div>
    ${account.conflicts.length ? `<div class="gh">需要你選擇</div><div class="group">${account.conflicts.map((c, n) => `<div style="padding:13px 16px"><b>${esc(c.title || c.remote.payload?.trip?.name || c.remote.payload?.library?.name || '一份資料')}</b>
      <div class="sub" style="margin:4px 0 8px">${c.remote.deleted ? '另一台裝置刪除了它，這裡則修改過。' : !c.title ? '這裡刪除了它，另一台裝置則修改過。' : '兩邊都修改過。'}</div>
      <div class="row between"><button class="btn ghost" data-resolve="${n}" data-keep="local">${!c.title ? '刪除' : '保留這裡的版本'}</button><button class="btn ghost" data-resolve="${n}" data-keep="remote">${c.remote.deleted ? '刪除' : '使用雲端版本'}</button></div></div>`).join('')}</div>` : ''}
    <div class="group" style="margin-top:12px"><button class="gbtn danger" data-act="delete-account">刪除雲端帳號</button></div>
    <div class="foot">資料存放在 Supabase（${esc(CONFIG_REGION)}）。關閉同步、登出或清除瀏覽器資料都不會刪除雲端帳號。</div>`;
  return `${backBar('帳號與同步')}<h1>帳號與同步</h1><p class="sub">和 iPhone 版用同一個帳號，就能共用行程與常備清單。</p>${body}${account.message ? `<p class="sub" role="status">${esc(account.message)}</p>` : ''}`;
}
import { CONFIG } from './config.js';
const CONFIG_REGION = CONFIG?.region || '未設定';
async function runAccount(work) {
  account.busy = true; account.message = ''; render();
  try { await work(); } catch (e) { account.message = e.message || '發生錯誤，請稍後再試。'; }
  account.busy = false; render();
}
async function synchronize(quiet = false) {
  if (!cloud.session || !cloud.syncEnabled() || syncing) return;
  syncing = true;
  try { const summary = await cloud.synchronize(); account.conflicts = summary.conflicts;
    if (!quiet || summary.downloaded || summary.deleted || summary.conflicts.length) { if (summary.conflicts.length) account.message = `有 ${summary.conflicts.length} 份資料在兩台裝置都被修改，請到「帳號與同步」選擇要保留的版本。`; render(); }
  } catch (e) { if (!quiet) account.message = e.message; }
  finally { syncing = false; }
}
let syncing = false, syncTimer;
const scheduleSync = () => { clearTimeout(syncTimer); syncTimer = setTimeout(() => synchronize(true), 1500); };

// ---------- 繪製 ----------
function render() {
  const t = route.page === 'trip' ? findTrip(route.id) : null;
  const views = { trips: homeView, new: newView, search: searchView, knowledge: knowledgeView, me: meView };
  $('#app').innerHTML = t ? tripView(t) : (views[route.page] || homeView)();
  const tab = route.page === 'trip' || route.page === 'new' ? 'trips' : route.page;
  $('#tabbar').innerHTML = [['trips', 'luggage', '行程'], ['search', 'search', '查詢'], ['knowledge', 'book', '知識'], ['me', 'user', '我的']]
    .map(([k, ic, l]) => `<a href="#${k}" ${tab === k ? 'aria-current="page"' : ''}>${icon(ic)}${l}</a>`).join('');
  ui.lastPacked = null;
}

// ---------- 事件 ----------
const itemOf = id => findTrip(route.id)?.packingItems.find(i => i.id === id);
function itemSheet(i) {
  const staple = essentials().some(s => normalized(s.name) === normalized(i.name));
  sheet(`<h3>${esc(i.name)}</h3><div class="group"><button class="gbtn" data-qty="${i.id}">修改數量</button><button class="gbtn" data-staple="${i.id}">${staple ? '移除常備' : '加入常備'}</button><button class="gbtn danger" data-remove="${i.id}">移除物品</button></div>
    ${i.reasonKey ? `<p style="margin:12px 4px 0;font-size:13px">${esc(i.reasonKey)}</p>` : ''}`);
}
function qtySheet(i) { sheet(`<h3>修改數量・${esc(i.name)}</h3><div class="row between" style="margin-bottom:16px"><button class="icon-btn" data-step="-1" aria-label="減少">−</button><b id="qty-v" style="font-size:28px;font-variant-numeric:tabular-nums">${i.quantity}</b><button class="icon-btn" data-step="1" aria-label="增加">${icon('plus')}</button></div><button class="btn block" data-save-qty="${i.id}">儲存</button>`); }
function itemForm(title, action) {
  sheet(`<h3>${esc(title)}</h3><div class="stack"><input class="field" id="f-name" maxlength="40" placeholder="物品名稱" aria-label="物品名稱">
    <select class="field" id="f-cat" aria-label="分類">${Object.entries(CATEGORIES).map(([k, [l]]) => `<option value="${k}" ${k === 'other' ? 'selected' : ''}>${l}</option>`).join('')}</select>
    <input class="field" id="f-qty" type="number" min="1" max="99" value="1" aria-label="數量"><button class="btn block" data-act="${action}">加入</button></div>`);
}
const formValue = () => ({ name: $('#f-name').value.trim(), category: $('#f-cat').value, quantity: Math.max(1, Math.min(99, +$('#f-qty').value || 1)) });

document.addEventListener('click', async e => {
  const el = e.target.closest('button, [data-act]');
  if (!el) return;
  const d = el.dataset, t = route.page === 'trip' ? findTrip(route.id) : null;
  if (d.act === 'close') return closeSheet();
  // 建立行程
  if (route.page === 'new' && draft) {
    if (d.country) { draft.country = d.country; draft.city = defaultCity(d.country)?.cityZh || ''; render(); return refreshDraftWeather(); }
    if (d.city) { draft.city = d.city; render(); return refreshDraftWeather(); }
    if (d.style) { draft.prefs.packingStyle = d.style; return render(); }
    const toggle = (list, v) => list.includes(v) ? list.filter(x => x !== v) : [...list, v];
    if (d.device) { draft.prefs.devices = toggle(draft.prefs.devices, d.device); return render(); }
    if (d.need) { draft.prefs.needs = toggle(draft.prefs.needs, d.need); return render(); }
    if (d.activity) { draft.context.activities = toggle(draft.context.activities, d.activity); return render(); }
    if (d.stay) { draft.context.stays = toggle(draft.context.stays, d.stay); return render(); }
    if (d.laundry) { draft.context.laundry = d.laundry; return render(); }
    if (d.rec) { draft.excluded.has(d.rec) ? draft.excluded.delete(d.rec) : draft.excluded.add(d.rec); return render(); }
    if (d.custom) { draft.custom[+d.custom].include = !draft.custom[+d.custom].include; return render(); }
    if (d.act === 'next-step') { draft.name = $('#d-name').value; draft.step = 2; render(); return window.scrollTo(0, 0); }
    if (d.act === 'prev-step') { draft.step = 1; return render(); }
    if (d.act === 'draft-add') return itemForm('新增自訂用品', 'draft-add-save');
    if (d.act === 'draft-add-save') { const v = formValue(); if (!v.name) return toast('請輸入物品名稱'); draft.custom.push({ ...v, staple: false, include: true }); closeSheet(); return render(); }
    if (d.act === 'create') return createTrip();
    if (d.act === 'cancel-new') { draft = null; return go('trips'); }
  }
  // 行程
  if (t) {
    if (d.seg) { ui.seg = d.seg; history.replaceState(null, '', `#trip/${t.id}/${d.seg}`); render(); return; }
    if (d.mode) { store.mode = d.mode; save(); return render(); }
    if (d.filter) { ui.filter = ui.filter === d.filter ? null : d.filter; return render(); }
    if (d.pack) { const i = itemOf(d.pack); i.isPacked = !i.isPacked; ui.lastPacked = i.isPacked ? i.id : null; if (!progress(t).remaining) setTimeout(() => toast('全部裝好了！出發吧'), 300); return commit(); }
    if (d.item) return itemSheet(itemOf(d.item));
    if (d.qty) return qtySheet(itemOf(d.qty));
    if (d.step) { const v = $('#qty-v'); v.textContent = Math.max(1, Math.min(99, +v.textContent + +d.step)); return; }
    if (d.saveQty) { itemOf(d.saveQty).quantity = +$('#qty-v').textContent; closeSheet(); return commit(); }
    if (d.staple) { const i = itemOf(d.staple), existing = store.library.find(s => s.isEssential && normalized(s.name) === normalized(i.name));
      if (existing) existing.isEssential = false; else store.library.push(compact({ id: uuid(), name: i.name, categoryRaw: i.categoryRaw, quantity: i.quantity, unitWeightKg: i.unitWeightKg, isEssential: true, sortIndex: store.library.length, useCount: 0, lastUsedAt: new Date().toISOString() }));
      closeSheet(); toast(existing ? '已從常備清單移除' : '已加入常備清單，之後的新行程會自動帶上'); return commit(); }
    if (d.remove) { const i = itemOf(d.remove);
      if (!i.isCustom) { const names = new Set(t.excludedPackingNamesRaw.split('\n').filter(Boolean)); names.add(i.name); t.excludedPackingNamesRaw = [...names].sort().join('\n');
        if (i.catalogItemID) { const ids = new Set(t.excludedPackingIDsRaw.split('\n').filter(Boolean)); ids.add(i.catalogItemID); t.excludedPackingIDsRaw = [...ids].sort().join('\n'); } }
      t.packingItems = t.packingItems.filter(x => x !== i); closeSheet(); toast(`已移除 ${i.name}`); return commit(); }
    if (d.act === 'add-item') return itemForm('新增物品', 'add-item-save');
    if (d.act === 'add-item-save') { const v = formValue(); if (!v.name) return toast('請輸入物品名稱');
      t.packingItems.push({ id: uuid(), name: v.name, categoryRaw: v.category, reasonKey: CUSTOM_REASON, quantity: v.quantity, isPacked: false, isCustom: true, sortIndex: CUSTOM_SORT }); closeSheet(); return commit(); }
    if (d.cp) { ui.step = d.cp; return render(); }
    if (d.rule) { const checks = store.checks[t.id] ||= {}; checks[d.rule] = !checks[d.rule]; save(); return render(); }
    if (d.act === 'trip-menu') return sheet(`<h3>${esc(t.name)}</h3><div class="group">${t.completedAt ? '<button class="gbtn" data-act="reopen">重新開啟行程</button>' : '<button class="gbtn" data-act="complete">完成行程</button>'}<button class="gbtn danger" data-act="ask-delete">刪除行程</button></div>`);
    if (d.act === 'complete') { t.completedAt = new Date().toISOString(); t.startedAt ||= t.completedAt; t.isClosed = true; closeSheet(); return commit(); }
    if (d.act === 'reopen') { t.completedAt = undefined; t.isClosed = false; closeSheet(); return commit(); }
    if (d.act === 'ask-delete') return confirmSheet('刪除這趟行程？', '行程與打包清單會從這裡移除；有開啟同步時，其他裝置也會一起刪除。', '刪除', 'delete-trip', true);
    if (d.act === 'delete-trip') { store.trips = store.trips.filter(x => x !== t); delete store.checks[t.id]; closeSheet(); save(); scheduleSync(); return go('trips'); }
  }
  // 查詢、知識
  if (d.q) { ui.query = d.q; return render(); }
  if (d.kc) { ui.knowledgeCountry = d.kc; return render(); }
  // 我的
  if (d.pstyle) { store.prefs.packingStyle = d.pstyle; return render(); }
  if (d.pdevice) { const l = store.prefs.devices; store.prefs.devices = l.includes(d.pdevice) ? l.filter(x => x !== d.pdevice) : [...l, d.pdevice]; return render(); }
  if (d.pneed) { const l = store.prefs.needs; store.prefs.needs = l.includes(d.pneed) ? l.filter(x => x !== d.pneed) : [...l, d.pneed]; return render(); }
  if (d.act === 'save-prefs') { store.onboarded = true; save(); toast('已儲存，之後的新行程會套用'); return go('me'); }
  if (d.act === 'add-staple') return itemForm('新增常備用品', 'add-staple-save');
  if (d.act === 'add-staple-save') { const v = formValue(); if (!v.name) return toast('請輸入物品名稱');
    if (essentials().some(s => normalized(s.name) === normalized(v.name))) return toast('常備清單已經有這項用品');
    store.library.push({ id: uuid(), name: v.name, categoryRaw: v.category, quantity: v.quantity, isEssential: true, sortIndex: store.library.length, useCount: 0, lastUsedAt: new Date().toISOString() }); closeSheet(); return commit(); }
  if (d.unstaple) { const s = store.library.find(x => x.id === d.unstaple); s.isEssential = false; return commit(); }
  // 帳號
  if (d.act === 'send-code') { const email = (route.sub === 'account' && $('#email')?.value || account.email).trim().toLowerCase();
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) { account.message = '請輸入正確的 Email。'; return render(); }
    return runAccount(async () => { await cloud.sendCode(email); account.email = email; account.awaiting = true; account.message = `驗證碼已寄到 ${email}。`; }); }
  if (d.act === 'verify') { const code = $('#code').value.trim(); if (!/^\d{6}$/.test(code)) { account.message = '請輸入 6 位數驗證碼。'; return render(); }
    return runAccount(async () => { await cloud.verify(account.email, code); account.awaiting = false; account.health = await cloud.healthConsent().catch(() => null); }); }
  if (d.act === 'change-email') { account.awaiting = false; account.message = ''; return render(); }
  if (d.act === 'sign-out') return runAccount(async () => { await cloud.signOut(); account.conflicts = []; account.health = null; });
  if (d.act === 'toggle-sync') { if (cloud.syncEnabled()) { cloud.setSyncEnabled(false); return render(); }
    return confirmSheet('開啟雲端同步？', `會上傳行程（名稱、目的地、日期、打包偏好與清單、打包狀態）與常備用品，讓你在 iPhone 和網頁版都能使用。「健康」分類的物品預設不上傳。\n\n資料存放在 Supabase（${CONFIG_REGION}）。授權的 PackSmart 管理員在處理你回報的問題時可以查看，每次查看都會留下紀錄。你可以隨時關閉同步或刪除雲端帳號。`, '同意並開啟', 'enable-sync'); }
  if (d.act === 'enable-sync') { closeSheet(); cloud.setSyncEnabled(true); return runAccount(async () => { account.health = await cloud.healthConsent(); await synchronize(); account.message ||= '已開啟同步。'; }); }
  if (d.act === 'toggle-health') { if (account.health) return runAccount(async () => { await cloud.setHealthConsent(false); account.health = false; await synchronize(); });
    return confirmSheet('同步「健康」分類的物品？', '藥品等健康類物品可能屬於敏感個人資料。同意後會上傳到雲端，你登入的每台裝置都會看到，授權管理員處理問題時也可能看到。之後關閉，下一次同步會把它們從雲端移除，裝置上的仍保留。', '同意同步', 'enable-health'); }
  if (d.act === 'enable-health') { closeSheet(); return runAccount(async () => { await cloud.setHealthConsent(true); account.health = true; await synchronize(); }); }
  if (d.act === 'sync-now') return runAccount(() => synchronize());
  if (d.resolve) { const c = account.conflicts[+d.resolve]; return runAccount(async () => { await cloud.resolve(c, d.keep === 'local'); account.conflicts.splice(+d.resolve, 1); }); }
  if (d.act === 'delete-account') return confirmSheet('刪除雲端帳號？', '雲端上的帳號、行程與常備用品會立即刪除，無法復原。這個瀏覽器與其他裝置上的資料會保留。', '刪除雲端帳號', 'delete-account-confirmed', true);
  if (d.act === 'delete-account-confirmed') { closeSheet(); return runAccount(async () => { await cloud.deleteAccount(); account.conflicts = []; account.message = '雲端帳號與資料已刪除；這裡的資料仍保留。'; }); }
});
document.addEventListener('change', e => {
  if (e.target.id === 'd-start') { draft.start = e.target.value; if (draft.end < draft.start) draft.end = draft.start; render(); refreshDraftWeather(); }
  if (e.target.id === 'd-end') { draft.end = e.target.value; render(); refreshDraftWeather(); }
  if (e.target.id === 'd-origin') { draft.origin = e.target.value; if (draft.country === draft.origin) { draft.country = ''; draft.city = ''; } render(); }
  if (e.target.id === 'q-dest') { ui.queryDest = e.target.value; render(); }
});
document.addEventListener('input', e => {
  if (e.target.id === 'q') { ui.query = e.target.value; const pos = e.target.selectionStart; render(); const q = $('#q'); q.focus(); q.setSelectionRange(pos, pos); }
  if (e.target.id === 'd-name' && draft) draft.name = e.target.value;
  if (e.target.id === 'email') account.email = e.target.value;
});
document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') synchronize(true); });

// ---------- 啟動 ----------
await loadData();
parse();
render();
account.health = cloud.session ? await cloud.healthConsent().catch(() => null) : null;
synchronize(true);
if ('serviceWorker' in navigator && location.protocol === 'https:') navigator.serviceWorker.register('sw.js');
