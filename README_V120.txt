V120 물품관리 입고 확인

- 결재로 물품관리 품목 생성
- 물품관리 관리 칸에 입고 확인 버튼 표시
- 실제 입고수량, 입고일, 메모 입력
- 입고 처리 시 현재재고 자동 증가
- inventory_transactions 입고 기록 생성
- 구매신청 상태 자동 구매완료
- 입고 담당자·일자·수량 저장
- 다른 로그인 계정에도 Realtime 즉시 반영
- 기존 물품을 다시 등록할 필요 없음
- 버전 1.16.8

적용 순서:
1. SQL/00_RUN_FIRST_V120_INVENTORY_RECEIPT_CONFIRM.sql 실행
2. GitHub 전체 덮어쓰기
3. Actions에서 1.16.8 Release 생성
4. 프로그램 업데이트
