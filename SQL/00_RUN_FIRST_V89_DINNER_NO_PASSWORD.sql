begin;

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.dinner_rooms (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  dinner_date date not null default current_date,
  created_by uuid,
  created_by_name text,
  created_at timestamptz not null default now()
);

alter table public.dinner_rooms add column if not exists title text;
alter table public.dinner_rooms add column if not exists dinner_date date default current_date;
alter table public.dinner_rooms add column if not exists created_by uuid;
alter table public.dinner_rooms add column if not exists created_by_name text;
alter table public.dinner_rooms add column if not exists created_at timestamptz default now();

-- 이전 비밀번호 열이 있어도 더 이상 필수로 사용하지 않음
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='dinner_rooms' and column_name='room_password'
  ) then
    execute 'alter table public.dinner_rooms alter column room_password drop not null';
  end if;
  if exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='dinner_rooms' and column_name='password_hash'
  ) then
    execute 'alter table public.dinner_rooms alter column password_hash drop not null';
  end if;
end $$;

create table if not exists public.dinner_room_members (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.dinner_rooms(id) on delete cascade,
  user_id uuid not null,
  member_name text not null,
  joined_at timestamptz not null default now(),
  unique(room_id,user_id)
);

create table if not exists public.dinner_menu_options (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.dinner_rooms(id) on delete cascade,
  menu_name text not null,
  created_by uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.dinner_menu_votes (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.dinner_rooms(id) on delete cascade,
  option_id uuid not null references public.dinner_menu_options(id) on delete cascade,
  user_id uuid not null,
  voter_name text,
  created_at timestamptz not null default now(),
  unique(room_id,user_id)
);

create table if not exists public.dinner_game_results (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.dinner_rooms(id) on delete cascade,
  game_type text not null,
  result_text text not null,
  created_by uuid,
  created_by_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.dinner_room_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.dinner_rooms(id) on delete cascade,
  sender_id uuid not null,
  sender_name text not null,
  message_text text not null,
  created_at timestamptz not null default now()
);

-- 예전 비밀번호 버전 함수 제거
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
  if auth.uid() is null then raise exception '로그인이 필요합니다.'; end if;
  if trim(coalesce(p_title,''))='' then raise exception '회식방 이름을 입력하세요.'; end if;

  select coalesce(nullif(trim(name),''),'관리자') into v_creator_name
  from public.profiles where id=auth.uid();

  insert into public.dinner_rooms(title,dinner_date,created_by,created_by_name)
  values(trim(p_title),coalesce(p_dinner_date,current_date),auth.uid(),coalesce(v_creator_name,'관리자'))
  returning id into v_room_id;

  for v_member in select value from jsonb_array_elements(coalesce(p_members,'[]'::jsonb)) loop
    begin
      v_user_id:=nullif(coalesce(v_member->>'user_id',v_member->>'id'),'')::uuid;
    exception when others then
      v_user_id:=null;
    end;
    v_member_name:=coalesce(nullif(trim(v_member->>'member_name'),''),nullif(trim(v_member->>'name'),''),'직원');
    if v_user_id is not null then
      insert into public.dinner_room_members(room_id,user_id,member_name)
      values(v_room_id,v_user_id,v_member_name)
      on conflict(room_id,user_id) do update set member_name=excluded.member_name;
    end if;
  end loop;

  insert into public.dinner_room_members(room_id,user_id,member_name)
  values(v_room_id,auth.uid(),coalesce(v_creator_name,'관리자'))
  on conflict(room_id,user_id) do update set member_name=excluded.member_name;

  return v_room_id;
end;
$$;

create or replace function public.delete_dinner_room_secure(p_room_id uuid)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare v_allowed boolean:=false;
begin
  if auth.uid() is null then raise exception '로그인이 필요합니다.'; end if;
  select exists(
    select 1 from public.dinner_rooms r
    left join public.profiles p on p.id=auth.uid()
    where r.id=p_room_id and (
      r.created_by=auth.uid() or coalesce(p.is_super_admin,false)
      or trim(coalesce(p.name,''))='손동오'
      or trim(coalesce(p.emp_no,''))='201911041'
    )
  ) into v_allowed;
  if not v_allowed then raise exception '방장 또는 최고관리자만 삭제할 수 있습니다.'; end if;
  delete from public.dinner_rooms where id=p_room_id;
  return true;
end;
$$;

grant select,insert,update,delete on public.dinner_rooms,public.dinner_room_members,public.dinner_menu_options,public.dinner_menu_votes,public.dinner_game_results,public.dinner_room_messages to authenticated;
grant execute on function public.create_dinner_room_secure(text,date,jsonb) to authenticated;
grant execute on function public.delete_dinner_room_secure(uuid) to authenticated;

notify pgrst,'reload schema';
commit;
