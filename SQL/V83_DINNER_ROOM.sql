-- V83 회식방/메뉴투표/게임 결과
begin;
create extension if not exists pgcrypto;
create table if not exists public.dinner_rooms (
 id uuid primary key default gen_random_uuid(), title text not null, dinner_date date not null default current_date, messenger_room_id uuid, created_by uuid not null, created_by_name text, created_at timestamptz not null default now()
);
create table if not exists public.dinner_room_members (
 id uuid primary key default gen_random_uuid(), room_id uuid not null references public.dinner_rooms(id) on delete cascade, user_id uuid not null, member_name text not null, joined_at timestamptz not null default now(), unique(room_id,user_id)
);
create table if not exists public.dinner_menu_options (
 id uuid primary key default gen_random_uuid(), room_id uuid not null references public.dinner_rooms(id) on delete cascade, menu_name text not null, created_by uuid, created_at timestamptz not null default now()
);
create table if not exists public.dinner_menu_votes (
 id uuid primary key default gen_random_uuid(), room_id uuid not null references public.dinner_rooms(id) on delete cascade, option_id uuid not null references public.dinner_menu_options(id) on delete cascade, user_id uuid not null, voter_name text, created_at timestamptz not null default now(), unique(room_id,user_id)
);
create table if not exists public.dinner_game_results (
 id uuid primary key default gen_random_uuid(), room_id uuid not null references public.dinner_rooms(id) on delete cascade, game_type text not null, result_text text not null, created_by uuid, created_by_name text, created_at timestamptz not null default now()
);

alter table public.dinner_rooms enable row level security;
alter table public.dinner_room_members enable row level security;
alter table public.dinner_menu_options enable row level security;
alter table public.dinner_menu_votes enable row level security;
alter table public.dinner_game_results enable row level security;

do $$ declare r record; begin
 for r in select schemaname,tablename,policyname from pg_policies where schemaname='public' and tablename in ('dinner_rooms','dinner_room_members','dinner_menu_options','dinner_menu_votes','dinner_game_results') loop execute format('drop policy if exists %I on public.%I',r.policyname,r.tablename); end loop;
end $$;
create policy dinner_rooms_auth_all on public.dinner_rooms for all to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);
create policy dinner_members_auth_all on public.dinner_room_members for all to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);
create policy dinner_options_auth_all on public.dinner_menu_options for all to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);
create policy dinner_votes_auth_all on public.dinner_menu_votes for all to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);
create policy dinner_results_auth_all on public.dinner_game_results for all to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);
grant select,insert,update,delete on public.dinner_rooms,public.dinner_room_members,public.dinner_menu_options,public.dinner_menu_votes,public.dinner_game_results to authenticated;
notify pgrst,'reload schema';
commit;
