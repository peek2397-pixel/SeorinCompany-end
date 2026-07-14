-- V78 차량 운행일지 전체 항목 및 전체 직원 조회
begin;

alter table public.vehicle_trip_logs add column if not exists start_odometer_km numeric(14,1) not null default 0;
alter table public.vehicle_trip_logs add column if not exists end_odometer_km numeric(14,1) not null default 0;
alter table public.vehicle_trip_logs add column if not exists toll_cost numeric(14,0) not null default 0;

-- 기존 자료 변환: 기존 최종 계기판 값을 도착 주행거리로 사용
update public.vehicle_trip_logs
set end_odometer_km = coalesce(nullif(end_odometer_km,0), odometer_km, 0),
    start_odometer_km = case
      when coalesce(start_odometer_km,0)=0 and coalesce(odometer_km,0)>0
      then greatest(coalesce(odometer_km,0)-coalesce(distance_km,0),0)
      else coalesce(start_odometer_km,0)
    end
where coalesce(end_odometer_km,0)=0 or coalesce(start_odometer_km,0)=0;

alter table public.vehicle_trip_logs enable row level security;

drop policy if exists "vehicle trip logs authenticated select" on public.vehicle_trip_logs;
create policy "vehicle trip logs authenticated select"
on public.vehicle_trip_logs for select to authenticated using (true);

grant select on public.vehicle_trip_logs to authenticated;
notify pgrst, 'reload schema';
commit;
