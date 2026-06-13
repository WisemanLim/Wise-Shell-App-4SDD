#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# WSA4SDD App (v1.0.0) — Service Deployment and Distribution Shell
# ─────────────────────────────────────────────────────────────────────────────
set -u

# ══ ANSI Styling & Escape Sequences ═══════════════════════════════════════════
ESC=$'\033'
CSI="${ESC}["
C_RST="${ESC}[0m"
C_BOLD="${ESC}[1m"
C_DIM="${ESC}[2m"
C_GREEN="${ESC}[32m"
C_YELLOW="${ESC}[33m"
C_RED="${ESC}[31m"
C_CYAN="${ESC}[36m"
C_WHITE="${ESC}[97m"
C_BG_BLUE="${ESC}[44m"

# ══ Logging Helpers ═══════════════════════════════════════════════════════════
log()   { printf '%s▶%s %s\n' "${C_CYAN}"   "${C_RST}" "$*" >&2; }
ok()    { printf '%s✓%s %s\n' "${C_GREEN}"  "${C_RST}" "$*" >&2; }
warn()  { printf '%s!%s %s\n' "${C_YELLOW}" "${C_RST}" "$*" >&2; }
err()   { printf '%s✗%s %s\n' "${C_RED}"    "${C_RST}" "$*" >&2; }
die()   { err "$*"; cache_delete; _cleanup; exit 1; }

clog()   { log "$*"; }
cok()    { ok "$*"; }
cwarn()  { warn "$*"; }
cerr()   { err "$*"; }
cprint() { printf "%s\n" "$*"; }

# ══ Global Parameters & Configuration ═════════════════════════════════════════
WORKSPACE_DIR=""
OPS_NAME=""
declare -a INPUT_REPOS=()
NO_RUN=0
AUTH_METHOD=""
GITHUB_USERNAME=""
GITHUB_PAT=""
DEFAULT_TARGET=""
BOOTSTRAP_DONE=0

# Operational values determined dynamically during execution
OPS_DIR=""
CONF_FILE=""
declare -a SYNCED_NAMES=()
declare -a COMPOSE_FILES=()
OS_KIND=""
OS_FAMILY=""
PKG_MGR=""
PKG_INSTALL=""
DAEMON_NEEDS_SG=0

# ══ Cache Management ══════════════════════════════════════════════════════════
_CACHE="/tmp/.wsa4sdd-${UID}.cache"

cache_save() {
  {
    printf 'CACHE_REPOS=%q\n'     "${INPUT_REPOS[*]:-}"
    printf 'CACHE_WORKSPACE=%q\n' "${WORKSPACE_DIR:-}"
    printf 'CACHE_OPS=%q\n'       "${OPS_NAME:-}"
    printf 'CACHE_AUTH=%q\n'      "${AUTH_METHOD:-}"
    printf 'CACHE_USER=%q\n'      "${GITHUB_USERNAME:-}"
    printf 'CACHE_TARGET=%q\n'    "${DEFAULT_TARGET:-}"
    printf 'CACHE_BOOTSTRAPPED=%q\n' "${BOOTSTRAP_DONE:-0}"
  } > "${_CACHE}"
  chmod 600 "${_CACHE}"
}

cache_load() {
  [[ -f "${_CACHE}" ]] || return 0
  local CACHE_REPOS="" CACHE_WORKSPACE="" CACHE_OPS=""
  local CACHE_AUTH="" CACHE_USER="" CACHE_TARGET="" CACHE_BOOTSTRAPPED=""
  # Load the cache file variables safely
  # shellcheck disable=SC1090
  . "${_CACHE}"
  [[ -n "${CACHE_REPOS}" ]]     && read -r -a INPUT_REPOS <<< "${CACHE_REPOS}" || true
  [[ -n "${CACHE_WORKSPACE}" ]] && WORKSPACE_DIR="${CACHE_WORKSPACE}"
  [[ -n "${CACHE_OPS}" ]]       && OPS_NAME="${CACHE_OPS}"
  [[ -n "${CACHE_AUTH}" ]]      && AUTH_METHOD="${CACHE_AUTH}"
  [[ -n "${CACHE_USER}" ]]      && GITHUB_USERNAME="${CACHE_USER}"
  [[ -n "${CACHE_TARGET}" ]]    && DEFAULT_TARGET="${CACHE_TARGET}"
  [[ -n "${CACHE_BOOTSTRAPPED}" ]] && BOOTSTRAP_DONE="${CACHE_BOOTSTRAPPED}"
}

cache_delete() {
  rm -f "${_CACHE}" 2>/dev/null || true
}

# ══ Interactive Prompt Inputs & Selectors ═════════════════════════════════════
MENU_IDX=0

run_menu() {
  local title="$1" sel="$2"; shift 2
  local -a items=("$@")
  local count="${#items[@]}"
  local total_lines=$(( count + 1 ))

  # Print title
  printf "  %s%s%s\n" "${C_BOLD}" "${title}" "${C_RST}"
  local i
  for (( i=0; i<count; i++ )); do
    if (( i == sel )); then
      printf "  %s▶ %s%s\n" "${C_GREEN}${C_BOLD}" "${items[$i]}" "${C_RST}"
    else
      printf "    %s\n" "${items[$i]}"
    fi
  done

  # Save current TTY settings and set raw mode to read arrow keys
  local old_stty; old_stty=$(stty -g 2>/dev/null)
  stty -echo -icanon min 1 time 0 2>/dev/null || true

  while true; do
    local key=""
    local char=""
    IFS= read -r -s -n1 char 2>/dev/null || char=""
    if [[ "${char}" == $'\x1b' ]]; then
      local next1="" next2=""
      stty -echo -icanon min 0 time 1 2>/dev/null || true
      IFS= read -r -s -n1 next1 2>/dev/null || next1=""
      if [[ "${next1}" == "[" || "${next1}" == "O" ]]; then
        IFS= read -r -s -n1 next2 2>/dev/null || next2=""
        case "${next2}" in
          A) key="UP";;
          B) key="DOWN";;
        esac
      fi
      stty -echo -icanon min 1 time 0 2>/dev/null || true
    elif [[ "${char}" == $'\n' || "${char}" == $'\r' || -z "${char}" ]]; then
      key="ENTER"
    elif [[ "${char}" == "q" || "${char}" == "Q" || "${char}" == $'\x1b' ]]; then
      key="ESC"
    elif [[ "${char}" == "k" ]]; then
      key="UP"
    elif [[ "${char}" == "j" ]]; then
      key="DOWN"
    fi

    if [[ "${key}" == "UP" ]]; then
      sel=$(( (sel - 1 + count) % count ))
    elif [[ "${key}" == "DOWN" ]]; then
      sel=$(( (sel + 1) % count ))
    elif [[ "${key}" == "ENTER" ]]; then
      # Erase menu lines and write selection
      printf "\033[%dA" "${total_lines}"
      printf "\033[J"
      printf "  %s%s:%s %s\n" "${C_BOLD}" "${title}" "${C_RST}" "${items[$sel]}"
      MENU_IDX="${sel}"
      stty "${old_stty}" 2>/dev/null || true
      return 0
    elif [[ "${key}" == "ESC" ]]; then
      # Erase menu lines and exit
      printf "\033[%dA" "${total_lines}"
      printf "\033[J"
      MENU_IDX=-1
      stty "${old_stty}" 2>/dev/null || true
      return 1
    fi

    # Redraw the list
    printf "\033[%dA" "${count}"
    for (( i=0; i<count; i++ )); do
      printf "\r\033[K"
      if (( i == sel )); then
        printf "  %s▶ %s%s\n" "${C_GREEN}${C_BOLD}" "${items[$i]}" "${C_RST}"
      else
        printf "    %s\n" "${items[$i]}"
      fi
    done
  done
}

