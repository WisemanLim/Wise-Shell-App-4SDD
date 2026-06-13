# WSA4SDD (Wise Shell App for Service Deployment & Distribution)

WSA4SDD(Wise Shell App)는 터미널 안에서 명령어로 분산 다중 저장소 서비스를 수집하고 Docker Compose 프로젝트의 수명주기를 조율하는 **Claude Code 스타일 대화형 배포 및 배포 쉘**입니다.

기존의 단순 마법사형 스크립트(`dist-ss-tui.sh` 등)의 경직된 환경을 개선하여, 사용자가 원하는 순서대로 명령어를 통해 변수를 설정하고 환경을 검증하며, 최종적으로 Docker Compose 배포 명령을 안전하게 내릴 수 있는 유연한 TUI REPL을 제공합니다.

또한, CLI 인수 파싱과 논인터랙티브 파이프라인 대응 기능을 포함하여 `curl -fsSL ... | bash`를 통한 원격 완전 자동 배포도 동일하게 지원합니다.

---

## 1. 주요 특징 (Core Features)

### A. Claude Code 스타일 TUI & REPL
- 실행 시 시스템 상태와 명령어 도움말을 직관적으로 설명하는 웰컴 헤더와 구분선(`───`)을 제공합니다.
- 자체 구현된 고급 라인 에디터 REPL 프롬프트 영역(`>    `)을 제공합니다.
  - **입력 히스토리**: 위/아래 화살표 키를 통해 이전 실행한 명령어 기록(세션 파일 `/tmp/.wsa4sdd_history` 연동)을 탐색하고 다시 불러옵니다.
  - **입력 편집**: 좌/우 화살표 키로 실시간 커서 이동이 가능하며, Backspace 및 Delete 키를 통한 자연스러운 글자 삽입 및 삭제를 지원합니다.
  - **자동완성 팝오버**: 빈 입력창 상태에서 `/` 키를 입력하면 선택 가능한 명령어 리스트가 화면 하단에 드롭다운 형태로 팝업되어 위/아래 키와 `Enter`로 손쉽게 자동 완성할 수 있습니다.
- TTY가 없는 자동화 파이프라인(`! -t 0`) 또는 CLI 인수 설정 시 대화형 TUI를 건너뛰고 direct CLI 모드로 실행됩니다.

### B. 명령어 기반 개별 단계 관리
배포의 흐름을 대화형 쉘 안에서 각각 제어할 수 있습니다.
- `/repo [repo1 repo2...]`, `/R [repo1 repo2...]`: 배포할 Git 저장소 URL 목록을 인자로 직접 전달하여 일괄 설정하거나, 인자를 생략할 경우 대화형 Repository Manager(추가, 삭제, 화살표 키 순서 정렬)를 기동합니다.
- `/workspace [path]`, `/W [path]`: 레포지토리를 복제할 워크스페이스 디렉터리 경로를 인자로 즉시 설정하거나, 인자를 생략할 경우 TUI 팝업 메뉴(Current, Parent, Custom)를 통해 선택합니다.
- `/auth [gh|pat|none]`, `/A [gh|pat|none]`: 사용할 GitHub 인증 방식(`gh` CLI 로그인, `pat` 토큰 방식, `none` 공개 저장소 전용)을 설정하며, 인자를 생략하면 선택 TUI 메뉴가 팝업됩니다.
- `/bootstrap`, `/B`: 의존성 자동 확인(git, gh, docker, make), 레포지토리 동기화, Makefile 생성 등 시스템 사전 구축.
- `/status`, `/S`: 현재 누적 설정값 및 필수값의 누락 현황 검사.
- `/dist-run`, `/D`: 구성 정합성 검증 후 pre-run 명령어 실행 및 Makefile 타겟 선택 메뉴 구동.
- `/help`, `/H`: 사용 설명 및 도움말 호출.
- `/exit`, `/E`: 프로그램 세션 종료 및 세션 캐시 전체 삭제.
- `! <command>`: 대화형 REPL 모드에서 로컬 쉘 명령어(예: `! pwd`, `! ls -la`)를 즉시 실행하고 결과를 출력합니다.

