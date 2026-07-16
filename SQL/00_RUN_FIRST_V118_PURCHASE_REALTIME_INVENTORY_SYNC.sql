begin;

-- V118 구매신청·물품관리 전체 직원 실시간 동기화

grant select, insert, update, delete
on table public.purchase_requests
to authenticated;

grant select, insert, update, delete
on table public.inventory_items
to authenticated;

grant select, insert, update, delete
on table public.inventory_transactions
to authenticated;

alter table public.purchase_requests enable row level security;
alter table public.inventory_items enable row level security;
alter table public.inventory_transactions enable row level security;

drop policy if exists "purchase_requests_select_all_authenticated" on public.purchase_requests;
drop policy if exists "purchase_requests_insert_authenticated" on public.purchase_requests;
drop policy if exists "purchase_requests_update_authenticated" on public.purchase_requests;
drop policy if exists "inventory_items_select_all_authenticated" on public.inventory_items;
drop policy if exists "inventory_items_insert_authenticated" on public.inventory_items;
drop policy if exists "inventory_items_update_authenticated" on public.inventory_items;
drop policy if exists "inventory_transactions_select_all_authenticated" on public.inventory_transactions;
drop policy if exists "inventory_transactions_insert_authenticated" on public.inventory_transactions;

create policy "purchase_requests_select_all_authenticated"
on public.purchase_requests for select to authenticated
using (true);

create policy "purchase_requests_insert_authenticated"
on public.purchase_requests for insert to authenticated
with check (auth.uid() is not null);

create policy "purchase_requests_update_authenticated"
on public.purchase_requests for update to authenticated
using (true) with check (true);

create policy "inventory_items_select_all_authenticated"
on public.inventory_items for select to authenticated
using (true);

create policy "inventory_items_insert_authenticated"
on public.inventory_items for insert to authenticated
with check (auth.uid() is not null);

create policy "inventory_items_update_authenticated"
on public.inventory_items for update to authenticated
using (true) with check (true);

create policy "inventory_transactions_select_all_authenticated"
on public.inventory_transactions for select to authenticated
using (true);

create policy "inventory_transactions_insert_authenticated"
on public.inventory_transactions for insert to authenticated
with check (auth.uid() is not null);

alter table public.purchase_requests replica identity full;
alter table public.inventory_items replica identity full;
alter table public.inventory_transactions replica identity full;

do $$
begin
  begin
    alter publication supabase_realtime add table public.purchase_requests;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.inventory_items;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.inventory_transactions;
  exception when duplicate_object then null;
  end;
end $$;

create index if not exists idx_purchase_requests_created_at
on public.purchase_requests(created_at desc);

create index if not exists idx_purchase_requests_status
on public.purchase_requests(status);

notify pgrst, 'reload schema';

commit;