cinput() {
  local prompt="$1" varname="$2" opt="${3:-}"
  printf "%s%s%s " "${C_CYAN}${C_BOLD}" "${prompt}" "${C_RST}"

  local val=""
  if [[ "${opt}" == "secret" ]]; then
    stty -echo 2>/dev/null || true
    read -r val
    stty echo 2>/dev/null || true
    printf "\n"
  else
    read -r val
  fi

  # trim whitespace
  val="${val#"${val%%[![:space:]]*}"}"
  val="${val%"${val##*[![:space:]]}"}"

  eval "${varname}=\"${val}\""
}

# ══ OS & Dependency Detection ═════════════════════════════════════════════════
detect_os() {
  OS_KIND=""; OS_FAMILY=""; PKG_MGR=""; PKG_INSTALL=""
  case "$(uname -s)" in
    Darwin)
      OS_KIND="macos"
      if command -v brew >/dev/null 2>&1; then
        PKG_MGR="brew"; PKG_INSTALL="brew install"
      else
        cwarn "Homebrew not found. Install from https://brew.sh"
      fi
      ;;
    Linux)
      OS_KIND="linux"
      if [[ -r /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        case "${ID_LIKE:-$ID}" in
          *debian*|*ubuntu*)
            OS_FAMILY="debian"; PKG_MGR="apt"
            PKG_INSTALL="sudo apt-get update && sudo apt-get install -y" ;;
          *fedora*|*rhel*|*centos*|*rocky*|*almalinux*)
            OS_FAMILY="fedora"
            if command -v dnf >/dev/null 2>&1; then PKG_MGR="dnf"; else PKG_MGR="yum"; fi
            PKG_INSTALL="sudo ${PKG_MGR} install -y" ;;
          *arch*)
            OS_FAMILY="arch"; PKG_MGR="pacman"
            PKG_INSTALL="sudo pacman -S --noconfirm" ;;
          *)
            OS_FAMILY="unknown" ;;
        esac
      fi
      ;;
    *)
      die "Unsupported OS: $(uname -s)"
      ;;
  esac
  cok "OS: ${OS_KIND} (${OS_FAMILY:-unknown}), pkg=${PKG_MGR:-none}"
}

install_pkg() {
  local pkg="$1"
  [[ -n "${PKG_INSTALL}" ]] || die "No package manager — install ${pkg} manually."
  clog "Installing ${pkg}..."
  eval "${PKG_INSTALL} ${pkg}"
}

ensure_cmd() {
  local cmd="$1" pkg="${2:-$1}"
  if command -v "${cmd}" >/dev/null 2>&1; then
    cok "${cmd}: OK"
  else
    cwarn "${cmd} missing — installing"
    install_pkg "${pkg}"
    command -v "${cmd}" >/dev/null 2>&1 || die "${cmd} still missing after install"
  fi
}

repair_apt_gh_keyring() {
  [[ "${OS_FAMILY}" == "debian" ]] || return 0
  local out; out="$(sudo apt-get update 2>&1 || true)"
  grep -qE 'NO_PUBKEY[[:space:]]+23F3D4EA75716059|cli\.github\.com.*not signed' <<<"${out}" || return 0
  cwarn "GitHub CLI APT keyring broken — repairing"
  sudo mkdir -p /etc/apt/keyrings
  if curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
       | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null 2>&1; then
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    if sudo apt-get update -y 2>&1 | grep -qE 'NO_PUBKEY|not signed'; then
      cwarn "Keyring fix failed — disabling gh APT repo"
      sudo rm -f /etc/apt/sources.list.d/github-cli.list \
                 /etc/apt/keyrings/githubcli-archive-keyring.gpg
      sudo apt-get update -y >/dev/null 2>&1
    else
      cok "GitHub CLI keyring restored"
    fi
  fi
}

install_docker_debian() {
  clog "Installing Docker via official APT repo"
  sudo apt-get install -y ca-certificates curl gnupg >/dev/null 2>&1
  sudo install -m 0755 -d /etc/apt/keyrings
  if [[ ! -s /etc/apt/keyrings/docker.gpg ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
  fi
  local distro codename arch
  distro="$(. /etc/os-release && echo "${ID}")"
  codename="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
  arch="$(dpkg --print-architecture)"
  [[ "${distro}" == "ubuntu" || "${distro}" == "debian" ]] || distro="ubuntu"
  echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${distro} ${codename} stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update -y >/dev/null 2>&1
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
}

install_docker_rhel() {
  clog "Installing Docker via official ${PKG_MGR} repo"
  sudo "${PKG_MGR}" remove -y podman-docker >/dev/null 2>&1 || true
  command -v dnf >/dev/null 2>&1 \
    && sudo dnf install -y dnf-plugins-core >/dev/null 2>&1 \
    || sudo yum install -y yum-utils >/dev/null 2>&1
  local repo_distro
  case "$(. /etc/os-release && echo "${ID}")" in
    fedora) repo_distro="fedora" ;; rhel) repo_distro="rhel" ;; *) repo_distro="centos" ;;
  esac
  local repo_url="https://download.docker.com/linux/${repo_distro}/docker-ce.repo"
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf config-manager --add-repo "${repo_url}" >/dev/null 2>&1 \
      || sudo dnf config-manager addrepo --from-repofile="${repo_url}" >/dev/null 2>&1
  else
    sudo yum-config-manager --add-repo "${repo_url}" >/dev/null 2>&1
  fi
  sudo "${PKG_MGR}" install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1
}

ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    cwarn "docker missing — installing"
    case "${OS_KIND}" in
      macos) install_pkg "--cask docker" ;;
      linux)
        case "${OS_FAMILY}" in
          debian) repair_apt_gh_keyring; install_docker_debian ;;
          fedora) install_docker_rhel ;;
          arch)   install_pkg "docker docker-compose" ;;
          *)      die "Unsupported Linux family for docker: ${OS_FAMILY}" ;;
        esac ;;
      *) die "Unsupported OS for docker install: ${OS_KIND}" ;;
    esac
    command -v docker >/dev/null 2>&1 || die "docker install failed"
  fi
  cok "docker: OK"

  DAEMON_NEEDS_SG=0
  if docker info >/dev/null 2>&1; then
    cok "docker daemon: running"
  elif sudo -n docker info >/dev/null 2>&1 || sudo docker info >/dev/null 2>&1; then
    cwarn "Docker daemon running, but socket not accessible without 'docker' group."
    DAEMON_NEEDS_SG=1
  else
    case "${OS_KIND}" in
      linux)
        clog "Starting docker daemon..."
        sudo systemctl enable --now docker >/dev/null 2>&1 || die "Failed to start docker" ;;
      macos)
        cwarn "Docker not running — launching Docker.app"
        open -ga Docker 2>/dev/null || true
        clog "Waiting up to 60s for docker daemon..."
        local i; for i in {1..30}; do docker info >/dev/null 2>&1 && break; sleep 2; done ;;
    esac
    docker info >/dev/null 2>&1 || sudo docker info >/dev/null 2>&1 \
      || die "docker daemon offline"
    cok "docker daemon: running"
  fi

  if [[ "${OS_KIND}" == "linux" ]]; then
    local me="${USER:-$(id -un)}"
    if ! getent group docker 2>/dev/null | grep -qE "(:|,)${me}(,|\$)"; then
      clog "Adding ${me} to docker group"
      sudo usermod -aG docker "${me}" 2>/dev/null || cwarn "usermod failed"
    fi
    if id -nG 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
      cok "docker group: active"
      DAEMON_NEEDS_SG=0
    else
      cwarn "docker group not active in current shell — using sg docker -c"
      DAEMON_NEEDS_SG=1
    fi
  fi
  export DAEMON_NEEDS_SG

  if ! docker compose version >/dev/null 2>&1; then
    clog "docker compose v2 missing — installing plugin"
    case "${OS_FAMILY}" in
      debian) repair_apt_gh_keyring; install_docker_debian ;;
      fedora) install_docker_rhel ;;
      arch)   install_pkg "docker-compose" ;;
      *)      cwarn "Install docker compose v2 manually for ${OS_KIND}" ;;
    esac
    docker compose version >/dev/null 2>&1 || die "docker compose v2 still missing"
  fi
  cok "docker compose: OK"
}

