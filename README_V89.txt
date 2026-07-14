V89 변경사항
1. 회식방 비밀번호 입력/확인 기능 삭제
2. 초대된 직원은 회식방을 바로 열 수 있음
3. 기존 room_password/password_hash NOT NULL 제약 해제 SQL 포함
4. 차량·장비관리의 '관리' 버튼 클릭 이벤트 보강
5. 관리 버튼 클릭 시 차량 등록·수정 화면으로 이동하고 화면을 자동 스크롤
적용 순서: SQL/00_RUN_FIRST_V89_DINNER_NO_PASSWORD.sql 실행 → 전체 파일 GitHub 덮어쓰기 → 빌드
