-- SeorinCompany-end V123 통합 SQL
-- 1) 손동오 이사 일정: 손동오·김헌정만 조회/등록/수정/삭제
-- 2) 구매·물품관리: 모든 로그인 직원이 전체 목록 조회 및 즉시 동기화
-- 3) 최고관리자: 실제 서버 삭제
-- Supabase > SQL Editor > New query에 전체 붙여넣고 Run

begin;

-- =========================================================
-- A. 손동오 이사 전용 일정
-- =========================================================
create table if not exists public.director_schedules (
  id uuid primary key default gen_random_uuid(),
  schedule_date date not null,
  start_time time,
  end_time time,
  title text not null,
  location text default '',
  memo text default '',
  importance text not null default '일반' check (importance in ('일반','중요')),
  is_completed boolean not null default false,
  created_by uuid references auth.users(id),
  created_by_name text,
  updated_by uuid references auth.users(id),
  updated_by_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.director_schedules enable row level security;

drop policy if exists director_schedule_select on public.director_schedules;
drop policy if exists director_schedule_insert on public.director_schedules;
drop policy if exists director_schedule_update on public.director_schedules;
drop policy if exists director_schedule_delete on public.director_schedules;

create policy director_schedule_select
on public.director_schedules
for select to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and trim(coalesce(p.name,'')) in ('손동오','김헌정')
  )
);

create policy director_schedule_insert
on public.director_schedules
for insert to authenticated
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and trim(coalesce(p.name,'')) in ('손동오','김헌정')
  )
);

create policy director_schedule_update
on public.director_schedules
for update to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and trim(coalesce(p.name,'')) in ('손동오','김헌정')
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and trim(coalesce(p.name,'')) in ('손동오','김헌정')
  )
);

create policy director_schedule_delete
on public.director_schedules
for delete to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and trim(coalesce(p.name,'')) in ('손동오','김헌정')
  )
);

grant select, insert, update, delete on public.director_schedules to authenticated;

-- 일정도 두 사람의 다른 기기에서 즉시 보이도록 Realtime 등록
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'director_schedules'
  ) then
    alter publication supabase_realtime add table public.director_schedules;
  end if;
end $$;

-- =========================================================
-- B. 구매·물품관리 전체 사용자 즉시 동기화
-- =========================================================
alter table public.purchase_requests enable row level security;

drop policy if exists purchase_requests_authenticated_select_all on public.purchase_requests;
create policy purchase_requests_authenticated_select_all
on public.purchase_requests
for select to authenticated
using (true);

drop policy if exists purchase_requests_authenticated_insert_own on public.purchase_requests;
create policy purchase_requests_authenticated_insert_own
on public.purchase_requests
for insert to authenticated
with check (requester_id = auth.uid());

-- 모든 로그인 기기에 등록/수정/삭제 이벤트 즉시 전달
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'purchase_requests'
  ) then
    alter publication supabase_realtime add table public.purchase_requests;
  end if;
end $$;

-- 최고관리자가 화면에서만 숨기는 것이 아니라 실제 서버에서 삭제
create or replace function public.admin_delete_purchase_request(p_request_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_is_admin boolean := false;
  v_deleted integer := 0;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  select coalesce(p.is_super_admin,false)
      or trim(coalesce(p.name,'')) = '손동오'
      or trim(coalesce(p.emp_no,'')) = '201911041'
  into v_is_admin
  from public.profiles p
  where p.id = auth.uid();

  if not coalesce(v_is_admin,false) then
    raise exception '최고관리자만 삭제할 수 있습니다.';
  end if;

  delete from public.purchase_requests
  where id = p_request_id;

  get diagnostics v_deleted = row_count;

  if v_deleted = 0 then
    raise exception '삭제할 구매 신청을 찾을 수 없습니다.';
  end if;

  return jsonb_build_object('success',true,'deleted_id',p_request_id);
end;
$$;

grant execute on function public.admin_delete_purchase_request(uuid) to authenticated;

notify pgrst, 'reload schema';
commit;
