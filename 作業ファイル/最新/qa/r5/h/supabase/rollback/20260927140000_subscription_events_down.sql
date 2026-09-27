-- Manual rollback for 20260927140000_subscription_events.sql.
-- This file is not a migration. Do not move it into supabase/migrations.
-- Full down-order: supabase/rollback/README.md. Run this after the
-- 20260927150000 down and before the 20260927120000 down.
-- Apply it by hand only when reverting the subscription metrics change.
-- Never run this against production unless that revert is intentional.

begin;

drop trigger if exists subscription_events_force_row on public.subscription_events;
drop function if exists public.subscription_events_force_row();
drop function if exists public.subscription_event_counts();
drop table if exists public.subscription_events;

commit;
