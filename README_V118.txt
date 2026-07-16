V118 구매·물품 실시간 동기화

1. SQL/00_RUN_FIRST_V118_PURCHASE_REALTIME_INVENTORY_SYNC.sql을 Supabase에서 먼저 실행
2. 전체 파일을 GitHub에 덮어쓰기
3. Actions 버전 1.16.6으로 Release 생성
4. 프로그램 업데이트

반영:
- 구매신청을 모든 로그인 직원이 같은 목록으로 조회
- 다른 직원이 등록/수정하면 Realtime으로 즉시 반영
- Realtime 누락 대비 5초 자동 재조회
- 최종 결재 시 물품관리 품목 자동 생성·연결
- 결재 완료 후 물품관리 화면 자동 이동
