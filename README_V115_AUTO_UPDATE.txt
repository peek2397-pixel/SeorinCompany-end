SeorinCompany V115 자동 업데이트

1. 최초 1회
   직원 PC에 V115 설치파일을 설치합니다.

2. 새 버전 배포
   - package.json과 코드를 GitHub에 올립니다.
   - GitHub > Actions > Release SeorinCompany Auto Update > Run workflow
   - 새 버전 번호를 입력합니다. 예: 1.16.0
   - Release에 Setup.exe, latest.yml, blockmap이 자동 등록됩니다.

3. 직원 사용
   - 프로그램 실행 후 오른쪽 위 '업데이트 확인' 클릭
   - 새 버전이 있으면 '새 버전 다운로드' 클릭
   - 다운로드 완료 후 '재시작 후 설치' 클릭
   - 설치파일을 따로 전달할 필요가 없습니다.

중요
- GitHub 저장소 이름: peek2397-pixel/SeorinCompany-end
- GitHub Releases를 직원 PC에서 읽을 수 있어야 합니다.
- 저장소가 비공개이면 GitHub Releases 직접 자동 업데이트가 제한될 수 있습니다.
