# impl/3 시험 결과 — bootstrap 단계 실패 시 [DONE] 금지 (버그 수정)

날짜: 2026-06-13 · 환경: macOS, bash 3.2.57 · 판정: **ALL PASS**

## 버그
clone 실패(`✗ Clone failed: wsa4sdd-samples1`)에도 `Bootstrap : [DONE]` 처리됨.
- **원인**: `sync_repo`의 `die`가 `name="$(sync_repo …)"` 명령치환 **서브셸**에서 실행 → `exit 1`이 서브셸만 종료, 메인 루프는 계속 → `handle_bootstrap`가 `BOOTSTRAP_DONE=1`까지 도달. (부수 버그: 그 `die`가 캐시까지 삭제.)

## 수정
- `sync_repo` clone 실패: `die` → `return 1`(서브셸 종료 버그·캐시삭제 회피).
- `sync_all_repos`: 실패 집계(`fail=1`) + 동기화 0건이면 비0 반환.
- `handle_bootstrap`: `sync_all_repos`/`resolve_ops_dir`/`load_compose_files`/`generate_makefile` 각각 `|| return 1` 가드 → 실패 시 `[DONE]` 전에 abort, `BOOTSTRAP_DONE` 0 유지.

## 단위 시험 (`bash test/impl/3/run.sh`) — 9/9 PASS
| # | 결과 |
|---|---|
| 1 sync_all_repos 부분실패 → 비0 | ✅ |
| 2 전부성공 → 0 | ✅ |
| 3a handle_bootstrap 비0 반환 | ✅ |
| 3b BOOTSTRAP_DONE 0 유지 | ✅ |
| 4 status PENDING | ✅ |
| 5 전단계 성공 시 DONE | ✅ |
| 6 clone-fail 경로 die 미사용(return 1) | ✅ |

## 실제 재현 (로컬 유효 repo + 없는 원격)
`bootstrap rc=1 BOOTSTRAP_DONE=0 status=PENDING` — 수정 확인.

## 회귀 — impl/1=0, impl/2=0, verify.sh=0
