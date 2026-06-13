# impl/9 시험 결과 — 서비스 역할 인식 + compose 연동 자동생성

날짜: 2026-06-13 · 환경: macOS, bash 3.2.57 · 판정: **ALL PASS**

## 구현 여부 재확인
- 기존: 자동생성 compose가 서비스를 **개별 나열만**(연동 없음, backend 포트가 +i 오프셋으로 8001). → **미흡**.
- 구현: 서비스 **역할 분류 + 연동**. frontend→backend(`BACKEND_URL`/`depends_on`), backend→database(`DATABASE_URL`/`depends_on`), 포트 publish, cli는 포트/연동 없음. host 포트는 충돌 시에만 증가.

## 단위 시험 (`bash test/impl/9/run.sh`) — 18/18 PASS
| 영역 | 결과 |
|---|---|
| 2 `_classify_role` frontend/backend/database/cli/api | ✅ (5) |
| 1 frontend↔backend 연동 + backend 8000:8000(오프셋 없음) | ✅ (5) |
| 3 frontend+api+database+cli 연동(DATABASE_URL, cli 포트 없음) | ✅ (4) |
| 4 cli 분류 | ✅ |
| 5 다중 backend host 포트 8000/8001(충돌 회피) | ✅ |
| 6 database 없으면 DATABASE_URL 없음 | ✅ |

## 회귀 — impl/1~8=0, verify.sh=0

## 구현 노트
- `RUN_APP_ROLE[]` + `_classify_role`(이름 키워드 + 신호: uvicorn→backend, node server→frontend, hello→cli, 포트→backend).
- 기본 포트: frontend 3000, backend 8000(uvicorn), database 5432. cli 없음.
- `generate_compose_from_apps`: backend/db 서비스 식별 후 역할별 `environment`/`depends_on` 작성. host 포트는 `used` 셋으로 충돌 회피(단일 backend=8000 그대로).
- 샘플(node-frontend + python-backend) 출력이 사용자가 제시한 기대 compose와 정확히 일치.
