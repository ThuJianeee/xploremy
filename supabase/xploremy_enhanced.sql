-- XploreMY Enhanced schema additions
-- Run in Supabase SQL Editor after the existing auth/profiles setup.
-- All user-owned tables are protected with Row Level Security (RLS).

create extension if not exists pgcrypto;

create table if not exists public.user_rewards (
  user_id uuid primary key references auth.users(id) on delete cascade,
  xp integer not null default 0 check (xp >= 0),
  streak integer not null default 0 check (streak >= 0),
  last_active_date date,
  updated_at timestamptz not null default now()
);

create table if not exists public.user_badges (
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_id text not null,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, badge_id)
);

create table if not exists public.user_missions (
  user_id uuid not null references auth.users(id) on delete cascade,
  mission_id text not null,
  progress integer not null default 0 check (progress >= 0),
  completed_at timestamptz,
  updated_at timestamptz not null default now(),
  primary key (user_id, mission_id)
);

create table if not exists public.user_reward_claims (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reward_id text not null,
  xp_cost integer not null default 0 check (xp_cost >= 0),
  claimed_at timestamptz not null default now(),
  unique (user_id, reward_id)
);

create table if not exists public.saved_journeys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  label text,
  from_payload jsonb not null,
  to_payload jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.recent_journeys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  from_payload jsonb not null,
  to_payload jsonb not null,
  used_at timestamptz not null default now()
);

create table if not exists public.travel_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  home_payload jsonb,
  work_payload jsonb,
  prefer_fewer_transfers boolean not null default false,
  prefer_less_walking boolean not null default false,
  prefer_rail boolean not null default false,
  accessible_mode boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.alerts (
  id uuid primary key default gen_random_uuid(),
  operator_id text,
  title text not null,
  body text not null,
  severity text not null default 'info' check (severity in ('info','warning','critical')),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  source_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.alert_reads (
  user_id uuid not null references auth.users(id) on delete cascade,
  alert_id uuid not null references public.alerts(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (user_id, alert_id)
);

create index if not exists saved_journeys_user_created_idx on public.saved_journeys(user_id, created_at desc);
create index if not exists recent_journeys_user_used_idx on public.recent_journeys(user_id, used_at desc);
create index if not exists alerts_active_idx on public.alerts(starts_at, ends_at);

alter table public.user_rewards enable row level security;
alter table public.user_badges enable row level security;
alter table public.user_missions enable row level security;
alter table public.user_reward_claims enable row level security;
alter table public.saved_journeys enable row level security;
alter table public.recent_journeys enable row level security;
alter table public.travel_preferences enable row level security;
alter table public.alerts enable row level security;
alter table public.alert_reads enable row level security;

-- User-owned tables: a signed-in user can only access their own rows.
do $$
declare
  t text;
begin
  foreach t in array array['user_rewards','user_badges','user_missions','user_reward_claims','saved_journeys','recent_journeys','travel_preferences','alert_reads']
  loop
    execute format('drop policy if exists %I on public.%I', t || '_select_own', t);
    execute format('drop policy if exists %I on public.%I', t || '_insert_own', t);
    execute format('drop policy if exists %I on public.%I', t || '_update_own', t);
    execute format('drop policy if exists %I on public.%I', t || '_delete_own', t);

    execute format('create policy %I on public.%I for select to authenticated using (auth.uid() = user_id)', t || '_select_own', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (auth.uid() = user_id)', t || '_insert_own', t);
    execute format('create policy %I on public.%I for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id)', t || '_update_own', t);
    execute format('create policy %I on public.%I for delete to authenticated using (auth.uid() = user_id)', t || '_delete_own', t);
  end loop;
end $$;

-- Alerts are readable by signed-in users, but app clients cannot create/edit them.
drop policy if exists alerts_read_authenticated on public.alerts;
create policy alerts_read_authenticated on public.alerts
  for select to authenticated
  using (
    starts_at <= now()
    and (ends_at is null or ends_at >= now())
  );

-- Optional profile columns for cross-device preference summaries.
alter table public.profiles add column if not exists home_stop jsonb;
alter table public.profiles add column if not exists work_stop jsonb;
alter table public.profiles add column if not exists travel_preferences jsonb not null default '{}'::jsonb;

-- Helper trigger for updated_at columns.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_user_rewards_updated_at on public.user_rewards;
create trigger trg_user_rewards_updated_at before update on public.user_rewards
for each row execute function public.set_updated_at();

drop trigger if exists trg_user_missions_updated_at on public.user_missions;
create trigger trg_user_missions_updated_at before update on public.user_missions
for each row execute function public.set_updated_at();

drop trigger if exists trg_saved_journeys_updated_at on public.saved_journeys;
create trigger trg_saved_journeys_updated_at before update on public.saved_journeys
for each row execute function public.set_updated_at();

drop trigger if exists trg_travel_preferences_updated_at on public.travel_preferences;
create trigger trg_travel_preferences_updated_at before update on public.travel_preferences
for each row execute function public.set_updated_at();

-- Harden the existing core tables used by the current app.
-- These statements assume the existing README setup has already created them.
create unique index if not exists favourite_stops_user_stop_unique
  on public.favourite_stops(user_id, stop_id);

alter table public.profiles enable row level security;
alter table public.favourite_stops enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated using (auth.uid() = id);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (auth.uid() = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists favourite_stops_select_own on public.favourite_stops;
create policy favourite_stops_select_own on public.favourite_stops
  for select to authenticated using (auth.uid() = user_id);

drop policy if exists favourite_stops_insert_own on public.favourite_stops;
create policy favourite_stops_insert_own on public.favourite_stops
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists favourite_stops_update_own on public.favourite_stops;
create policy favourite_stops_update_own on public.favourite_stops
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists favourite_stops_delete_own on public.favourite_stops;
create policy favourite_stops_delete_own on public.favourite_stops
  for delete to authenticated using (auth.uid() = user_id);
