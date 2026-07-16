-- SeorinCompany-end V122
-- 구매·물품관리 전체 사용자 즉시 동기화 + 확실한 관리자 삭제
-- Supabase > SQL Editor에서 이 파일 전체를 한 번 실행하세요.

begin;

-- 로그인한 모든 직원이 전체 구매 신청을 조회할 수 있어야
-- 어느 기기에서 등록해도 다른 기기에서 즉시 확인할 수 있습니다.
alter table public.purchase_requests enable row level security;

drop policy if exists purchase_requests_authenticated_select_all on public.purchase_requests;
create policy purchase_requests_authenticated_select_all
on public.purchase_requests
for select
to authenticated
using (true);

-- 모든 로그인 직원이 본인의 구매 신청을 등록할 수 있습니다.
drop policy if exists purchase_requests_authenticated_insert_own on public.purchase_requests;
create policy purchase_requests_authenticated_insert_own
on public.purchase_requests
for insert
to authenticated
with check (requester_id = auth.uid());

-- Supabase Realtime publication에 구매 테이블을 등록합니다.
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

-- 삭제는 화면에서만 지우지 않고, 최고관리자 여부를 서버가 확인한 뒤 실제 DB에서 삭제합니다.
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

  delete from public.purchase_requests where id = p_request_id;
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
