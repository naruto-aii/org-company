-- Hand rollback for 20260927170000_store_apple_refresh_tokens.sql.
-- Not picked up by supabase db push. Run it yourself in the SQL editor.
-- Full down-order: supabase/rollback/README.md. This file is second,
-- after the 20260927180000 down and before the 20260927160000 down.
--
-- Drops the three Vault RPCs and deletes this app's Sign in with Apple
-- secrets. Does not drop the supabase_vault extension and does not change
-- public.delete_own_account(). Git revert does not remove secrets that were
-- already stored; this file does.

begin;

drop function if exists public.store_apple_refresh_token(uuid, text);
drop function if exists public.read_apple_refresh_token(uuid);
drop function if exists public.delete_apple_refresh_token(uuid);

delete from vault.secrets
where pg_catalog.starts_with(name, 'apple_refresh_token:');

commit;
