# Sign in with Apple token revocation

Native Sign in with Apple (iOS / macOS) sends the authorization code to the
`store-apple-refresh-token` Edge Function. The function exchanges it at Apple
for a refresh token and stores that token in Supabase Vault. The app never
sees the refresh token.

`delete-account` reads the token, calls `https://appleid.apple.com/auth/revoke`,
then calls `public.delete_own_account()` with the user's JWT. A failed revoke
is logged and does not stop deletion. Responses to the app are `{ stored: true|false }`
or `{ ok: true|false }` with no Apple or database error text.

Web and Android Apple OAuth do not give the app an authorization code, so those
sessions have nothing to revoke. Deletion still runs.

This change does not deploy functions and does not apply the migration.

## Secrets

Set these in the Supabase project with the CLI. Put the values only in that
command, never in git, `supabase/config.toml`, or a committed env file.

- `APPLE_TEAM_ID` — Apple Developer Team ID
- `APPLE_KEY_ID` — Sign in with Apple key id
- `APPLE_PRIVATE_KEY` — contents of the Apple `.p8` key (PKCS#8). Literal `\n`
  sequences are accepted.
- `APPLE_CLIENT_ID` — native app bundle id `com.narutoaii.ayg`

```sh
supabase secrets set \
  APPLE_TEAM_ID=... \
  APPLE_KEY_ID=... \
  APPLE_PRIVATE_KEY=... \
  APPLE_CLIENT_ID=...
```

`APPLE_CLIENT_ID` must be the bundle id above. The other three values stay with
the account owner. The function reads the names from the environment; it does
not fall back to a committed client id.

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are injected
by the platform. Do not commit those either.

Keep `verify_jwt = true` for both functions.

Deploy is a separate owner step after the migration is applied:

```sh
supabase functions deploy store-apple-refresh-token
supabase functions deploy delete-account
```

Until those functions exist, account deletion in the app shows the existing
unavailable message and does not print the server response.

## Rollback

1. Revert this change. The app calls `delete_own_account` directly again.
2. If `supabase/migrations/20260927170000_store_apple_refresh_tokens.sql` was
   applied, run `supabase/rollback/20260927170000_store_apple_refresh_tokens_down.sql`
   by hand. It drops `store_apple_refresh_token`, `read_apple_refresh_token`,
   and `delete_apple_refresh_token`, and deletes Vault rows whose names start
   with `apple_refresh_token:`. It does not drop the Vault extension and does
   not change `delete_own_account`. The down file is outside `supabase/migrations`,
   so `supabase db push` will not run it. A git revert does not delete secrets
   already stored.
3. If the functions were deployed, delete them:

```sh
supabase functions delete store-apple-refresh-token
supabase functions delete delete-account
```

4. Optional: `supabase secrets unset APPLE_TEAM_ID APPLE_KEY_ID APPLE_PRIVATE_KEY APPLE_CLIENT_ID`.

## Tests

```sh
deno test supabase/functions/_shared/apple_account_test.ts
```
