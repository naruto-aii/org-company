-- Stand-in used only when the real supabase_vault extension is absent.
-- The smoke test copies this into Postgres's extension directory.

create table vault.secrets (
  id uuid primary key default gen_random_uuid(),
  name text unique,
  secret text,
  description text
);

create view vault.decrypted_secrets as
  select id, name, secret as decrypted_secret, description
  from vault.secrets;

create function vault.create_secret(
  new_secret text,
  new_name text default null,
  new_description text default ''
)
returns uuid
language plpgsql
as $$
declare
  new_id uuid;
begin
  insert into vault.secrets (name, secret, description)
  values (new_name, new_secret, new_description)
  returning id into new_id;
  return new_id;
end;
$$;

create function vault.update_secret(
  secret_id uuid,
  new_secret text default null,
  new_name text default null,
  new_description text default null
)
returns void
language plpgsql
as $$
begin
  update vault.secrets
  set secret = coalesce(new_secret, secret),
      name = coalesce(new_name, name),
      description = coalesce(new_description, description)
  where id = secret_id;
end;
$$;