### C. 대화형 저장소 순서 변경 및 관리 (Interactive Reordering)
- `/repo` 명령을 인수 없이 실행하면 대화형 **Repository Manager**가 구동됩니다.
- 레포지토리를 **추가(Add)**하거나, 선택하여 **삭제(Delete)**할 수 있습니다.
- 특히 **Reorder** 기능을 선택하면 터미널 상에서 방향키(`UP`/`DOWN` 또는 `k`/`j`)를 이용해 선택한 저장소의 동기화 및 조율 순서를 물리적으로 바꿀 수 있으며, `Enter` 키로 그 자리에서 락(Lock)을 걸어 순서를 변경합니다.

### D. 지능적 세션 캐시 (Session Cache)
- 명령어 입력으로 설정된 변수들은 `/tmp/.wsa4sdd-${UID}.cache` 파일로 매번 직렬화되어 보관됩니다.
- 도중에 연결이 끊어지거나 임의 종료되더라도, 재기동 시 세션 상태가 고스란히 복원됩니다.
- 배포가 완전히 끝났거나(`/dist-run` 정상 종료), 사용자가 `/exit` 또는 2회 연속 `Ctrl+C`를 눌러 명시적으로 종료할 경우에는 캐시를 완벽히 소거하여 임시 파일을 남기지 않습니다.

---

## 2. TUI 구성 및 레이아웃 (Layout & Commands)

실행 시 터미널 화면에 아래와 같이 구성된 웰컴 안내가 출력됩니다.

```
  WSA4SDD App (v1.0.0) — Service Deployment and Distribution Shell
  Lives in your terminal, manages git repos, and deploys docker-compose.
  ─────────────────────────────────────────────────────────────────────────────
  Commands:
    /repo, /R           Configure repository URLs to deploy
    /workspace, /W      Configure target workspace directory path
    /auth, /A           Configure GitHub credentials (gh, pat, none)
    /bootstrap, /B      Verify dependencies and sync git repositories
    /status, /S         Show current configuration status
    /dist-run, /D       Verify configurations and run make deployment
    /help, /H           Show this help message
    /exit, /E           Exit wsa4sdd shell and clear cache
    ! <command>         Execute a shell command and display the output
  ─────────────────────────────────────────────────────────────────────────────

>    
```

### 상세 명령어 가이드

#### 1. 저장소 구성 (`/repo`, `/R`)
- **CLI direct**: `/repo <url1> <url2>` 형태로 입력 시 해당 목록으로 덮어씁니다.
- **TUI interactive**: `/repo`만 입력 시 인터랙티브 관리 메뉴가 동작합니다.
  - `Add Repository`를 통해 추가, `Delete`를 통해 삭제가 가능합니다.
  - `Change Order`를 실행한 뒤, 원하는 저장소를 선택하고 방향키를 눌러 위아래 순서를 섞을 수 있습니다.

#### 2. 워크스페이스 디렉터리 (`/workspace`, `/W`)
- **CLI direct**: `/workspace /path/to/dir`
- **TUI interactive**: `/workspace`만 입력 시 `현재 디렉터리(./)`, `상위 디렉터리(../)`, `사용자 정의 입력(Custom path...)` 메뉴가 팝업됩니다.

#### 3. 인증 방식 (`/auth`, `/A`)
- **CLI direct**: `/auth <gh|pat|none>`
- **TUI interactive**: `/auth` 입력 시 인증 프로토콜 선택 메뉴가 뜨며, `pat` 선택 시 Username과 Access Token 입력을 순차적으로 요구합니다. (입력한 토큰은 임시 파일에 안전하게 은닉 저장되며, 프로세스 종료 시 자동 삭제됩니다.)

#### 4. 배포 실행 (`/dist-run`, `/D`)
- 설정된 값들이 온전한지 검증합니다. 누락된 필수 변수가 있는 경우 설정 가능한 명령어를 가이드합니다.
- 동기화(Sync)가 되지 않은 상태라면 즉시 `/bootstrap`을 내부에서 자동 유발합니다.
- Makefile에 존재하는 배포 타겟 목록(`up-*` 등)을 수집하여 동적인 TUI 화살표 선택 메뉴로 제공합니다.
- pre-run 명령어 입력 단계를 거쳐 `make <target>`을 실행하고, 실행 완료 시 캐시를 삭제하고 종료됩니다.

---

## 3. 원격 직접 실행 및 설치 방법 (Execution & Installation)

