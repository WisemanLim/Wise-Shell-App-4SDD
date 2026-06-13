# One-Page PRD: WSA4SDD App (Service Deployment and Distribution)

본 문서는 서비스 배포 및 배포 조율 도구인 **WSA4SDD App**의 기획 및 제품 요구사항(PRD) 문서입니다.
이 문서는 사용자의 요구사항과 서비스 배포/분배 도메인을 바탕으로 작성되었습니다.

---

## 1. 목적 및 배경 (Why)
- **문제 정의**: 기존의 마법사(Wizard)형 배포 도구들은 복잡한 단계가 고정되어 있어, 필요한 단계만 골라서 설정하거나 이전 설정을 변경하기가 까다로웠습니다.
- **해결 방안**: 대화형 에이전트 도구인 Claude Code와 유사한 TUI를 제공하여, 사용자가 명령어 입력 형식(`>    `)으로 원하는 배포 단계(레포지토리 설정, 워크스페이스 설정, 인증 설정 등)를 제어하고, 한눈에 상태를 확인하여 안전하고 직관적인 배포 프로세스를 구축할 수 있도록 합니다.

## 2. 대상 사용자 (Who)
- 개발 및 운영 환경에서 서비스를 배포하고 분배해야 하는 **DevOps 엔지니어 및 백엔드 개발자**.
- 원격 서버에서 간단히 `curl | bash` 형태로 다운로드 없이 배포 스크립트를 즉시 실행하고 싶은 시스템 운영자.

## 3. 핵심 기능 (What)

### A. Claude Code 스타일 TUI 화면
- 실행 시 시스템 상태와 사용 가능한 명령어 도움말을 표시합니다.
- 상단 설명 영역과 하단 명령 영역을 구분선(`───`)으로 나눕니다.
- 프롬프트는 `>    ` 형태를 제공합니다.

### B. 고급 REPL 라인 에디터 및 사용자 입력 편의 기능
- **명령어 히스토리**: `UP`/`DOWN` 방향키를 사용해 이전에 실행했던 명령어 기록(`.wsa4sdd_history`)을 조회하고 탐색할 수 있습니다.
- **커서 기반 인플레이스 편집**: `LEFT`/`RIGHT` 방향키로 입력줄 안에서 자유롭게 커서를 이동하며, Backspace 및 Delete 키로 편집할 수 있습니다.
- **자동완성 메뉴**: 빈 프롬프트에서 `/` 키를 누르면 사용할 수 있는 명령어 자동완성 드롭다운 메뉴가 나타나며, 방향키와 `Enter`로 자동 입력이 가능합니다.
- **외부 명령어 실행 (Shell Escape)**: `!`로 시작하는 명령어를 입력하면(예: `! pwd`), 대화형 세션이나 TUI 프롬프트를 탈출하지 않고 로컬 쉘 명령어를 실행하고 결과를 화면에 즉시 출력합니다.

### C. 명령어 기반 설정 관리 (Step to Command)
배포를 구성하는 각 단계를 명령어 형태로 개별 설정할 수 있습니다. 각 설정은 **실행 전까지 `[NOT SET]`**,
실행하면 선택/지정한 값으로 정의됩니다(상태 모델은 §G 참조).
- `/repo` 또는 `/R`: Git 저장소를 **1개 또는 여러 개** 등록. 0개이거나 등록된 URL이 모두 유효하지 않으면 `[NOT SET]`.
  유효 형식: `https://…/…`, `git@host:owner/repo`, `ssh://…`, 또는 존재하는 로컬 경로. 무효 URL은 등록 시 거부됩니다.
  **브랜치 지정**: `<url>#<branch>` 형태로 브랜치를 지정하면 해당 브랜치로 clone/pull 한다(미지정 시 기본/현재 브랜치).
  **다중 입력**: 한 번에 공백 또는 콤마로 구분해 여러 저장소를 입력할 수 있다(positional·대화형 Add 공통, 최대 8개).
- `/workspace` 또는 `/W`: 저장소를 clone할 워크스페이스 경로. **실행 전까지 `[NOT SET]`**이며,
  실행 시 **① 현재 경로(current) ② 상위 경로(parent) ③ 사용자 지정(custom path)** 3가지 중 선택/지정한 값으로 정의됩니다.
