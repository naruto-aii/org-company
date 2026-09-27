# Rollback order

These files are not migrations. `supabase db push` does not apply them.
Do not run them against production unless a rollback of this stack is intentional.

When every unpublished migration from pull requests #25 through #29 has been
applied, roll them back by running the files below in this order (newest
first). Do not sort them oldest-first.

Apply the forward migrations `20260927120000` through `20260927180000`
together in one batch. Without `20260927180000`, a failed email
anonymization is swallowed and deletion is reported as success.

1. `20260927180000_delete_own_account_service_role_only_down.sql`
   Drops `delete_own_account(uuid)` and restores the zero-argument function.
   The email rewrite stays outside an exception handler. Run this before the
   160000 down. If it is skipped, the uuid function remains and still writes
   `saved_foods.owner_deleted`.

2. `20260927170000_store_apple_refresh_tokens_down.sql`
   Drops the Vault RPCs and deletes secrets named `apple_refresh_token:*`.
   Does not change `delete_own_account`.

3. `20260927160000_delete_subscription_events_on_account_deletion_down.sql`
   Restores a zero-argument `delete_own_account` that still sets
   `owner_deleted` and does not delete `subscription_events`. The email
   rewrite stays outside an exception handler: a failure aborts and rolls
   the deletion back. Run this before the 150000 down.

4. `20260927150000_protect_owner_deleted_and_revoke_sessions_down.sql`
   Restores the already-applied `20260920120000` body (that body still
   ignores a failed email rewrite), then drops `saved_foods.owner_deleted`
   and the guard trigger. Running this file before the 160000 down drops
   the column, and the 160000 down then reinstalls a function that writes
   `owner_deleted`. The next account deletion fails.

5. `20260927140000_subscription_events_down.sql`
   Drops `public.subscription_events`. The function restored by the 160000
   down does not delete from that table.

6. `20260927120000_reject_banned_public_food_names_down.sql`
   Restores publish and validate from `20260723120000` and drops the
   banned-name helpers.
