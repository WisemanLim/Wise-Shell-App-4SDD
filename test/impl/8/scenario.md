# impl/8 시험 시나리오 — 여러 repo 스캔 → ops repo에 compose/Makefile 생성

요구: repo를 여러 개 지정한 경우, ops repo뿐 아니라 **등록된 모든 repo**에서 구동 가능한 앱을 확인하고,
ops repo에 docker-compose.yml / Makefile을 생성한다(다른 repo의 앱은 `../<repo>/...` 빌드컨텍스트로 참조).

실행: `bash test/impl/8/run.sh`(소스 단위) + verify/impl1~7 회귀.

| # | Given | When | Then |
|---|---|---|---|
| 1 | WS={ops(빈), svcA(python), svcB(node)}, SYNCED_NAMES=3, OPS_DIR=ops | `ensure_runnable_ops` | rc=0, AUTO=1, 2앱 탐지 |
| 2 | 1의 결과 | ops/docker-compose.yml | svcA·svcB 서비스 존재 |
| 3 | 1의 결과 | build 컨텍스트 | sibling repo 앱은 `../svcA/...`, `../svcB` |
| 4 | 1의 결과 | Dockerfile | 각 repo의 앱 디렉터리에 생성 |
| 5 | 서비스명 | grep | repo 접두로 충돌 없음(svca-python-cli, svcb) |
| 6 | ops repo 자체에도 앱 + 다른 repo 앱 | `ensure_runnable_ops` | ops 앱은 짧은 이름·`.`/상대경로, 타 repo는 `../` |
| 7 | SYNCED_NAMES 없음(폴백) | `detect_run_apps` | OPS_DIR만 스캔(기존 동작) |
| R | 회귀 | verify + impl1~7 | 모두 PASS |
