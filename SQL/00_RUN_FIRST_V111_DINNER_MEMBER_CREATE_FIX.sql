begin;

-- 회식방 생성 시 방장과 선택 직원이 반드시 참여자로 저장되도록 재구성

create table if not exists public.dinner_rooms (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  dinner_date date not null default current_date,
  created_by uuid,
  created_by_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.dinner_room_members (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.dinner_rooms(id) on delete cascade,
  user_id uuid not null,
  member_name text not null,
  joined_at timestamptz not null default now(),
  unique(room_id,user_id)
);

alter table public.dinner_rooms disable row level security;
alter table public.dinner_room_members disable row level security;
grant select,insert,update,delete on public.dinner_rooms,public.dinner_room_members to authenticated;

-- 과거 비밀번호형/중복 함수 제거
drop function if exists public.create_dinner_room_secure(text,date,text,jsonb);
drop function if exists public.create_dinner_room_secure(text,text,date,text,jsonb);
drop function if exists public.create_dinner_room_secure(text,date,jsonb);

create function public.create_dinner_room_secure(
  p_title text,
  p_dinner_date date,
  p_members jsonb
)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_room_id uuid;
  v_member jsonb;
  v_user_id uuid;
  v_member_name text;
  v_creator_name text;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  if trim(coalesce(p_title,''))='' then
    raise exception '회식방 이름을 입력하세요.';
  end if;

  select coalesce(nullif(trim(p.name),''),'관리자')
    into v_creator_name
  from public.profiles p
  where p.id::text=auth.uid()::text
  limit 1;

  v_creator_name:=coalesce(v_creator_name,'관리자');

  insert into public.dinner_rooms(title,dinner_date,created_by,created_by_name)
  values(trim(p_title),coalesce(p_dinner_date,current_date),auth.uid(),v_creator_name)
  returning id into v_room_id;

  -- 방장은 무조건 참여자로 저장
  insert into public.dinner_room_members(room_id,user_id,member_name)
  values(v_room_id,auth.uid(),v_creator_name)
  on conflict(room_id,user_id)
  do update set member_name=excluded.member_name;

  -- 화면에서 선택한 직원 전부 저장
  for v_member in
    select value from jsonb_array_elements(coalesce(p_members,'[]'::jsonb))
  loop
    begin
      v_user_id:=nullif(trim(coalesce(v_member->>'user_id',v_member->>'id','')),'')::uuid;
    exception when others then
      v_user_id:=null;
    end;

    v_member_name:=coalesce(
      nullif(trim(v_member->>'member_name'),''),
      nullif(trim(v_member->>'name'),''),
      '직원'
    );

    if v_user_id is not null then
      insert into public.dinner_room_members(room_id,user_id,member_name)
      values(v_room_id,v_user_id,v_member_name)
      on conflict(room_id,user_id)
      do update set member_name=excluded.member_name;
    end if;
  end loop;

  return v_room_id;
end;
$$;

grant execute on function public.create_dinner_room_secure(text,date,jsonb) to authenticated;

-- 방장 또는 최고관리자 삭제 함수도 text/uuid 충돌 없이 통일
drop function if exists public.delete_dinner_room_secure(uuid);
drop function if exists public.delete_dinner_room_secure(text);

create function public.delete_dinner_room_secure(p_room_id text)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_allowed boolean:=false;
begin
  if auth.uid() is null then raise exception '로그인이 필요합니다.'; end if;

  select exists(
    select 1
    from public.dinner_rooms r
    left join public.profiles p on p.id::text=auth.uid()::text
    where r.id::text=trim(p_room_id)
      and (
        r.created_by::text=auth.uid()::text
        or coalesce(p.is_super_admin,false)
        or trim(coalesce(p.name,''))='손동오'
        or trim(coalesce(p.emp_no::text,''))='201911041'
      )
  ) into v_allowed;

  if not v_allowed then raise exception '방장 또는 최고관리자만 삭제할 수 있습니다.'; end if;

  delete from public.dinner_rooms where id::text=trim(p_room_id);
  if not found then raise exception '회식방을 찾을 수 없습니다.'; end if;
  return true;
end;
$$;

grant execute on function public.delete_dinner_room_secure(text) to authenticated;

create index if not exists idx_dinner_members_room on public.dinner_room_members(room_id);
create index if not exists idx_dinner_members_user on public.dinner_room_members(user_id);

notify pgrst,'reload schema';
commit;
