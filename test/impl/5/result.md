# impl/5 시험 결과 — compose/Makefile 부재 시 자동 구성 또는 거부

날짜: 2026-06-13 · 환경: macOS, bash 3.2.57 · 판정: **ALL PASS**

## 단위 시험 (`bash test/impl/5/run.sh`) — 31/31 PASS

> 갱신: 단일 앱 탐지 → **다중 앱 탐지**로 개선. ops repo 내 모든 python/node 앱을 찾아 compose 서비스 1개씩 생성, 누락 없음.
> 테스트 8: 4앱 repo(`apps/python-cli`·`node-cli`·`python-backend/app`·`node-frontend`) → 4 서비스 + 앱별 Dockerfile + `make -n up` 파싱 + 앱별 `up-*` 타겟 검증.
| 영역 | 결과 |
|---|---|
| 1 python(hello.py) → Dockerfile+compose+Makefile 자동생성, AUTO=1 | ✅ (7) |
| 2 node(package.json start) → 자동생성, CMD npm start | ✅ (4) |
| 3 빈 repo → rc≠0 + "Cannot prepare a deployment" | ✅ (2) |
| 4 compose 존재·Makefile 없음 → Makefile만 생성(Dockerfile 미생성), AUTO=0 | ✅ (4) |
| 5 Makefile 존재 → "already present" 그대로 사용 | ✅ (2) |
| 6 생성 Makefile에 `up` 타겟 존재 | ✅ |
| 7 py+node 공존 → node 우선 | ✅ |

## 회귀 — impl/1·2·3·4=0, verify.sh=0
(impl/3 stub을 `ensure_runnable_ops`로 갱신 — bootstrap 흐름이 load/generate → ensure_runnable_ops로 변경됨에 맞춤)

## 구현
- `detect_run_method`: node(package.json, 최단경로) 우선 → python(hello.py/main.py/app.py). RUN_KIND/RUN_ENTRY/RUN_DIR 설정.
- `generate_compose_from_project`: RUN_KIND별 Dockerfile + 루트 docker-compose.yml(`build: <rel>`) 생성.
- `ensure_runnable_ops` 결정 흐름:
  1. Makefile 있으면 그대로 사용.
  2. compose 있으면(Makefile 없음) compose 기반 Makefile 생성(Dockerfile 미생성).
  3. 둘 다 없으면 직접 실행법 탐지 → 있으면 compose+Makefile 자동생성(AUTO_GENERATED=1), 없으면 rc≠0(거부).
- `handle_bootstrap`/`run_cli_mode`가 `ensure_runnable_ops` 사용. 거부 시 bootstrap은 `[PENDING]` 유지(dist-run 게이트가 차단). 자동생성 시 사용자에게 "auto-generated → run /dist-run" 안내.

## 추가 버그 수정 — 생성 Makefile `missing separator` (line 8)
- 증상: `make up` → `Makefile:8: *** missing separator. Stop.`
- 원인: `generate_makefile`의 `help` 레시피를 `echo -e "\t…"`로 출력 → awk 문자열 안의 `\\n`(리터럴 `\n` 의도)을 `echo -e`가 **실제 개행**으로 해석 → 레시피가 2줄로 쪼개져 8번째 줄에 탭 없는 연속행 발생. verify.sh가 `--no-run`이라 make를 실제 실행 안 해 미검출.
- 수정: 레시피 출력을 실제 탭 변수(`TAB=$'\t'`) + 평범한 `echo`(`-e` 제거)로 변경 → 탭은 진짜 탭, `\n`은 리터럴 유지.
- 가드 추가: impl/5 6b/6c가 `make -n up`/`make -n help`로 **실제 파싱**을 검증(탭 깨짐 재발 방지).

## 회귀 버그(이전) 동시 수정
- `generate_makefile`이 compose 0건일 때 `return`(=비0)이라 직전 구현의 abort 가드에 오검출되던 문제 → `ensure_runnable_ops`가 compose 유무를 먼저 분기하므로 해소.
