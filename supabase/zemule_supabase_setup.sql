-- Zemule Supabase setup
-- Run in Supabase SQL Editor for project: zshiwjywiajevjtfrtsi

create extension if not exists "pgcrypto";
create extension if not exists "cube";
create extension if not exists "earthdistance";

create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  name text,
  avatar_url text,
  pin_hash text,
  pin_enabled boolean default false,
  created_at timestamptz not null default now(),
  last_login timestamptz
);

alter table public.users
add column if not exists pin_hash text,
add column if not exists pin_enabled boolean default false,
add column if not exists is_admin boolean not null default false;

create table if not exists public.login_attempts (
  id uuid primary key default gen_random_uuid(),
  email text not null,
  attempted_at timestamptz default now(),
  success boolean default false
);

grant insert on table public.login_attempts to anon, authenticated;

drop table if exists public.reset_otps;

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id) on delete cascade,
  name text not null,
  category text not null,
  description text default '',
  phone text,
  whatsapp text,
  email text,
  website text,
  address text not null,
  area text not null,
  latitude double precision default 0,
  longitude double precision default 0,
  photos text[] not null default '{}',
  services jsonb not null default '[]'::jsonb,
  opening_hours jsonb not null default '{}'::jsonb,
  rating numeric(3,2) not null default 0,
  review_count integer not null default 0,
  status text not null default 'pending',
  is_premium boolean not null default false,
  premium_expiry timestamptz,
  owner_reply jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

alter table public.businesses
add column if not exists main_category text default '',
add column if not exists subcategory text default '',
add column if not exists city text default '',
add column if not exists views integer not null default 0,
add column if not exists calls integer not null default 0,
add column if not exists whatsapp_clicks integer not null default 0;

create index if not exists businesses_status_idx
on public.businesses (status);

create index if not exists businesses_area_lower_idx
on public.businesses (lower(area));

create index if not exists businesses_city_lower_idx
on public.businesses (lower(city));

create index if not exists businesses_location_idx
on public.businesses using gist (ll_to_earth(latitude, longitude))
where latitude between -90 and 90
  and longitude between -180 and 180
  and not (latitude = 0 and longitude = 0);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text default '',
  photos text[] not null default '{}',
  is_anonymous boolean not null default false,
  owner_reply jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);

create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  business_id uuid not null references public.businesses(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, business_id)
);

