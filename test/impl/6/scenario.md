# impl/6 시험 시나리오 — /repo 브랜치 지정 + 다중 입력 개선

요구: `/repo`,`/R`이 URL만 받던 것을 **브랜치별 clone/pull** 가능하게 개선. 여러 주소 입력 방식 개선.
- repo 스펙: `<url>` 또는 `<url>#<branch>` (SSH `git@`의 `@`와 충돌 없는 `#` 구분자).
- 다중 입력: 공백/콤마 구분 (positional·interactive Add 공통).

실행: `bash test/impl/6/run.sh`(소스 단위 + 로컬 git repo, 네트워크 없음) + verify/impl1~5 회귀.

| # | Given | When | Then |
|---|---|---|---|
| 1 | `url#dev` | `repo_url_part`/`repo_branch_part` | url=url, branch=dev |
| 2 | `url`(브랜치 없음) | `repo_branch_part` | 빈 문자열 |
| 3 | `https://h/o/name.git#feature/x` | `repo_name_from_url` | name (브랜치 무시) |
| 4 | `git@h:o/r.git#main` | `is_valid_repo_url` | valid (브랜치 허용) |
| 5 | `bogus#dev` | `is_valid_repo_url` | invalid |
| 6 | positional `'a#dev,b' 'c#main'` (콤마+공백) | `handle_repo` | 3개 스펙 등록 |
| 7 | 로컬 repo(main,dev) `src#dev` | `sync_repo` | dev 브랜치로 clone, devfile 존재 |
| 8 | clone된 repo, `src#main`로 재sync | `sync_repo` | main으로 checkout+pull |
| 9 | help/welcome | grep | `#branch` 안내 노출 |
| R | 회귀 | verify + impl1~5 | 모두 PASS |
