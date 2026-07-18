# macOS Setup Center CLI Core Engine
# ==============================================================================
# SETUP CENTER CLI — macOS / Bash Edition (Core Engine)
# ==============================================================================

set -o pipefail

# ── Self-relaunch (USB pendrive safe copy) ────────────────────────────────────
SAFE_DIR="$HOME/.local/share/setup-center"
SAFE_SCRIPT="$SAFE_DIR/setup-center-cli-mac.sh"
THIS_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || echo ".")/$(basename "${BASH_SOURCE[0]:-$0}")"
if [[ "$THIS_SCRIPT" != "$SAFE_SCRIPT" ]]; then
    mkdir -p "$SAFE_DIR" 2>/dev/null
    if cp -f "$THIS_SCRIPT" "$SAFE_SCRIPT" 2>/dev/null; then
        chmod +x "$SAFE_SCRIPT" 2>/dev/null
    fi
fi

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC}    $1"; }
log_ok()      { echo -e "${GREEN}[OK]${NC}      $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}    $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC}   $1"; }
log_section() { echo -e "\n${CYAN}${BOLD}=== $1 ===${NC}"; }

press_enter() { echo ""; read -rp "  Press Enter to return to menu..." _ < /dev/tty; }

# ── macOS guard ───────────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
    echo "ERROR: Yeh script sirf macOS ke liye hai!"
    exit 1
fi

# ── Root guard ────────────────────────────────────────────────────────────────
if [[ "$EUID" -eq 0 ]]; then
    log_error "Do NOT run this script as root. Run as a normal user."
    log_error "The script will ask for sudo when needed."
    exit 1
fi

# ── Sudo keep-alive ───────────────────────────────────────────────────────────
log_info "Acquiring sudo privileges..."
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

# ── Fix Environment & Prerequisites ───────────────────────────────────────────
fix_environment() {
    log_section "FIX ENVIRONMENT & PREREQUISITES"
    log_info "1. Checking Xcode Command Line Tools..."
    if ! xcode-select -p &>/dev/null 2>&1; then
        log_warn "Xcode Command Line Tools missing — installing..."
        xcode-select --install 2>/dev/null || true
        log_warn "Please complete the Xcode CLT installation popup window."
    else
        log_ok "Xcode Command Line Tools already installed."
    fi

    log_info "2. Checking Homebrew..."
    if ! command -v brew &>/dev/null; then
        log_warn "Homebrew not found — installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        log_ok "Homebrew is installed."
    fi

    log_info "3. Fixing Homebrew PATH..."
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
        grep -q "homebrew/bin" "$HOME/.zprofile" 2>/dev/null || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        grep -q "homebrew/bin" "$HOME/.bash_profile" 2>/dev/null || echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.bash_profile"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    log_info "4. Updating Homebrew formula cache..."
    brew update &>/dev/null || true

    log_ok "Environment fixed & ready!"
    press_enter
}

# ── Preflight: Homebrew install ───────────────────────────────────────────────
preflight_dependencies() {
    log_info "Checking base tools (Homebrew, curl, git, etc.)..."

    # Check / setup Homebrew PATH if installed
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    # Trigger Xcode CLT if missing (in background)
    if ! xcode-select -p &>/dev/null 2>&1; then
        log_warn "Xcode Command Line Tools missing — triggering installer..."
        xcode-select --install 2>/dev/null || true
    fi

    # Install Homebrew if missing (Homebrew auto-installs Xcode CLT if needed)
    if ! command -v brew &>/dev/null; then
        log_warn "Homebrew not found — installing Homebrew now..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.bash_profile"
        elif [[ -f /usr/local/bin/brew ]]; then
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi

    log_ok "Base tools check complete. Homebrew: $(brew --version 2>/dev/null | head -1 || echo 'ready')"
}
preflight_dependencies

# ── Tailscale Auto-Send Config ────────────────────────────────────────────────
NTFY_SERVER="http://192.168.126.101:8080"   # Private self-hosted ntfy (Mac Mini via Docker)
NTFY_ADMIN_CHANNEL="priyanshu-setup"

