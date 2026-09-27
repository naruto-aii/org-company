-- Cleanup Food Master V1.1 SQL test fixtures (local Supabase only).
-- Requires: food_master_v1_1_test_helpers.sql
-- Run: psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/food_master_v1_1_cleanup.sql

select ayg_test.cleanup_fixtures();
do $$ begin raise notice 'FIXTURE CLEANUP COMPLETE'; end $$;
