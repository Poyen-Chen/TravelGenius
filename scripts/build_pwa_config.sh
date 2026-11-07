#!/bin/bash
# 由 Supabase CLI 取得 publishable key，寫入 pwa/js/config.js（不印出 key）。用法：scripts/build_pwa_config.sh <project-ref> <地區名稱>
set -euo pipefail
cd "$(dirname "$0")/.."
ref="$1"; region="${2:-未設定}"
supabase projects api-keys --project-ref "$ref" -o json 2>/dev/null | python3 -c "
import json, sys
keys = json.load(sys.stdin)
key = next(k['api_key'] for k in keys if k['type'] == 'publishable')
assert key.startswith('sb_publishable_')
cfg = {'url': f'https://$ref.supabase.co', 'publishableKey': key, 'region': '$region', 'appleServicesID': '', 'appleRedirectURI': ''}
open('pwa/js/config.js', 'w').write('// 由 scripts/build_pwa_config.sh 產生；勿提交。\nexport const CONFIG = ' + json.dumps(cfg, ensure_ascii=False) + ';\n')
"
echo "wrote pwa/js/config.js for $ref"