# ── Package list & selections ─────────────────────────────────────────────────
OPTIONS=(
    "Core Utilities (git, curl, wget, htop, tmux, unzip, tree)"
    "Node.js LTS (via NVM)"
    "Google Chrome"
    "Visual Studio Code"
    "MySQL Workbench"
    "DBeaver Community Edition"
    "Postman"
    "Redis Insight"
    "MongoDB Compass"
    "Tailscale VPN"
    "iTerm2 (Better Terminal)"
    "Time Doctor"
    "ESET PROTECT Agent (Antivirus/EDR)"
    "Action1 Agent (RMM)"
    "Rectangle (Window Manager)"
    "Screen Timeout (14 minutes)"
)
SELECTIONS=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)

# ── Install functions ─────────────────────────────────────────────────────────
install_core_utilities() {
    log_info "Installing core utilities via Homebrew..."
    brew install git curl wget htop tmux unzip tree coreutils gnupg
    log_ok "Core utilities installed."
}

install_node() {
    log_info "Installing NVM + Node.js LTS..."
    if [ ! -d "$HOME/.nvm" ]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash || { log_error "NVM install failed."; return 1; }
    fi
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    local nvm_snippet='export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
    for f in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zprofile"; do
        if [ -f "$f" ] && ! grep -q "NVM_DIR" "$f"; then
            echo "$nvm_snippet" >> "$f"
        fi
    done

    nvm install --lts && nvm use --lts && nvm alias default 'lts/*'
    log_ok "Node $(node -v) / npm $(npm -v) ready."
}

install_chrome() { log_info "Installing Google Chrome..."; brew install --cask google-chrome; }
install_vscode() {
    log_info "Installing Visual Studio Code..."
    brew install --cask visual-studio-code
    if ! command -v code &>/dev/null; then
        local code_path="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
        [ -f "$code_path" ] && sudo ln -sf "$code_path" /usr/local/bin/code 2>/dev/null || true
    fi
}
install_mysql_workbench() { log_info "Installing MySQL Workbench..."; brew install --cask mysqlworkbench; }
install_dbeaver()         { log_info "Installing DBeaver..."; brew install --cask dbeaver-community; }
install_postman()         { log_info "Installing Postman..."; brew install --cask postman; }
install_redisinsight()    { log_info "Installing Redis Insight..."; brew install --cask redis-insight; }
install_mongodb_compass() { log_info "Installing MongoDB Compass..."; brew install --cask mongodb-compass; }
install_tailscale()       { log_info "Installing Tailscale..."; brew install --cask tailscale; log_ok "Tailscale installed."; }
install_iterm2()          { log_info "Installing iTerm2..."; brew install --cask iterm2; }

install_timedoctor() {
    log_info "Installing Time Doctor (macOS)..."
    local tmp_dir="$HOME/.sc_tmp"; mkdir -p "$tmp_dir"
    local tmp_pkg="$tmp_dir/timedoctor.pkg"
    local td_url="https://download.timedoctor.com/3.16.69/mac/silent/sfproc-3.16.69.pkg"
    if curl -fsSL -o "$tmp_pkg" "$td_url" 2>/dev/null; then
        if sudo installer -pkg "$tmp_pkg" -target /; then
            rm -f "$tmp_pkg"; log_ok "Time Doctor installed."; return 0
        fi
        rm -f "$tmp_pkg"
    fi
    open "https://www.timedoctor.com/download.html" 2>/dev/null || true
    return 1
}

install_eset_protect() {
    log_info "Installing ESET PROTECT Agent..."
    open "https://protect.eset.com" 2>/dev/null || true
}

