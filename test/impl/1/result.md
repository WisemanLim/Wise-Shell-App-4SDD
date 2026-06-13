# impl/1 시험 결과 — 6개 요구사항

날짜: 2026-06-13 · 환경: macOS, bash 3.2.57, gh 2.92.0, docker present, GNU Make 3.81
판정: **ALL PASS**

## 단위 시험 (`bash test/impl/1/run.sh`) — 23/23 PASS, exit 0
| 요구 | 검증 | 결과 |
|---|---|---|
| 1 모듈분리 | `system_env_check`·`pre_install_deps` 정의 | ✅ |
| 2 repo검증 | 빈/무효 → NOT SET, https·git@·로컬경로 valid, 무효만 → 0 valid | ✅ (8) |
| 4 auth 4택 | `auth_gh_status/switch/login`·`auth_pat_register` 정의 | ✅ (4) |
| 5 bootstrap | 미충족→PENDING, 충족+DONE→DONE, 충족·미실행→PENDING, 미충족 시 거부+NOT SET 출력 | ✅ (5) |
| 6 dist-run | PENDING이면 비0 반환·bootstrap 가이드·NOT SET 출력·make 미실행 | ✅ (4) |

## 회귀 시험 (`./verify.sh`) — exit 0
Test 1 help / Test 2 missing-input 오류 / Test 3 cache 함수 / Test 4 CLI dry-run(`--no-run`) 전부 PASS.

## 구현 노트
- `handle_bootstrap`을 `system_env_check`(설치 없는 환경확인) + `pre_install_deps`(의존성 설치)로 분리.
- `is_valid_repo_url`/`count_valid_repos`/`repo_is_set`/`workspace_is_set`/`auth_is_set`/`bootstrap_ready`/`bootstrap_status_str`/`print_not_set_items` 상태 헬퍼 추가.
- repo/workspace/auth 변경 시 `invalidate_bootstrap`로 `BOOTSTRAP_DONE=0` 리셋(상태 정합).
- `/auth` 메뉴를 gh status/switch/login + PAT 4택으로 재작성, 현재 gh 사용자 표시.
- `/dist-run` 자동 bootstrap 제거 → PENDING이면 가이드+NOT SET 출력 후 미실행(Req 6).
- 말미 `[[ "${BASH_SOURCE[0]}" == "${0}" ]]` 가드 추가 — 직접실행 보존 + 시험용 source 허용.

## 수정 이력
- run.sh 초기: 카운터 0/0. 원인=소스된 wsa4sdd.sh가 테스트의 `ok()` 재정의. → 헬퍼를 source 이후 정의 + `tpass/tfail`로 개명. PASS.

## 미실행 (의도)
- `handle_bootstrap`의 ready 경로(실제 의존성 설치)와 `handle_dist_run`의 DONE 경로(실 make 배포)는 부작용/TTY 필요로 단위시험서 제외. CLI dry-run은 verify.sh Test 4로 커버.
