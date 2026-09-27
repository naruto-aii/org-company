create schema auth;
create table auth.users (id uuid primary key, email text, raw_user_meta_data jsonb);
create table auth.identities (id uuid default gen_random_uuid() primary key, user_id uuid references auth.users(id));
create table auth.sessions (id uuid default gen_random_uuid() primary key, user_id uuid);
create table auth.refresh_tokens (id bigserial primary key, user_id varchar(255));
create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
create function auth.role() returns text language sql stable as $$ select nullif(current_setting('request.jwt.claim.role', true), '') $$;
grant usage on schema auth to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;
