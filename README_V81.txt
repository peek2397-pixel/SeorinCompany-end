SeorinCompany-end V81

1. Supabase SQL Editor에서 SQL/00_RUN_THIS_V81_FORKLIFT_SYNC.sql 전체 실행
2. GitHub SeorinCompany-end 저장소 루트에 이 폴더 내용을 덮어쓰기
3. Commit changes
4. Actions > Build SeorinCompany Windows Setup > Run workflow
5. 새 Artifact 설치

V81 수정 내용
- 지게차 asset_name/equipment_name 컬럼 호환
- 전동/디젤 구분 동기화
- 종합물류/3물류 위치 동기화
- 상태값 CHECK 오류 해결
- 사용중/대기/정비중/수리중/고장/사용중지/폐기 허용
- 증류수 날짜 컬럼 동기화
- 지게차 정비 테이블/권한 보완
- 기존 V79 차량 및 회식 비밀방 기능 유지
