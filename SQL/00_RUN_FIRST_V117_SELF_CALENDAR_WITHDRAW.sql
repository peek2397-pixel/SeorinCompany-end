-- V117 본인 근무·휴무 일정 회수
-- Supabase SQL Editor에서 한 번 실행하세요.

create or replace function public.withdraw_work_calendar_entry(p_entry_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_employee_id uuid;
  v_is_admin boolean := false;
begin
  select employee_id
    into v_employee_id
  from public.work_calendar_entries
  where id = p_entry_id;

  if v_employee_id is null then
    raise exception '회수할 일정을 찾을 수 없습니다.';
  end if;

  select coalesce(p.is_super_admin,false)
         or coalesce(up.calendar_manage,false)
    into v_is_admin
  from public.profiles p
  left join public.user_permissions up on up.user_id = p.id
  where p.id = auth.uid();

  if v_employee_id <> auth.uid() and not coalesce(v_is_admin,false) then
    raise exception '본인의 일정만 회수할 수 있습니다.';
  end if;

  delete from public.work_calendar_entries
  where id = p_entry_id;
end;
$$;

grant execute on function public.withdraw_work_calendar_entry(uuid) to authenticated;
