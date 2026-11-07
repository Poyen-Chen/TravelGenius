// 複製成 js/config.js（已 gitignore），或執行 scripts/build_pwa_config.sh 從 Supabase CLI 產生。
// 只能放 publishable key；資料保護靠登入身分與 RLS。不設定時 PWA 只用瀏覽器本機資料。
// appleServicesID 是 Sign in with Apple 的 Services ID（公開值）；空白時不顯示 Apple 按鈕（PD-068）。
// appleRedirectURI 是在 Apple 註冊的網址；空白時用目前網頁的網址。.p8 與 client secret 只放在 Supabase。
export const CONFIG = { url: 'https://YOUR_PROJECT_REF.supabase.co', publishableKey: 'sb_publishable_...', region: '新加坡', appleServicesID: '', appleRedirectURI: '' };