ensure_make() {
  if command -v make >/dev/null 2>&1; then
    cok "make: OK"
    return
  fi
  cwarn "make missing — installing"
  install_pkg make
  command -v make >/dev/null 2>&1 || die "make install failed"
}

# ══ Repo Sync & Resolution ════════════════════════════════════════════════════
repo_name_from_url() { local u="${1%.git}"; basename "${u}"; }

ssh_to_https() {
  local url="$1"
  [[ "${url}" =~ ^git@([^:]+):(.+)$ ]] \
    && printf 'https://%s/%s' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" \
    || printf '%s' "${url}"
}

sync_repo() {
  local url="$1"
  local name; name="$(repo_name_from_url "${url}")"
  local target="${WORKSPACE_DIR}/${name}"
  local -a git_opts=()
  local clone_url="${url}"

  if [[ "${AUTH_METHOD}" == "pat" && -n "${_PAT_CRED_FILE}" ]]; then
    clone_url="$(ssh_to_https "${url}")"
    git_opts+=("-c" "credential.helper=store --file=${_PAT_CRED_FILE}")
  fi

  local tmpf; tmpf="$(mktemp)"; local rc=0

  if [[ -d "${target}/.git" ]]; then
    clog "Pulling ${name}..."
    local branch; branch="$(git -C "${target}" symbolic-ref --quiet --short HEAD 2>/dev/null || echo main)"
    git ${git_opts+"${git_opts[@]}"} -C "${target}" fetch --all --prune >"${tmpf}" 2>&1 || true
    git ${git_opts+"${git_opts[@]}"} -C "${target}" pull --ff-only origin "${branch}" >>"${tmpf}" 2>&1 || rc=$?
    (( rc == 0 )) && cok "Pulled: ${name}" || cwarn "${name}: pull skipped (rc=${rc})"
  elif [[ -e "${target}" ]]; then
    cwarn "${target} exists but not a git repo — skipping"
  else
    clog "Cloning ${name}..."
    git ${git_opts+"${git_opts[@]}"} clone "${clone_url}" "${target}" >"${tmpf}" 2>&1 || rc=$?
    if (( rc != 0 )); then
      cerr "Clone failed: ${name}"
      while IFS= read -r line; do cwarn "  ${line}"; done < "${tmpf}"
      rm -f "${tmpf}"; die "Clone failed for ${name}"
    fi
    cok "Cloned: ${name}"
  fi
  rm -f "${tmpf}"
  printf '%s\n' "${name}"
}

sync_all_repos() {
  clog "Workspace: ${WORKSPACE_DIR}"
  SYNCED_NAMES=()
  local url name
  for url in "${INPUT_REPOS[@]}"; do
    name="$(sync_repo "${url}")"
    SYNCED_NAMES+=("${name}")
  done
  cok "Synced: ${SYNCED_NAMES[*]}"
}

