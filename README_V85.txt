V85 회식방 생성 오류 복구

1) Supabase SQL Editor에서 아래 파일을 전체 실행
   SQL/00_RUN_FIRST_V85_DINNER_FIX.sql
2) 결과가 Success. No rows returned 인지 확인
3) GitHub 저장소에 이 폴더 전체를 덮어쓰기
4) 새 Commit 후 Actions > Run workflow
5) 새 설치파일 설치

수정 내용
- public.create_dinner_room_secure 함수 확실히 생성
- 회식방/참여자/메뉴투표/게임결과/채팅 테이블 생성
- 비밀번호 암호화
- 초대 직원만 회식방 조회
- Windows 초대 알림과 방 내부 채팅 유지
