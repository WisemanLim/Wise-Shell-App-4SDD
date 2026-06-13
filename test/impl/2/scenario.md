# impl/2 시험 시나리오 — 테마 기능 (Claude-CLI 스타일)

대상: wsa4sdd.sh `/theme`,`/T` + 최초 실행 선택 + 캐시 영속. 6 테마.
실행: `bash test/impl/2/run.sh` (source 단위) + `./verify.sh`(회귀) + `bash test/impl/1/run.sh`(회귀).

| # | 항목 | Given | When | Then |
|---|---|---|---|---|
| 1 | 6 테마 적용 | 소스 | `apply_theme <each>` | THEME 갱신, 색상 var 비어있지 않음 |
| 2 | 폴백 | 무효명 `bogus` | `apply_theme bogus` | THEME=dark |
| 3 | 라벨 | — | `theme_label` | dark→Dark, *-daltonized→colorblind-friendly, *-ansi→ANSI 16-color |
| 4 | 위치인자 | `handle_theme light` | — | THEME=light, `_THEME_SET=1`, 0 반환 |
| 5 | 위치인자 무효 | `handle_theme nope` | — | "Unknown theme" 출력 |
| 6 | 캐시 왕복 | THEME=dark-ansi, cache_save | 리셋 후 cache_load | THEME=dark-ansi 복원 + `_THEME_SET=1` |
| 7 | 최초실행 게이트 | `_THEME_SET=1` | `first_run_theme` | 즉시 0 반환(프롬프트 없음) |
| 8 | status | 테마 설정 | `handle_status` | "Theme :" 라인 표시 |
| 9 | 등록 | 소스 | grep | 디스패처 `/theme|/T`, 자동완성 `/theme`, help 라인 존재 |
| R | 회귀 | — | verify.sh + impl/1 | 모두 PASS |
