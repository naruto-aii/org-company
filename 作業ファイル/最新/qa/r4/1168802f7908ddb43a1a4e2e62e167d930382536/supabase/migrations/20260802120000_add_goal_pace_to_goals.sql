-- GoalPace（減量・増量ペース）を goals に追加。
-- 既存行は NULL = アプリ側で standard にフォールバック。

alter table public.goals
  add column if not exists goal_pace text;

alter table public.goals
  drop constraint if exists goals_goal_pace_check;

alter table public.goals
  add constraint goals_goal_pace_check
  check (goal_pace is null or goal_pace in ('slow', 'standard'));

comment on column public.goals.goal_pace is
  '減量・増量時のペース（slow/standard）。維持または未設定は NULL。';
