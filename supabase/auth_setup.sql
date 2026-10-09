-- CalamansiCare account/auth setup
-- Run this in Supabase SQL Editor after the existing report/image/email setup.

create extension if not exists pgcrypto;

create table if not exists public.farmer_settings (
  device_id text primary key,
  device_signature text,
  device_model text,
  device_brand text,
  android_version text,
  farmer_name text,
  farmer_location text,
  office_email text,
  language text default 'English',
  consent_enabled boolean default true,
  font_scale double precision default 1.0,
  updated_at timestamptz default now()
);

create table if not exists public.farmer_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  farmer_name text default '',
  farmer_location text default '',
  office_email text default '',
  language text default 'English',
  consent_enabled boolean default true,
  font_scale double precision default 1.0,
  device_id text,
  device_signature text,
  device_model text,
  device_brand text,
  android_version text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

alter table public.farmer_profiles enable row level security;

drop policy if exists "Farmers can read own profile" on public.farmer_profiles;
create policy "Farmers can read own profile"
on public.farmer_profiles
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Farmers can create own profile" on public.farmer_profiles;
create policy "Farmers can create own profile"
on public.farmer_profiles
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Farmers can update own profile" on public.farmer_profiles;
create policy "Farmers can update own profile"
on public.farmer_profiles
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

alter table public.farmer_settings
add column if not exists user_id uuid references auth.users(id) on delete set null;

create table if not exists public.diagnosis_reports (
  id bigint generated always as identity primary key,
  local_report_id text not null unique,
  office_email text not null,
  disease text not null,
  confidence numeric not null check (confidence >= 0 and confidence <= 1),
  reported_at timestamptz,
  received_at timestamptz not null default now()
);

alter table public.diagnosis_reports
alter column local_report_id type text using local_report_id::text;

alter table public.diagnosis_reports
add column if not exists user_id uuid references auth.users(id) on delete set null,
add column if not exists device_id text,
add column if not exists device_signature text,
add column if not exists device_model text,
add column if not exists farmer_name text,
add column if not exists farmer_location text,
add column if not exists image_path text,
add column if not exists consent boolean default false,
add column if not exists status text default 'synced',
add column if not exists synced_at timestamptz default now(),
add column if not exists created_at timestamptz default now(),
add column if not exists image_url text,
add column if not exists email_status text default 'pending',
add column if not exists email_sent_at timestamptz,
add column if not exists email_error text;

create unique index if not exists diagnosis_reports_local_report_id_unique
on public.diagnosis_reports (local_report_id);

alter table public.diagnosis_reports enable row level security;

drop policy if exists "Anon can submit diagnosis reports" on public.diagnosis_reports;
drop policy if exists "Authenticated farmers can submit reports" on public.diagnosis_reports;
create policy "Authenticated farmers can submit reports"
on public.diagnosis_reports
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Authenticated farmers can update own reports" on public.diagnosis_reports;
create policy "Authenticated farmers can update own reports"
on public.diagnosis_reports
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Authenticated farmers can read own reports" on public.diagnosis_reports;
create policy "Authenticated farmers can read own reports"
on public.diagnosis_reports
for select
to authenticated
using (auth.uid() = user_id);

drop view if exists public.community_reports;

create or replace view public.community_reports as
select
  id::text as id,
  disease,
  confidence,
  coalesce(nullif(farmer_name, ''), '---') as farmer_name,
  coalesce(nullif(farmer_location, ''), 'Barangay area') as farmer_location,
  case
    when disease ilike '%HLB%' or disease ilike '%Greening%' or disease ilike '%Canker%' then 'High risk'
    when disease ilike '%Healthy%' or disease ilike '%Nutrient%' then 'Low risk'
    else 'Medium risk'
  end as priority,
  image_url,
  coalesce(reported_at, received_at, created_at) as reported_at
from public.diagnosis_reports
where consent = true;

grant select on public.community_reports to anon, authenticated;

insert into storage.buckets (id, name, public)
values ('report-images', 'report-images', true)
on conflict (id) do update set public = true;

drop policy if exists "Allow report image uploads" on storage.objects;
drop policy if exists "Allow report image updates" on storage.objects;
drop policy if exists "Allow public report image reads" on storage.objects;
drop policy if exists "Authenticated farmers can upload report images" on storage.objects;
drop policy if exists "Authenticated farmers can update report images" on storage.objects;
drop policy if exists "Public can read report images" on storage.objects;

create policy "Authenticated farmers can upload report images"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'report-images');

create policy "Authenticated farmers can update report images"
on storage.objects
for update
to authenticated
using (bucket_id = 'report-images')
with check (bucket_id = 'report-images');

create policy "Public can read report images"
on storage.objects
for select
to anon, authenticated
using (bucket_id = 'report-images');
