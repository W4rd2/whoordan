create index if not exists strength_workouts_user_workout_owner_idx
  on public.strength_workouts(user_id, workout_id)
  where workout_id is not null;