install_action1_agent() {
    log_info "Installing Action1 Agent..."
    local pkg="/tmp/action1_agent_mac.pkg"
    local url="https://app.action1.com/agent/6fc55c64-6a4c-11f1-9c44-05814ea2b314/macOS/agent(Saleshandy).pkg"
    if curl -fsSL -o "$pkg" "$url" 2>/dev/null; then
        if sudo installer -pkg "$pkg" -target /; then
            rm -f "$pkg"; log_ok "Action1 Agent installed."; return 0
        fi
        rm -f "$pkg"
    fi
    return 1
}

install_rectangle() { log_info "Installing Rectangle..."; brew install --cask rectangle; }

set_screen_timeout_14m() {
    log_info "Setting screen timeout to 14 minutes..."
    sudo pmset -a displaysleep 14
    defaults -currentHost write com.apple.screensaver idleTime 840 2>/dev/null || true
    log_ok "Screen timeout set to 14m."
}

uninstall_core_utilities()  { brew uninstall git curl wget htop tmux unzip tree coreutils gnupg 2>/dev/null || true; }
uninstall_node()            { rm -rf "$HOME/.nvm" "$HOME/.npm"; }
uninstall_chrome()          { brew uninstall --cask google-chrome 2>/dev/null || true; }
uninstall_vscode()          { brew uninstall --cask visual-studio-code 2>/dev/null || true; }
uninstall_mysql_workbench() { brew uninstall --cask mysqlworkbench 2>/dev/null || true; }
uninstall_dbeaver()         { brew uninstall --cask dbeaver-community 2>/dev/null || true; }
uninstall_postman()         { brew uninstall --cask postman 2>/dev/null || true; }
uninstall_redisinsight()    { brew uninstall --cask redis-insight 2>/dev/null || true; }
uninstall_mongodb_compass() { brew uninstall --cask mongodb-compass 2>/dev/null || true; }
uninstall_tailscale()       { brew uninstall --cask tailscale 2>/dev/null || true; }
uninstall_iterm2()          { brew uninstall --cask iterm2 2>/dev/null || true; }
uninstall_timedoctor()      { sudo rm -rf "/Applications/Time Doctor.app" 2>/dev/null || true; }
uninstall_eset_protect()    { sudo rm -rf "/Applications/ESET Management Agent.app" 2>/dev/null || true; }
uninstall_action1_agent()   { sudo rm -rf "/Applications/Action1.app" 2>/dev/null || true; }
uninstall_rectangle()       { brew uninstall --cask rectangle 2>/dev/null || true; }
reset_screen_timeout()      { sudo pmset -a displaysleep 5; }

is_installed() {
    case $1 in
        0)  command -v curl &>/dev/null && command -v git &>/dev/null ;;
        1)  local nd="$HOME/.nvm"; [[ -s "$nd/nvm.sh" ]] && source "$nd/nvm.sh" 2>/dev/null && command -v node &>/dev/null ;;
        2)  [ -d "/Applications/Google Chrome.app" ] ;;
        3)  [ -d "/Applications/Visual Studio Code.app" ] || command -v code &>/dev/null ;;
        4)  [ -d "/Applications/MySQLWorkbench.app" ] ;;
        5)  [ -d "/Applications/DBeaver.app" ] ;;
        6)  [ -d "/Applications/Postman.app" ] ;;
        7)  [ -d "/Applications/RedisInsight.app" ] ;;
        8)  [ -d "/Applications/MongoDB Compass.app" ] ;;
        9)  [ -d "/Applications/Tailscale.app" ] || command -v tailscale &>/dev/null ;;
        10) [ -d "/Applications/iTerm.app" ] ;;
        11) pgrep -f "Time Doctor" &>/dev/null || [ -d "/Applications/Time Doctor.app" ] || pgrep -f sfproc &>/dev/null ;;
        12) [ -d "/Applications/ESET Management Agent.app" ] ;;
        13) [ -d "/Applications/Action1.app" ] || command -v action1 &>/dev/null ;;
        14) [ -d "/Applications/Rectangle.app" ] ;;
        15) [[ "$(sudo pmset -g 2>/dev/null | awk '/displaysleep/{print $2}')" == "14" ]] ;;
        *) return 1 ;;
    esac
}

