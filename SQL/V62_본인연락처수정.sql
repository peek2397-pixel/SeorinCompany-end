-- 조직도에서 로그인한 본인이 자기 연락처만 수정할 수 있도록 하는 함수

alter table public.profiles add column if not exists emergency_contact_name text;
alter table public.profiles add column if not exists emergency_contact_relation text;
alter table public.profiles add column if not exists emergency_contact_phone text;

create or replace function public.update_my_contact_info(
  p_phone text,
  p_emergency_contact_name text,
  p_emergency_contact_relation text,
  p_emergency_contact_phone text
) returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  update public.profiles
  set phone=nullif(trim(coalesce(p_phone,'')),''),
      emergency_contact_name=nullif(trim(coalesce(p_emergency_contact_name,'')),''),
      emergency_contact_relation=nullif(trim(coalesce(p_emergency_contact_relation,'')),''),
      emergency_contact_phone=nullif(trim(coalesce(p_emergency_contact_phone,'')),'')
  where id=auth.uid();

  if not found then
    raise exception '본인 직원 정보를 찾을 수 없습니다.';
  end if;
end;
$$;

grant execute on function public.update_my_contact_info(text,text,text,text) to authenticated;
notify pgrst, 'reload schema';
