
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

create table if not exists public.saved_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  label text not null check (char_length(label) between 1 and 40),
  address_role text not null default 'other' check (address_role in ('home','work','other')),
  stop_payload jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  service_alerts boolean not null default true,
  journey_reminders boolean not null default true,
  departure_reminders boolean not null default true,
  reward_updates boolean not null default true,
  data_freshness_alerts boolean not null default true,
  reminder_lead_minutes integer not null default 10 check (reminder_lead_minutes in (5,10,15,30)),
  updated_at timestamptz not null default now()
);

create table if not exists public.favorite_folders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 40),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.favorite_folder_items (
  id uuid primary key default gen_random_uuid(),
  folder_id uuid not null references public.favorite_folders(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  item_type text not null check (item_type in ('stop','journey')),
  item_key text not null,
  label text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (folder_id, item_key)
);

create table if not exists public.stop_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  operator_id text not null,
  stop_id text not null,
  rating integer not null check (rating between 1 and 5),
  comment text not null default '' check (char_length(comment) <= 500),
  display_name text not null default 'Commuter',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.stop_reviews
  add column if not exists moderation_status text not null default 'approved';
alter table public.stop_reviews
  add column if not exists moderation_note text;
alter table public.stop_reviews
  add column if not exists moderated_at timestamptz;
alter table public.stop_reviews
  add column if not exists moderated_by uuid references auth.users(id) on delete set null;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'stop_reviews_moderation_status_check'
  ) then
    alter table public.stop_reviews
      add constraint stop_reviews_moderation_status_check
      check (moderation_status in ('pending','approved','rejected','hidden'));
  end if;
end $$;

alter table public.stop_reviews alter column moderation_status set default 'pending';

alter table public.stop_reviews
  drop constraint if exists stop_reviews_user_id_operator_id_stop_id_key;

create index if not exists stop_reviews_user_stop_idx
  on public.stop_reviews(user_id, operator_id, stop_id, created_at desc);

