-- V88 회식방 DB 복구 + 팀 선택 화면용 + 방 삭제 기능
begin;
create extension if not exists pgcrypto;

create table if not exists public.dinner_rooms (
  id uuid primary key default gen_random_uuid(), title text not null, dinner_date date not null default current_date,
  password_hash text not null, messenger_room_id uuid, created_by uuid not null, created_by_name text, created_at timestamptz not null default now()
);
create table if not exists public.dinner_room_members (
  id uuid primary key default gen_random_uuid(), room_id uuid not null references public.dinner_rooms(id) on delete cascade,
  user_id uuid not null, member_name text not null, joined_at timestamptz not null default now(), unique(room_id,user_id)
);
create table if not exists public.dinner_menu_options (id uuid primary key default gen_random_uuid(), room_id uuid not null references public.dinner_rooms(id) on delete cascade, menu_name text not null, created_by uuid, created_at timestamptz not null default now());
create table if not exists public.dinner_menu_votes (id uuid primary key default gen_random_uuid(), room_id uuid not null references public.dinner_rooms(id) on delete cascade, option_id uuid not null references public.dinner_menu_options(id) on delete cascade, user_id uuid not null, voter_name text, created_at timestamptz not null default now(), unique(room_id,user_id));
create table if not exists public.dinner_game_results (id uuid primary key default gen_random_uuid(), room_id uuid not null references public.dinner_rooms(id) on delete cascade, game_type text not null, result_text text not null, created_by uuid, created_by_name text, created_at timestamptz not null default now());
create table if not exists public.dinner_room_messages (id uuid primary key default gen_random_uuid(), room_id uuid not null references public.dinner_rooms(id) on delete cascade, sender_id uuid not null, sender_name text not null, message_text text not null check(length(trim(message_text)) between 1 and 3000), created_at timestamptz not null default now());
create index if not exists idx_dinner_room_members_user on public.dinner_room_members(user_id);
create index if not exists idx_dinner_room_messages_room_time on public.dinner_room_messages(room_id,created_at);

drop function if exists public.create_dinner_room_secure(text,date,text,jsonb);
create function public.create_dinner_room_secure(p_title text,p_dinner_date date,p_password text,p_members jsonb) returns uuid language plpgsql security definer set search_path=public as $$
declare v_room uuid; v_member jsonb; v_name text; v_user_id uuid; v_member_name text;
begin
 if auth.uid() is null then raise exception '로그인이 필요합니다.'; end if;
 if length(trim(coalesce(p_title,'')))=0 then raise exception '회식방 이름이 필요합니다.'; end if;
 if length(coalesce(p_password,''))<4 then raise exception '비밀번호는 4자 이상이어야 합니다.'; end if;
 select name into v_name from public.profiles where id=auth.uid();
 insert into public.dinner_rooms(title,dinner_date,password_hash,created_by,created_by_name) values(trim(p_title),coalesce(p_dinner_date,current_date),crypt(p_password,gen_salt('bf')),auth.uid(),coalesce(v_name,'관리자')) returning id into v_room;
 for v_member in select value from jsonb_array_elements(coalesce(p_members,'[]'::jsonb)) loop
   begin v_user_id:=nullif(v_member->>'user_id','')::uuid; exception when others then v_user_id:=null; end;
   v_member_name:=coalesce(nullif(trim(v_member->>'member_name'),''),'직원');
   if v_user_id is not null then insert into public.dinner_room_members(room_id,user_id,member_name) values(v_room,v_user_id,v_member_name) on conflict(room_id,user_id) do nothing; end if;
 end loop;
 insert into public.dinner_room_members(room_id,user_id,member_name) values(v_room,auth.uid(),coalesce(v_name,'관리자')) on conflict(room_id,user_id) do nothing;
 return v_room;
end $$;

create or replace function public.verify_dinner_room_password(p_room_id uuid,p_password text) returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.dinner_room_members m join public.dinner_rooms r on r.id=m.room_id where m.room_id=p_room_id and m.user_id=auth.uid() and r.password_hash=crypt(p_password,r.password_hash));
$$;

