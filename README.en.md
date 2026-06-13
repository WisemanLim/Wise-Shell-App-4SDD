# WSA4SDD (Wise Shell App for Service Deployment & Distribution)

WSA4SDD (Wise Shell App) is a **Claude Code-style interactive deployment and distribution shell** designed to manage multi-repository service syncs and Docker Compose configurations directly in your terminal.

Improving upon rigid, wizard-like deployment scripts (such as `dist-ss-tui.sh`), WSA4SDD introduces a flexible TUI REPL that lets users configure variables in any order, verify environment setups, run pre-flight checks, and trigger Docker Compose distributions safely using intuitive commands.

It also supports standard CLI arguments parsing and handles non-interactive pipelines (like `curl -fsSL ... | bash`) for completely automated remote deployments.

---

## 1. Core Features

### A. Claude Code-Style TUI & REPL
- Displays an intuitive welcome description banner and a horizontal divider line (`───`) outlining system state and available commands.
- Features a custom-built advanced line editor and REPL prompt (`>    `):
  - **Input History**: Navigate and recall previously executed command histories (synchronized with `/tmp/.wsa4sdd_history`) using UP/DOWN arrow keys.
  - **In-Place Editing**: Move the cursor interactively using LEFT/RIGHT arrow keys, and modify inputs using Backspace and Delete keys.
  - **Autocomplete Popover**: Pressing the `/` key on an empty prompt pops up a dropdown selection menu of all available commands. Navigate using UP/DOWN keys and press `Enter` to auto-fill the selected command into the prompt buffer.
- Detects non-interactive pipeline environments (`! -t 0`) or active CLI arguments, automatically bypassing the TUI to execute in direct CLI mode.

### B. Command-Driven Steps Configuration
Each stage of the deployment pipeline is managed as a standalone shell command:
- `/repo [repo1 repo2...]`, `/R [repo1 repo2...]`: Configure git repository lists directly, or open the Repository Manager (supporting add, delete, and arrow-key reordering) if empty.
- `/workspace [path]`, `/W [path]`: Set target workspace folder where repos are cloned, or open the TUI selection menu (Current, Parent, Custom) if empty.
- `/auth [gh|pat|none]`, `/A [gh|pat|none]`: Set GitHub credentials, or open the selector menu if empty.
- `/bootstrap`, `/B`: Perform dependency check (git, gh, docker, make), clone/pull synced repositories, and generate/verify Makefiles.
- `/status`, `/S`: Reviews current settings and checks for missing required parameters.
- `/dist-run`, `/D`: Pre-flight configuration validation, runs optional pre-run hooks, and launches the Make targets deployment selector.
- `/help`, `/H`: Displays the help instructions and command manual.
- `/exit`, `/E`: Exits the session and completely purges saved caches.
- `! <command>`: Executes a local shell command (e.g. `! pwd`, `! ls -la`) immediately within the interactive REPL and displays the output.

### C. Interactive Repository Manager & Reordering
- Typing `/repo` or `/R` without parameters opens the interactive **Repository Manager** sub-menu:
  - **Add Repository**: Registers new URLs (limit of 8).
  - **Delete Repository**: Opens a quick selector to remove registered items.
  - **Change Order (Reorder)**: An interactive selector that uses arrow keys (`UP`/`DOWN` or `k`/`j`) to swap positions in-place, allowing user-customized distribution sequences. Press `Enter` to lock the selected item, and select `Done` (or press `ESC`) to save and exit.

### D. Smart Session Cache
- Configured parameters are serialized to `/tmp/.wsa4sdd-${UID}.cache` on every update.
- If the terminal disconnects or terminates unexpectedly, the session state is restored upon reboot.
- If the deployment finishes successfully (`/dist-run` done) or if the user exits cleanly (via `/exit` or pressing `Ctrl+C` twice within 2 seconds), the cache file is deleted.

---

## 2. TUI Layout & Commands

When starting `wsa4sdd.sh` interactively, the terminal displays the welcome header:

