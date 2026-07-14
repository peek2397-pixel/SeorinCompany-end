-- V76 모든 차량 자동차 검사 관리
begin;

alter table public.fleet_vehicles
  add column if not exists last_inspection_date date;

create table if not exists public.vehicle_inspections (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.fleet_vehicles(id) on delete cascade,
  completed_date date not null,
  next_expiry_date date not null,
  agency text,
  memo text,
  completed_by uuid,
  completed_by_name text,
  created_at timestamptz not null default now(),
  check (next_expiry_date > completed_date)
);

create index if not exists idx_vehicle_inspections_vehicle_date
  on public.vehicle_inspections(vehicle_id, completed_date desc);

alter table public.vehicle_inspections enable row level security;

drop policy if exists "vehicle inspections authenticated select" on public.vehicle_inspections;
create policy "vehicle inspections authenticated select" on public.vehicle_inspections
for select to authenticated using (true);

drop policy if exists "vehicle inspections authenticated insert" on public.vehicle_inspections;
create policy "vehicle inspections authenticated insert" on public.vehicle_inspections
for insert to authenticated with check (auth.uid() is not null);

drop policy if exists "vehicle inspections authenticated update" on public.vehicle_inspections;
create policy "vehicle inspections authenticated update" on public.vehicle_inspections
for update to authenticated using (true) with check (true);

drop policy if exists "vehicle inspections authenticated delete" on public.vehicle_inspections;
create policy "vehicle inspections authenticated delete" on public.vehicle_inspections
for delete to authenticated using (true);

grant select, insert, update, delete on public.vehicle_inspections to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.vehicle_inspections;
exception when duplicate_object then null;
end $$;

notify pgrst, 'reload schema';
commit;