create or replace function public.delete_dinner_room_secure(p_room_id uuid) returns boolean language plpgsql security definer set search_path=public as $$
declare v_allowed boolean:=false;
begin
 if auth.uid() is null then raise exception '로그인이 필요합니다.'; end if;
 select exists(select 1 from public.dinner_rooms r left join public.profiles p on p.id=auth.uid() where r.id=p_room_id and (r.created_by=auth.uid() or coalesce(p.is_super_admin,false) or trim(coalesce(p.name,''))='손동오' or trim(coalesce(p.emp_no,''))='201911041')) into v_allowed;
 if not v_allowed then raise exception '방을 만든 사람 또는 최고관리자만 삭제할 수 있습니다.'; end if;
 delete from public.dinner_rooms where id=p_room_id; return true;
end $$;

grant execute on function public.create_dinner_room_secure(text,date,text,jsonb) to authenticated;
grant execute on function public.verify_dinner_room_password(uuid,text) to authenticated;
grant execute on function public.delete_dinner_room_secure(uuid) to authenticated;

alter table public.dinner_rooms enable row level security; alter table public.dinner_room_members enable row level security; alter table public.dinner_menu_options enable row level security; alter table public.dinner_menu_votes enable row level security; alter table public.dinner_game_results enable row level security; alter table public.dinner_room_messages enable row level security;
do $$ declare r record; begin for r in select tablename,policyname from pg_policies where schemaname='public' and tablename in ('dinner_rooms','dinner_room_members','dinner_menu_options','dinner_menu_votes','dinner_game_results','dinner_room_messages') loop execute format('drop policy if exists %I on public.%I',r.policyname,r.tablename); end loop; end $$;
create policy dinner_rooms_member_select on public.dinner_rooms for select to authenticated using(exists(select 1 from public.dinner_room_members m where m.room_id=id and m.user_id=auth.uid()));
create policy dinner_rooms_creator_update on public.dinner_rooms for update to authenticated using(created_by=auth.uid()) with check(created_by=auth.uid());
create policy dinner_rooms_creator_delete on public.dinner_rooms for delete to authenticated using(created_by=auth.uid() or exists(select 1 from public.profiles p where p.id=auth.uid() and (coalesce(p.is_super_admin,false) or trim(coalesce(p.name,''))='손동오' or trim(coalesce(p.emp_no,''))='201911041')));
create policy dinner_members_member_select on public.dinner_room_members for select to authenticated using(exists(select 1 from public.dinner_room_members me where me.room_id=room_id and me.user_id=auth.uid()));
create policy dinner_members_creator_write on public.dinner_room_members for all to authenticated using(exists(select 1 from public.dinner_rooms r where r.id=room_id and r.created_by=auth.uid())) with check(exists(select 1 from public.dinner_rooms r where r.id=room_id and r.created_by=auth.uid()));
create policy dinner_options_member_all on public.dinner_menu_options for all to authenticated using(exists(select 1 from public.dinner_room_members m where m.room_id=room_id and m.user_id=auth.uid())) with check(exists(select 1 from public.dinner_room_members m where m.room_id=room_id and m.user_id=auth.uid()));
create policy dinner_votes_member_all on public.dinner_menu_votes for all to authenticated using(exists(select 1 from public.dinner_room_members m where m.room_id=room_id and m.user_id=auth.uid())) with check(user_id=auth.uid() and exists(select 1 from public.dinner_room_members m where m.room_id=room_id and m.user_id=auth.uid()));
create policy dinner_results_member_all on public.dinner_game_results for all to authenticated using(exists(select 1 from public.dinner_room_members m where m.room_id=room_id and m.user_id=auth.uid())) with check(exists(select 1 from public.dinner_room_members m where m.room_id=room_id and m.user_id=auth.uid()));
create policy dinner_messages_member_select on public.dinner_room_messages for select to authenticated using(exists(select 1 from public.dinner_room_members m where m.room_id=room_id and m.user_id=auth.uid()));
create policy dinner_messages_member_insert on public.dinner_room_messages for insert to authenticated with check(sender_id=auth.uid() and exists(select 1 from public.dinner_room_members m where m.room_id=room_id and m.user_id=auth.uid()));
grant select,insert,update,delete on public.dinner_rooms,public.dinner_room_members,public.dinner_menu_options,public.dinner_menu_votes,public.dinner_game_results,public.dinner_room_messages to authenticated;
do $$ begin alter publication supabase_realtime add table public.dinner_room_members; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.dinner_room_messages; exception when duplicate_object then null; end $$;
notify pgrst,'reload schema'; commit;