```
  WSA4SDD App (v1.0.0) — Service Deployment and Distribution Shell
  Lives in your terminal, manages git repos, and deploys docker-compose.
  ─────────────────────────────────────────────────────────────────────────────
  Commands:
    /repo, /R [repo1 repo2...]    Configure repository URLs to deploy (or open manager if empty)
    /workspace, /W [path]       Configure target workspace directory path (or open menu if empty)
    /auth, /A [gh|pat|none]     Configure GitHub credentials (or open menu if empty)
    /bootstrap, /B              Verify dependencies and sync git repositories
    /status, /S                 Show current configuration status
    /dist-run, /D               Verify configurations and run make deployment
    /help, /H                   Show this help message
    /exit, /E                   Exit wsa4sdd shell and clear cache
    ! <command>                 Execute a shell command and display the output
  ─────────────────────────────────────────────────────────────────────────────

>    
```

### Detailed Commands Guide

#### 1. Repository Configuration (`/repo`, `/R`)
- **CLI direct**: Overwrite target repos by passing arguments: `/repo <url1> <url2>`.
- **TUI interactive**: Call `/repo` with no arguments to manage items interactively.
  - Use `Add Repository` to append and `Delete` to remove.
  - Select `Change Order` to select an item and use arrow keys to swap its index position.

#### 2. Target Workspace (`/workspace`, `/W`)
- **CLI direct**: `/workspace /path/to/dir`
- **TUI interactive**: Call `/workspace` to select between `Current dir (./)`, `Parent dir (../)`, and `Custom path...`.

#### 3. Authentication Protocol (`/auth`, `/A`)
- **CLI direct**: `/auth <gh|pat|none>`
- **TUI interactive**: Opens the selector menu. Choosing `pat` prompts for your GitHub Username and Token. (Tokens are written to an encrypted temporary helper file and removed automatically when the script exits).

#### 4. Run Deployment (`/dist-run`, `/D`)
- Validates the configurations. If inputs are missing, it guides the user with suggestion commands.
- Triggers `/bootstrap` automatically if repositories haven't been synchronized yet.
- Parses the parsed Makefile targets (such as `up-*`) and shows them as a visual arrow-key menu.
- Runs user-defined pre-run commands and triggers `make <target>`. On success, cache is wiped, and the script exits.

---

## 3. Remote Execution & Local Installation Guide

### A. Remote Direct Execution (curl | bash)
You can execute the script directly from the remote repository without downloading it, which is ideal for one-off tasks or CI/CD pipelines.
Arguments can be appended to configure the app before running, allowing you to choose between launching the interactive TUI or non-interactive CLI.

```bash
# 1) Remote TUI mode (pre-populate inputs, but launch interactive REPL)
curl -fsSL https://raw.githubusercontent.com/WisemanLim/Wise-Shell-App-4SDD/refs/heads/main/wsa4sdd.sh \
  | bash -s -- -I "https://github.com/ClaroPessoas/claro-svc" -w "~/workspace"

# 2) Remote non-interactive CLI mode (trigger automated deployment immediately)
curl -fsSL https://raw.githubusercontent.com/WisemanLim/Wise-Shell-App-4SDD/refs/heads/main/wsa4sdd.sh \
  | bash -s -- -I "https://github.com/ClaroPessoas/claro-svc" --cli

# 3) Remote non-interactive CLI dry-run (perform setup/sync but skip deployment)
curl -fsSL https://raw.githubusercontent.com/WisemanLim/Wise-Shell-App-4SDD/refs/heads/main/wsa4sdd.sh \
  | bash -s -- -I "https://github.com/ClaroPessoas/claro-svc" --no-run
```

---

### B. Script Download & Local Installation
To download the script to your local system for persistent usage:

1. **Download and make executable**:
   ```bash
   curl -fsSL -o wsa4sdd.sh https://raw.githubusercontent.com/WisemanLim/Wise-Shell-App-4SDD/refs/heads/main/wsa4sdd.sh
   chmod +x wsa4sdd.sh
   ```

2. **Install to System PATH for global access (Optional)**:
   ```bash
   # Move the script to a folder in your system PATH (e.g. /usr/local/bin)
   sudo mv wsa4sdd.sh /usr/local/bin/wsa4sdd
   ```

3. **Local Execution & Parameter Passing Examples**:
   ```bash
   # Standalone execution (starts TUI mode by default)
   wsa4sdd
   
   # Pre-populate variables and launch interactive TUI mode
   wsa4sdd -I "https://github.com/ClaroPessoas/claro-svc" -w "~/workspace"
   
   # Force non-interactive CLI mode for immediate deployment
   wsa4sdd -I "https://github.com/ClaroPessoas/claro-svc" --cli
   
   # Force non-interactive CLI dry-run (skip deployment target execution)
   wsa4sdd -I "https://github.com/ClaroPessoas/claro-svc" --no-run
   ```


