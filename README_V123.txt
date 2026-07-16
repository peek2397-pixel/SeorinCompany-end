SeorinCompany-end V123 통합본

포함 기능
- 손동오 이사 일정: 손동오·김헌정만 사용
- 김헌정 계정은 profiles.is_super_admin=true일 때 손동오와 같은 최고관리자 권한
- 구매·물품관리: 누가 등록·수정해도 모든 로그인 기기에 즉시 반영
- Realtime 지연 시 3초 보조 동기화
- 삭제 성공 후 서버 재조회, 재로그인 시 삭제 자료 재등장 방지

적용 순서
1. 00_먼저_SUPABASE에_전체붙여넣기_V123.txt 전체를 SQL Editor에서 실행
2. 이 폴더의 파일을 GitHub 저장소 루트에 덮어쓰기
3. Commit changes
4. Actions 빌드 완료 확인

버전: 1.23.0