create table if not exists public.review_reports (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.stop_reviews(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null,
  details text not null default '' check (char_length(details) <= 300),
  status text not null default 'open' check (status in ('open','resolved','dismissed')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id) on delete set null,
  unique (review_id, reporter_id)
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
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.alerts add column if not exists created_by uuid references auth.users(id) on delete set null;
alter table public.alerts add column if not exists updated_at timestamptz not null default now();

create table if not exists public.alert_reads (
  user_id uuid not null references auth.users(id) on delete cascade,
  alert_id uuid not null references public.alerts(id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (user_id, alert_id)
);

create index if not exists saved_addresses_user_idx on public.saved_addresses(user_id, created_at desc);
create index if not exists saved_journeys_user_created_idx on public.saved_journeys(user_id, created_at desc);
create index if not exists recent_journeys_user_used_idx on public.recent_journeys(user_id, used_at desc);
create index if not exists favorite_folders_user_idx on public.favorite_folders(user_id, created_at desc);
create index if not exists favorite_folder_items_folder_idx on public.favorite_folder_items(folder_id, created_at);
create index if not exists stop_reviews_stop_idx on public.stop_reviews(operator_id, stop_id, moderation_status, updated_at desc);
create index if not exists review_reports_status_idx on public.review_reports(status, created_at desc);
create index if not exists alerts_active_idx on public.alerts(starts_at, ends_at);

alter table public.user_rewards enable row level security;
alter table public.user_badges enable row level security;
alter table public.user_missions enable row level security;
alter table public.user_reward_claims enable row level security;
alter table public.saved_journeys enable row level security;
alter table public.recent_journeys enable row level security;
alter table public.travel_preferences enable row level security;
alter table public.saved_addresses enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.favorite_folders enable row level security;
alter table public.favorite_folder_items enable row level security;
alter table public.stop_reviews enable row level security;
alter table public.review_reports enable row level security;
alter table public.alerts enable row level security;
alter table public.alert_reads enable row level security;

do $$
declare
  t text;
begin
  foreach t in array array['user_rewards','user_badges','user_missions','user_reward_claims','saved_journeys','recent_journeys','travel_preferences','saved_addresses','notification_preferences','favorite_folders','favorite_folder_items','alert_reads']
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

alter table public.profiles add column if not exists role text not null default 'user';
alter table public.profiles add column if not exists is_suspended boolean not null default false;
alter table public.profiles add column if not exists suspended_at timestamptz;
alter table public.profiles add column if not exists suspended_by uuid references auth.users(id) on delete set null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'profiles_role_check'
  ) then
    alter table public.profiles
      add constraint profiles_role_check check (role in ('user','admin'));
  end if;
end $$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to authenticated;

create or replace function public.admin_dashboard_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
  result jsonb;
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  select jsonb_build_object(
    'total_users', (select count(*) from auth.users),
    'pending_reviews', (select count(*) from public.stop_reviews where moderation_status = 'pending'),
    'open_reports', (select count(*) from public.review_reports where status = 'open'),
    'active_alerts', (select count(*) from public.alerts where starts_at <= now() and (ends_at is null or ends_at >= now()))
  ) into result;

  return result;
end;
$$;

revoke all on function public.admin_dashboard_stats() from public;
grant execute on function public.admin_dashboard_stats() to authenticated;

drop function if exists public.admin_list_users();

create or replace function public.admin_list_users()
returns table (
  id uuid,
  email text,
  full_name text,
  role text,
  is_suspended boolean,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  return query
  select
    u.id,
    coalesce(u.email, '')::text,
    coalesce(p.full_name, '')::text,
    coalesce(p.role, 'user')::text,
    coalesce(p.is_suspended, false),
    u.created_at
  from auth.users u
  left join public.profiles p on p.id = u.id
  order by u.created_at desc;
end;
$$;

revoke all on function public.admin_list_users() from public;
grant execute on function public.admin_list_users() to authenticated;

drop function if exists public.admin_set_user_suspended(uuid, boolean);
drop function if exists public.admin_set_user_suspension(uuid, boolean);

create or replace function public.admin_set_user_suspension(
  p_target_user_id uuid,
  p_suspended boolean
)
returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.is_admin() then
    raise exception 'Admin access required';
  end if;

  if p_target_user_id = auth.uid() then
    raise exception 'You cannot suspend your own admin account';
  end if;

  if exists (
    select 1 from public.profiles
    where id = p_target_user_id and role = 'admin'
  ) then
    raise exception 'Admin accounts are protected from suspension';
  end if;

  update public.profiles
  set
    is_suspended = p_suspended,
    suspended_at = case when p_suspended then now() else null end,
    suspended_by = case when p_suspended then auth.uid() else null end
  where id = p_target_user_id;

  if not found then
    insert into public.profiles (id, is_suspended, suspended_at, suspended_by)
    values (
      p_target_user_id,
      p_suspended,
      case when p_suspended then now() else null end,
      case when p_suspended then auth.uid() else null end
    );
  end if;
end;
$$;

revoke all on function public.admin_set_user_suspension(uuid, boolean) from public;
grant execute on function public.admin_set_user_suspension(uuid, boolean) to authenticated;

drop policy if exists stop_reviews_select_authenticated on public.stop_reviews;
drop policy if exists stop_reviews_select_visible on public.stop_reviews;
create policy stop_reviews_select_visible on public.stop_reviews
  for select to authenticated using (
    moderation_status = 'approved'
    or auth.uid() = user_id
    or public.is_admin()
  );

drop policy if exists stop_reviews_insert_own on public.stop_reviews;
create policy stop_reviews_insert_own on public.stop_reviews
  for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists stop_reviews_update_own on public.stop_reviews;
drop policy if exists stop_reviews_update_own_or_admin on public.stop_reviews;
create policy stop_reviews_update_own_or_admin on public.stop_reviews
  for update to authenticated
  using (
    public.is_admin()
    or (auth.uid() = user_id and moderation_status = 'pending')
  )
  with check (
    public.is_admin()
    or (auth.uid() = user_id and moderation_status = 'pending')
  );

drop policy if exists stop_reviews_delete_own on public.stop_reviews;
drop policy if exists stop_reviews_delete_own_or_admin on public.stop_reviews;
create policy stop_reviews_delete_own_or_admin on public.stop_reviews
  for delete to authenticated using (auth.uid() = user_id or public.is_admin());

drop policy if exists review_reports_select_own_or_admin on public.review_reports;
create policy review_reports_select_own_or_admin on public.review_reports
  for select to authenticated using (auth.uid() = reporter_id or public.is_admin());

drop policy if exists review_reports_insert_own on public.review_reports;
create policy review_reports_insert_own on public.review_reports
  for insert to authenticated with check (
    auth.uid() = reporter_id
    and exists (
      select 1 from public.stop_reviews r
      where r.id = review_id
        and r.user_id <> auth.uid()
        and r.moderation_status = 'approved'
    )
  );

drop policy if exists review_reports_update_admin on public.review_reports;
drop policy if exists review_reports_update_own_or_admin on public.review_reports;
create policy review_reports_update_admin on public.review_reports
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists review_reports_delete_admin on public.review_reports;
create policy review_reports_delete_admin on public.review_reports
  for delete to authenticated using (public.is_admin());

drop policy if exists alerts_read_authenticated on public.alerts;
create policy alerts_read_authenticated on public.alerts
  for select to authenticated
  using (
    starts_at <= now()
    and (ends_at is null or ends_at >= now())
  );

drop policy if exists alerts_select_admin on public.alerts;
create policy alerts_select_admin on public.alerts
  for select to authenticated using (public.is_admin());

drop policy if exists alerts_insert_admin on public.alerts;
create policy alerts_insert_admin on public.alerts
  for insert to authenticated with check (public.is_admin());

drop policy if exists alerts_update_admin on public.alerts;
create policy alerts_update_admin on public.alerts
  for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists alerts_delete_admin on public.alerts;
create policy alerts_delete_admin on public.alerts
  for delete to authenticated using (public.is_admin());

alter table public.profiles add column if not exists avatar_url text;
alter table public.profiles add column if not exists home_stop jsonb;
alter table public.profiles add column if not exists work_stop jsonb;
alter table public.profiles add column if not exists travel_preferences jsonb not null default '{}'::jsonb;

alter table public.travel_preferences
  add column if not exists default_transport text not null default 'any';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'travel_preferences_default_transport_check'
  ) then
    alter table public.travel_preferences
      add constraint travel_preferences_default_transport_check
      check (default_transport in ('any','rail','bus'));
  end if;
end $$;


create or replace function public.protect_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    return new;
  end if;
  if tg_op = 'INSERT' then
    if not public.is_admin() then
      new.role := 'user';
      new.is_suspended := false;
      new.suspended_at := null;
      new.suspended_by := null;
    end if;
  elsif not public.is_admin() then
    if new.role is distinct from old.role then
      new.role := old.role;
    end if;
    if new.is_suspended is distinct from old.is_suspended
      or new.suspended_at is distinct from old.suspended_at
      or new.suspended_by is distinct from old.suspended_by then
      new.is_suspended := old.is_suspended;
      new.suspended_at := old.suspended_at;
      new.suspended_by := old.suspended_by;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_profiles_protect_role on public.profiles;
drop trigger if exists trg_profiles_protect_admin_fields on public.profiles;
drop function if exists public.protect_profile_admin_fields();
create trigger trg_profiles_protect_role
before insert or update on public.profiles
for each row execute function public.protect_profile_role();

create or replace function public.normalize_review_submission()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    if tg_op = 'UPDATE' and old.moderation_status <> 'pending' then
      raise exception 'Only pending reviews can be edited. Delete and submit a new review instead.';
    end if;
    new.moderation_status := 'pending';
    new.moderation_note := null;
    new.moderated_at := null;
    new.moderated_by := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_stop_reviews_normalize_submission on public.stop_reviews;
create trigger trg_stop_reviews_normalize_submission
before insert or update on public.stop_reviews
for each row execute function public.normalize_review_submission();

create or replace function public.normalize_review_report()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then
    new.status := 'open';
    new.resolved_at := null;
    new.resolved_by := null;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_review_reports_normalize on public.review_reports;
create trigger trg_review_reports_normalize
before insert or update on public.review_reports
for each row execute function public.normalize_review_report();

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

drop trigger if exists trg_saved_addresses_updated_at on public.saved_addresses;
create trigger trg_saved_addresses_updated_at before update on public.saved_addresses
for each row execute function public.set_updated_at();

drop trigger if exists trg_notification_preferences_updated_at on public.notification_preferences;
create trigger trg_notification_preferences_updated_at before update on public.notification_preferences
for each row execute function public.set_updated_at();

drop trigger if exists trg_favorite_folders_updated_at on public.favorite_folders;
create trigger trg_favorite_folders_updated_at before update on public.favorite_folders
for each row execute function public.set_updated_at();

drop trigger if exists trg_stop_reviews_updated_at on public.stop_reviews;
create trigger trg_stop_reviews_updated_at before update on public.stop_reviews
for each row execute function public.set_updated_at();


drop trigger if exists trg_alerts_updated_at on public.alerts;
create trigger trg_alerts_updated_at before update on public.alerts
for each row execute function public.set_updated_at();

create unique index if not exists favourite_stops_user_stop_unique
  on public.favourite_stops(user_id, stop_id);

alter table public.profiles enable row level security;
alter table public.favourite_stops enable row level security;

drop policy if exists profiles_select_own_or_admin on public.profiles;
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles
  for select to authenticated using (auth.uid() = id);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles
  for insert to authenticated with check (auth.uid() = id);

drop policy if exists profiles_update_own_or_admin on public.profiles;
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


create or replace function public.delete_my_account()
returns void
language plpgsql
security definer
set search_path = pg_catalog
as $$
declare
  target_id uuid := auth.uid();
begin
  if target_id is null then
    raise exception 'Not authenticated';
  end if;

  delete from public.favourite_stops where user_id = target_id;
  delete from public.profiles where id = target_id;
  delete from auth.users where id = target_id;
end;
$$;

revoke all on function public.delete_my_account() from public;
grant execute on function public.delete_my_account() to authenticated;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do update set public = true;

drop policy if exists avatars_select_public on storage.objects;
create policy avatars_select_public on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists avatars_insert_own on storage.objects;
create policy avatars_insert_own on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists avatars_delete_own on storage.objects;
create policy avatars_delete_own on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
