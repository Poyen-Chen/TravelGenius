// 複製成 js/config.js（已 gitignore），或執行 scripts/build_pwa_config.sh 從 Supabase CLI 產生。
// 只能放 publishable key；資料保護靠登入身分與 RLS。不設定時 PWA 只用瀏覽器本機資料。
export const CONFIG = { url: 'https://YOUR_PROJECT_REF.supabase.co', publishableKey: 'sb_publishable_...', region: '新加坡' };
