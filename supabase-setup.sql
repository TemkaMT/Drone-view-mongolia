-- Drone View Mongolia: Supabase setup.
-- Run once: Supabase dashboard -> SQL Editor -> New query -> paste -> Run.
--
-- BEFORE RUNNING: replace YOUR_EMAIL (one place, in is_admin below) with the
-- e-mail of your admin user, in lowercase. Only that account can add, change
-- or delete anything. Everyone else can only read.

create table if not exists public.videos (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  url text not null,
  title_mn text not null,
  title_en text,
  desc_mn text,
  desc_en text,
  kind text not null default 'other',
  aimag_mn text,
  aimag_en text,
  lat text,
  lon text
);

create table if not exists public.photos (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  url text not null,
  path text,
  title_mn text,
  title_en text
);

create table if not exists public.news (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  date date not null default current_date,
  title_mn text not null,
  title_en text,
  body_mn text,
  body_en text
);

create table if not exists public.contacts (
  key text primary key,
  value text not null default ''
);

insert into public.contacts (key, value)
values ('email', ''), ('facebook', ''), ('instagram', ''), ('youtube', '')
on conflict (key) do nothing;

-- Who is the admin
create or replace function public.is_admin()
returns boolean
language sql
stable
as $$
  select coalesce(auth.jwt() ->> 'email', '') = 'YOUR_EMAIL'
$$;

-- Everyone can read, only the admin can write
do $$
declare t text;
begin
  foreach t in array array['videos', 'photos', 'news', 'contacts'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "public read" on public.%I', t);
    execute format('drop policy if exists "admin write" on public.%I', t);
    execute format('create policy "public read" on public.%I for select to anon, authenticated using (true)', t);
    execute format('create policy "admin write" on public.%I for all to authenticated using (public.is_admin()) with check (public.is_admin())', t);
  end loop;
end $$;

-- Photo storage (public bucket, only the admin can upload or delete)
insert into storage.buckets (id, name, public)
values ('photos', 'photos', true)
on conflict (id) do nothing;

drop policy if exists "photos admin write" on storage.objects;
create policy "photos admin write" on storage.objects
  for all to authenticated
  using (bucket_id = 'photos' and public.is_admin())
  with check (bucket_id = 'photos' and public.is_admin());
