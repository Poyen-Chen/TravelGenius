// 建立行程時的天氣參考：移植自 WeatherService.swift／WeatherPlanning.swift。
// 產生的 JSON 與 iOS 的 PackingWeather 相同，存進 packingWeatherRaw 後兩邊都能讀。
import { DATA, defaultCity, datesBetween } from './engine.js';

const REFERENCE_EPOCH = 978307200; // Swift Date 預設以 2001-01-01 為基準
const dayIn = (timeZone, date = new Date()) => new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit' }).format(date);
const addDays = (day, n) => { const d = new Date(day + 'T00:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); };

export function weatherRequest(countryCode, cityName, start, end) {
  const city = DATA.cities.find(c => c.countryCode === countryCode && c.cityZh === cityName) || defaultCity(countryCode);
  if (!city) return null;
  const cityID = `${countryCode}-${city.cityZh}`;
  const profile = DATA.seasonal_weather.find(p => p.cityID === cityID);
  if (!profile) return null;
  return { cityID, cityName: city.cityZh, latitude: city.lat, longitude: city.lon, timeZoneID: profile.timeZoneID, start, end, provider: 'openmeteo' };
}

function snapshot(request, days, failure) {
  const profile = DATA.seasonal_weather.find(p => p.cityID === request.cityID) || null;
  const value = { version: 1, request, days, fetchedAt: Date.now() / 1000 - REFERENCE_EPOCH };
  if (profile) value.seasonal = profile;
  const all = datesBetween(request.start, request.end);
  const reason = failure ?? (days.length < all.length ? 'incomplete' : null);
  if (reason) value.failure = reason;
  return value;
}

export async function fetchWeather(request) {
  const today = dayIn(request.timeZoneID), horizon = addDays(today, 15);
  const allowed = datesBetween(request.start, request.end).filter(d => d >= today && d <= horizon);
  if (!allowed.length) return snapshot(request, [], 'outsideRange');
  const url = new URL('https://api.open-meteo.com/v1/forecast');
  Object.entries({ latitude: request.latitude, longitude: request.longitude, timezone: request.timeZoneID,
    start_date: allowed[0], end_date: allowed.at(-1), daily: 'temperature_2m_max,temperature_2m_min,precipitation_probability_max' })
    .forEach(([k, v]) => url.searchParams.set(k, v));
  try {
    const response = await fetch(url, { signal: AbortSignal.timeout(8000) });
    if (!response.ok) return snapshot(request, [], 'unavailable');
    const { daily } = await response.json();
    const days = (daily?.time || []).map((date, i) => ({ date, low: daily.temperature_2m_min[i], high: daily.temperature_2m_max[i],
      rainChance: daily.precipitation_probability_max[i] == null ? null : daily.precipitation_probability_max[i] / 100 }))
      .filter(d => allowed.includes(d.date) && [d.low, d.high, d.rainChance].every(Number.isFinite) && d.low <= d.high && d.rainChance >= 0 && d.rainChance <= 1);
    return snapshot(request, days, null);
  } catch (error) {
    return snapshot(request, [], error?.name === 'TimeoutError' ? 'timeout' : navigator.onLine === false ? 'offline' : 'unavailable');
  }
}

export const FAILURE = { outsideRange: '旅行日期不在目前可取得的預報範圍，先用季節參考。', unavailable: '暫時無法取得天氣預報，先用季節參考。',
  offline: '目前無法連線取得預報，先用季節參考。', timeout: '天氣查詢逾時，先使用季節參考。', incomplete: '部分日期缺少預報，其餘用季節參考。' };
