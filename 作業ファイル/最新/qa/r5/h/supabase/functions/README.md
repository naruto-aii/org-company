# Sign in with Apple token revocation

Native Sign in with Apple (iOS / macOS) sends the authorization code to the
`store-apple-refresh-token` Edge Function. The function exchanges it at Apple
for a refresh token and stores that token in Supabase Vault. The app never
sees the refresh token.

`delete-account` reads any stored token, then calls
`public.delete_own_account(uuid)` with the service role. The user id is the
one returned by the Auth API for the caller's JWT. The request body is not
used as a user id. `anon` and `authenticated` cannot execute the function.
Apple is called only after that deletion succeeds. A failed deletion does not
call `https://appleid.apple.com/auth/revoke` and does not remove the Vault row.

When a refresh token was stored, a failed revoke is logged and the account
stays deleted. The response is `{ ok: true, apple_revoke_failed: true }` so
the app can tell the user to remove the app from Sign in with Apple. The
Vault row is still deleted after that. If that delete fails, the row can
remain; there is no later cleanup job.

When no token is stored, the function asks the Auth admin API whether the
user has an Apple identity. An Apple identity sets the same
`apple_revoke_failed` flag and does not call Apple. No Apple identity omits
the flag. If that lookup fails, the flag is omitted and the failure is logged.
Other responses are `{ stored: true|false }` or `{ ok: true|false }` with no
Apple or database error text.

Web and Android Apple OAuth do not give the app an authorization code, so
those sessions have nothing to revoke. Deletion still runs, and an Apple
identity still sets the flag above.

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
by the platform. Do not commit those either. Do not set
`ALLOW_LOCALHOST_ORIGIN` on the production project. It is off when unset, and
only `https://naruto-aii.github.io` can call these functions from a browser.

Keep `verify_jwt = true` for both functions.

Production allows only `Origin: https://naruto-aii.github.io` (the web preview).
`http://localhost` and `http://127.0.0.1` on any port are allowed only when
`ALLOW_LOCALHOST_ORIGIN=true` is set. Leave that variable unset in production.
Any other origin, including localhost while the variable is unset, gets no
`Access-Control-Allow-Origin` header. Native apps do not send `Origin`.

Deploy, in this order, before the app that calls `delete-account` is released:

1. Apply migrations in timestamp order through
   `20260927180000_delete_own_account_service_role_only.sql`. That migration
   drops the client-callable `delete_own_account()` and leaves deletion to the
   service role.
2. Set the four Apple secrets above.
3. Deploy both functions:

```sh
supabase functions deploy store-apple-refresh-token
supabase functions deploy delete-account
```

4. Release the app only after steps 1–3 succeed.

If `delete-account` is not deployed, the app shows that deletion did not happen
and does not sign the user out. It does not call `delete_own_account` itself.

## Rollback

1. Revert this change. The app calls `delete_own_account` directly again only
   after the database grant is restored in step 2.
2. If `supabase/migrations/20260927180000_delete_own_account_service_role_only.sql`
   was applied, run
   `supabase/rollback/20260927180000_delete_own_account_service_role_only_down.sql`
   by hand first. It restores the zero-argument function and `EXECUTE` for
   `authenticated`.
3. If `supabase/migrations/20260927170000_store_apple_refresh_tokens.sql` was
   applied, run `supabase/rollback/20260927170000_store_apple_refresh_tokens_down.sql`
   by hand. It drops `store_apple_refresh_token`, `read_apple_refresh_token`,
   and `delete_apple_refresh_token`, and deletes Vault rows whose names start
   with `apple_refresh_token:`. It does not drop the Vault extension and does
   not change `delete_own_account`. The down files are outside `supabase/migrations`,
   so `supabase db push` will not run them. A git revert does not delete secrets
   already stored.
4. If the functions were deployed, delete them:

```sh
supabase functions delete store-apple-refresh-token
supabase functions delete delete-account
```

5. Optional: `supabase secrets unset APPLE_TEAM_ID APPLE_KEY_ID APPLE_PRIVATE_KEY APPLE_CLIENT_ID`.

## Tests

```sh
deno test --allow-env=ALLOW_LOCALHOST_ORIGIN --config supabase/functions/deno.json supabase/functions/_shared/apple_account_test.ts
```
