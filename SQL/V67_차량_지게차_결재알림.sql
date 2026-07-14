-- V67 차량·지게차 정비 보고/금액확인/최종결재
create extension if not exists pgcrypto;

alter table public.vehicle_maintenance add column if not exists reported_by uuid;
alter table public.vehicle_maintenance add column if not exists reported_by_name text;
alter table public.vehicle_maintenance add column if not exists workflow_status text not null default 'reported';
alter table public.vehicle_maintenance add column if not exists amount_checked_by uuid;
alter table public.vehicle_maintenance add column if not exists amount_checked_by_name text;
alter table public.vehicle_maintenance add column if not exists amount_checked_at timestamptz;
alter table public.vehicle_maintenance add column if not exists approved_by uuid;
alter table public.vehicle_maintenance add column if not exists approved_by_name text;
alter table public.vehicle_maintenance add column if not exists approved_at timestamptz;
alter table public.vehicle_maintenance add column if not exists updated_at timestamptz default now();

create table if not exists public.forklift_assets(
 id uuid primary key default gen_random_uuid(), asset_name text not null, location text not null, manager_name text not null,
 current_hours numeric(12,1) not null default 0, last_distilled_water_date date, status text not null default '사용중', memo text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.forklift_maintenance(
 id uuid primary key default gen_random_uuid(), forklift_id uuid not null references public.forklift_assets(id) on delete cascade,
 maintenance_date date not null, maintenance_type text not null, operating_hours numeric(12,1) not null default 0, shop_name text, cost numeric(14,2) not null default 0,
 next_due_date date, next_due_hours numeric(12,1), memo text, reported_by uuid, reported_by_name text, workflow_status text not null default 'reported',
 amount_checked_by uuid, amount_checked_by_name text, amount_checked_at timestamptz, approved_by uuid, approved_by_name text, approved_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);

alter table public.forklift_assets enable row level security;
alter table public.forklift_maintenance enable row level security;
drop policy if exists forklift_assets_authenticated_all on public.forklift_assets;
create policy forklift_assets_authenticated_all on public.forklift_assets for all to authenticated using (true) with check (true);
drop policy if exists forklift_maintenance_authenticated_all on public.forklift_maintenance;
create policy forklift_maintenance_authenticated_all on public.forklift_maintenance for all to authenticated using (true) with check (true);

grant select,insert,update,delete on public.forklift_assets to authenticated;
grant select,insert,update,delete on public.forklift_maintenance to authenticated;

-- Realtime 알림 대상 테이블 등록(이미 등록돼 있으면 오류 없이 넘어감)
do $$ begin
 alter publication supabase_realtime add table public.vehicle_maintenance;
exception when duplicate_object then null; end $$;
do $$ begin
 alter publication supabase_realtime add table public.forklift_maintenance;
exception when duplicate_object then null; end $$;
do $$ begin
 alter publication supabase_realtime add table public.purchase_requests;
exception when duplicate_object then null; end $$;

notify pgrst, 'reload schema';
