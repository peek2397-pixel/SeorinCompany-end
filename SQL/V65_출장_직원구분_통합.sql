-- V65 홈페이지: 출장 일정 + 직원 업무/근무지/고용형태 구분
-- Supabase SQL Editor에서 전체 실행

begin;

alter table public.profiles add column if not exists work_category text default '기타';
alter table public.profiles add column if not exists work_location text default '현재 창고';
alter table public.profiles add column if not exists employment_type text default '정규직';

alter table public.employee_registry add column if not exists work_category text default '기타';
alter table public.employee_registry add column if not exists work_location text default '현재 창고';
alter table public.employee_registry add column if not exists employment_type text default '정규직';

create or replace function public.admin_update_employee_work_info(
  p_emp_no text,
  p_work_category text,
  p_work_location text,
  p_employment_type text
) returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  if auth.uid() is null then raise exception '로그인이 필요합니다.'; end if;
  if not (public.is_super_admin() or public.has_permission('employees_manage')) then
    raise exception '직원관리 권한이 없습니다.';
  end if;

  update public.profiles
     set work_category=coalesce(nullif(trim(p_work_category),''),'기타'),
         work_location=coalesce(nullif(trim(p_work_location),''),'현재 창고'),
         employment_type=coalesce(nullif(trim(p_employment_type),''),'정규직')
   where emp_no=p_emp_no;

  update public.employee_registry
     set work_category=coalesce(nullif(trim(p_work_category),''),'기타'),
         work_location=coalesce(nullif(trim(p_work_location),''),'현재 창고'),
         employment_type=coalesce(nullif(trim(p_employment_type),''),'정규직')
   where emp_no=p_emp_no;
end;
$$;

grant execute on function public.admin_update_employee_work_info(text,text,text,text) to authenticated;
notify pgrst, 'reload schema';
commit;
