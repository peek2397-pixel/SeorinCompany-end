begin;

-- 회식방은 로그인한 사내 직원끼리 사용하는 기능이므로
-- 기존 RLS 충돌로 참여자/채팅이 보이지 않는 문제를 제거합니다.
do $$
declare
  t text;
begin
  foreach t in array array[
    'dinner_rooms','dinner_room_members','dinner_room_messages',
    'dinner_menu_options','dinner_menu_votes','dinner_game_results'
  ] loop
    if to_regclass('public.'||t) is not null then
      execute format('alter table public.%I disable row level security',t);
      execute format('grant select,insert,update,delete on public.%I to authenticated',t);
    end if;
  end loop;
end $$;

-- 기존 삭제 함수 오버로드를 정리합니다.
drop function if exists public.delete_dinner_room_secure(uuid);
drop function if exists public.delete_dinner_room_secure(text);

create function public.delete_dinner_room_secure(p_room_id text)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_allowed boolean := false;
  v_uid text := auth.uid()::text;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  select exists(
    select 1
    from public.dinner_rooms r
    left join public.profiles p on p.id::text=v_uid
    where r.id::text=trim(p_room_id)
      and (
        r.created_by::text=v_uid
        or coalesce(p.is_super_admin,false)
        or trim(coalesce(p.name,''))='손동오'
        or trim(coalesce(p.emp_no::text,''))='201911041'
      )
  ) into v_allowed;

  if not v_allowed then
    raise exception '방장 또는 최고관리자만 삭제할 수 있습니다.';
  end if;

  if to_regclass('public.dinner_room_messages') is not null then
    execute 'delete from public.dinner_room_messages where room_id::text=$1' using trim(p_room_id);
  end if;
  if to_regclass('public.dinner_game_results') is not null then
    execute 'delete from public.dinner_game_results where room_id::text=$1' using trim(p_room_id);
  end if;
  if to_regclass('public.dinner_menu_votes') is not null then
    execute 'delete from public.dinner_menu_votes where room_id::text=$1' using trim(p_room_id);
  end if;
  if to_regclass('public.dinner_menu_options') is not null then
    execute 'delete from public.dinner_menu_options where room_id::text=$1' using trim(p_room_id);
  end if;
  if to_regclass('public.dinner_room_members') is not null then
    execute 'delete from public.dinner_room_members where room_id::text=$1' using trim(p_room_id);
  end if;

  delete from public.dinner_rooms where id::text=trim(p_room_id);
  if not found then raise exception '회식방을 찾을 수 없습니다.'; end if;
  return true;
end;
$$;

grant execute on function public.delete_dinner_room_secure(text) to authenticated;

-- 조회 속도용 인덱스(컬럼이 존재할 때만 생성)
do $$
begin
  if to_regclass('public.dinner_room_members') is not null then
    begin execute 'create index if not exists idx_dinner_members_room_text on public.dinner_room_members ((room_id::text))'; exception when others then null; end;
    begin execute 'create index if not exists idx_dinner_members_user_text on public.dinner_room_members ((user_id::text))'; exception when others then null; end;
  end if;
  if to_regclass('public.dinner_room_messages') is not null then
    begin execute 'create index if not exists idx_dinner_messages_room_created on public.dinner_room_messages (room_id,created_at)'; exception when others then null; end;
  end if;
end $$;

notify pgrst,'reload schema';
commit;