install_component() {
    case $1 in
        0) install_core_utilities ;; 1) install_node ;; 2) install_chrome ;; 3) install_vscode ;;
        4) install_mysql_workbench ;; 5) install_dbeaver ;; 6) install_postman ;; 7) install_redisinsight ;;
        8) install_mongodb_compass ;; 9) install_tailscale ;; 10) install_iterm2 ;; 11) install_timedoctor ;;
        12) install_eset_protect ;; 13) install_action1_agent ;; 14) install_rectangle ;; 15) set_screen_timeout_14m ;;
    esac
}

uninstall_component() {
    case $1 in
        0) uninstall_core_utilities ;; 1) uninstall_node ;; 2) uninstall_chrome ;; 3) uninstall_vscode ;;
        4) uninstall_mysql_workbench ;; 5) uninstall_dbeaver ;; 6) uninstall_postman ;; 7) uninstall_redisinsight ;;
        8) uninstall_mongodb_compass ;; 9) uninstall_tailscale ;; 10) uninstall_iterm2 ;; 11) uninstall_timedoctor ;;
        12) uninstall_eset_protect ;; 13) uninstall_action1_agent ;; 14) uninstall_rectangle ;; 15) reset_screen_timeout ;;
    esac
}

install_with_retry() {
    local idx=$1 name="${OPTIONS[$1]}"
    if is_installed "$idx" 2>/dev/null; then log_info "$name already installed — skipping."; return 0; fi
    while true; do
        log_section "Installing: $name"
        set +e; install_component "$idx"; local rc=$?; set -e
        if [[ $rc -eq 0 ]]; then log_ok "$name installed."; break; fi
        log_error "Failed to install $name."
        echo -e "  ${BOLD}r)${NC} Retry   ${BOLD}s)${NC} Skip   ${BOLD}a)${NC} Abort"
        read -rp "  Choice [r/s/a]: " ch < /dev/tty
        case "$ch" in
            [Rr]*) continue ;;
            [Ss]*) log_warn "Skipping $name."; break ;;
            [Aa]*) log_error "Aborted."; exit 1 ;;
            *)     log_warn "Invalid — retrying."; continue ;;
        esac
    done
}

check_status_all() {
    log_section "SOFTWARE INSTALLATION STATUS"
    local i
    for i in "${!OPTIONS[@]}"; do
        printf "  %-42s : " "${OPTIONS[$i]}"
        if is_installed "$i" 2>/dev/null; then
            echo -e "${GREEN}INSTALLED${NC}"
        else
            echo -e "${RED}NOT INSTALLED${NC}"
        fi
    done
    echo ""
}