- `/auth` 또는 `/A`: GitHub 인증. **실행 전까지 `[NOT SET]`**이며, 실행 시 다음 **4가지** 중 선택/지정합니다 —
  **① gh login status**(현재 로그인 사용자 확인) **② gh auth switch**(계정 전환) **③ gh auth login**(신규 로그인) **④ PAT 등록**.
- `/bootstrap` 또는 `/B`: §G의 1~4(repo·workspace·auth)가 **모두 `[NOT SET]`이 아닐 때만** 진행 가능.
  진행 시 **시스템 환경 확인 모듈**(OS 감지 + 도구 존재 보고, 설치 안 함)과 **사전 설치 모듈**(누락 의존성 설치)을 거쳐
  레포 동기화 및 Makefile 생성. 하나라도 `[NOT SET]`이면 `[PENDING]`이며 실행을 거부하고 누락 항목을 안내합니다.
  **각 단계(저장소 동기화·ops 해석·Makefile 생성 등)에서 실패가 발생하면 `[DONE]`으로 처리하지 않고 즉시 중단하여 `[PENDING]`을 유지합니다.**
  - **ops repo 배포자산 준비(compose/Makefile)**:
    1. **Makefile이 있으면** 그대로 사용.
    2. **docker-compose가 있고 Makefile이 없으면** compose 기반으로 Makefile을 생성.
    3. **둘 다 없으면** 직접 빌드·실행 방법을 탐지한다(예: Python `hello.py`/`main.py`/`app.py`, Node `package.json`/엔트리). **하위의 모든 앱을 빠짐없이 탐지**하여(예: `apps/python-cli`, `apps/node-cli`, `apps/python-backend`, `apps/node-frontend`) **앱마다 Dockerfile + docker-compose 서비스 1개씩 생성**하고, 모든 서비스를 포괄하는 Makefile(전체 `up`/`down` + 앱별 `up-<name>`/`down-<name>`)을 생성한다. 그 뒤 "자동 생성됨"을 알리고 `/dist-run`을 실행할 수 있게 한다. 방법을 찾지 못하면 **`/dist-run`을 실행할 수 없는 구조임을 사용자에게 알리고 종료**(bootstrap `[PENDING]` 유지)한다.
       - Python 앱은 **매니페스트 디렉터리**(`pyproject.toml`/`requirements.txt`/`setup.py`)를 빌드컨텍스트로 삼아 의존성이 설치되도록 한다(엔트리가 `app/main.py`처럼 중첩돼도 부모 매니페스트 포함). FastAPI/uvicorn 의존이면 `uvicorn <module>:<app>` CMD + 포트 publish, 서버 의존성(fastapi/uvicorn) 설치를 보장한다.
       - **다중 repo 스캔**: repo를 여러 개 지정한 경우 ops repo뿐 아니라 **등록된 모든 repo**에서 구동 가능한 앱을 탐지한다. 생성물(docker-compose.yml·Makefile)은 **ops repo**에 두고, 다른 repo의 앱은 `../<repo>/...` 빌드컨텍스트로 참조한다(서비스명은 repo 접두로 충돌 방지).
       - **역할 인식 연동**: 각 서비스의 **역할(ops/frontend/backend/database/cli)** 을 이름·신호로 분류하여 compose를 단순 나열이 아닌 **연동된 구성**으로 작성한다.
         - frontend → `environment: BACKEND_URL=http://<backend>:<port>` + `depends_on: <backend>` + 포트(3000) publish
         - backend → 포트(8000) publish, database 존재 시 `DATABASE_URL` + `depends_on: <db>`
         - database → 5432, cli → 포트/연동 없음. host 포트는 충돌 시에만 증가(단일 backend=8000 유지).
- `/status` 또는 `/S`: 현재 설정 값과 누락(`[NOT SET]`) 여부, bootstrap 상태(`[PENDING]`/`[DONE]`), 적용된 테마를 표시.
- `/theme` 또는 `/T`: Claude CLI 스타일 **색상 테마** 전환. 6종 —
  `dark` / `light` / `dark-daltonized`(색약 친화) / `light-daltonized` / `dark-ansi`(16색) / `light-ansi`.
  인자 생략 시 선택 메뉴(현재 테마 기본 선택) + 색 스와치 미리보기. **최초 실행 시** 또는 `/theme`,`/T` 재설정 시 테마를 **전용 영속 캐시**(`/tmp/.wsa4sdd-theme-${UID}.cache`)에 저장한다.
  이후 `/theme`,`/T`로 재설정하지 않으면 이전 캐시 값을 그대로 사용하며, **세션 캐시 삭제(`/exit`·Ctrl+C 2회·dist-run 성공)에도 테마 캐시는 삭제하지 않는다.**
