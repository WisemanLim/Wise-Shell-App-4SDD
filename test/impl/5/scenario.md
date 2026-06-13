# impl/5 시험 시나리오 — ops repo에 compose/Makefile 없을 때 처리

요구: bootstrap 시 ops repo에 docker-compose도 Makefile도 없으면 에러. 다음 처리 추가.
1. compose/Makefile 없으면 **직접 빌드·실행 방법 확인**(python hello.py, node package.json 등).
2. 1에서 방법이 있으면 **docker-compose 생성 → 그 파일 기준 Makefile 생성**.
3. (1·2와 별개) docker-compose가 있으면 **Makefile 먼저 확인**, 없으면 compose 기반 Makefile 생성.
결과: 직접 실행법 확인 불가 → dist-run 불가 안내 후 종료(bootstrap PENDING 유지). 자동 생성 시 → 자동생성 알림 + dist-run 가능.

실행: `bash test/impl/5/run.sh`(소스 단위, 네트워크 없음) + verify/impl1~4 회귀.

| # | Given (OPS_DIR) | When | Then |
|---|---|---|---|
| 1 | python: hello.py만 | `ensure_runnable_ops` | rc=0, AUTO=1, Dockerfile+compose+Makefile 생성, RUN_KIND=python |
| 2 | node: package.json(start) + index.js | `ensure_runnable_ops` | rc=0, AUTO=1, 생성됨, RUN_KIND=node, CMD npm start |
| 3 | 빈 repo(README만) | `ensure_runnable_ops` | rc≠0, "Cannot prepare", dist-run 불가 안내 |
| 4 | compose 존재, Makefile 없음 | `ensure_runnable_ops` | rc=0, AUTO=0, Makefile 생성, **Dockerfile 미생성** |
| 5 | Makefile 존재 | `ensure_runnable_ops` | rc=0, AUTO=0, "already present" 그대로 사용 |
| 6 | 생성된 Makefile | grep | `up` 타겟 존재(=dist-run 타겟 확보) |
| 7 | detect_run_method node 우선 | py+node 공존 | RUN_KIND=node (node 우선순위) |
| R | 회귀 | verify + impl1~4 | 모두 PASS |
