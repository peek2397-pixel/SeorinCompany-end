-- SeorinCompany-end V86
-- 최고관리자(손동오)는 구매담당자 검토 전에도 즉시 승인·반려·완료 처리 가능

begin;

alter table public.purchase_requests
  add column if not exists review_skip_reason text;

alter table public.purchase_requests
  add column if not exists approver_id uuid;

alter table public.purchase_requests
  add column if not exists approver_name text;

alter table public.purchase_requests
  add column if not exists approved_at timestamptz;

alter table public.purchase_requests
  add column if not exists completed_at timestamptz;

alter table public.purchase_requests
  add column if not exists reject_reason text;

create or replace function public.admin_direct_purchase_status(
  p_request_id uuid,
  p_status text,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_name text;
  v_is_admin boolean := false;
begin
  if auth.uid() is null then
    raise exception '로그인이 필요합니다.';
  end if;

  select
    coalesce(nullif(trim(p.name), ''), '손동오'),
    (
      coalesce(p.is_super_admin, false)
      or trim(coalesce(p.name, '')) = '손동오'
      or trim(coalesce(p.emp_no, '')) = '201911041'
    )
  into v_admin_name, v_is_admin
  from public.profiles p
  where p.id = auth.uid();

  if not coalesce(v_is_admin, false) then
    raise exception '최고관리자만 검토 단계를 생략할 수 있습니다.';
  end if;

  if p_status not in ('approved', 'rejected', 'completed') then
    raise exception '직접 처리할 수 없는 상태입니다: %', p_status;
  end if;

  if not exists (
    select 1 from public.purchase_requests where id = p_request_id
  ) then
    raise exception '구매 신청을 찾을 수 없습니다.';
  end if;

  if p_status = 'approved' then
    update public.purchase_requests
    set
      status = 'approved',
      review_skip_reason = '검토 생략 - 최고관리자 직접 승인',
      approver_id = auth.uid(),
      approver_name = v_admin_name,
      approved_at = now(),
      reject_reason = null
    where id = p_request_id;

  elsif p_status = 'completed' then
    update public.purchase_requests
    set
      status = 'completed',
      review_skip_reason = '검토 생략 - 최고관리자 직접 완료',
      approver_id = auth.uid(),
      approver_name = v_admin_name,
      approved_at = coalesce(approved_at, now()),
      completed_at = now(),
      reject_reason = null
    where id = p_request_id;

  else
    update public.purchase_requests
    set
      status = 'rejected',
      review_skip_reason = '검토 생략 - 최고관리자 직접 반려',
      approver_id = auth.uid(),
      approver_name = v_admin_name,
      approved_at = now(),
      reject_reason = coalesce(nullif(trim(p_reason), ''), '최고관리자 반려')
    where id = p_request_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'request_id', p_request_id,
    'status', p_status,
    'processed_by', v_admin_name,
    'review_skipped', true
  );
end;
$$;

grant execute
on function public.admin_direct_purchase_status(uuid, text, text)
to authenticated;

notify pgrst, 'reload schema';

commit;