find_compose_files() {
  find "$1" \
    \( -name .git -o -name node_modules -o -name vendor -o -name dist \
       -o -name build -o -name .venv -o -name venv -o -name __pycache__ \) -prune -o \
    -maxdepth 6 -type f \
    \( -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' \
       -o -name 'compose.yml' -o -name 'compose.yaml' \) \
    -print 2>/dev/null
}

resolve_ops_dir() {
  if [[ -z "${OPS_NAME}" ]]; then
    local n
    for n in "${SYNCED_NAMES[@]}"; do
      if [[ -n "$(find_compose_files "${WORKSPACE_DIR}/${n}" | head -n1)" ]]; then
        OPS_NAME="${n}"; break
      fi
    done
    [[ -n "${OPS_NAME}" ]] || OPS_NAME="${SYNCED_NAMES[0]}"
  fi
  OPS_DIR="${WORKSPACE_DIR}/${OPS_NAME}"
  [[ -d "${OPS_DIR}" ]] || die "Ops dir not found: ${OPS_DIR}"
  CONF_FILE="${OPS_DIR}/.dist-standard.conf"
  cok "Ops project: ${OPS_NAME}"
}

load_compose_files() {
  COMPOSE_FILES=()
  if [[ -f "${OPS_DIR}/Makefile" ]]; then
    cok "Makefile already present"
    return
  fi
  local abs rel
  while IFS= read -r abs; do
    [[ -z "${abs}" ]] && continue
    rel="${abs#${OPS_DIR}/}"; COMPOSE_FILES+=("${rel}")
  done < <(find_compose_files "${OPS_DIR}" | sort)
  if [[ ${#COMPOSE_FILES[@]} -eq 0 ]]; then
    cwarn "No docker-compose*.yml under ${OPS_DIR} — deployment target list may be empty"
    NO_RUN=1; return
  fi
  clog "Compose files found: ${COMPOSE_FILES[*]}"
}

generate_makefile() {
  local mk="${OPS_DIR}/Makefile"
  [[ -f "${mk}" ]] && { cok "Makefile already present"; return; }
  [[ ${#COMPOSE_FILES[@]} -gt 0 ]] || return
  cwarn "Makefile missing — generating from compose files"

  local base="" f bn shallowest=99 depth
  for f in "${COMPOSE_FILES[@]}"; do
    bn="$(basename "${f}")"
    if [[ "${bn}" == "docker-compose.yml" || "${bn}" == "compose.yml" \
       || "${bn}" == "docker-compose.yaml" || "${bn}" == "compose.yaml" ]]; then
      depth="$(awk -F/ '{print NF}' <<<"${f}")"
      (( depth < shallowest )) && { shallowest="${depth}"; base="${f}"; }
    fi
  done

  {
    echo "SHELL := /bin/bash"
    echo "# Auto-generated by WSA4SDD App"
    echo ""
    local flags=""; [[ -n "${base}" ]] && flags="-f ${base}"
    echo ".PHONY: help up down ps logs build clean"
    echo ""
    echo "help:"
    echo -e "\t@grep -E '^[a-zA-Z0-9_-]+:.*?## ' \$(MAKEFILE_LIST) | awk 'BEGIN{FS=\":.*?## \"};{printf \"  %-30s %s\\n\", \$\$1, \$\$2}'"
    echo ""
    local dir tag dtag
    for f in "${COMPOSE_FILES[@]}"; do
      [[ "${f}" == "${base}" ]] && continue
      bn="$(basename "${f}")"; dir="$(dirname "${f}")"
      tag="${bn%.yml}"; tag="${tag%.yaml}"
      tag="${tag#docker-compose.}"; tag="${tag#docker-compose}"
      tag="${tag#compose.}"; tag="${tag#compose}"
      if [[ "${dir}" != "." ]]; then
        dtag="${dir//\//-}"
        [[ -n "${tag}" ]] && tag="${dtag}-${tag}" || tag="${dtag}"
      fi
      [[ -z "${tag}" ]] && continue
      echo "up-${tag}: ## up: ${f}"
      echo -e "\tdocker compose ${flags} -f ${f} up -d"
      echo "down-${tag}: ## down: ${f}"
      echo -e "\tdocker compose ${flags} -f ${f} down"
      echo ""
    done
    if [[ -n "${base}" ]]; then
      echo "up: ## up base (${base})"
      echo -e "\tdocker compose ${flags} up -d"
      echo "down: ## down base"
      echo -e "\tdocker compose ${flags} down"
      echo "ps:"
      echo -e "\tdocker compose ${flags} ps"
      echo "logs:"
      echo -e "\tdocker compose ${flags} logs -f --tail=200"
      echo "build:"
      echo -e "\tdocker compose ${flags} build"
      echo "clean:"
      echo -e "\tdocker compose ${flags} down -v --remove-orphans"
    fi
  } > "${mk}"
  cok "Generated Makefile under ${mk}"
}

list_make_up_targets() {
  local mk="${OPS_DIR}/Makefile"; [[ -f "${mk}" ]] || return
  local all up_only
  all="$(awk -F: '/^[A-Za-z0-9_.\/-]+[ \t]*:/{name=$1;sub(/[ \t]+$/,"",name);if(name~/^\./||name=="help"||name=="list-targets")next;print name}' "${mk}" | sort -u)"
  up_only="$(grep -E '^up(-|$)' <<<"${all}" || true)"
  [[ -n "${up_only}" ]] && printf '%s\n' "${up_only}" || printf '%s\n' "${all}"
}

load_default() {
  [[ -f "${CONF_FILE:-}" ]] || { DEFAULT_TARGET=""; return; }
  # shellcheck disable=SC1090
  . "${CONF_FILE}"
  DEFAULT_TARGET="${LAST_TARGET:-}"
}

save_default() {
  [[ -n "${CONF_FILE:-}" ]] || return 0
  printf 'LAST_TARGET=%q\nLAST_RUN=%q\n' "$1" "$(date -u +%FT%TZ)" > "${CONF_FILE}"
}

dump_unhealthy_logs() {
  cwarn "Collecting logs from unhealthy containers..."
  local use_sg=0
  [[ "${OS_KIND}" == "linux" && "${DAEMON_NEEDS_SG:-0}" -eq 1 ]] \
    && command -v sg >/dev/null 2>&1 && use_sg=1

  local listing
  (( use_sg )) \
    && listing="$(sg docker -c 'docker ps -a --format "{{.Names}}\t{{.Status}}"' 2>/dev/null || true)" \
    || listing="$(docker ps -a --format '{{.Names}}\t{{.Status}}' 2>/dev/null || true)"
  [[ -n "${listing}" ]] || { cwarn "No containers found"; return; }

  while IFS=$'\t' read -r name status; do
    [[ -z "${name}" ]] && continue
    [[ "${status}" == *"(healthy)"* ]] && continue
    { [[ "${status}" == "Up "* ]] && [[ "${status}" != *"(unhealthy)"* ]]; } && continue
    clog "── ${name} (${status}) ──"
    local logs
    (( use_sg )) \
      && logs="$(sg docker -c "docker logs --tail=40 '${name}' 2>&1" || true)" \
      || logs="$(docker logs --tail=40 "${name}" 2>&1 || true)"
    while IFS= read -r line; do printf "  %s\n" "${line}"; done <<< "${logs}"
  done <<< "${listing}"
}

_finalize_docker_access() {
  [[ "${OS_KIND}" == "linux" ]] || return 0
  [[ "${DAEMON_NEEDS_SG:-0}" -eq 1 ]] || return 0
  command -v sg >/dev/null 2>&1 || { cwarn "'sg' not available — log out/in to activate docker group"; return 0; }

  local items=("sg docker 서브셸 실행 (권장)" "활성화 방법 안내" "건너뜀")
  run_menu "Docker Group 활성화" 0 "${items[@]}" || return 0

  case "${MENU_IDX}" in
    0) exec sg docker -c "${SHELL:-/bin/bash}" ;;
    1)
      printf "\n현재 터미널에서 아래 중 하나를 실행하세요:\n"
      printf "  %snewgrp docker%s\n" "${C_GREEN}" "${C_RST}"
      printf "  %sexec sg docker -c \"\$SHELL\"%s\n" "${C_GREEN}" "${C_RST}"
      printf "  로그아웃 후 재로그인\n\n" ;;
  esac
}

# ══ Commands Logic ════════════════════════════════════════════════════════════
move_item_loop() {
  local ref_list_name="$1"
  local idx="$2"
  eval "local -a list=(\"\${${ref_list_name}[@]}\")"
  local count="${#list[@]}"
  local total_lines=$(( count + 2 ))

  while true; do
    printf "  %sMove the selected item [Up/Down], Enter to lock, ESC to cancel:%s\n" "${C_BOLD}" "${C_RST}"
    local i
    for (( i=0; i<count; i++ )); do
      if (( i == idx )); then
        printf "  %s⇄ %d) %s%s\n" "${C_YELLOW}${C_BOLD}" $((i+1)) "${list[$i]}" "${C_RST}"
      else
        printf "    %d) %s\n" $((i+1)) "${list[$i]}"
      fi
    done
    printf "    Done\n"

    local key=""
    local char=""
    IFS= read -r -s -n1 char 2>/dev/null || char=""
    if [[ "${char}" == $'\x1b' ]]; then
      local next1="" next2=""
      stty -echo -icanon min 0 time 1 2>/dev/null || true
      IFS= read -r -s -n1 next1 2>/dev/null || next1=""
      if [[ "${next1}" == "[" || "${next1}" == "O" ]]; then
        IFS= read -r -s -n1 next2 2>/dev/null || next2=""
        case "${next2}" in
          A) key="UP";;
          B) key="DOWN";;
        esac
      fi
      stty -echo -icanon min 1 time 0 2>/dev/null || true
    elif [[ "${char}" == $'\n' || "${char}" == $'\r' || -z "${char}" ]]; then
      key="ENTER"
    elif [[ "${char}" == "q" || "${char}" == "Q" || "${char}" == $'\x1b' ]]; then
      key="ESC"
    elif [[ "${char}" == "k" ]]; then
      key="UP"
    elif [[ "${char}" == "j" ]]; then
      key="DOWN"
    fi

    if [[ "${key}" == "UP" ]]; then
      if (( idx > 0 )); then
        local temp="${list[$idx]}"
        list[$idx]="${list[$((idx-1))]}"
        list[$((idx-1))]="${temp}"
        idx=$((idx - 1))
      fi
    elif [[ "${key}" == "DOWN" ]]; then
      if (( idx < count - 1 )); then
        local temp="${list[$idx]}"
        list[$idx]="${list[$((idx+1))]}"
        list[$((idx+1))]="${temp}"
        idx=$((idx + 1))
      fi
    elif [[ "${key}" == "ENTER" || "${key}" == "ESC" ]]; then
      printf "\033[%dA" "${total_lines}"
      printf "\033[J"
      eval "${ref_list_name}=(\"\${list[@]}\")"
      return 0
    fi

    printf "\033[%dA" "$((total_lines - 1))"
  done
}

reorder_repos_ui() {
  local ref_name="$1"
  eval "local -a list=(\"\${${ref_name}[@]}\")"
  local count="${#list[@]}"
  local sel=0
  local total_lines=$(( count + 2 ))

  local old_stty; old_stty=$(stty -g 2>/dev/null)
  stty -echo -icanon min 1 time 0 2>/dev/null || true

  while true; do
    printf "  %sSelect repository to move, or choose Done:%s\n" "${C_BOLD}" "${C_RST}"
    local i
    for (( i=0; i<count; i++ )); do
      if (( i == sel )); then
        printf "  %s▶ %d) %s%s\n" "${C_GREEN}${C_BOLD}" $((i+1)) "${list[$i]}" "${C_RST}"
      else
        printf "    %d) %s\n" $((i+1)) "${list[$i]}"
      fi
    done
    if (( sel == count )); then
      printf "  %s▶ Done%s\n" "${C_GREEN}${C_BOLD}" "${C_RST}"
    else
      printf "    Done\n"
    fi

    local key=""
    local char=""
    IFS= read -r -s -n1 char 2>/dev/null || char=""
    if [[ "${char}" == $'\x1b' ]]; then
      local next1="" next2=""
      stty -echo -icanon min 0 time 1 2>/dev/null || true
      IFS= read -r -s -n1 next1 2>/dev/null || next1=""
      if [[ "${next1}" == "[" || "${next1}" == "O" ]]; then
        IFS= read -r -s -n1 next2 2>/dev/null || next2=""
        case "${next2}" in
          A) key="UP";;
          B) key="DOWN";;
        esac
      fi
      stty -echo -icanon min 1 time 0 2>/dev/null || true
    elif [[ "${char}" == $'\n' || "${char}" == $'\r' || -z "${char}" ]]; then
      key="ENTER"
    elif [[ "${char}" == "q" || "${char}" == "Q" || "${char}" == $'\x1b' ]]; then
      key="ESC"
    elif [[ "${char}" == "k" ]]; then
      key="UP"
    elif [[ "${char}" == "j" ]]; then
      key="DOWN"
    fi

    if [[ "${key}" == "UP" ]]; then
      sel=$(( (sel - 1 + count + 1) % (count + 1) ))
    elif [[ "${key}" == "DOWN" ]]; then
      sel=$(( (sel + 1) % (count + 1) ))
    elif [[ "${key}" == "ENTER" ]]; then
      if (( sel == count )); then
        printf "\033[%dA" "${total_lines}"
        printf "\033[J"
        stty "${old_stty}" 2>/dev/null || true
        eval "${ref_name}=(\"\${list[@]}\")"
        return 0
      else
        printf "\033[%dA" "${total_lines}"
        printf "\033[J"
        move_item_loop list "${sel}"
        stty -echo -icanon min 1 time 0 2>/dev/null || true
      fi
    elif [[ "${key}" == "ESC" ]]; then
      printf "\033[%dA" "${total_lines}"
      printf "\033[J"
      stty "${old_stty}" 2>/dev/null || true
      eval "${ref_name}=(\"\${list[@]}\")"
      return 0
    fi

    printf "\033[%dA" "$((total_lines - 1))"
  done
}

handle_repo() {
  if [[ $# -gt 0 ]]; then
    INPUT_REPOS=("$@")
    cok "Repositories updated: ${INPUT_REPOS[*]}"
    cache_save
  else
    local -a temp_repos=("${INPUT_REPOS[@]:-}")
    while true; do
      printf "\n%s━━ Repository Manager ━━%s\n" "${C_BOLD}" "${C_RST}"
      if [[ ${#temp_repos[@]} -eq 0 ]]; then
        printf "  %s(No repositories registered)%s\n" "${C_DIM}" "${C_RST}"
      else
        local i
        for (( i=0; i<${#temp_repos[@]}; i++ )); do
          printf "  %d) %s\n" $((i+1)) "${temp_repos[$i]}"
        done
      fi
      printf "\n"

      local -a items=()
      items+=("Add Repository")
      if [[ ${#temp_repos[@]} -gt 0 ]]; then
        items+=("Delete Repository")
        items+=("Clear All")
      fi
      if [[ ${#temp_repos[@]} -gt 1 ]]; then
        items+=("Change Order (Reorder)")
      fi
      items+=("Save & Exit")
      items+=("Cancel & Discard")

      run_menu "Actions" 0 "${items[@]}"
      local action="${items[${MENU_IDX:-0}]}"

      if [[ "${MENU_IDX}" -eq -1 ]]; then
        cwarn "Discarded changes."
        return 0
      fi

      case "${action}" in
        "Add Repository")
          if [[ ${#temp_repos[@]} -ge 8 ]]; then
            cwarn "Maximum limit of 8 repositories reached."
            continue
          fi
          local url=""
          cinput "Enter Repo URL:" url
          if [[ -n "${url}" ]]; then
            temp_repos+=("${url}")
            cok "Added: ${url}"
          fi
          ;;
        "Delete Repository")
          run_menu "Select Repository to Delete" 0 "${temp_repos[@]}"
          if (( MENU_IDX >= 0 )); then
            local deleted="${temp_repos[${MENU_IDX}]}"
            local -a next_repos=()
            local i
            for (( i=0; i<${#temp_repos[@]}; i++ )); do
              if (( i != MENU_IDX )); then
                next_repos+=("${temp_repos[$i]}")
              fi
            done
            temp_repos=("${next_repos[@]}")
            cok "Deleted: ${deleted}"
          fi
          ;;
        "Clear All")
          local confirm_items=("Yes, Clear All" "No, Keep Them")
          run_menu "Are you sure you want to clear all registered repositories?" 1 "${confirm_items[@]}"
          if (( MENU_IDX == 0 )); then
            temp_repos=()
            cok "Cleared all repositories."
          fi
          ;;
        "Change Order (Reorder)")
          reorder_repos_ui temp_repos
          ;;
        "Save & Exit")
          INPUT_REPOS=("${temp_repos[@]}")
          cok "Saved repositories changes."
          cache_save
          return 0
          ;;
        "Cancel & Discard")
          cwarn "Discarded changes."
          return 0
          ;;
      esac
    done
  fi
}

handle_workspace() {
  if [[ $# -gt 0 ]]; then
    WORKSPACE_DIR="$1"
    mkdir -p "${WORKSPACE_DIR}"
    WORKSPACE_DIR="$(cd "${WORKSPACE_DIR}" && pwd)"
    cok "Workspace updated: ${WORKSPACE_DIR}"
    cache_save
  else
    local cwd="${PWD}"
    local parent; parent="$(cd "${cwd}/.." && pwd)"
    local items=(
      "Current dir  →  ${cwd}"
      "Parent dir   →  ${parent}"
      "Custom path..."
    )
    run_menu "Select Clone Workspace" 0 "${items[@]}"
    case "${MENU_IDX}" in
      0) WORKSPACE_DIR="${cwd}" ;;
      1) WORKSPACE_DIR="${parent}" ;;
      2)
        local custom=""
        cinput "Custom path:" custom
        custom="${custom/#\~/$HOME}"
        WORKSPACE_DIR="${custom:-${cwd}}"
        ;;
      *) return ;;
    esac
    mkdir -p "${WORKSPACE_DIR}"
    WORKSPACE_DIR="$(cd "${WORKSPACE_DIR}" && pwd)"
    cok "Workspace resolved: ${WORKSPACE_DIR}"
    cache_save
  fi
}

handle_auth() {
  if [[ $# -gt 0 ]]; then
    case "$1" in
      gh|pat|none)
        AUTH_METHOD="$1"
        cok "Auth method updated: ${AUTH_METHOD}"
        cache_save
        ;;
      *)
        cerr "Unknown auth method: $1. Use: gh, pat, or none"
        return
        ;;
    esac
  else
    local items=(
      "gh auth login      — GitHub CLI (영구 저장, 권장)"
      "Access Token (PAT) — 1회성 Personal Access Token"
      "No auth            — 공개 저장소 전용"
    )
    run_menu "Select Auth Method" 0 "${items[@]}"
    case "${MENU_IDX}" in
      0) AUTH_METHOD="gh" ;;
      1) AUTH_METHOD="pat" ;;
      2) AUTH_METHOD="none" ;;
      *) return ;;
    esac
    cok "Auth method: ${AUTH_METHOD}"
    cache_save
  fi

  if [[ "${AUTH_METHOD}" == "pat" ]]; then
    cinput "GitHub Username (선택사항):" GITHUB_USERNAME
    cinput "Personal Access Token:" GITHUB_PAT "secret"
    if [[ -n "${GITHUB_PAT}" ]]; then
      _PAT_CRED_FILE="$(mktemp)"; chmod 600 "${_PAT_CRED_FILE}"
      if [[ -n "${GITHUB_USERNAME}" ]]; then
        printf 'https://%s:%s@github.com\n' "${GITHUB_USERNAME}" "${GITHUB_PAT}" > "${_PAT_CRED_FILE}"
      else
        printf 'https://x-access-token:%s@github.com\n' "${GITHUB_PAT}" > "${_PAT_CRED_FILE}"
      fi
      cok "PAT saved to temporary credentials file."
      cache_save
    else
      cwarn "PAT is empty. Authentication might fail."
    fi
  fi
}

handle_bootstrap() {
  clog "Detecting OS and checking dependencies..."
  detect_os

  if [[ "${AUTH_METHOD}" == "gh" ]]; then
    ensure_cmd git
    ensure_cmd gh
    if ! gh auth status >/dev/null 2>&1; then
      cwarn "gh CLI not authenticated. Running gh auth login..."
      gh auth login || { cerr "gh auth login failed."; return 1; }
    fi
  else
    ensure_cmd git
  fi

  ensure_docker
  ensure_make

  if [[ ${#INPUT_REPOS[@]} -eq 0 ]]; then
    cwarn "No repositories specified. Run /repo to add repositories before bootstrapping."
    return 1
  fi

  clog "Synchronizing repositories..."
  sync_all_repos

  clog "Resolving operations directory..."
  resolve_ops_dir

  clog "Loading compose files..."
  load_compose_files

  clog "Generating Makefile..."
  generate_makefile

  cok "Bootstrap completed successfully!"
  BOOTSTRAP_DONE=1
  cache_save
}

handle_status() {
  printf "\n%s━━ WSA4SDD Configuration Status ━━%s\n" "${C_BOLD}" "${C_RST}"

  # Workspace
  if [[ -n "${WORKSPACE_DIR}" ]]; then
    printf "  Workspace : %s%s%s\n" "${C_GREEN}" "${WORKSPACE_DIR}" "${C_RST}"
  else
    printf "  Workspace : %s[NOT SET]%s (Use /workspace to set)\n" "${C_RED}" "${C_RST}"
  fi

  # Repositories
  if [[ ${#INPUT_REPOS[@]} -gt 0 ]]; then
    printf "  Repos     : %s%s%s\n" "${C_GREEN}" "${INPUT_REPOS[*]}" "${C_RST}"
  else
    printf "  Repos     : %s[NOT SET]%s (Use /repo to set)\n" "${C_RED}" "${C_RST}"
  fi

  # Auth Method
  if [[ -n "${AUTH_METHOD}" ]]; then
    printf "  Auth      : %s%s%s\n" "${C_GREEN}" "${AUTH_METHOD}" "${C_RST}"
  else
    printf "  Auth      : %s[NOT SET]%s (Use /auth to set)\n" "${C_RED}" "${C_RST}"
  fi

  # Ops Project
  if [[ -n "${OPS_NAME}" ]]; then
    printf "  Ops Repo  : %s%s%s\n" "${C_GREEN}" "${OPS_NAME}" "${C_RST}"
  else
    printf "  Ops Repo  : %s[NOT SET]%s (Resolved during /bootstrap)\n" "${C_DIM}" "${C_RST}"
  fi

  # Bootstrap status
  if [[ "${BOOTSTRAP_DONE:-0}" -eq 1 ]]; then
    printf "  Bootstrap : %s[DONE]%s\n" "${C_GREEN}" "${C_RST}"
  else
    printf "  Bootstrap : %s[PENDING]%s (Run /bootstrap or let /dist-run do it)\n" "${C_YELLOW}" "${C_RST}"
  fi

  printf "\n"
}

handle_dist_run() {
  # 1. Validation
  local missing=0
  if [[ ${#INPUT_REPOS[@]} -eq 0 ]]; then
    cerr "Missing repositories. Please run /repo or /R to set them."
    missing=1
  fi
  if [[ -z "${WORKSPACE_DIR}" ]]; then
    cerr "Missing workspace directory. Please run /workspace or /W to set it."
    missing=1
  fi
  if [[ -z "${AUTH_METHOD}" ]]; then
    cerr "Missing authentication method. Please run /auth or /A to set it."
    missing=1
  fi

  if (( missing )); then
    return 1
  fi

  # 2. Automatically bootstrap if not yet done
  if [[ "${BOOTSTRAP_DONE:-0}" -ne 1 ]]; then
    clog "Bootstrap has not been run yet. Executing bootstrap first..."
    handle_bootstrap || { cerr "Bootstrap failed. Cannot run deployment."; return 1; }
  fi

  # 3. Present Make Target menu
  load_default
  local raw=()
  while IFS= read -r _t; do
    [[ -n "${_t}" ]] && raw+=("${_t}")
  done < <(list_make_up_targets)

  if [[ ${#raw[@]} -eq 0 ]]; then
    cerr "No make targets found in ${OPS_DIR}/Makefile. Cannot run deployment."
    return 1
  fi

  local display=() def_idx=0 i
  for (( i=0; i<${#raw[@]}; i++ )); do
    if [[ "${raw[$i]}" == "${DEFAULT_TARGET}" ]]; then
      display+=("${raw[$i]}  (last used)")
      def_idx="${i}"
    else
      display+=("${raw[$i]}")
    fi
  done
  display+=("Custom target…")

  run_menu "Select Make Target [ops: ${OPS_NAME}]" "${def_idx}" "${display[@]}" || return 1

  local target=""
  if (( MENU_IDX == ${#display[@]}-1 )); then
    cinput "Custom target:" target
    [[ -z "${target}" ]] && return 1
  else
    target="${raw[${MENU_IDX}]}"
  fi
  DEFAULT_TARGET="${target}"
  cache_save

  # 4. Pre-run commands
  clog "Pre-run commands (Optional. Enter empty line to skip)"
  while true; do
    local ucmd=""
    cinput "Command:" ucmd
    [[ -z "${ucmd}" ]] && break
    clog "Running: ${ucmd}"
    local rc=0
    if [[ "${OS_KIND}" == "linux" && "${DAEMON_NEEDS_SG:-0}" -eq 1 ]] && command -v sg >/dev/null 2>&1; then
      sg docker -c "cd \"${OPS_DIR}\" && ${ucmd}" || rc=$?
    else
      ( cd "${OPS_DIR}" && bash -c "${ucmd}" ) || rc=$?
    fi
    if (( rc != 0 )); then
      cwarn "Command exited with status ${rc}"
    else
      cok "Done"
    fi
  done

  # 5. Confirm Deployment
  local items=("▶ Run Now" "✗ Cancel")
  run_menu "Deploy?" 0 "${items[@]}" || return 1
  if (( MENU_IDX == 1 )); then
    cwarn "Deployment cancelled."
    return 1
  fi

  # 6. Execute Make target
  clog "Executing: make -C \"${OPS_DIR}\" ${target}"
  save_default "${target}"

  local exit_code=0
  if [[ "${OS_KIND}" == "linux" && "${DAEMON_NEEDS_SG:-0}" -eq 1 ]] && command -v sg >/dev/null 2>&1; then
    sg docker -c "cd \"${OPS_DIR}\" && make ${target}" || exit_code=$?
  else
    ( cd "${OPS_DIR}" && make "${target}" ) || exit_code=$?
  fi

  if (( exit_code != 0 )); then
    cerr "Deployment failed (make exited with ${exit_code})"
    dump_unhealthy_logs
    return "${exit_code}"
  fi

  cok "Deployment completed successfully!"

  # 7. Finalize Docker Access (Linux only)
  _finalize_docker_access

  # Delete cache on successful completion
  cache_delete
  exit 0
}

# ══ UI Lifecycle & Screen Redrawing ═══════════════════════════════════════════
print_welcome() {
  printf "\n"
  printf "  %sWSA4SDD App (v1.0.0)%s — Service Deployment and Distribution Shell\n" "${C_BOLD}${C_CYAN}" "${C_RST}"
  printf "  %sLives in your terminal, manages git repos, and deploys docker-compose.%s\n" "${C_DIM}" "${C_RST}"
  printf "  %s─────────────────────────────────────────────────────────────────────────────%s\n" "${C_DIM}" "${C_RST}"
  printf "  Commands:\n"
  printf "    %s/repo, /R [repo1 repo2...]%s    Configure repository URLs to deploy (or open manager if empty)\n" "${C_BOLD}" "${C_RST}"
  printf "    %s/workspace, /W [path]%s       Configure target workspace directory path (or open menu if empty)\n" "${C_BOLD}" "${C_RST}"
  printf "    %s/auth, /A [gh|pat|none]%s     Configure GitHub credentials (or open menu if empty)\n" "${C_BOLD}" "${C_RST}"
  printf "    %s/bootstrap, /B%s              Verify dependencies and sync git repositories\n" "${C_BOLD}" "${C_RST}"
  printf "    %s/status, /S%s                 Show current configuration status\n" "${C_BOLD}" "${C_RST}"
  printf "    %s/dist-run, /D%s               Verify configurations and run make deployment\n" "${C_BOLD}" "${C_RST}"
  printf "    %s/help, /H%s                   Show this help message\n" "${C_BOLD}" "${C_RST}"
  printf "    %s/exit, /E%s                   Exit wsa4sdd shell and clear cache\n" "${C_BOLD}" "${C_RST}"
  printf "    %s! <command>%s                 Execute a shell command and display the output\n" "${C_BOLD}" "${C_RST}"
  printf "  %s─────────────────────────────────────────────────────────────────────────────%s\n" "${C_DIM}" "${C_RST}"
  printf "\n"

  if [[ -f "${_CACHE}" ]]; then
    printf "  %s⚡ Loaded previous session cache.%s\n" "${C_YELLOW}" "${C_RST}"
    printf "\n"
  fi
}

# ══ Traps & Signal Handlers ═══════════════════════════════════════════════════
_PAT_CRED_FILE=""
_cleanup() {
  [[ -n "${_PAT_CRED_FILE:-}" ]] && rm -f "${_PAT_CRED_FILE}" 2>/dev/null || true
  stty sane 2>/dev/null || true
}
trap '_cleanup' EXIT TERM HUP

_INT_LAST=0
_int_handler() {
  local now="${SECONDS}"
  if (( now - _INT_LAST <= 2 )); then
    cache_delete
    _cleanup
    exit 130
  fi
  _INT_LAST="${now}"
  printf "\n%s!%s Press Ctrl+C again within 2 seconds to exit (clears cache)\n" "${C_YELLOW}" "${C_RST}"
}
trap '_int_handler' INT

# ══ Modes Execution ═══════════════════════════════════════════════════════════
# ══ REPL Line Editor & History ════════════════════════════════════════════════
declare -a REPL_HISTORY=()
REPL_HIST_FILE="/tmp/.wsa4sdd_history"

load_history() {
  if [[ -f "${REPL_HIST_FILE}" ]]; then
    while IFS= read -r line; do
      [[ -n "${line}" ]] && REPL_HISTORY+=("${line}")
    done < "${REPL_HIST_FILE}"
  fi
}

save_history() {
  local h
  printf "" > "${REPL_HIST_FILE}"
  for h in "${REPL_HISTORY[@]:-}"; do
    if [[ -n "${h}" ]]; then
      printf "%s\n" "${h}" >> "${REPL_HIST_FILE}"
    fi
  done
}

repl_read() {
  local buffer=""
  local cursor=0
  local hist_pos=${#REPL_HISTORY[@]}
  local prompt="${C_BOLD}${C_GREEN}>    ${C_RST}"
  local menu_sel=0
  local menu_closed=0

  local old_stty; old_stty=$(stty -g 2>/dev/null)
  stty -echo -icanon min 1 time 0 2>/dev/null || true

  while true; do
    # 1. Filter commands and determine menu state
    local -a all_commands=(
      "/repo"
      "/workspace"
      "/auth"
      "/bootstrap"
      "/status"
      "/dist-run"
      "/help"
      "/exit"
    )
    local -a filtered_items=()
    local menu_active=0

    if (( ! menu_closed )) && [[ "${buffer}" == /* && "${buffer}" != *" "* ]]; then
      local cmd
      for cmd in "${all_commands[@]}"; do
        if [[ "${cmd}" == "${buffer}"* ]]; then
          filtered_items+=("${cmd}")
        fi
      done
      if (( ${#filtered_items[@]} > 0 )); then
        menu_active=1
        # Clamp menu_sel
        if (( menu_sel >= ${#filtered_items[@]} )); then
          menu_sel=0
        elif (( menu_sel < 0 )); then
          menu_sel=$(( ${#filtered_items[@]} - 1 ))
        fi
      fi
    fi

    # 2. Redraw prompt and menu
    # Clear current line and below
    printf "\r\033[J"
    # Print prompt and buffer
    printf "%s%s" "${prompt}" "${buffer}"

    local menu_lines=0
    if (( menu_active )); then
      printf "\n  %sAutocomplete Command%s" "${C_BOLD}" "${C_RST}"
      menu_lines=1
      local i
      for (( i=0; i<${#filtered_items[@]}; i++ )); do
        if (( i == menu_sel )); then
          printf "\n  %s▶ %s%s" "${C_GREEN}${C_BOLD}" "${filtered_items[$i]}" "${C_RST}"
        else
          printf "\n    %s" "${filtered_items[$i]}"
        fi
        menu_lines=$((menu_lines + 1))
      done
    fi

    # Move cursor back to prompt line if menu was drawn
    if (( menu_lines > 0 )); then
      printf "\033[%dA" "${menu_lines}"
    fi

    # Position cursor at the edit column
    printf "\r%s%s" "${prompt}" "${buffer:0:cursor}"

    # 3. Read key
    local char=""
    IFS= read -r -s -n1 char 2>/dev/null || char=""

    if [[ "${char}" == $'\x1b' ]]; then
      local next1="" next2=""
      stty -echo -icanon min 0 time 1 2>/dev/null || true
      IFS= read -r -s -n1 next1 2>/dev/null || next1=""
      if [[ -z "${next1}" ]]; then
        # ESC key pressed
        menu_closed=1
      elif [[ "${next1}" == "[" || "${next1}" == "O" ]]; then
        IFS= read -r -s -n1 next2 2>/dev/null || next2=""
        case "${next2}" in
          A) # UP ARROW
            if (( menu_active )); then
              menu_sel=$(( menu_sel - 1 ))
            else
              if (( hist_pos > 0 )); then
                hist_pos=$((hist_pos - 1))
                buffer="${REPL_HISTORY[$hist_pos]}"
                cursor=${#buffer}
              fi
            fi
            ;;
          B) # DOWN ARROW
            if (( menu_active )); then
              menu_sel=$(( menu_sel + 1 ))
            else
              if (( hist_pos < ${#REPL_HISTORY[@]} )); then
                hist_pos=$((hist_pos + 1))
                if (( hist_pos == ${#REPL_HISTORY[@]} )); then
                  buffer=""
                else
                  buffer="${REPL_HISTORY[$hist_pos]}"
                fi
                cursor=${#buffer}
              fi
            fi
            ;;
          C) # RIGHT ARROW
            if (( cursor < ${#buffer} )); then
              cursor=$((cursor + 1))
            fi
            ;;
          D) # LEFT ARROW
            if (( cursor > 0 )); then
              cursor=$((cursor - 1))
            fi
            ;;
          3) # Delete key
            local next3=""
            IFS= read -r -s -n1 next3 2>/dev/null || next3=""
            if [[ "${next3}" == "~" ]]; then
              if (( cursor < ${#buffer} )); then
                buffer="${buffer:0:cursor}${buffer:cursor+1}"
              fi
            fi
            ;;
        esac
      fi
      stty -echo -icanon min 1 time 0 2>/dev/null || true
    elif [[ -z "${char}" ]]; then
      # Enter key pressed
      if (( menu_active )); then
        buffer="${filtered_items[$menu_sel]} "
        cursor=${#buffer}
        menu_closed=0
      else
        if (( menu_active )); then
          printf "\r\033[J"
        fi
        printf "\n"
        stty "${old_stty}" 2>/dev/null || true

        if [[ -n "${buffer}" ]]; then
          local last_idx=$(( ${#REPL_HISTORY[@]} - 1 ))
          if (( last_idx < 0 )) || [[ "${REPL_HISTORY[$last_idx]}" != "${buffer}" ]]; then
            REPL_HISTORY+=("${buffer}")
            save_history
          fi
        fi

        REPL_READ_RESULT="${buffer}"
        return 0
      fi
    elif [[ "${char}" == $'\x7f' || "${char}" == $'\x08' ]]; then
      if (( cursor > 0 )); then
        buffer="${buffer:0:cursor-1}${buffer:cursor}"
        cursor=$((cursor - 1))
      fi
      menu_closed=0
    else
      local ascii_val
      ascii_val=$(printf '%d' "'${char}" 2>/dev/null || echo 0)
      if (( ascii_val >= 32 && ascii_val <= 126 )); then
        buffer="${buffer:0:cursor}${char}${buffer:cursor}"
        cursor=$((cursor + 1))
        menu_closed=0
      fi
    fi
  done
}

run_tui_mode() {
  cache_load
  load_history
  print_welcome

  local line cmd args
  while true; do
    repl_read
    line="${REPL_READ_RESULT}"

    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    [[ -z "${line}" ]] && continue

    if [[ "${line}" == "!"* ]]; then
      local external_cmd="${line#!}"
      external_cmd="${external_cmd#"${external_cmd%%[![:space:]]*}"}"
      external_cmd="${external_cmd%"${external_cmd##*[![:space:]]}"}"
      if [[ -z "${external_cmd}" ]]; then
        cwarn "Usage: ! <command>"
      else
        clog "Running external command: ${external_cmd}"
        echo ""
        eval "${external_cmd}"
        echo ""
      fi
      continue
    fi

    read -r cmd args <<< "${line}"

    case "${cmd}" in
      /repo|/R)
        local -a cmd_args=()
        read -r -a cmd_args <<< "${args}"
        handle_repo "${cmd_args[@]:-}"
        ;;
      /workspace|/W)
        handle_workspace ${args}
        ;;
      /auth|/A)
        handle_auth ${args}
        ;;
      /bootstrap|/B)
        handle_bootstrap
        ;;
      /status|/S)
        handle_status
        ;;
      /dist-run|/D)
        handle_dist_run
        ;;
      /help|/H|help)
        print_welcome
        ;;
      /exit|/E)
        cok "Exiting WSA4SDD App. Clearing cache..."
        cache_delete
        _cleanup
        exit 0
        ;;
      *)
        cerr "Unknown command: ${cmd}. Type /help for available commands."
        ;;
    esac
  done
}

run_cli_mode() {
  clog "Running WSA4SDD App in non-interactive CLI mode..."

  if [[ ${#INPUT_REPOS[@]} -eq 0 ]]; then
    die "Missing repositories. Specify repository URLs using -I or --input."
  fi

  if [[ -z "${WORKSPACE_DIR}" ]]; then
    WORKSPACE_DIR="${PWD}"
  fi

  mkdir -p "${WORKSPACE_DIR}"
  WORKSPACE_DIR="$(cd "${WORKSPACE_DIR}" && pwd)"

  cok "Workspace resolved: ${WORKSPACE_DIR}"
  cok "Repositories: ${INPUT_REPOS[*]}"

  # In CLI mode, default to 'none' if no auth method is specified
  if [[ -z "${AUTH_METHOD}" ]]; then
    AUTH_METHOD="none"
  fi

  detect_os
  ensure_cmd git

  if [[ "${AUTH_METHOD}" == "gh" ]]; then
    ensure_cmd gh
    gh auth status >/dev/null 2>&1 || die "gh CLI not logged in"
  fi

  ensure_docker
  ensure_make

  clog "Syncing repositories..."
  sync_all_repos

  resolve_ops_dir
  load_compose_files
  generate_makefile

  if [[ "${NO_RUN}" -eq 1 ]]; then
    warn "--no-run is set. Skipping deployment execution."
    exit 0
  fi

  load_default
  local raw=()
  while IFS= read -r _t; do
    [[ -n "${_t}" ]] && raw+=("${_t}")
  done < <(list_make_up_targets)

  if [[ ${#raw[@]} -eq 0 ]]; then
    warn "No make targets found. Skipping deployment execution."
    exit 0
  fi

  local target=""
  if [[ -n "${DEFAULT_TARGET}" ]]; then
    target="${DEFAULT_TARGET}"
    cok "Using default target: ${target}"
  else
    target="${raw[0]}"
    cok "No default target set. Using first available target: ${target}"
  fi

  clog "Executing: make -C \"${OPS_DIR}\" ${target}"
  local exit_code=0
  if [[ "${OS_KIND}" == "linux" && "${DAEMON_NEEDS_SG:-0}" -eq 1 ]] && command -v sg >/dev/null 2>&1; then
    sg docker -c "cd \"${OPS_DIR}\" && make ${target}" || exit_code=$?
  else
    ( cd "${OPS_DIR}" && make "${target}" ) || exit_code=$?
  fi

  if (( exit_code != 0 )); then
    cerr "Deployment failed (make exited with ${exit_code})"
    dump_unhealthy_logs
    exit "${exit_code}"
  fi

  cok "Deployment completed successfully!"
  exit 0
}

usage() {
  cat <<EOF
WSA4SDD App (v1.0.0) — TUI & CLI Service Deployment & Distribution Tool

Usage:
  ./wsa4sdd.sh                          # Interactive TUI mode (normal REPL)
  ./wsa4sdd.sh -I "url1 url2"           # TUI mode with pre-filled repositories
  ./wsa4sdd.sh -I "url1" --cli          # Non-interactive CLI mode (direct deploy)
  ./wsa4sdd.sh -I url -w ~/work -o ops  # TUI mode with pre-filled settings
  ./wsa4sdd.sh -I url --no-run          # Non-interactive CLI dry-run (no deploy)

Options:
  -I, --input <repos>    Space-separated git repository URLs
  -w, --workspace <dir>  Workspace directory to clone repositories
  -o, --ops <name>       Ops repository name containing Makefile/docker-compose
  -c, --cli              Force non-interactive CLI mode execution
  --no-run               Skip targets deployment execution (forces CLI mode)
  -h, --help             Show this help guide
EOF
}

# ══ Entry Point ═══════════════════════════════════════════════════════════════
main() {
  local force_cli=0

  # 1. Parse CLI arguments
  while (( $# )); do
    case "$1" in
      -I|--input)
        [[ $# -ge 2 ]] || die "--input needs a value"
        shift
        while (( $# )) && [[ "$1" != -* ]]; do
          read -r -a _tmp <<< "$1"
          INPUT_REPOS+=("${_tmp[@]}")
          shift
        done
        ;;
      -w|--workspace) WORKSPACE_DIR="$2"; shift 2 ;;
      -o|--ops)       OPS_NAME="$2"; shift 2 ;;
      --no-run)       NO_RUN=1; shift ;;
      -c|--cli)       force_cli=1; shift ;;
      -h|--help)      usage; exit 0 ;;
      *)              printf 'Unknown arg: %s\n' "$1" >&2; usage; exit 1 ;;
    esac
  done

  # 2. Determine TUI vs CLI execution mode
  local run_tui=1
  if (( NO_RUN )) || (( force_cli )); then
    run_tui=0
  fi

  # 3. If TUI mode is desired but stdin is piped (e.g. curl | bash), try to redirect stdin to TTY
  if (( run_tui )) && [[ ! -t 0 ]]; then
    if [[ -c /dev/tty ]]; then
      exec < /dev/tty
    else
      run_tui=0
    fi
  fi

  # 4. Run the selected mode
  if (( run_tui )) && [[ -t 0 ]]; then
    run_tui_mode
  else
    run_cli_mode
  fi
}

main "$@"

