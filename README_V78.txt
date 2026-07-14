V78 적용 순서
1. SQL/V78_VEHICLE_TRIP_LOG_FULL.sql 전체를 Supabase SQL Editor에 붙여넣고 Run
2. GitHub SeorinCompany-end 저장소에 전체 파일 덮어쓰기 후 Commit
3. Actions에서 새 Run workflow 실행
4. 새 설치파일 설치

반영내용
- 일반차량/운송팀차량 동일 카드 및 차량정보 화면
- 차량·장비관리 상단 관리 버튼은 관리자에게만 표시
- 운행일지 전체 직원 조회 가능
- 운행일, 운전자, 출발지, 도착지, 출발/도착 주행거리, 운행거리, 주유비, 통행료, 운행목적, 비고 표시
- 도착 주행거리 저장 시 차량 현재 주행거리 자동 갱신
