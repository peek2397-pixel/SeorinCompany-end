-- SeorinCompany-end V81
-- 지게차 화면/DB 컬럼 및 상태값 통합 동기화
-- Supabase SQL Editor에 전체 붙여넣고 Run

begin;

create extension if not exists pgcrypto;

-- 1) 지게차 기본 테이블: 기존 테이블이 없어도 생성
create table if not exists public.forklift_assets (
  id uuid primary key default gen_random_uuid(),
  asset_name text,
  equipment_name text,
  equipment_number text,
  equipment_type text default '전동',
  asset_type text default '전동',
  location text default '종합물류',
  warehouse_type text default '종합물류',
  manager_name text,
  current_hours numeric(14,1) not null default 0,
  last_distilled_water_date date,
  distilled_water_date date,
  status text not null default '사용중',
  memo text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_by uuid,
  updated_at timestamptz not null default now()
);

-- 2) 기존 버전 테이블에 빠진 컬럼 보완
alter table public.forklift_assets add column if not exists asset_name text;
alter table public.forklift_assets add column if not exists equipment_name text;
alter table public.forklift_assets add column if not exists equipment_number text;
alter table public.forklift_assets add column if not exists equipment_type text default '전동';
alter table public.forklift_assets add column if not exists asset_type text default '전동';
alter table public.forklift_assets add column if not exists location text default '종합물류';
alter table public.forklift_assets add column if not exists warehouse_type text default '종합물류';
alter table public.forklift_assets add column if not exists manager_name text;
alter table public.forklift_assets add column if not exists current_hours numeric(14,1) not null default 0;
alter table public.forklift_assets add column if not exists last_distilled_water_date date;
alter table public.forklift_assets add column if not exists distilled_water_date date;
alter table public.forklift_assets add column if not exists status text not null default '사용중';
alter table public.forklift_assets add column if not exists memo text;
alter table public.forklift_assets add column if not exists created_by uuid;
alter table public.forklift_assets add column if not exists created_at timestamptz not null default now();
alter table public.forklift_assets add column if not exists updated_by uuid;
alter table public.forklift_assets add column if not exists updated_at timestamptz not null default now();

-- 3) 기존 데이터의 명칭/구분/위치/증류수 날짜를 서로 맞춤
update public.forklift_assets
set
  asset_name = coalesce(nullif(trim(asset_name), ''), nullif(trim(equipment_name), ''), '지게차'),
  equipment_name = coalesce(nullif(trim(equipment_name), ''), nullif(trim(asset_name), ''), '지게차'),
  equipment_type = case
    when coalesce(nullif(trim(equipment_type), ''), nullif(trim(asset_type), ''), '전동') in ('디젤','전동')
      then coalesce(nullif(trim(equipment_type), ''), nullif(trim(asset_type), ''), '전동')
    else '전동'
  end,
  asset_type = case
    when coalesce(nullif(trim(asset_type), ''), nullif(trim(equipment_type), ''), '전동') in ('디젤','전동')
      then coalesce(nullif(trim(asset_type), ''), nullif(trim(equipment_type), ''), '전동')
    else '전동'
  end,
  location = case
    when coalesce(nullif(trim(location), ''), nullif(trim(warehouse_type), ''), '종합물류') in ('종합물류','3물류')
      then coalesce(nullif(trim(location), ''), nullif(trim(warehouse_type), ''), '종합물류')
    else '종합물류'
  end,
  warehouse_type = case
    when coalesce(nullif(trim(warehouse_type), ''), nullif(trim(location), ''), '종합물류') in ('종합물류','3물류')
      then coalesce(nullif(trim(warehouse_type), ''), nullif(trim(location), ''), '종합물류')
    else '종합물류'
  end,
  last_distilled_water_date = coalesce(last_distilled_water_date, distilled_water_date),
  distilled_water_date = coalesce(distilled_water_date, last_distilled_water_date),
  status = case
    when status in ('사용중','대기','정비중','수리중','고장','사용중지','폐기') then status
    when status in ('사용가능','운행가능','정상','available') then '사용중'
    when status in ('maintenance','점검중') then '정비중'
    when status in ('repair') then '수리중'
    when status in ('retired') then '폐기'
    else '사용중'
  end;

-- 4) 예전 상태 CHECK 제거 후 현재 화면 값으로 통일
alter table public.forklift_assets
  drop constraint if exists forklift_assets_status_check;

alter table public.forklift_assets
  add constraint forklift_assets_status_check
  check (status in ('사용중','대기','정비중','수리중','고장','사용중지','폐기'));

alter table public.forklift_assets
  drop constraint if exists forklift_assets_equipment_type_check;
alter table public.forklift_assets
  drop constraint if exists forklift_assets_asset_type_check;
alter table public.forklift_assets
  drop constraint if exists forklift_assets_location_check;
alter table public.forklift_assets
  drop constraint if exists forklift_assets_warehouse_type_check;

alter table public.forklift_assets
  add constraint forklift_assets_equipment_type_check
  check (equipment_type in ('전동','디젤'));

alter table public.forklift_assets
  add constraint forklift_assets_asset_type_check
  check (asset_type in ('전동','디젤'));

alter table public.forklift_assets
  add constraint forklift_assets_location_check
  check (location in ('종합물류','3물류'));

alter table public.forklift_assets
  add constraint forklift_assets_warehouse_type_check
  check (warehouse_type in ('종합물류','3물류'));

