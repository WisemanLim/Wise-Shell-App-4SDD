# impl/4 시험 시나리오 — --default-env 기본환경 + -a/--auth

요구: `--default-env` 처리 시 기본환경 구성.
1. `-I/--input`(=/repo) 필수 — 없으면 에러+종료.
2. workspace=현재경로(PWD), ops repo=첫 번째 repo 이름.
3. `-a/--auth` 필수, 기본 method=pat, 토큰값 필수 — 없으면 에러+종료.
   `-a <value>`: 키워드 gh|pat|none = method, 그 외 문자열 = PAT 토큰 직접 운반(method=pat). `-a`/`--auth` 양형 지원.

실행: `bash test/impl/4/run.sh` (실제 호출, 로컬 repo로 네트워크 없이) + verify/impl1~3 회귀.

| # | Given | When | Then |
|---|---|---|---|
| 1 | `--default-env -a tok` (no -I) | 실행 | rc≠0 + "repositories are required" |
| 2 | `--default-env -I url` (no -a) | 실행 | rc≠0 + "-a/--auth is required" |
| 3 | `--default-env -I url -a pat`(토큰 없음) | 실행 | rc≠0 + "PAT value is required" |
| 4 | `-I <localrepo> -a <token> --default-env --no-run`, cwd=tmp | 실행 | rc=0, ws=cwd, ops=첫repo명, cloned, deploy skip |
| 5 | `-a gh` | 파싱 | AUTH_METHOD=gh (키워드 method) |
| 6 | `-a <token>` | 파싱 | AUTH_METHOD=pat + GITHUB_PAT=token (직접 운반) |
| 7 | help | `--help` | `--default-env`, `-a, --auth` 노출 |
| R | 회귀 | verify + impl1~3 | 모두 PASS |
