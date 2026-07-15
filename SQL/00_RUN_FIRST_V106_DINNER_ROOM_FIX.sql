begin;

create table if not exists public.dinner_rooms (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  dinner_date date not null default current_date,
  created_by uuid not null,
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

create table if not exists public.dinner_room_messages (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references public.dinner_rooms(id) on delete cascade,
  sender_id uuid not null,
  sender_name text not null,
  message_text text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_dinner_members_user on public.dinner_room_members(user_id);
create index if not exists idx_dinner_members_room on public.dinner_room_members(room_id);
create index if not exists idx_dinner_messages_room_time on public.dinner_room_messages(room_id,created_at);

drop function if exists public.create_dinner_room_secure(text,date,jsonb);
create function public.create_dinner_room_secure(p_title text,p_dinner_date date,p_members jsonb)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_room uuid; v_member jsonb; v_uid uuid; v_name text; v_creator text;
begin
  if auth.uid() is null then raise exception '로그인이 필요합니다.'; end if;
  if trim(coalesce(p_title,''))='' then raise exception '회식방 이름을 입력하세요.'; end if;
  select coalesce(nullif(trim(name),''),'관리자') into v_creator from public.profiles where id=auth.uid();
  insert into public.dinner_rooms(title,dinner_date,created_by,created_by_name) values(trim(p_title),coalesce(p_dinner_date,current_date),auth.uid(),coalesce(v_creator,'관리자')) returning id into v_room;
  for v_member in select value from jsonb_array_elements(coalesce(p_members,'[]'::jsonb)) loop
    begin v_uid=nullif(coalesce(v_member->>'user_id',v_member->>'id'),'')::uuid; exception when others then v_uid=null; end;
    v_name=coalesce(nullif(trim(v_member->>'member_name'),''),nullif(trim(v_member->>'name'),''),'직원');
    if v_uid is not null then insert into public.dinner_room_members(room_id,user_id,member_name) values(v_room,v_uid,v_name) on conflict(room_id,user_id) do update set member_name=excluded.member_name; end if;
  end loop;
  insert into public.dinner_room_members(room_id,user_id,member_name) values(v_room,auth.uid(),coalesce(v_creator,'관리자')) on conflict(room_id,user_id) do update set member_name=excluded.member_name;
  return v_room;
end;$$;

drop function if exists public.delete_dinner_room_secure(uuid);
create function public.delete_dinner_room_secure(p_room_id uuid) returns boolean language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception '로그인이 필요합니다.'; end if;
  delete from public.dinner_rooms where id=p_room_id and created_by=auth.uid();
  if not found then raise exception '방을 만든 사람만 삭제할 수 있습니다.'; end if;
  return true;
end;$$;

grant select,insert,update,delete on public.dinner_rooms,public.dinner_room_members,public.dinner_room_messages to authenticated;
grant execute on function public.create_dinner_room_secure(text,date,jsonb) to authenticated;
grant execute on function public.delete_dinner_room_secure(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