### CLI Options

| Option | Description | Example |
| :--- | :--- | :--- |
| `-I, --input` | Space-separated list of repository URLs. | `-I "url1 url2"` |
| `-w, --workspace` | Destination folder to clone repos. | `-w ~/dev/workspace` |
| `-o, --ops` | The name of the primary operations repository hosting the Makefile/docker-compose files. | `-o my-ops-repo` |
| `--no-run` | Syncs repositories and runs build bootstrapping (like Makefile generation) but skips target deployment. | `--no-run` |
| `-h, --help` | Shows the CLI arguments usage guide. | `-h` |

---

## 4. Tests and Verification

The package includes an automated diagnostic test suite in [verify.sh](verify.sh).

```bash
# Run local verification suite
./verify.sh
```

`verify.sh` tests:
1. File permissions and `--help` output of `wsa4sdd.sh`.
2. Validation rules when executing in CLI mode with missing parameters.
3. Cache serialization and deserialization functions.
4. Simulates a complete dry-run deployment by spinning up a dummy local git repository and verifying cloning, build parsing, and Makefile generator steps.

---

## 5. Compatibility & Requirements

- **100% Native macOS Support**: The default macOS shell is `/bin/bash` (v3.2.x). To ensure seamless execution without requiring bash upgrades or external packages, `wsa4sdd.sh` was built from the ground up to avoid Bash 4.x+ specific patterns, such as `local -n` (namerefs) and associative arrays (`declare -A`).
- **Automatic Environment Verification**: During interactive launch or `/bootstrap`, the script automatically checks if core dependencies (`git`, `docker`, `docker compose`, `make`) are installed on the host system, notifying the user about any missing requirements.

---

## 6. GitHub Private Repository Integration Guide

To safely synchronize and deploy Private Repositories, you must configure the correct Git address format and credentials. Please follow the instructions below.

### A. Copying Git Repository Addresses
Navigate to your target Repository page on the GitHub Web Console, click the green **[Code]** button at the top right, and copy the address.

1. **HTTPS Address**
   - **Format**: `https://github.com/<Owner>/<Repo>.git`
   - **Auth Mode**: Choose this format if you plan to use `/auth pat` (Personal Access Token) or `gh` CLI login.
2. **SSH Address**
   - **Format**: `git@github.com:<Owner>/<Repo>.git`
   - **Auth Mode**: Choose this format if your server already has SSH Keys registered and configured to clone without prompts. Set `/auth none` in the script, and Git will handle SSH key verification under the hood.

---

### B. Generating a Personal Access Token (PAT)
If you configure `/auth pat`, you will need a personal access token generated from GitHub.

1. **Navigate to the Token Settings**:
   - Click your profile image in the top-right corner of GitHub ➔ **Settings**.
   - Select **Developer settings** at the bottom-left sidebar.
   - Select **Personal access tokens**.

2. **Fine-grained Personal Access Tokens (Recommended)**:
   - Click **[Generate new token]**.
   - Define a **Token name** and **Expiration** date.
   - **Repository access**:
     - Select **[Only select repositories]** to limit token access to specific deployment repos.
     - Select **[All repositories]** to allow access to all your repos.
   - **Permissions**:
     - Go to **Repository permissions** ➔ **Contents** and select **Read-only** (or **Read and write**).
   - Click **[Generate token]** at the bottom and copy the generated token (save it securely as it will not be shown again).

3. **Tokens (classic)**:
   - Click **[Generate new token]** ➔ **[Generate new token (classic)]**.
   - Input a name in **Note** and select the **Expiration**.
   - **Select scopes**: Check the **`repo`** scope (required to access private repositories).
   - Click **[Generate token]** at the bottom and copy your token.

---

### C. Authentication Configuration Examples (`/auth`)
* **PAT Authentication**: Type `/auth pat` and input your GitHub **Username** and the generated **PAT** token sequentially when prompted.
* **SSH Authentication**: Input the SSH URL format (`git@github.com:...`) when setting up repositories, and set `/auth none`.
* **GitHub CLI (gh) Auth**: If `gh` CLI is installed and logged in on the host, configure `/auth gh` to authenticate automatically.
