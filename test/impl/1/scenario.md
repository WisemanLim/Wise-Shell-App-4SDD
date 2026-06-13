# impl/1 시험 시나리오 — 6개 신규/변경 요구사항

대상: wsa4sdd.sh v1.1.0. 상태 로직(NOT SET / PENDING / DONE)을 소스 가드로 단위 시험.
실행: `bash test/impl/1/run.sh` (스크립트를 source 하여 함수 단위 검증) + 루트 `./verify.sh`(회귀).

| # | 요구 | Given | When | Then |
|---|---|---|---|---|
| 1 | 모듈 분리 | 소스 | `system_env_check`/`pre_install_deps` 함수 존재 | 둘 다 정의됨 |
| 2a | repo 검증 | 빈 INPUT_REPOS | `repo_is_set` | false (NOT SET) |
| 2b | repo 검증 | 무효 URL `foo` | `is_valid_repo_url` | false |
| 2c | repo 검증 | `https://x/y`, `git@h:o/r`, 로컬경로 | `is_valid_repo_url` | 각 true |
| 2d | repo 검증 | 무효만 등록 | `count_valid_repos` | 0 → NOT SET |
| 4 | auth 4택 | 소스 | `auth_gh_status/switch/login` + `auth_pat_register` 존재 | 4 함수 정의 |
| 5a | bootstrap 게이트 | repo/ws/auth 중 일부 미설정 | `bootstrap_status_str` | `PENDING` |
| 5b | bootstrap 게이트 | 셋 다 set + DONE=1 | `bootstrap_status_str` | `DONE` |
| 5c | bootstrap 게이트 | 셋 다 set, 미실행 | `bootstrap_status_str` | `PENDING` |
| 5d | 거부 | 미충족 상태 | `handle_bootstrap` | 비0 반환 + NOT SET 출력 |
| 6a | dist-run 게이트 | PENDING | `handle_dist_run` | 비0 반환, make 미실행, NOT SET 정보 출력 |
| 6b | 무자동부트 | PENDING | `handle_dist_run` | bootstrap 자동실행 안 함 |
| R | 회귀 | — | `./verify.sh` | 4/4 PASS |