- `/dist-run` 또는 `/D`: 배포 실행. **bootstrap이 `[PENDING]`이면 자동 부트스트랩하지 않고**, `/bootstrap` 실행을 안내한 뒤
  bootstrap 외에 `[NOT SET]`인 항목 정보를 함께 출력하고 **아무것도 실행하지 않은 채 종료**합니다.
  `[DONE]`일 때만 Makefile 배포 타겟 메뉴를 띄워 실행합니다.
- `/exit` 또는 `/E`: 세션을 종료하고 캐시를 삭제합니다.
- `! <command>`: 대화형 REPL 모드 안에서 로컬 쉘 명령어를 즉시 실행합니다.

### G. 설정·부트스트랩 상태 모델 (NOT SET / PENDING / DONE)
- **설정 항목(1~4)**: ① 모듈 분리(시스템 환경 확인 / 사전 설치) ② repo ③ workspace ④ auth.
  ②~④는 값이 채워지기 전까지 `[NOT SET]`.
- **bootstrap(5)**: repo·workspace·auth가 **모두 `[NOT SET]`이 아닐 때만** 실행 가능하고, 실행 완료 시 `[DONE]`.
  하나라도 `[NOT SET]`이거나 아직 실행 전이면 `[PENDING]`. 설정이 바뀌면 `[DONE]`은 다시 `[PENDING]`으로 무효화됩니다.
- **dist-run(6)**: bootstrap이 `[DONE]`이 아니면 실행하지 않고 가이드 + `[NOT SET]` 정보만 출력합니다.

### H. 기본환경 일괄 구성 (`--default-env`) 및 CLI 인증 플래그 (`-a/--auth`)
원격/자동화에서 한 줄로 기본환경을 구성하기 위한 비대화 플래그.
- `-a, --auth <value>`: CLI 인증 지정. 값이 키워드 `gh|pat|none`이면 인증 방식, 그 외 문자열이면 **PAT 토큰**으로 직접 운반(방식=pat). `-a`/`--auth` 양형 지원.
- `--default-env`: 비대화(CLI) 모드로 기본환경을 구성한다.
  1. **`-I/--input`(repo) 필수** — 없으면 에러 출력 후 종료.
  2. **workspace = 현재 경로(PWD)**, **ops repo = 첫 번째 repo 이름**으로 자동 지정.
  3. **`-a/--auth` 필수**, 기본 방식 `pat`, **토큰 값을 반드시 받아야 실행**. 값이 없으면(또는 `pat`만 주고 토큰 누락) 에러 출력 후 종료.
- 보안: `-a <token>`는 토큰이 프로세스 인자(argv)에 노출되므로 자동화/데모 편의용. 운영 시 셸 히스토리·CI 시크릿 마스킹에 유의.

### D. 실행 검증 및 배포 (`/dist-run`)
- 필수값(저장소 목록, 워크스페이스 경로 등)이 모두 지정되었는지 확인합니다.
- 누락된 값이 있다면 설정할 수 있는 알맞은 명령어(예: "Missing workspace. Run `/workspace`")를 출력하여 안내합니다.
- 필수값이 모두 채워졌을 경우, bootstrap 과정을 거쳐 Makefile 타겟 메뉴를 띄고 사용자가 선택하여 실행할 수 있도록 합니다.

### E. 입력 값 세션 캐시 (Cache)
- 각각의 명령어로 입력된 값은 캐시 파일(`/tmp/.wsa4sdd-${UID}.cache`)로 보존됩니다.
- 프로세스가 비정상 종료되거나 재부팅되더라도 캐시가 자동으로 복구 및 로드됩니다.
- 배포가 완료(`dist-run` 성공)되거나, 사용자가 `/exit` 혹은 `Ctrl+C` 2회 연속 입력하여 명시적으로 종료할 경우 캐시를 완벽하게 삭제합니다.

