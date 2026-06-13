# impl/4 시험 결과 — --default-env 기본환경 + -a/--auth

날짜: 2026-06-13 · 환경: macOS, bash 3.2.57 · 판정: **ALL PASS**

## 단위/통합 시험 (`bash test/impl/4/run.sh`) — 15/15 PASS
| # | 결과 |
|---|---|
| 1 `--default-env` -I 없음 → rc≠0 + "repositories are required" | ✅ |
| 2 -a 없음 → rc≠0 + "-a/--auth is required" | ✅ |
| 3 `-a pat`(토큰 없음) → rc≠0 + "PAT value is required" | ✅ |
| 4 positive dry-run: rc=0, ws=cwd, ops=첫repo(src), auth=pat, cwd로 clone | ✅ (5) |
| 5 `-a gh` → method gh | ✅ |
| 6 `-a <token>` → pat + GITHUB_PAT=token | ✅ |
| 7 help에 `--default-env`, `-a, --auth` 노출 | ✅ |

## 회귀 — impl/1=0, impl/2=0, impl/3=0, verify.sh=0

## 구현 노트
- 신규 플래그 `-a, --auth <value>` + `--default-env`.
- `-a` 값 해석: 키워드 `gh|none|pat` = method, 그 외 문자열 = PAT 토큰 직접 운반(method=pat). `-a`/`--auth` 양형.
- `--default-env`: `force_cli=1`(비대화), repos 필수, `WORKSPACE_DIR=PWD`, `OPS_NAME=repo_name_from_url(첫 repo)`, auth(-a) 필수·기본 pat·토큰값 필수. 누락 시 `die`(에러+종료).
- `set_pat_credentials()` 헬퍼 추출 — CLI `-a` 토큰 경로와 대화형 `auth_pat_register` 공용.

## 보안 메모
- `-a <token>`는 argv에 토큰이 노출됨(ps/히스토리). 데모/자동화 편의 위주 설계(사용자 요청). 운영 시 셸 히스토리 무시 접두 공백·CI 시크릿 마스킹 권장.
