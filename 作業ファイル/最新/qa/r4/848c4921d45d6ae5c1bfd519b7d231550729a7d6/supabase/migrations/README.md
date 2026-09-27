# Supabase migrations

## Grant hardening policy

Every migration that creates objects in `public` must set explicit privileges.
Do not assume Supabase default grants or `supabase_admin` default ACLs are safe.

### Tables and sequences

```sql
revoke all on table public.new_table from anon, authenticated;
grant select, insert, update on table public.new_table to authenticated;
-- grant anon only when a public-read RLS policy requires it (rare)
```

Use the smallest privilege set matching app usage. Prefer soft-delete (`UPDATE`)
over `DELETE` when the app does not hard-delete rows.

### Functions exposed to clients

```sql
revoke all on function public.some_rpc(...) from public, anon, authenticated;
grant execute on function public.some_rpc(...) to authenticated;
```

RLS policy helpers may grant `EXECUTE` to `anon` when policies call them, but
helpers must not query personal tables as `anon` unless unavoidable. Prefer
early return in `plpgsql` when `auth.uid() is null`.

### Internal triggers and SECURITY DEFINER RPCs

Leave owned by `postgres`. Do not grant `EXECUTE` to `anon` / `authenticated`.
They run with owner privileges.

### `supabase_admin` default privileges

Migration runner (`postgres`) may lack permission to
`ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin`. The hardening migration
skips safely with `NOTICE` in that case. **Always** add explicit
`REVOKE ALL` / `GRANT` on each new table and function in the same migration
that creates it.

### `seed.sql`

Local seed is for test **data** only. Never put `GRANT`, `REVOKE`,
`ALTER DEFAULT PRIVILEGES`, or schema DDL in `seed.sql`.
