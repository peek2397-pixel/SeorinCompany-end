V110 회식방 참여자/접속표시 수정
1. SQL/00_RUN_FIRST_V110_DINNER_MEMBERS_PRESENCE_FIX.sql 전체를 Supabase SQL Editor에서 실행
2. 전체 파일을 GitHub 저장소에 덮어쓰기
3. Actions 새 빌드

반영:
- 방 생성 직후 선택 직원과 방장을 참여자 영역에 즉시 표시
- 방 입장 시 현재 접속자는 초록 원으로 표시
- 참여자/채팅 조회를 막던 RLS 충돌 해소
- text/uuid 혼합 회식방 삭제 오류 수정
