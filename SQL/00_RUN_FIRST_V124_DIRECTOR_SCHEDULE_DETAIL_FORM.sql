BEGIN;

-- ==========================================================
-- V124 이사 스케줄 상세 입력 항목
-- 구분, 종료일, 담당자, 참여 인원 추가
-- ==========================================================

ALTER TABLE public.director_schedules
ADD COLUMN IF NOT EXISTS category text NOT NULL DEFAULT 'business';

ALTER TABLE public.director_schedules
ADD COLUMN IF NOT EXISTS end_date date;

ALTER TABLE public.director_schedules
ADD COLUMN IF NOT EXISTS manager text;

ALTER TABLE public.director_schedules
ADD COLUMN IF NOT EXISTS participant_count integer NOT NULL DEFAULT 0;

UPDATE public.director_schedules
SET end_date = schedule_date
WHERE end_date IS NULL;

ALTER TABLE public.director_schedules
ALTER COLUMN end_date SET DEFAULT current_date;

ALTER TABLE public.director_schedules
ADD CONSTRAINT director_schedules_date_order_check
CHECK (end_date IS NULL OR end_date >= schedule_date)
NOT VALID;

ALTER TABLE public.director_schedules
VALIDATE CONSTRAINT director_schedules_date_order_check;

ALTER TABLE public.director_schedules
ADD CONSTRAINT director_schedules_participant_count_check
CHECK (participant_count >= 0)
NOT VALID;

ALTER TABLE public.director_schedules
VALIDATE CONSTRAINT director_schedules_participant_count_check;

GRANT SELECT, INSERT, UPDATE, DELETE
ON TABLE public.director_schedules
TO authenticated;

ALTER TABLE public.director_schedules REPLICA IDENTITY FULL;

NOTIFY pgrst, 'reload schema';

COMMIT;
