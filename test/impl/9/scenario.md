# impl/9 시험 시나리오 — 서비스 역할 인식 + compose 연동 자동생성

요구: 자동생성 compose가 서비스를 개별 나열만 하지 말고, **역할(ops/frontend/backend/database/cli)** 과 연동을 고려해 작성.
- frontend → `environment: BACKEND_URL=http://<backend>:<port>` + `depends_on: backend` + 포트 publish
- backend → 포트 publish, database 있으면 `DATABASE_URL` + `depends_on: db`
- database → 5432
- cli → 포트/연동 없음
- host 포트는 충돌 시에만 증가(단일 backend는 8000 그대로, 8001 아님)

실행: `bash test/impl/9/run.sh`(소스 단위) + verify/impl1~8 회귀.

| # | Given | When | Then |
|---|---|---|---|
| 1 | node-frontend + python-backend(fastapi) | `ensure_runnable_ops` | frontend: BACKEND_URL+depends_on+3000, backend: 8000:8000(오프셋 없음) |
| 2 | 역할 분류 | `_classify_role` | frontend/backend/database/cli/ 정확 |
| 3 | frontend+api+database+cli | compose | frontend→api, api→database(DATABASE_URL), cli 포트 없음 |
| 4 | cli (hello.js / hello.py) | role | cli, 포트 없음 |
| 5 | 다중 backend | host 포트 | 8000, 8001 (충돌 회피) |
| 6 | backend만(db 없음) | compose | DATABASE_URL 없음 |
| R | 회귀 | verify + impl1~8 | 모두 PASS |
