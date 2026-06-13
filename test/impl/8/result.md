# impl/8 시험 결과 — 여러 repo 스캔 → ops repo에 compose/Makefile 생성

날짜: 2026-06-13 · 환경: macOS, bash 3.2.57 · 판정: **ALL PASS**

## 구현 여부 재확인
- 기존: `detect_run_apps`가 `OPS_DIR`(단일 ops repo)만 스캔 → **미구현**.
- 구현: 등록된 **모든 synced repo**를 스캔하도록 변경, ops repo에 compose/Makefile 생성, 타 repo 앱은 `../<repo>/...` 빌드컨텍스트로 참조.

## 단위 시험 (`bash test/impl/8/run.sh`) — 16/16 PASS
| 영역 | 결과 |
|---|---|
| 1 ops(빈)+svcA(py)+svcB(node) → 2앱 탐지, AUTO=1 | ✅ |
| 2 ops/docker-compose.yml에 svcA·svcB 서비스 | ✅ |
| 3 sibling repo 빌드컨텍스트 `../svcA/...`·`../svcB` | ✅ |
| 4 각 repo 앱 디렉터리에 Dockerfile | ✅ |
| 5 ops/Makefile 생성 + `make -n up` 파싱 | ✅ |
| 6 ops 앱 짧은 이름·상대경로, sibling 접두·`../` | ✅ |
| 7 SYNCED_NAMES 없으면 OPS_DIR만 스캔(폴백) | ✅ |

## 회귀 — impl/1~7=0, verify.sh=0

## 구현 노트
- `_scan_roots`: SYNCED_NAMES → `WORKSPACE_DIR/<repo>` 목록(없으면 OPS_DIR 폴백).
- `detect_run_apps`: 스캔 루트 전체를 순회. `_app_seen`/`_app_under`로 repo 간 중복·중첩 방지.
- `_app_name_from_dir`: ops repo 내부는 ops 상대경로(짧은 이름), 타 repo는 `<repo>/...`(워크스페이스 상대)로 접두 → 전역 고유.
- `_app_build_context`: ops 내부=상대경로, sibling=`../<repo>/...`, 그 외=절대. compose `build:`에 사용.
- bootstrap/CLI 모두 `sync_all_repos`(SYNCED_NAMES 채움) 후 `ensure_runnable_ops` 호출 → 다중 repo 스캔 자동 적용.