### F. 원격 실행 및 다운로드 실행 지원
- GitHub Public 저장소에 업로드되어 `curl -fsSL <URL> | bash -s -- -I "URL" --no-run`과 같은 형태로 배포 자동화 파이프라인에서 원격 다이렉트 실행이 가능해야 합니다.
- CLI 인자(argument)가 주어지면 대화형 TUI를 띄우지 않고 논인터랙티브(CLI) 모드로 자동 실행하는 하이브리드 모드를 지원합니다.

---

## 4. 기술 스택 및 제약사항 (How)
- **언어**: pure Bash (`#!/usr/bin/env bash`)
- **이식성**: **macOS 기본 Bash 3.2** 버전 및 최신 Linux 환경(Debian, RHEL, Arch 등)의 표준 유틸리티들(git, curl, docker, make 등)과의 완전한 호환성을 보장해야 합니다.
- **제약 조건**: Bash 3.2의 한계로 인해 `local -n` (참조 변수 / nameref)이나 associative arrays (`declare -A`) 등의 기능을 사용하지 않고 순수 Bash 3.2 문법으로 구현해야 합니다.
- **가정**: 
  - *가정 1*: 사용자가 `Ctrl+C`를 1회 입력 시 "종료를 원하면 2초 이내에 한번 더 입력하거나 /exit를 입력하세요"와 같은 안내를 표시하고, 2초 이내에 2번째 `Ctrl+C` 입력 시 캐시를 삭제하고 즉시 세션을 종료합니다.
  - *가정 2*: `/dist-run` 진행 도중 pre-run 명령어 입력 단계를 제공하며, pre-run 및 make 실행 도중 에러가 나면 캐시를 지우지 않고 복구를 시도할 수 있도록 상태를 유지합니다.
  - *가정 3*: TUI 환경은 ANSI Escape Sequence를 이용해 화면 전환 및 입력을 제어하며, TTY가 없는 논인터랙티브 환경(`! -t 0`)이나 인자(`-I` 등)가 주어진 경우에는 TUI 모드를 생략하고 CLI 모드로 동작합니다.

---

## 5. 성공 지표 (Success)
- **TUI 사용성**: TUI 모드에서 단 한 번의 오작동 없이 사용자 명령어 입력을 정확히 처리하고 화면 출력을 실시간으로 갱신하는가?
- **호환성**: macOS 기본 터미널(`/bin/bash`)에서 구문 에러 없이 정상적으로 입출력 및 방향키 조작이 가능한가?
- **캐시 라이프사이클**: 정상 종료 및 배포 완료 시 임시 캐시 파일이 온전히 삭제되는가? 오동작이나 강제 중단 시 설정 정보가 제대로 유지되는가?
- **원격 동작 신뢰성**: `curl`을 통한 일회성 원격 실행 시 파이프라인 중단 없이 `--no-run`을 포함한 매개변수가 정확히 전달되고 동작을 완료하는가?

---

## 6. 요구사항 반영 현황 및 미반영 내용 (Implementation Status & Unimplemented Requirements)
- **미반영 요구사항**: 없음 (모든 요구사항이 성공적으로 구현되었으며, `verify.sh` 테스트를 통과함)
- **반영 완료 요구사항**:
  - Claude Code 스타일 TUI 및 REPL 프롬프트 제공
  - 명령어 히스토리 (UP/DOWN 방향키 및 `/tmp/.wsa4sdd_history` 캐싱)
  - 인플레이스 커서 편집 (LEFT/RIGHT, Backspace, Delete 지원)
  - `/` 입력 시 명령어 자동완성 팝업 메뉴 및 화살표/Enter 선택 지원 (자동완성 상태에서도 계속적인 키 입력 지원)
  - GitHub Private 저장소 연동 가이드 문서화 (HTTPS/SSH 주소 복사 및 PAT 발급법 포함)
  - 외부 명령어 실행 기능 (`! <command>` 입력 시 로컬 쉘 명령 실행 및 출력)
  - 세션 캐시 관리 (`/tmp/.wsa4sdd-${UID}.cache` 복구 및 종료 시 삭제) 및 Ctrl+C 2회 입력 시 캐시 삭제 후 종료
  - 무결성 검증용 `./verify.sh` 자동화 테스트 구현
