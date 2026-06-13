# impl/3 시험 시나리오 — bootstrap 단계 실패 시 [DONE] 금지

버그: clone 실패(`✗ Clone failed`)에도 `Bootstrap : [DONE]` 처리됨.
원인: `sync_repo`의 `die`가 `$()` 서브셸에서만 종료 → 메인 루프 계속 → `BOOTSTRAP_DONE=1` 도달.
수정: 실패를 return code로 전파, `sync_all_repos`가 비0 반환, `handle_bootstrap`가 각 단계 실패 시 `[DONE]` 전에 abort.

실행: `bash test/impl/3/run.sh`(stub로 네트워크 없이 제어흐름 검증) + verify.sh/impl1/impl2 회귀.

| # | Given | When | Then |
|---|---|---|---|
| 1 | sync_repo 한 개 실패(stub) | `sync_all_repos` (repo 2개) | 비0 반환 |
| 2 | sync_repo 전부 성공(stub) | `sync_all_repos` | 0 반환, SYNCED_NAMES 채워짐 |
| 3 | 한 repo clone 실패(stub), 나머지 stub 통과 | `handle_bootstrap` | 비0 반환 + `BOOTSTRAP_DONE=0` 유지 |
| 4 | 동일 상태 | `bootstrap_status_str` | `PENDING` (DONE 아님) |
| 5 | 전 단계 성공(stub) | `handle_bootstrap` | 0 반환 + `BOOTSTRAP_DONE=1` + `DONE` |
| 6 | clone 실패 경로 | `sync_repo` 소스 | `die` 미사용(서브셸 종료 버그 회피), `return 1` 사용 |
| R | 회귀 | verify.sh + impl1 + impl2 | 모두 PASS |
