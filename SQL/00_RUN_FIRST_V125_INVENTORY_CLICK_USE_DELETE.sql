BEGIN;

-- ==========================================================
-- V125 재고현황 클릭 사용 + 테스트 삭제
-- ==========================================================

DROP FUNCTION IF EXISTS public.use_inventory_item_direct(text,numeric,text,text);

CREATE FUNCTION public.use_inventory_item_direct(
  p_item_id text,
  p_quantity numeric,
  p_person_name text,
  p_memo text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item public.inventory_items%ROWTYPE;
  v_new_stock numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.';
  END IF;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION '사용 수량은 0보다 커야 합니다.';
  END IF;

  SELECT *
  INTO v_item
  FROM public.inventory_items
  WHERE id::text = TRIM(p_item_id)
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '품목을 찾을 수 없습니다.';
  END IF;

  IF COALESCE(v_item.current_stock,0) < p_quantity THEN
    RAISE EXCEPTION '현재재고보다 많이 사용할 수 없습니다.';
  END IF;

  v_new_stock := COALESCE(v_item.current_stock,0) - p_quantity;

  INSERT INTO public.inventory_transactions(
    item_id,
    transaction_type,
    quantity,
    person_name,
    memo,
    created_by
  )
  VALUES(
    v_item.id,
    'out',
    p_quantity,
    NULLIF(TRIM(p_person_name),''),
    NULLIF(TRIM(p_memo),''),
    auth.uid()
  );

  UPDATE public.inventory_items
  SET current_stock = v_new_stock
  WHERE id::text = v_item.id::text;

  RETURN jsonb_build_object(
    'success',true,
    'item_id',v_item.id,
    'used_quantity',p_quantity,
    'new_stock',v_new_stock
  );
END;
$$;

REVOKE ALL
ON FUNCTION public.use_inventory_item_direct(text,numeric,text,text)
FROM public;

GRANT EXECUTE
ON FUNCTION public.use_inventory_item_direct(text,numeric,text,text)
TO authenticated;

DROP FUNCTION IF EXISTS public.admin_force_delete_inventory_item_test(text);

CREATE FUNCTION public.admin_force_delete_inventory_item_test(
  p_item_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item public.inventory_items%ROWTYPE;
  v_admin boolean := false;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION '로그인이 필요합니다.';
  END IF;

  SELECT
    COALESCE(p.is_super_admin,false)
    OR TRIM(COALESCE(p.name,'')) = '손동오'
    OR TRIM(COALESCE(p.emp_no::text,'')) = '201911041'
  INTO v_admin
  FROM public.profiles p
  WHERE p.id::text = auth.uid()::text
  LIMIT 1;

  IF NOT COALESCE(v_admin,false) THEN
    RAISE EXCEPTION '관리자만 삭제할 수 있습니다.';
  END IF;

  SELECT *
  INTO v_item
  FROM public.inventory_items
  WHERE id::text = TRIM(p_item_id)
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION '삭제할 품목을 찾을 수 없습니다.';
  END IF;

  UPDATE public.purchase_requests
  SET inventory_item_id = NULL
  WHERE inventory_item_id::text = v_item.id::text;

  DELETE FROM public.inventory_transactions
  WHERE item_id::text = v_item.id::text;

  DELETE FROM public.inventory_items
  WHERE id::text = v_item.id::text;

  RETURN jsonb_build_object(
    'success',true,
    'item_id',v_item.id,
    'message','테스트 품목과 입출고 기록을 삭제했습니다. 구매신청 내역은 유지됩니다.'
  );
END;
$$;

REVOKE ALL
ON FUNCTION public.admin_force_delete_inventory_item_test(text)
FROM public;

GRANT EXECUTE
ON FUNCTION public.admin_force_delete_inventory_item_test(text)
TO authenticated;

GRANT SELECT,INSERT,UPDATE,DELETE
ON TABLE public.inventory_items,
         public.inventory_transactions,
         public.purchase_requests
TO authenticated;

ALTER TABLE public.inventory_items REPLICA IDENTITY FULL;
ALTER TABLE public.inventory_transactions REPLICA IDENTITY FULL;

NOTIFY pgrst, 'reload schema';

COMMIT;
