-- V68 출장관리 + 운송팀 차량번호/정비결재
create extension if not exists pgcrypto;

create table if not exists public.business_trips(
 id uuid primary key default gen_random_uuid(),
 trip_type text not null check (trip_type in ('domestic_trip','overseas_trip')),
 employee_ids uuid[] not null default '{}',
 employee_names text[] not null default '{}',
 start_date date not null, end_date date not null, destination text, purpose text,
 vehicle_id uuid references public.fleet_vehicles(id) on delete set null, vehicle_number text, driver_name text,
 exclude_meal boolean not null default true, memo text, created_by uuid, created_by_name text, created_at timestamptz not null default now()
);

alter table public.work_calendar_entries add column if not exists business_trip_id uuid references public.business_trips(id) on delete cascade;
alter table public.fleet_vehicles add column if not exists vehicle_group text not null default 'company';
alter table public.fleet_vehicles add column if not exists tonnage text;
alter table public.vehicle_maintenance add column if not exists manager_approved_by uuid;
alter table public.vehicle_maintenance add column if not exists manager_approved_by_name text;
alter table public.vehicle_maintenance add column if not exists manager_approved_at timestamptz;

alter table public.business_trips enable row level security;
drop policy if exists business_trips_authenticated_all on public.business_trips;
create policy business_trips_authenticated_all on public.business_trips for all to authenticated using (true) with check (true);
grant select,insert,update,delete on public.business_trips to authenticated;

do $$ begin alter publication supabase_realtime add table public.business_trips; exception when duplicate_object then null; end $$;
notify pgrst, 'reload schema';