### A. 원격 직접 실행 (curl | bash)
CI/CD 파이프라인이나 일회성 배포 환경에서 파일 다운로드 없이 원격 주소의 스크립트를 즉시 실행할 수 있습니다. 
기본적으로 인수(argument)를 전달하여 기동이 가능하며, 대화형 TUI 모드로 기동하거나 비대화형 CLI 모드로 실행하도록 매개변수를 조정할 수 있습니다.

```bash
# 1) 원격 TUI 모드 실행 (인수 사전 입력 + 대화형 REPL 기동)
curl -fsSL https://raw.githubusercontent.com/WisemanLim/Wise-Shell-App-4SDD/refs/heads/main/wsa4sdd.sh \
  | bash -s -- -I "https://github.com/ClaroPessoas/claro-svc" -w "~/workspace"

# 2) 원격 비대화형 CLI 모드 실행 (자동 배포 실행)
curl -fsSL https://raw.githubusercontent.com/WisemanLim/Wise-Shell-App-4SDD/refs/heads/main/wsa4sdd.sh \
  | bash -s -- -I "https://github.com/ClaroPessoas/claro-svc" --cli

# 3) 원격 비대화형 CLI 드라이런 실행 (배포 없이 구성/동기화만 수행)
curl -fsSL https://raw.githubusercontent.com/WisemanLim/Wise-Shell-App-4SDD/refs/heads/main/wsa4sdd.sh \
  | bash -s -- -I "https://github.com/ClaroPessoas/claro-svc" --no-run
```

---

### B. 스크립트 다운로드 및 설치 (Download & Local Install)
스크립트를 로컬 시스템에 직접 내려받아 영구 설치하여 명령어로 사용하고 싶은 경우 아래 순서대로 수행합니다.

1. **스크립트 다운로드 및 실행 권한 부여**:
   ```bash
   curl -fsSL -o wsa4sdd.sh https://raw.githubusercontent.com/WisemanLim/Wise-Shell-App-4SDD/refs/heads/main/wsa4sdd.sh
   chmod +x wsa4sdd.sh
   ```

2. **시스템 경로(PATH)에 등록하여 글로벌 실행 (선택 사항)**:
   ```bash
   # /usr/local/bin 또는 사용자 환경의 PATH 경로로 파일 이동
   sudo mv wsa4sdd.sh /usr/local/bin/wsa4sdd
   ```

3. **로컬 실행 및 파라미터 전달 예시**:
   ```bash
   # 단독 실행 (기본 TUI 모드 기동)
   wsa4sdd
   
   # 사전 설정을 주입한 대화형 TUI 모드 기동
   wsa4sdd -I "https://github.com/ClaroPessoas/claro-svc" -w "~/workspace"
   
   # 비대화형 CLI 모드로 즉시 자동 배포 실행
   wsa4sdd -I "https://github.com/ClaroPessoas/claro-svc" --cli
   
   # 비대화형 CLI 모드로 빌드/동기화 드라이런만 실행 (배포 생략)
   wsa4sdd -I "https://github.com/ClaroPessoas/claro-svc" --no-run
   ```


### CLI Options

| 옵션 | 설명 | 예시 |
| :--- | :--- | :--- |
| `-I, --input` | 공백으로 분리된 깃 저장소 URL 목록. | `-I "url1 url2"` |
| `-w, --workspace` | 저장소들을 클론할 타겟 디렉터리. | `-w ~/dev/workspace` |
| `-o, --ops` | Makefile 및 Compose 환경을 내장한 메인 조율 저장소 명칭. | `-o my-ops-repo` |
| `--no-run` | 저장소 동기화와 도구 빌드(Makefile 생성 등)까지만 수행하고 실제 배포 타겟 선택 및 실행 단계를 건너뜁니다. | `--no-run` |
| `-h, --help` | 도움말을 출력합니다. | `-h` |

---

## 4. 자가 진단 및 검증 (Tests)

패키지 내부에는 배포 쉘의 동작 무결성을 자동 검증하기 위한 테스트 스크립트 [verify.sh](verify.sh)가 포함되어 있습니다.

```bash
# 로컬 테스트 모음 실행
./verify.sh
```

`verify.sh`는 아래 항목들을 연속적으로 모의 실행(Dry-run)하여 테스트합니다:
1. `wsa4sdd.sh` 파일의 권한 및 `--help` 출력 형태 체크.
2. CLI 다이렉트 모드 구동 시 필수값 부재에 따른 실패 분기 확인.
3. 소스코드 내부 세션 캐시 제어 함수의 정상 적재 검증.
4. 임시 Git 레포지토리 및 Compose 구조 생성 후, CLI direct 모드를 통한 클론-빌드-Makefile 생성 파이프라인의 Dry-run 검증.

