-- V121 손동오 이사 전용 일정
create table if not exists public.director_schedules (
  id uuid primary key default gen_random_uuid(),
  schedule_date date not null,
  start_time time,
  end_time time,
  title text not null,
  location text default '',
  memo text default '',
  importance text not null default '일반' check (importance in ('일반','중요')),
  is_completed boolean not null default false,
  created_by uuid references auth.users(id),
  created_by_name text,
  updated_by uuid references auth.users(id),
  updated_by_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.director_schedules enable row level security;
drop policy if exists director_schedule_select on public.director_schedules;
drop policy if exists director_schedule_insert on public.director_schedules;
drop policy if exists director_schedule_update on public.director_schedules;
drop policy if exists director_schedule_delete on public.director_schedules;
create policy director_schedule_select on public.director_schedules for select to authenticated using (exists(select 1 from public.profiles p where p.id=auth.uid() and trim(p.name) in ('손동오','김헌정')));
create policy director_schedule_insert on public.director_schedules for insert to authenticated with check (exists(select 1 from public.profiles p where p.id=auth.uid() and trim(p.name) in ('손동오','김헌정')));
create policy director_schedule_update on public.director_schedules for update to authenticated using (exists(select 1 from public.profiles p where p.id=auth.uid() and trim(p.name) in ('손동오','김헌정'))) with check (exists(select 1 from public.profiles p where p.id=auth.uid() and trim(p.name) in ('손동오','김헌정')));
create policy director_schedule_delete on public.director_schedules for delete to authenticated using (exists(select 1 from public.profiles p where p.id=auth.uid() and trim(p.name) in ('손동오','김헌정')));
grant select,insert,update,delete on public.director_schedules to authenticated;
