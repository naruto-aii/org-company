#!/bin/bash
# fetch.sh N : fetch selected blobs of head N using tree json
n=$1; sha=$(readlink h$n)
python3 - "$n" <<'PY' > list$n.txt
import json,sys
n=sys.argv[1]
d=json.load(open(f'tree{n}.json'))
for t in d['tree']:
  p=t['path']
  if t['type']!='blob': continue
  if (p.startswith('.github') or p.startswith('supabase/migrations/') or p.startswith('supabase/rollback') or p.startswith('supabase/tests') or p.startswith('supabase/functions') or p in ('supabase/config.toml',)
      or p.startswith('lib/moderation/') or p in ('test/public_food_name_moderation_test.dart','legal/privacy.html','legal/account-deletion.html',
      'lib/repositories/account_deletion_rpc.dart','lib/repositories/supabase_authentication_repository.dart','lib/repositories/apple_refresh_token.dart',
      'lib/screens/settings/account_deletion_screen.dart','lib/constants/app_strings.dart','lib/repositories/auth_exceptions.dart','docs/legal/README.md','supabase/migrations/README.md','ios/Runner/PrivacyInfo.xcprivacy','docs/app-review/app-privacy-draft.md')):
    print(p)
PY
while read p; do mkdir -p $sha/$(dirname "$p"); curl -sfL "https://raw.githubusercontent.com/naruto-aii/AYG/$sha/$p" -o "$sha/$p" || echo "FAIL $p"; done < list$n.txt
