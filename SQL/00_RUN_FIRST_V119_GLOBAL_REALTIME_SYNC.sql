BEGIN;

-- ==========================================================
-- V119 전체 공통자료 실시간 동기화
-- 외주 인력 입력 즉시 다른 로그인 계정의 근무달력/대시보드에 반영
-- 일정, 회의실, 출장, 차량, 카드, 직원·조직도도 동일 방식 적용
-- ==========================================================

GRANT SELECT, INSERT, UPDATE, DELETE
ON TABLE public.contractor_workforce
TO authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE
ON TABLE public.work_calendar_entries
TO authenticated;

ALTER TABLE public.contractor_workforce ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_calendar_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "contractor_workforce_select_authenticated"
ON public.contractor_workforce;

DROP POLICY IF EXISTS "contractor_workforce_insert_authenticated"
ON public.contractor_workforce;

DROP POLICY IF EXISTS "contractor_workforce_update_authenticated"
ON public.contractor_workforce;

DROP POLICY IF EXISTS "contractor_workforce_delete_authenticated"
ON public.contractor_workforce;

DROP POLICY IF EXISTS "work_calendar_entries_select_authenticated"
ON public.work_calendar_entries;

CREATE POLICY "contractor_workforce_select_authenticated"
ON public.contractor_workforce
FOR SELECT TO authenticated
USING (true);

CREATE POLICY "contractor_workforce_insert_authenticated"
ON public.contractor_workforce
FOR INSERT TO authenticated
WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "contractor_workforce_update_authenticated"
ON public.contractor_workforce
FOR UPDATE TO authenticated
USING (true)
WITH CHECK (true);

CREATE POLICY "contractor_workforce_delete_authenticated"
ON public.contractor_workforce
FOR DELETE TO authenticated
USING (true);

CREATE POLICY "work_calendar_entries_select_authenticated"
ON public.work_calendar_entries
FOR SELECT TO authenticated
USING (true);

ALTER TABLE public.contractor_workforce REPLICA IDENTITY FULL;
ALTER TABLE public.work_calendar_entries REPLICA IDENTITY FULL;

DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'contractor_workforce',
    'work_calendar_entries',
    'company_events',
    'meeting_bookings',
    'business_trips',
    'corporate_card_expenses',
    'vehicles',
    'vehicle_trips',
    'vehicle_maintenance',
    'vehicle_inspections',
    'forklift_assets',
    'forklift_maintenance',
    'employee_registry',
    'profiles',
    'org_teams'
  ]
  LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      BEGIN
        EXECUTE format('ALTER TABLE public.%I REPLICA IDENTITY FULL', t);
      EXCEPTION WHEN OTHERS THEN
        NULL;
      END;

      BEGIN
        EXECUTE format(
          'ALTER PUBLICATION supabase_realtime ADD TABLE public.%I',
          t
        );
      EXCEPTION
        WHEN duplicate_object THEN NULL;
      END;
    END IF;
  END LOOP;
END $$;

CREATE INDEX IF NOT EXISTS idx_contractor_workforce_work_date
ON public.contractor_workforce(work_date DESC);

CREATE INDEX IF NOT EXISTS idx_work_calendar_entries_start_date
ON public.work_calendar_entries(start_date);

NOTIFY pgrst, 'reload schema';

COMMIT;
