begin;

-- 채팅 관련 테이블을 Supabase Realtime에 등록합니다.
-- 이미 등록되어 있으면 오류 없이 넘어갑니다.
do $$
declare
  t text;
begin
  foreach t in array array[
    'chat_messages',
    'messenger_messages',
    'private_messages',
    'private_message_replies',
    'dinner_room_messages'
  ]
  loop
    if to_regclass('public.'||t) is not null then
      begin
        execute format('alter publication supabase_realtime add table public.%I',t);
      exception when duplicate_object then
        null;
      end;
    end if;
  end loop;
end $$;

notify pgrst,'reload schema';
commit;
