-- Stores Sign in with Apple refresh tokens in Supabase Vault.
-- Not applied to production by this change.
--
-- The ciphertext lives in vault.secrets. That schema is not in the Data API
-- (public, graphql_public). These three functions are the only app access.
-- They run as the owner so they can use Vault. EXECUTE is granted only to
-- service_role. The Edge Function calls them with the service role key and
-- never returns the token to the app.
--
-- Do not put Apple key material in this file. The Edge Function reads
-- APPLE_TEAM_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY, and APPLE_CLIENT_ID from
-- secrets.

begin;

do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_extension
    where extname = 'supabase_vault'
  ) then
    create extension supabase_vault with schema vault;
  end if;
end
$$;

-- vault.create_secret(new_secret, new_name, new_description)
-- vault.update_secret(secret_id, new_secret, new_name, new_description)
create or replace function public.store_apple_refresh_token(
  p_user_id uuid,
  p_refresh_token text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  secret_name text := 'apple_refresh_token:' || p_user_id::text;
  existing_id uuid;
begin
  if p_user_id is null
    or p_refresh_token is null
    or pg_catalog.length(pg_catalog.btrim(p_refresh_token)) = 0
  then
    raise exception 'apple refresh token payload is empty';
  end if;

  select s.id
    into existing_id
  from vault.secrets s
  where s.name = secret_name;

  if existing_id is not null then
    perform vault.update_secret(
      existing_id,
      p_refresh_token,
      secret_name,
      'Sign in with Apple refresh token'
    );
    return;
  end if;

  begin
    perform vault.create_secret(
      p_refresh_token,
      secret_name,
      'Sign in with Apple refresh token'
    );
  exception
    when unique_violation then
      select s.id
        into existing_id
      from vault.secrets s
      where s.name = secret_name;
      if existing_id is null then
        raise;
      end if;
      perform vault.update_secret(
        existing_id,
        p_refresh_token,
        secret_name,
        'Sign in with Apple refresh token'
      );
  end;
end;
$$;

create or replace function public.read_apple_refresh_token(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  token text;
begin
  if p_user_id is null then
    return null;
  end if;

  select d.decrypted_secret
    into token
  from vault.decrypted_secrets d
  where d.name = 'apple_refresh_token:' || p_user_id::text
  limit 1;

  return token;
end;
$$;

create or replace function public.delete_apple_refresh_token(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_user_id is null then
    return;
  end if;

  delete from vault.secrets as s
  where s.name = 'apple_refresh_token:' || p_user_id::text;
end;
$$;

revoke all on function public.store_apple_refresh_token(uuid, text) from public;
revoke all on function public.store_apple_refresh_token(uuid, text) from anon;
revoke all on function public.store_apple_refresh_token(uuid, text) from authenticated;
grant execute on function public.store_apple_refresh_token(uuid, text) to service_role;

revoke all on function public.read_apple_refresh_token(uuid) from public;
revoke all on function public.read_apple_refresh_token(uuid) from anon;
revoke all on function public.read_apple_refresh_token(uuid) from authenticated;
grant execute on function public.read_apple_refresh_token(uuid) to service_role;

revoke all on function public.delete_apple_refresh_token(uuid) from public;
revoke all on function public.delete_apple_refresh_token(uuid) from anon;
revoke all on function public.delete_apple_refresh_token(uuid) from authenticated;
grant execute on function public.delete_apple_refresh_token(uuid) to service_role;

commit;