create table if not exists public.feature_flags (
  flag_name text primary key,
  is_enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

create table if not exists public.business_interactions (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  user_id uuid references public.users(id) on delete set null,
  interaction_type text not null check (
    interaction_type in ('view', 'call', 'whatsapp', 'review')
  ),
  area text,
  created_at timestamptz not null default now()
);

create or replace function public.increment_business_counter(
  target_business_id uuid,
  counter_name text,
  increment_by integer default 1
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if target_business_id is null then
    return;
  end if;

  if coalesce(increment_by, 0) <= 0 then
    return;
  end if;

  if counter_name not in ('views', 'calls', 'whatsapp_clicks') then
    return;
  end if;

  update public.businesses
  set
    views = case
      when counter_name = 'views' then coalesce(views, 0) + increment_by
      else coalesce(views, 0)
    end,
    calls = case
      when counter_name = 'calls' then coalesce(calls, 0) + increment_by
      else coalesce(calls, 0)
    end,
    whatsapp_clicks = case
      when counter_name = 'whatsapp_clicks' then coalesce(whatsapp_clicks, 0) + increment_by
      else coalesce(whatsapp_clicks, 0)
    end,
    updated_at = now()
  where id = target_business_id;
end;
$$;

create or replace function public.touch_feature_flag_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists touch_feature_flag_updated_at on public.feature_flags;
create trigger touch_feature_flag_updated_at
before update on public.feature_flags
for each row
execute function public.touch_feature_flag_updated_at();

alter table public.users enable row level security;
alter table public.businesses enable row level security;
alter table public.reviews enable row level security;
alter table public.favorites enable row level security;
alter table public.login_attempts enable row level security;
alter table public.feature_flags enable row level security;
alter table public.business_interactions enable row level security;

grant select on table public.feature_flags to anon, authenticated;
grant insert, update on table public.feature_flags to authenticated;
grant insert on table public.business_interactions to anon, authenticated;
grant select on table public.business_interactions to authenticated;
grant execute on function public.increment_business_counter(uuid, text, integer)
to anon, authenticated;

drop policy if exists "users_select_own" on public.users;
create policy "users_select_own" on public.users
for select using (auth.uid() = id);

drop policy if exists "users_insert_own" on public.users;
create policy "users_insert_own" on public.users
for insert with check (auth.uid() = id);

drop policy if exists "users_update_own" on public.users;
create policy "users_update_own" on public.users
for update using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists "businesses_select_public" on public.businesses;
create policy "businesses_select_public" on public.businesses
for select using (true);

drop policy if exists "businesses_insert_owner" on public.businesses;
create policy "businesses_insert_owner" on public.businesses
for insert with check (auth.uid() = owner_id);

drop policy if exists "businesses_update_owner" on public.businesses;
create policy "businesses_update_owner" on public.businesses
for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);

drop policy if exists "reviews_select_public" on public.reviews;
create policy "reviews_select_public" on public.reviews
for select using (true);

drop policy if exists "reviews_insert_own" on public.reviews;
create policy "reviews_insert_own" on public.reviews
for insert with check (auth.uid() = user_id);

drop policy if exists "reviews_update_own_or_owner" on public.reviews;
create policy "reviews_update_own_or_owner" on public.reviews
for update using (
  auth.uid() = user_id
  or exists (
    select 1 from public.businesses b
    where b.id = reviews.business_id and b.owner_id = auth.uid()
  )
) with check (
  auth.uid() = user_id
  or exists (
    select 1 from public.businesses b
    where b.id = reviews.business_id and b.owner_id = auth.uid()
  )
);

drop policy if exists "reviews_delete_own" on public.reviews;
create policy "reviews_delete_own" on public.reviews
for delete using (auth.uid() = user_id);

drop policy if exists "favorites_select_own" on public.favorites;
create policy "favorites_select_own" on public.favorites
for select using (auth.uid() = user_id);

drop policy if exists "favorites_insert_own" on public.favorites;
create policy "favorites_insert_own" on public.favorites
for insert with check (auth.uid() = user_id);

drop policy if exists "favorites_delete_own" on public.favorites;
create policy "favorites_delete_own" on public.favorites
for delete using (auth.uid() = user_id);

drop policy if exists "login_attempts_insert_any" on public.login_attempts;
create policy "login_attempts_insert_any" on public.login_attempts
for insert with check (true);

drop policy if exists "feature_flags_select_public" on public.feature_flags;
create policy "feature_flags_select_public" on public.feature_flags
for select using (true);

drop policy if exists "feature_flags_admin_insert" on public.feature_flags;
create policy "feature_flags_admin_insert" on public.feature_flags
for insert with check (
  exists (
    select 1
    from public.users u
    where u.id = auth.uid() and coalesce(u.is_admin, false)
  )
);

drop policy if exists "feature_flags_admin_update" on public.feature_flags;
create policy "feature_flags_admin_update" on public.feature_flags
for update using (
  exists (
    select 1
    from public.users u
    where u.id = auth.uid() and coalesce(u.is_admin, false)
  )
) with check (
  exists (
    select 1
    from public.users u
    where u.id = auth.uid() and coalesce(u.is_admin, false)
  )
);

drop policy if exists "business_interactions_insert_public" on public.business_interactions;
create policy "business_interactions_insert_public" on public.business_interactions
for insert with check (true);

drop policy if exists "business_interactions_select_owner" on public.business_interactions;
create policy "business_interactions_select_owner" on public.business_interactions
for select using (
  exists (
    select 1
    from public.businesses b
    where b.id = business_interactions.business_id
      and b.owner_id = auth.uid()
  )
);

create or replace function public.get_nearby_businesses(
  user_lat double precision,
  user_lng double precision,
  radius_km double precision default 5,
  status_filter text default 'approved'
)
returns table (
  id uuid,
  owner_id uuid,
  name text,
  category text,
  main_category text,
  subcategory text,
  description text,
  phone text,
  whatsapp text,
  email text,
  website text,
  address text,
  area text,
  city text,
  latitude double precision,
  longitude double precision,
  photos text[],
  services jsonb,
  opening_hours jsonb,
  rating numeric,
  review_count integer,
  status text,
  is_premium boolean,
  premium_expiry timestamptz,
  owner_reply jsonb,
  created_at timestamptz,
  updated_at timestamptz,
  distance_km double precision
)
language sql
stable
as $$
  with params as (
    select
      user_lat as lat,
      user_lng as lng,
      least(greatest(coalesce(radius_km, 5), 5), 20) as capped_radius_km
  )
  select
    b.id,
    b.owner_id,
    b.name,
    b.category,
    coalesce(b.main_category, '') as main_category,
    coalesce(b.subcategory, b.category, '') as subcategory,
    b.description,
    b.phone,
    b.whatsapp,
    b.email,
    b.website,
    b.address,
    b.area,
    coalesce(b.city, '') as city,
    b.latitude,
    b.longitude,
    b.photos,
    b.services,
    b.opening_hours,
    b.rating,
    b.review_count,
    b.status,
    b.is_premium,
    b.premium_expiry,
    b.owner_reply,
    b.created_at,
    b.updated_at,
    earth_distance(
      ll_to_earth(p.lat, p.lng),
      ll_to_earth(b.latitude, b.longitude)
    ) / 1000.0 as distance_km
  from public.businesses b
  cross join params p
  where
    (status_filter is null or b.status = status_filter)
    and b.latitude is not null
    and b.longitude is not null
    and b.latitude between -90 and 90
    and b.longitude between -180 and 180
    and not (b.latitude = 0 and b.longitude = 0)
    and earth_box(
      ll_to_earth(p.lat, p.lng),
      p.capped_radius_km * 1000.0
    ) @> ll_to_earth(b.latitude, b.longitude)
    and earth_distance(
      ll_to_earth(p.lat, p.lng),
      ll_to_earth(b.latitude, b.longitude)
    ) <= p.capped_radius_km * 1000.0
  order by distance_km asc, b.is_premium desc, b.rating desc, b.created_at desc;
$$;

grant execute on function public.get_nearby_businesses(
  double precision,
  double precision,
  double precision,
  text
) to anon, authenticated;

insert into public.feature_flags (flag_name, is_enabled)
values ('show_analytics', false)
on conflict (flag_name) do nothing;

insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('businesses', 'businesses', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('reviews', 'reviews', true)
on conflict (id) do nothing;

drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects
for select using (bucket_id = 'avatars');

drop policy if exists "avatars_owner_write" on storage.objects;
create policy "avatars_owner_write" on storage.objects
for insert with check (bucket_id = 'avatars' and auth.role() = 'authenticated');

drop policy if exists "avatars_owner_update" on storage.objects;
create policy "avatars_owner_update" on storage.objects
for update using (bucket_id = 'avatars' and auth.role() = 'authenticated');

drop policy if exists "avatars_owner_delete" on storage.objects;
create policy "avatars_owner_delete" on storage.objects
for delete using (bucket_id = 'avatars' and auth.role() = 'authenticated');

drop policy if exists "businesses_public_read" on storage.objects;
create policy "businesses_public_read" on storage.objects
for select using (bucket_id = 'businesses');

drop policy if exists "businesses_auth_write" on storage.objects;
create policy "businesses_auth_write" on storage.objects
for insert with check (bucket_id = 'businesses' and auth.role() = 'authenticated');

drop policy if exists "businesses_auth_update" on storage.objects;
create policy "businesses_auth_update" on storage.objects
for update using (bucket_id = 'businesses' and auth.role() = 'authenticated');

drop policy if exists "businesses_auth_delete" on storage.objects;
create policy "businesses_auth_delete" on storage.objects
for delete using (bucket_id = 'businesses' and auth.role() = 'authenticated');

drop policy if exists "reviews_public_read" on storage.objects;
create policy "reviews_public_read" on storage.objects
for select using (bucket_id = 'reviews');

drop policy if exists "reviews_auth_write" on storage.objects;
create policy "reviews_auth_write" on storage.objects
for insert with check (bucket_id = 'reviews' and auth.role() = 'authenticated');

drop policy if exists "reviews_auth_update" on storage.objects;
create policy "reviews_auth_update" on storage.objects
for update using (bucket_id = 'reviews' and auth.role() = 'authenticated');

drop policy if exists "reviews_auth_delete" on storage.objects;
create policy "reviews_auth_delete" on storage.objects
for delete using (bucket_id = 'reviews' and auth.role() = 'authenticated');
