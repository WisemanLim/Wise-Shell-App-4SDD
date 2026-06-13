# impl/2 시험 결과 — 테마 기능

날짜: 2026-06-13 · 환경: macOS, bash 3.2.57 · 판정: **ALL PASS**

## 단위 시험 (`bash test/impl/2/run.sh`) — 21/21 PASS, exit 0

> 갱신: theme 캐시를 **전용 파일**(`/tmp/.wsa4sdd-theme-${UID}.cache`)로 분리. 세션 캐시 삭제(`cache_delete`, /exit·Ctrl+C·dist-run 성공)에도 theme는 보존되어 재실행 시 이전 값 사용, 재질문 없음(6c/6d 검증).
- 6 테마(dark/light/dark-daltonized/light-daltonized/dark-ansi/light-ansi) 적용 → THEME 갱신 + 색상 var 채워짐
- 무효명 → dark 폴백
- 라벨 매핑(Dark / colorblind-friendly / ANSI 16-color)
- `handle_theme <name>` 위치인자: 적용 + `_THEME_SET=1`, 무효명 "Unknown theme" 경고
- 캐시 왕복: `CACHE_THEME` 저장→리셋→로드 복원 + `_THEME_SET=1`
- 최초실행 게이트: `_THEME_SET=1`이면 `first_run_theme` 즉시 0 반환(프롬프트 없음)
- `/status`에 Theme 라인 표시
- 소스 등록 확인(디스패처 `/theme|/T`, 자동완성 `/theme`, help 라인)

## 회귀 — impl/1 exit 0, verify.sh exit 0

## 구현 노트
- ANSI 색상 블록을 `apply_theme()` 6 프리셋으로 전환. 의미색 매핑: GREEN=성공/선택, YELLOW=경고, RED=오류, CYAN=강조/프롬프트, WHITE=밝은 텍스트. C_BOLD/C_DIM/C_RST는 테마 불변.
- colorblind 변형: green↔red 혼동 회피 위해 success=blue(256), error=orange(256). ANSI 변형: 256/truecolor 미사용, 16색만.
- `/theme`,`/T`: 위치인자 또는 run_menu 선택. 선택 후 `theme_preview`로 색 스와치 출력.
- 최초 실행(캐시에 테마 없음) 시 `first_run_theme`로 선택 유도, `CACHE_THEME`로 영속(재실행 시 미질문).
- CLI 모드는 비대화형이라 first-run 프롬프트 미발생(run_tui_mode 한정).

## 미실행 (의도)
- `run_menu` 대화형 선택 경로는 TTY raw 모드 필요 → 단위시험서 제외. 위치인자 경로로 동등 로직 검증.