---

## 5. 호환성 및 제약사항 (Compatibility)

- **macOS Native 완벽 호환**: macOS의 기본 시스템 쉘은 `/bin/bash` 3.2.x 버전입니다. `wsa4sdd.sh`는 Bash 4.x+ 전용 기능(예: `local -n` 레퍼런스 지시어, Associative Arrays `declare -A` 등)을 배제하고 순수 Bash 3.2 호환 문법으로 설계 및 구현되었습니다.
- **의존성 자동 확인**: TUI 진입 또는 `/bootstrap` 과정에서 `git`, `docker`, `docker compose`, `make` 등의 의존 도구가 현재 시스템에 정상 설치되어 있는지 자동으로 감지하고 미비 시 알림을 줍니다.

---

## 6. GitHub Private 저장소 연동 가이드

Private 저장소를 안전하게 동기화하고 배포하기 위해서는 올바른 Git 주소 형식과 인증 설정이 필요합니다. 아래 가이드를 참고하여 설정해 주세요.

### A. Git 저장소 주소 복사 방법
GitHub 웹 콘솔에서 배포 대상 Repository 페이지로 이동한 뒤, 우측 상단의 **[Code]** 녹색 버튼을 눌러 주소를 복사합니다.

1. **HTTPS 주소 복사**
   - **형식**: `https://github.com/<Owner>/<Repo>.git`
   - **인증 매핑**: `/auth pat` (또는 `gh` CLI 로그인) 방식을 사용할 때 선택합니다.
2. **SSH 주소 복사**
   - **형식**: `git@github.com:<Owner>/<Repo>.git`
   - **인증 매핑**: 시스템에 SSH Key가 이미 등록되어 있고, 패스프레이즈 없이 클론이 가능할 때 선택합니다. 이 경우 `/auth none`을 선택하면 Git 엔진이 SSH 에이전트를 통해 백그라운드에서 직접 인증을 처리합니다.

---

### B. Personal Access Token (PAT) 발급 방법
`/auth pat` 방식을 사용할 경우 GitHub에서 발급받은 개인용 액세스 토큰이 필요합니다.

1. **토큰 생성 페이지 이동**:
   - GitHub 로그인 후 우측 상단 프로필 이미지 클릭 ➔ **Settings** 이동.
   - 좌측 최하단의 **Developer settings** 클릭.
   - **Personal access tokens** 선택.

2. **Fine-grained Personal Access Tokens (추천)**:
   - **[Generate new token]** 클릭.
   - **Token name** 및 만료 기한(**Expiration**) 설정.
   - **Repository access**: 
     - 특정 저장소만 허용하려면 **[Only select repositories]** 선택 후 배포 대상 저장소 지정.
     - 모든 저장소를 허용하려면 **[All repositories]** 선택.
   - **Permissions**:
     - **Repository permissions** ➔ **Contents** 항목을 **Read-only**(읽기 전용) 또는 **Read and write**로 설정.
   - 최하단의 **[Generate token]** 클릭 후 생성된 토큰 복사 (페이지를 벗어나면 다시 볼 수 없으므로 안전한 곳에 저장).

3. **Tokens (classic) (구버전)**:
   - **[Generate new token]** ➔ **[Generate new token (classic)]** 클릭.
   - Note(이름) 설정 및 Expiration(만료일) 선택.
   - **Select scopes**: **`repo`** 스코프 전체 체크 (Private 저장소 접근에 필수).
   - 최하단의 **[Generate token]** 클릭 후 토큰 복사.

---

### C. 인증 방식 설정 예시 (`/auth`)
* **PAT 방식**: `/auth pat` 입력 후 안내에 따라 GitHub **Username**과 복사한 **PAT**를 순차적으로 입력합니다.
* **SSH 방식**: 주소 입력 시 SSH 형식(`git@github.com:...`)을 사용하고, `/auth none`으로 설정합니다.
* **GitHub CLI 방식**: 시스템에 `gh`가 설치되어 있고 기로그인 상태라면, `/auth gh`를 지정해 세션을 즉시 조율합니다.
