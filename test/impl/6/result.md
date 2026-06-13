# impl/6 시험 결과 — /repo 브랜치 지정 + 다중 입력

날짜: 2026-06-13 · 환경: macOS, bash 3.2.57, git · 판정: **ALL PASS**

## 단위/통합 시험 (`bash test/impl/6/run.sh`) — 14/14 PASS
| 영역 | 결과 |
|---|---|
| 1~3 스펙 파싱(`repo_url_part`/`repo_branch_part`/`repo_name_from_url`) | ✅ |
| 4~5 `is_valid_repo_url` 브랜치 허용 / bogus 거부 | ✅ |
| 6 positional 다중 입력(콤마+공백) 3스펙 + `#branch` 보존 | ✅ |
| 7 로컬 repo `src#dev` → dev 브랜치로 clone(devfile 존재) | ✅ |
| 8 `src#main` 재sync → main으로 checkout+pull | ✅ |
| 9 welcome/help `url[#branch]` 안내 | ✅ |

## 회귀 — impl/1~5=0, verify.sh=0

## 구현
- repo "스펙" = `<url>` 또는 `<url>#<branch>`. 구분자 `#`(SSH `git@host:`의 `@`와 비충돌).
- `repo_url_part`/`repo_branch_part` 헬퍼. `repo_name_from_url`·`is_valid_repo_url`가 URL부만 사용(브랜치 무시/허용).
- `sync_repo`: 브랜치 있으면 clone `-b <branch>`, 기존 repo는 `checkout <branch>` 후 `pull --ff-only origin <branch>`. 없으면 현재 브랜치 유지(기존 동작).
- 다중 입력: positional은 콤마→공백 정규화 후 분할, interactive Add는 한 줄에 공백/콤마로 여러 스펙 입력 가능(각 검증, 최대 8 유지).
- `INPUT_REPOS`에 스펙(브랜치 포함) 저장 → 캐시·status에 그대로 표시.

## 비고
- 브랜치 구분자 `#`는 URL 프래그먼트와 형태가 같아 직관적이고, 기존 SSH/HTTPS URL과 충돌하지 않음.