-- 5) 신·구 컬럼을 자동 동기화하는 트리거
create or replace function public.sync_forklift_asset_columns()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.asset_name := coalesce(nullif(trim(new.asset_name), ''), nullif(trim(new.equipment_name), ''), '지게차');
  new.equipment_name := new.asset_name;

  new.equipment_type := case
    when coalesce(nullif(trim(new.equipment_type), ''), nullif(trim(new.asset_type), ''), '전동') in ('전동','디젤')
      then coalesce(nullif(trim(new.equipment_type), ''), nullif(trim(new.asset_type), ''), '전동')
    else '전동'
  end;
  new.asset_type := new.equipment_type;

  new.location := case
    when coalesce(nullif(trim(new.location), ''), nullif(trim(new.warehouse_type), ''), '종합물류') in ('종합물류','3물류')
      then coalesce(nullif(trim(new.location), ''), nullif(trim(new.warehouse_type), ''), '종합물류')
    else '종합물류'
  end;
  new.warehouse_type := new.location;

  new.last_distilled_water_date := coalesce(new.last_distilled_water_date, new.distilled_water_date);
  new.distilled_water_date := coalesce(new.distilled_water_date, new.last_distilled_water_date);

  new.current_hours := greatest(coalesce(new.current_hours, 0), 0);
  new.status := case
    when coalesce(nullif(trim(new.status), ''), '사용중') in ('사용중','대기','정비중','수리중','고장','사용중지','폐기')
      then coalesce(nullif(trim(new.status), ''), '사용중')
    when new.status in ('사용가능','운행가능','정상','available') then '사용중'
    when new.status in ('maintenance','점검중') then '정비중'
    when new.status = 'repair' then '수리중'
    when new.status = 'retired' then '폐기'
    else '사용중'
  end;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists trg_sync_forklift_asset_columns on public.forklift_assets;
create trigger trg_sync_forklift_asset_columns
before insert or update on public.forklift_assets
for each row execute function public.sync_forklift_asset_columns();

-- 6) 정비·증류수·부품 보고 테이블도 없으면 생성
create table if not exists public.forklift_maintenance (
  id uuid primary key default gen_random_uuid(),
  forklift_id uuid not null references public.forklift_assets(id) on delete cascade,
  maintenance_date date not null,
  maintenance_type text not null,
  operating_hours numeric(14,1) not null default 0,
  shop_name text,
  cost numeric(14,0) not null default 0,
  next_due_date date,
  next_due_hours numeric(14,1),
  memo text,
  reported_by uuid,
  reported_by_name text,
  workflow_status text not null default 'reported',
  amount_checked_by uuid,
  amount_checked_by_name text,
  amount_checked_at timestamptz,
  approved_by uuid,
  approved_by_name text,
  approved_at timestamptz,
  reject_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.forklift_maintenance add column if not exists operating_hours numeric(14,1) not null default 0;
alter table public.forklift_maintenance add column if not exists shop_name text;
alter table public.forklift_maintenance add column if not exists cost numeric(14,0) not null default 0;
alter table public.forklift_maintenance add column if not exists next_due_date date;
alter table public.forklift_maintenance add column if not exists next_due_hours numeric(14,1);
alter table public.forklift_maintenance add column if not exists memo text;
alter table public.forklift_maintenance add column if not exists reported_by uuid;
alter table public.forklift_maintenance add column if not exists reported_by_name text;
alter table public.forklift_maintenance add column if not exists workflow_status text not null default 'reported';
alter table public.forklift_maintenance add column if not exists amount_checked_by uuid;
alter table public.forklift_maintenance add column if not exists amount_checked_by_name text;
alter table public.forklift_maintenance add column if not exists amount_checked_at timestamptz;
alter table public.forklift_maintenance add column if not exists approved_by uuid;
alter table public.forklift_maintenance add column if not exists approved_by_name text;
alter table public.forklift_maintenance add column if not exists approved_at timestamptz;
alter table public.forklift_maintenance add column if not exists reject_reason text;
alter table public.forklift_maintenance add column if not exists created_at timestamptz not null default now();
alter table public.forklift_maintenance add column if not exists updated_at timestamptz not null default now();

alter table public.forklift_maintenance drop constraint if exists forklift_maintenance_workflow_status_check;
alter table public.forklift_maintenance add constraint forklift_maintenance_workflow_status_check
  check (workflow_status in ('reported','amount_checked','approved','rejected','completed'));

-- 7) 로그인 직원은 조회, 등록, 수정, 삭제 가능
alter table public.forklift_assets enable row level security;
alter table public.forklift_maintenance enable row level security;

-- 모든 기존 정책 제거 후 단순 통합 정책 생성
DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='forklift_assets'
  LOOP EXECUTE format('drop policy if exists %I on public.forklift_assets', r.policyname); END LOOP;
  FOR r IN SELECT policyname FROM pg_policies WHERE schemaname='public' AND tablename='forklift_maintenance'
  LOOP EXECUTE format('drop policy if exists %I on public.forklift_maintenance', r.policyname); END LOOP;
END $$;

create policy forklift_assets_authenticated_all
on public.forklift_assets for all to authenticated
using (auth.uid() is not null)
with check (auth.uid() is not null);

create policy forklift_maintenance_authenticated_all
on public.forklift_maintenance for all to authenticated
using (auth.uid() is not null)
with check (auth.uid() is not null);

grant select, insert, update, delete on public.forklift_assets to authenticated;
grant select, insert, update, delete on public.forklift_maintenance to authenticated;

-- 8) 실시간 등록(이미 등록되어 있으면 무시)
do $$
begin
  alter publication supabase_realtime add table public.forklift_assets;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.forklift_maintenance;
exception when duplicate_object then null;
end $$;

notify pgrst, 'reload schema';
commit;