menu_install() {
    clear
    echo -e "${MAGENTA}${BOLD}=== [3] INSTALL PACKAGES ===${NC}\n"
    while true; do
        local i
        for i in "${!OPTIONS[@]}"; do
            local cb color
            if [[ "${SELECTIONS[$i]}" -eq 1 ]]; then cb="[X]"; color="$GREEN"; else cb="[ ]"; color="$NC"; fi
            printf "  %2d) %b%s %s%b\n" "$((i+1))" "$color" "$cb" "${OPTIONS[$i]}" "$NC"
        done
        echo -e "\n  ${BOLD}e)${NC} Select all   ${BOLD}c)${NC} Clear all   ${BOLD}i)${NC} ${GREEN}Start Install${NC}   ${BOLD}b)${NC} Back"
        read -rp "  Toggle (number) or command: " ch < /dev/tty
        ch="${ch//[[:space:]]/}"

        if   [[ "$ch" =~ ^[Bb]$ ]]; then return
        elif [[ "$ch" =~ ^[Ee]$ ]]; then local j; for j in "${!SELECTIONS[@]}"; do SELECTIONS[$j]=1; done
        elif [[ "$ch" =~ ^[Cc]$ ]]; then local j; for j in "${!SELECTIONS[@]}"; do SELECTIONS[$j]=0; done
        elif [[ "$ch" =~ ^[Ii]$ ]]; then
            for i in "${!OPTIONS[@]}"; do
                [[ "${SELECTIONS[$i]}" -eq 1 ]] && install_with_retry "$i"
            done
            echo -e "\n${GREEN}${BOLD}Installation complete!${NC}"
            check_status_all
            press_enter; return
        elif [[ "$ch" =~ ^[0-9]+$ ]] && (( ch >= 1 && ch <= ${#OPTIONS[@]} )); then
            local idx=$((ch-1))
            SELECTIONS[$idx]=$(( 1 - SELECTIONS[$idx] ))
        fi
        clear
        echo -e "${MAGENTA}${BOLD}=== [3] INSTALL PACKAGES ===${NC}\n"
    done
}

menu_uninstall() {
    clear
    echo -e "${RED}${BOLD}=== UNINSTALL PACKAGES ===${NC}\n"
    for i in "${!OPTIONS[@]}"; do
        uninstall_component "$i"
    done
    press_enter
}

menu_update() {
    log_section "SYSTEM UPDATE"
    brew update && brew upgrade
    press_enter
}

menu_tailscale() {
    log_section "TAILSCALE VPN"
    install_tailscale
    press_enter
}

menu_sysconfig() {
    log_section "SYSTEM CONFIG"
    press_enter
}

menu_timedoctor() {
    log_section "TIME DOCTOR"
    install_timedoctor
    press_enter
}

menu_macos_settings() {
    log_section "MACOS SETTINGS"
    set_screen_timeout_14m
    press_enter
}

# ── MAIN MENU ─────────────────────────────────────────────────────────────────
while true; do
    clear
    echo -e "${MAGENTA}${BOLD}"
    echo "  ╔══════════════════════════════════════════════════════╗"
    echo "  ║     SETUP CENTER CLI  —  macOS / Bash Edition       ║"
    echo "  ║     Priyanshu Suryavanshi Mac Setup Toolkit         ║"
    echo "  ╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    local_brew_ver=$(brew --version 2>/dev/null | head -1 | awk '{print $2}' || echo "not installed")
    local_mac_ver=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    echo -e "  ${DIM}macOS ${local_mac_ver}  |  Homebrew ${local_brew_ver}  |  $(uname -m)${NC}\n"

    echo -e "  ${BOLD}${GREEN}[1] Fix Environment & Prerequisites${NC} — Auto-fix Homebrew, Xcode, PATH"
    echo -e "  ${BOLD}${CYAN}[2] Check System Status${NC}            — Check installed tools & services"
    echo -e "  ${BOLD}${MAGENTA}[3] Main Setup Center (Start Install)${NC} — Install tools & packages"
    echo -e "\n  ── Additional Features ─────────────────────────────────"
    echo -e "  ${BOLD}[4]${NC} Uninstall Packages    — Remove installed tools"
    echo -e "  ${BOLD}[5]${NC} Update System         — Brew update + upgrade"
    echo -e "  ${BOLD}[6]${NC} Tailscale VPN         — Install / connect"
    echo -e "  ${BOLD}[7]${NC} System Config         — Hostname & git setup"
    echo -e "  ${BOLD}[8]${NC} Time Doctor Setup     — Install / status"
    echo -e "  ${BOLD}[9]${NC} macOS Settings & WiFi — Screen timeout, dark mode"
    echo -e "  ${BOLD}[0]${NC} Exit"
    echo -e "\n  ────────────────────────────────────────────────────────"

    read -rp "  Choice: " choice < /dev/tty
    case "$choice" in
        1) fix_environment ;;
        2) check_status_all; press_enter ;;
        3) menu_install ;;
        4) menu_uninstall ;;
        5) menu_update ;;
        6) menu_tailscale ;;
        7) menu_sysconfig ;;
        8) menu_timedoctor ;;
        9) menu_macos_settings ;;
        0) echo -e "\n  ${CYAN}Goodbye!${NC}\n"; exit 0 ;;
        *) log_warn "Invalid choice — enter 0-9."; sleep 1 ;;
    esac
done