- **v1.1.0 추가 반영 (§C·§G)**:
  - (1) 모듈 분리 — `system_env_check`(설치 없는 환경 확인) / `pre_install_deps`(의존성 설치) 분리
  - (2) repo 1개+ 등록 및 유효성 검증, 0개/무효 시 `[NOT SET]`
  - (3) workspace 실행 시 current/parent/custom 3택, 실행 전 `[NOT SET]`
  - (4) auth 4택 — gh login status / gh auth switch / gh auth login / PAT 등록, 실행 전 `[NOT SET]`
  - (5) bootstrap 파생 상태 — repo·workspace·auth 모두 set일 때만 진행, 아니면 `[PENDING]`(설정 변경 시 무효화)
  - (6) dist-run 게이트 — `[PENDING]`이면 자동 부트스트랩 없이 가이드 + `[NOT SET]` 정보 출력 후 미실행
  - 시험: `test/impl/1/run.sh`(상태 로직 23 단위검증) + `./verify.sh`(회귀 4) 모두 PASS
- **v1.1.0 테마(§C `/theme`)**:
  - Claude CLI 스타일 6 테마(dark/light/dark·light-daltonized/dark·light-ansi) + `apply_theme` 의미색 매핑
  - `/theme`,`/T` 전환(위치인자 또는 메뉴) + 색 스와치 미리보기, 최초 실행 선택 유도
  - `CACHE_THEME`로 영속(재실행 시 미질문), `/status`에 현재 테마 표시
  - 시험: `test/impl/2/run.sh` 19 단위검증 PASS
- **v1.1.0 기본환경(§H `--default-env`, `-a/--auth`)**:
  - `-a, --auth <value>` CLI 인증(키워드 method 또는 PAT 토큰 직접 운반), `set_pat_credentials` 공용 헬퍼
  - `--default-env`: repos 필수 + workspace=PWD + ops=첫 repo + auth(-a) 필수·기본 pat·토큰값 필수, 누락 시 에러+종료
  - 시험: `test/impl/4/run.sh` 15 검증 PASS
- **v1.1.0 다중 repo 앱 스캔(§C `/bootstrap`)**:
  - 등록된 모든 repo를 스캔(`_scan_roots`)해 앱 탐지, ops repo에 compose/Makefile 생성, 타 repo 앱은 `../<repo>/...` 컨텍스트
  - 서비스명 repo 접두로 전역 고유(`_app_name_from_dir`), 빌드컨텍스트 `_app_build_context`
  - 시험: `test/impl/8/run.sh` 16 검증 PASS
- **v1.1.0 역할 인식 연동(§C `/bootstrap`)**:
  - `RUN_APP_ROLE`+`_classify_role`로 frontend/backend/database/cli 분류, compose에 `BACKEND_URL`/`DATABASE_URL`/`depends_on`/포트 자동 작성, host 포트 충돌 회피
  - 시험: `test/impl/9/run.sh` 18 검증 PASS
  - 버그수정: bootstrap 단계 실패 시 `[DONE]` 금지(`test/impl/3` 9 검증)
- **v1.1.0 ops 배포자산 자동구성(§C `/bootstrap`)**:
  - compose/Makefile 부재 시 직접 실행법 탐지(python/node) → compose(+Dockerfile)·Makefile 자동생성, 불가 시 dist-run 불가 안내+종료
  - `detect_run_method`·`generate_compose_from_project`·`ensure_runnable_ops` 추가, bootstrap/CLI 공용
  - 시험: `test/impl/5/run.sh` 21 검증 PASS
- **v1.1.0 /repo 브랜치·다중입력(§C `/repo`)**:
  - repo 스펙 `<url>#<branch>` — 브랜치별 clone(`-b`)/pull(`checkout`+`pull origin <branch>`), `repo_url_part`/`repo_branch_part` 헬퍼
  - 다중 입력 공백/콤마 구분(positional·대화형 Add), `is_valid_repo_url`/`repo_name_from_url` 브랜치 인식
  - 시험: `test/impl/6/run.sh` 14 검증 PASS(로컬 repo 브랜치 clone/switch 포함)
