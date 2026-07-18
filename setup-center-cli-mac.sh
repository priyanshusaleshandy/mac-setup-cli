#!/bin/sh
# ── Universal Auto-Relaunch (Direct Copy-Paste & File Execution Fix) ─────────
if [ -z "$BASH_VERSION" ]; then
    if [ -f "$0" ] && [ "$0" != "zsh" ] && [ "$0" != "-zsh" ] && [ "$0" != "sh" ] && [ "$0" != "-sh" ]; then
        exec bash "$0" "$@"
    else
        exec bash -c "$(curl -fsSL https://raw.githubusercontent.com/priyanshusaleshandy/mac-setup-cli/main/setup-center-cli-mac.sh)"
    fi
    exit 0
fi
# ── Ab yahan se Pure Bash environment chal raha hai ──────────────────────────
# ==============================================================================
# SETUP CENTER CLI — macOS / Bash Edition
# ==============================================================================
# Ubuntu wali script ka macOS version:
#
#  [1] Install Packages        — select from tools via checkbox menu
#  [2] Uninstall Packages      — remove selected or all packages
#  [3] System Status           — show what's installed / running
#  [4] Update System           — brew update + upgrade
#  [5] Tailscale VPN           — install / login / connect / diagnose / remove
#  [6] System Config           — hostname, git config
#  [7] Time Doctor Setup       — install / uninstall / status
#  [8] macOS Settings          — screen timeout, dark mode, Gatekeeper
#  [9] Network / WiFi Diagnose — DNS flush, connectivity check
#  [0] Exit
#
# Usage:
#   chmod +x setup-center-cli-mac.sh
#   ./setup-center-cli-mac.sh
#
# Requirements: macOS 12+ (Monterey or newer recommended)
# ==============================================================================

set -uo pipefail

# ── Self-relaunch (USB pendrive safe copy) ────────────────────────────────────
SAFE_DIR="$HOME/.local/share/setup-center"
SAFE_SCRIPT="$SAFE_DIR/setup-center-cli-mac.sh"
THIS_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
if [[ "$THIS_SCRIPT" != "$SAFE_SCRIPT" ]]; then
    mkdir -p "$SAFE_DIR" 2>/dev/null
    if cp -f "$THIS_SCRIPT" "$SAFE_SCRIPT" 2>/dev/null; then
        chmod +x "$SAFE_SCRIPT" 2>/dev/null
        exec bash "$SAFE_SCRIPT" "$@"
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

# ── Preflight: Homebrew install ───────────────────────────────────────────────
preflight_dependencies() {
    log_info "Checking base tools (Homebrew, curl, git, etc.)..."

    # Install Xcode Command Line Tools if missing
    if ! xcode-select -p &>/dev/null 2>&1; then
        log_warn "Xcode Command Line Tools missing — installing..."
        xcode-select --install 2>/dev/null || true
        log_warn "Please complete the Xcode CLT installation popup, then re-run this script."
        press_enter
        exit 0
    fi

    # Install Homebrew if missing
    if ! command -v brew &>/dev/null; then
        log_warn "Homebrew not found — installing now..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        # Add brew to PATH for Apple Silicon
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.bash_profile"
        fi
    fi

    # Make sure brew is in PATH
    if [[ -f /opt/homebrew/bin/brew ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f /usr/local/bin/brew ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi

    log_ok "Base tools ready. Homebrew: $(brew --version | head -1)"
}
preflight_dependencies

# ── Tailscale Auto-Send Config ────────────────────────────────────────────────
# Change these if you ever move to a different Admin channel or server.
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
SELECTIONS=(0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0)   # all unselected by default

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
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    # Add to shell profiles
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

install_chrome() {
    log_info "Installing Google Chrome..."
    brew install --cask google-chrome
}

install_vscode() {
    log_info "Installing Visual Studio Code..."
    brew install --cask visual-studio-code
    # Add 'code' command to PATH (macOS sometimes needs this)
    if ! command -v code &>/dev/null; then
        local code_path="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
        if [ -f "$code_path" ]; then
            sudo ln -sf "$code_path" /usr/local/bin/code 2>/dev/null || true
        fi
    fi
}

install_mysql_workbench() {
    log_info "Installing MySQL Workbench..."
    brew install --cask mysqlworkbench
}

install_dbeaver() {
    log_info "Installing DBeaver Community Edition..."
    brew install --cask dbeaver-community
}

install_postman() {
    log_info "Installing Postman..."
    brew install --cask postman
}

install_redisinsight() {
    log_info "Installing Redis Insight..."
    brew install --cask redis-insight
}

install_mongodb_compass() {
    log_info "Installing MongoDB Compass..."
    brew install --cask mongodb-compass
}

install_tailscale() {
    log_info "Installing Tailscale VPN..."
    brew install --cask tailscale
    log_ok "Tailscale installed."
    log_info "First time: macOS will ask for System Extension approval in Security & Privacy."
    log_info "Open Tailscale from menu bar to complete setup."
}

install_iterm2() {
    log_info "Installing iTerm2..."
    brew install --cask iterm2
    log_ok "iTerm2 installed. Find it in /Applications/iTerm.app"
}

install_timedoctor() {
    log_info "Installing Time Doctor (macOS)..."
    local tmp_dir="$HOME/.sc_tmp"
    mkdir -p "$tmp_dir"
    local tmp_pkg="$tmp_dir/timedoctor.pkg"

    # Try the pkg installer (silent macOS)
    local td_url="https://download.timedoctor.com/3.16.69/mac/silent/sfproc-3.16.69.pkg"
    log_info "Downloading Time Doctor for macOS..."
    if curl -fsSL -o "$tmp_pkg" "$td_url" 2>/dev/null; then
        if sudo installer -pkg "$tmp_pkg" -target /; then
            rm -f "$tmp_pkg"
            log_ok "Time Doctor installed."
            return 0
        fi
        rm -f "$tmp_pkg"
    fi

    # Fallback: open download page
    log_warn "Auto-download failed. Opening download page..."
    open "https://www.timedoctor.com/download.html" 2>/dev/null || true
    log_info "Please download and install Time Doctor manually."
    return 1
}

install_eset_protect() {
    log_info "Installing ESET PROTECT Agent (macOS)..."
    log_warn "ESET PROTECT Agent for macOS requires manual installation."
    log_info ""
    log_info "Steps:"
    log_info "  1. Contact your admin for the macOS ESET installer package."
    log_info "  2. Or visit: https://protect.eset.com"
    log_info "  3. Download the .pkg installer and run it."
    log_info ""
    read -rp "  Open ESET Protect portal in browser? (y/N): " conf < /dev/tty
    if [[ "$conf" =~ ^[Yy]$ ]]; then
        open "https://protect.eset.com" 2>/dev/null || true
    fi
}

install_action1_agent() {
    log_info "Installing Action1 Agent (RMM) for macOS..."
    local pkg="/tmp/action1_agent_mac.pkg"
    local url="https://app.action1.com/agent/6fc55c64-6a4c-11f1-9c44-05814ea2b314/macOS/agent(Saleshandy).pkg"

    if curl -fsSL -o "$pkg" "$url" 2>/dev/null; then
        if sudo installer -pkg "$pkg" -target /; then
            rm -f "$pkg"
            log_ok "Action1 Agent installed & registered."
        else
            log_error "Action1 Agent installation failed."
            rm -f "$pkg"
            log_info "Try downloading manually from: https://app.action1.com"
            return 1
        fi
    else
        log_error "Failed to download Action1 Agent."
        log_info "Download manually from: https://app.action1.com"
        log_info "Look for macOS/PKG installer for org: Saleshandy"
        return 1
    fi
}

install_rectangle() {
    log_info "Installing Rectangle (Window Manager)..."
    brew install --cask rectangle
    log_ok "Rectangle installed. Open it from /Applications/Rectangle.app"
}

set_screen_timeout_14m() {
    log_info "Setting display sleep to 14 minutes..."
    sudo pmset -a displaysleep 14
    # Also set screen saver timeout
    defaults -currentHost write com.apple.screensaver idleTime 840 2>/dev/null || true
    log_ok "Display sleep set to 14 minutes (840 seconds)."
}

# ── Uninstall functions ───────────────────────────────────────────────────────
uninstall_core_utilities()  {
    log_info "Removing core utilities..."
    brew uninstall git curl wget htop tmux unzip tree coreutils gnupg 2>/dev/null || true
}
uninstall_node()            {
    log_info "Removing NVM & Node.js..."
    rm -rf "$HOME/.nvm" "$HOME/.npm"
    for f in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.zprofile"; do
        [ -f "$f" ] && sed -i '' '/NVM_DIR/d' "$f" 2>/dev/null || true
    done
    log_ok "NVM removed."
}
uninstall_chrome()          { log_info "Removing Google Chrome..."; brew uninstall --cask google-chrome 2>/dev/null || true; }
uninstall_vscode()          {
    log_info "Removing VS Code..."
    brew uninstall --cask visual-studio-code 2>/dev/null || true
    sudo rm -f /usr/local/bin/code 2>/dev/null || true
}
uninstall_mysql_workbench() { log_info "Removing MySQL Workbench..."; brew uninstall --cask mysqlworkbench 2>/dev/null || true; }
uninstall_dbeaver()         { log_info "Removing DBeaver..."; brew uninstall --cask dbeaver-community 2>/dev/null || true; }
uninstall_postman()         { log_info "Removing Postman..."; brew uninstall --cask postman 2>/dev/null || true; }
uninstall_redisinsight()    { log_info "Removing Redis Insight..."; brew uninstall --cask redis-insight 2>/dev/null || true; }
uninstall_mongodb_compass() { log_info "Removing MongoDB Compass..."; brew uninstall --cask mongodb-compass 2>/dev/null || true; }
uninstall_tailscale()       {
    log_info "Removing Tailscale..."
    brew uninstall --cask tailscale 2>/dev/null || true
    sudo rm -rf /Applications/Tailscale.app 2>/dev/null || true
    log_ok "Tailscale removed."
}
uninstall_iterm2()          { log_info "Removing iTerm2..."; brew uninstall --cask iterm2 2>/dev/null || true; }
uninstall_timedoctor()      {
    log_info "Removing Time Doctor..."
    pkill -f "Time Doctor" 2>/dev/null || true
    pkill -f sfproc 2>/dev/null || true
    if [ -f "/Applications/Time Doctor.app/Contents/Resources/uninstall" ]; then
        sudo "/Applications/Time Doctor.app/Contents/Resources/uninstall" 2>/dev/null || true
    fi
    sudo rm -rf "/Applications/Time Doctor.app" 2>/dev/null || true
    rm -rf "$HOME/Library/Application Support/Time Doctor" 2>/dev/null || true
    rm -rf "$HOME/Library/Preferences/com.timedoctor."* 2>/dev/null || true
    log_ok "Time Doctor removed."
}
uninstall_eset_protect()    {
    log_info "Removing ESET PROTECT Agent..."
    local uninstall_script="/Library/Application Support/com.eset.remoteadministrator.agent/Uninstall.sh"
    if [ -f "$uninstall_script" ]; then
        sudo sh "$uninstall_script" 2>/dev/null || true
    else
        sudo rm -rf "/Applications/ESET Management Agent.app" 2>/dev/null || true
        sudo pkgutil --forget com.eset.remoteadministrator.agent 2>/dev/null || true
    fi
    log_ok "ESET PROTECT Agent removed (or was not installed)."
}
uninstall_action1_agent()   {
    log_info "Removing Action1 Agent..."
    if command -v action1 &>/dev/null; then
        sudo action1 --uninstall 2>/dev/null || true
    fi
    sudo pkgutil --forget com.action1.agent 2>/dev/null || true
    sudo rm -rf "/Applications/Action1.app" 2>/dev/null || true
    log_ok "Action1 Agent removed."
}
uninstall_rectangle()       { log_info "Removing Rectangle..."; brew uninstall --cask rectangle 2>/dev/null || true; }
reset_screen_timeout()      {
    log_info "Resetting screen timeout to default (5 minutes)..."
    sudo pmset -a displaysleep 5
    defaults -currentHost write com.apple.screensaver idleTime 300 2>/dev/null || true
    log_ok "Display sleep reset to 5 minutes."
}

# ── Is-installed checks ───────────────────────────────────────────────────────
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
        12) [ -d "/Applications/ESET Management Agent.app" ] || [ -f "/Library/Application Support/com.eset.remoteadministrator.agent/Uninstall.sh" ] ;;
        13) [ -d "/Applications/Action1.app" ] || command -v action1 &>/dev/null ;;
        14) [ -d "/Applications/Rectangle.app" ] ;;
        15) [[ "$(sudo pmset -g 2>/dev/null | awk '/displaysleep/{print $2}')" == "14" ]] ;;
        *) return 1 ;;
    esac
}

install_component() {
    case $1 in
        0)  install_core_utilities ;;
        1)  install_node ;;
        2)  install_chrome ;;
        3)  install_vscode ;;
        4)  install_mysql_workbench ;;
        5)  install_dbeaver ;;
        6)  install_postman ;;
        7)  install_redisinsight ;;
        8)  install_mongodb_compass ;;
        9)  install_tailscale ;;
        10) install_iterm2 ;;
        11) install_timedoctor ;;
        12) install_eset_protect ;;
        13) install_action1_agent ;;
        14) install_rectangle ;;
        15) set_screen_timeout_14m ;;
    esac
}

uninstall_component() {
    case $1 in
        0)  uninstall_core_utilities ;;
        1)  uninstall_node ;;
        2)  uninstall_chrome ;;
        3)  uninstall_vscode ;;
        4)  uninstall_mysql_workbench ;;
        5)  uninstall_dbeaver ;;
        6)  uninstall_postman ;;
        7)  uninstall_redisinsight ;;
        8)  uninstall_mongodb_compass ;;
        9)  uninstall_tailscale ;;
        10) uninstall_iterm2 ;;
        11) uninstall_timedoctor ;;
        12) uninstall_eset_protect ;;
        13) uninstall_action1_agent ;;
        14) uninstall_rectangle ;;
        15) reset_screen_timeout ;;
    esac
}

# ── Install with retry ────────────────────────────────────────────────────────
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

# ── Status check ──────────────────────────────────────────────────────────────
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
    # Extra: Tailscale service status
    echo ""
    printf "  %-42s : " "Tailscale (service running)"
    if pgrep -x "Tailscale" &>/dev/null || pgrep -f "tailscaled" &>/dev/null; then
        echo -e "${GREEN}RUNNING${NC}"
    else
        echo -e "${YELLOW}NOT RUNNING${NC}"
    fi
    echo ""
}

# ── [1] Install packages ──────────────────────────────────────────────────────
menu_install() {
    clear
    echo -e "${MAGENTA}${BOLD}=== [1] INSTALL PACKAGES ===${NC}\n"
    echo -e "Current selection (toggle with number, then press ${GREEN}i${NC} to install):\n"

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
            read -rp "  Reboot now? (y/N): " rb < /dev/tty
            [[ "$rb" =~ ^[Yy]$ ]] && sudo shutdown -r now
            return
        elif [[ "$ch" =~ ^[0-9]+$ ]] && (( ch >= 1 && ch <= ${#OPTIONS[@]} )); then
            local idx=$((ch-1))
            SELECTIONS[$idx]=$(( 1 - SELECTIONS[$idx] ))
        else
            log_warn "Invalid input."
        fi
        clear
        echo -e "${MAGENTA}${BOLD}=== [1] INSTALL PACKAGES ===${NC}\n"
        echo -e "Current selection:\n"
    done
}

# ── [2] Uninstall packages ────────────────────────────────────────────────────
menu_uninstall() {
    clear
    echo -e "${RED}${BOLD}=== [2] UNINSTALL PACKAGES ===${NC}\n"

    while true; do
        local i
        for i in "${!OPTIONS[@]}"; do
            local cb color
            if [[ "${SELECTIONS[$i]}" -eq 1 ]]; then cb="[X]"; color="$GREEN"; else cb="[ ]"; color="$NC"; fi
            printf "  %2d) %b%s %s%b\n" "$((i+1))" "$color" "$cb" "${OPTIONS[$i]}" "$NC"
        done
        echo -e "\n  ${BOLD}e)${NC} Select all   ${BOLD}c)${NC} Clear all   ${BOLD}u)${NC} ${RED}Uninstall Selected${NC}   ${BOLD}a)${NC} ${RED}Uninstall ALL${NC}   ${BOLD}b)${NC} Back"
        read -rp "  Toggle (number) or command: " ch < /dev/tty
        ch="${ch//[[:space:]]/}"

        if   [[ "$ch" =~ ^[Bb]$ ]]; then return
        elif [[ "$ch" =~ ^[Ee]$ ]]; then local j; for j in "${!SELECTIONS[@]}"; do SELECTIONS[$j]=1; done
        elif [[ "$ch" =~ ^[Cc]$ ]]; then local j; for j in "${!SELECTIONS[@]}"; do SELECTIONS[$j]=0; done
        elif [[ "$ch" =~ ^[Uu]$ || "$ch" =~ ^[Aa]$ ]]; then
            local scope="selected"; [[ "$ch" =~ ^[Aa]$ ]] && scope="all"
            echo ""
            read -rp "  Confirm uninstall $scope? (y/N): " conf < /dev/tty
            if [[ "$conf" =~ ^[Yy]$ ]]; then
                for i in "${!OPTIONS[@]}"; do
                    if [[ "$scope" == "all" || "${SELECTIONS[$i]}" -eq 1 ]]; then
                        echo -e "\n${YELLOW}Removing: ${OPTIONS[$i]}...${NC}"
                        set +e; uninstall_component "$i"; set -e
                    fi
                done
                log_ok "Uninstall complete."
                check_status_all
                press_enter; return
            fi
        elif [[ "$ch" =~ ^[0-9]+$ ]] && (( ch >= 1 && ch <= ${#OPTIONS[@]} )); then
            local idx=$((ch-1))
            SELECTIONS[$idx]=$(( 1 - SELECTIONS[$idx] ))
        else log_warn "Invalid input."; fi
        clear
        echo -e "${RED}${BOLD}=== [2] UNINSTALL PACKAGES ===${NC}\n"
    done
}

# ── [4] System update ─────────────────────────────────────────────────────────
menu_update() {
    log_section "SYSTEM UPDATE (Homebrew + macOS)"
    log_info "Running brew update + upgrade..."
    brew update
    brew upgrade
    brew upgrade --cask --greedy 2>/dev/null || brew upgrade --cask
    brew cleanup
    log_ok "Homebrew packages updated."
    echo ""
    log_info "Checking macOS software updates..."
    softwareupdate -l 2>/dev/null || true
    echo ""
    read -rp "  Install all available macOS updates now? (y/N): " conf < /dev/tty
    if [[ "$conf" =~ ^[Yy]$ ]]; then
        softwareupdate -i -a
        log_ok "macOS updates installed."
    fi
    press_enter
}

# ── [5] Tailscale VPN ─────────────────────────────────────────────────────────
menu_tailscale() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}=== [5] TAILSCALE VPN ===${NC}\n"
        echo -e "  [1] Install Tailscale"
        echo -e "  [2] Login  (auto-sent to Admin — no typing)"
        echo -e "  [3] Connect (accept routes)"
        echo -e "  [4] Full Reset + Connect (reset + accept DNS & routes)"
        echo -e "  [5] Connect with Exit Node (100.64.0.7)"
        echo -e "  [6] Diagnose & Status"
        echo -e "  [7] Uninstall Tailscale"
        echo -e "  [0] Back\n"

        local server="https://bifrost.saleshandy.com"
        read -rp "  Choice: " ch < /dev/tty
        case "$ch" in
            1) install_tailscale; press_enter ;;
            2)
                clear
                echo -e "${CYAN}${BOLD}=== [5.2] TAILSCALE LOGIN / REGISTER ===${NC}\n"
                echo -e "  [1] Auto-send Login Link to Admin (no typing, no QR)"
                echo -e "  [2] Auth Key Login    (Use pre-authorized key from Admin)"
                echo -e "  [0] Back\n"
                read -rp "  Select Login Method: " subChoice < /dev/tty
                if [[ "$subChoice" -eq 1 ]]; then
                    NTFY_TOPIC="$NTFY_ADMIN_CHANNEL"
                    NTFY_TOPIC="${NTFY_TOPIC#$NTFY_SERVER/}"
                    NTFY_TOPIC="${NTFY_TOPIC%/}"
                    log_info "Requesting login link (will auto-send to '$NTFY_TOPIC')..."
                    log_warn "This forces a fresh login — if SSH'd in over Tailscale, that session may drop."
                    TS_LOG="$(mktemp)"
                    sudo tailscale up --login-server="$server" --accept-routes --accept-dns --force-reauth > "$TS_LOG" 2>&1 &
                    TS_PID=$!
                    LOGIN_URL=""
                    for _ in $(seq 1 30); do
                        LOGIN_URL=$(grep -oE 'https://[^ ]+' "$TS_LOG" 2>/dev/null | head -1)
                        [[ -n "$LOGIN_URL" ]] && break
                        kill -0 "$TS_PID" 2>/dev/null || break
                        sleep 1
                    done
                    cat "$TS_LOG"
                    if [[ -n "$LOGIN_URL" ]]; then
                        log_info "Sending link to Admin channel '$NTFY_TOPIC'..."
                        if curl -fsSL --max-time 10 -d "New Mac ($(hostname)) Tailscale login: $LOGIN_URL" "$NTFY_SERVER/$NTFY_TOPIC" &>/dev/null; then
                            log_ok "Link sent! Admin should open: $NTFY_SERVER/$NTFY_TOPIC"
                        else
                            log_warn "Auto-send failed (server unreachable). Admin can use the URL above."
                        fi
                    else
                        log_ok "Already logged in — no link needed."
                    fi
                    wait "$TS_PID" 2>/dev/null
                    rm -f "$TS_LOG"
                elif [[ "$subChoice" -eq 2 ]]; then
                    read -rp "  Enter Tailscale Auth Key (tskey-auth-...): " authKey < /dev/tty
                    if [[ -z "$authKey" ]]; then
                        log_warn "Cancelled."
                    else
                        log_info "Registering node using Auth Key..."
                        sudo tailscale up --authkey="$authKey" --login-server="$server" --accept-routes --accept-dns
                        log_ok "Node registered with Auth Key!"
                    fi
                fi
                press_enter ;;
            3) sudo tailscale up --accept-routes --login-server="$server"; press_enter ;;
            4) sudo tailscale up --login-server="$server" --reset --accept-dns --accept-routes; press_enter ;;
            5) sudo tailscale up --login-server="$server" --accept-dns --accept-routes --exit-node=100.64.0.7; press_enter ;;
            6)
                log_section "TAILSCALE DIAGNOSTICS"
                log_info "Status:";
                sudo tailscale status 2>/dev/null || log_warn "tailscale not running"
                log_info "IP:";
                sudo tailscale ip 2>/dev/null || true
                log_info "Ping test (100.64.0.1):";
                sudo tailscale ping 100.64.0.1 2>/dev/null || log_warn "Ping failed"
                log_info "App running:";
                pgrep -x "Tailscale" &>/dev/null && echo "Tailscale.app: RUNNING" || echo "Tailscale.app: NOT RUNNING"
                press_enter ;;
            7)
                read -rp "  Confirm uninstall Tailscale? (y/N): " conf < /dev/tty
                [[ "$conf" =~ ^[Yy]$ ]] && uninstall_tailscale && log_ok "Tailscale removed."
                press_enter ;;
            0) return ;;
            *) log_warn "Invalid choice." ;;
        esac
    done
}

# ── [6] System config ─────────────────────────────────────────────────────────
configure_system_settings() {
    log_section "SYSTEM HOSTNAME & GIT SETUP"
    local cur_host; cur_host=$(hostname)
    echo "  Current hostname: $cur_host"
    read -rp "  New hostname (leave blank to keep): " new_host < /dev/tty
    read -rp "  Git user name  (leave blank to skip): " git_name < /dev/tty
    read -rp "  Git email      (leave blank to skip): " git_email < /dev/tty

    if [[ -n "$new_host" ]]; then
        # macOS uses scutil instead of hostnamectl
        sudo scutil --set HostName "$new_host"
        sudo scutil --set LocalHostName "$new_host"
        sudo scutil --set ComputerName "$new_host"
        log_ok "Hostname set to: $new_host"
    fi
    [[ -n "$git_name" ]]  && git config --global user.name "$git_name"  && log_ok "Git name: $git_name"
    [[ -n "$git_email" ]] && git config --global user.email "$git_email" && log_ok "Git email: $git_email"
}

menu_sysconfig() {
    log_section "SYSTEM CONFIGURATION"
    configure_system_settings
    press_enter
}

# ── [7] Time Doctor Menu ──────────────────────────────────────────────────────
menu_timedoctor() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}=== [7] TIME DOCTOR CONFIGURATION ===${NC}\n"

        local status_str="${RED}NOT INSTALLED${NC}"
        if [ -d "/Applications/Time Doctor.app" ]; then
            if pgrep -f "Time Doctor" &>/dev/null || pgrep -f sfproc &>/dev/null; then
                status_str="${GREEN}INSTALLED & RUNNING${NC}"
            else
                status_str="${YELLOW}INSTALLED (not running)${NC}"
            fi
        fi

        echo -e "  Current Status : ${status_str}"
        echo -e "  App Location   : /Applications/Time Doctor.app\n"
        echo -e "  [1] Install Time Doctor"
        echo -e "  [2] Uninstall Time Doctor"
        echo -e "  [3] Check Status / Process Info"
        echo -e "  [4] Open Time Doctor"
        echo -e "  [0] Back\n"

        read -rp "  Choice: " ch < /dev/tty
        case "$ch" in
            1) install_timedoctor; press_enter ;;
            2) uninstall_timedoctor; press_enter ;;
            3)
                log_section "TIME DOCTOR DIAGNOSTICS"
                if pgrep -lf "Time Doctor" 2>/dev/null || pgrep -lf sfproc 2>/dev/null; then
                    log_ok "Time Doctor process is running."
                else
                    log_warn "No Time Doctor process found running."
                fi
                [ -d "/Applications/Time Doctor.app" ] && log_ok "App found at /Applications/Time Doctor.app" || log_warn "App not found in /Applications"
                press_enter ;;
            4)
                if [ -d "/Applications/Time Doctor.app" ]; then
                    open -a "Time Doctor"
                    log_ok "Opened Time Doctor."
                else
                    log_warn "Time Doctor not installed."
                fi
                press_enter ;;
            0) return ;;
            *) log_warn "Invalid choice." ;;
        esac
    done
}

# ── [3] Status ────────────────────────────────────────────────────────────────
menu_status() {
    check_status_all
    echo -e "  Tailscale status:"
    sudo tailscale status 2>/dev/null || echo -e "  ${RED}tailscale not running / not installed${NC}"
    echo ""
    press_enter
}

# ── [8] macOS Settings ────────────────────────────────────────────────────────
menu_macos_settings() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}=== [8] macOS SETTINGS ===${NC}\n"

        local cur_sleep
        cur_sleep=$(sudo pmset -g 2>/dev/null | awk '/displaysleep/{print $2}' || echo "unknown")
        local dark_mode
        dark_mode=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo "Light")
        echo -e "  Display sleep  : ${YELLOW}${cur_sleep} minutes${NC}"
        echo -e "  Appearance     : ${YELLOW}${dark_mode}${NC}\n"

        echo -e "  [1] Set screen timeout to 14 minutes"
        echo -e "  [2] Reset screen timeout to 5 minutes (default)"
        echo -e "  [3] Toggle Dark / Light Mode"
        echo -e "  [4] Show macOS system info"
        echo -e "  [5] Disable Gatekeeper (allow apps from anywhere)"
        echo -e "  [6] Re-enable Gatekeeper (restore default security)"
        echo -e "  [0] Back\n"

        read -rp "  Choice: " ch < /dev/tty
        case "$ch" in
            1) set_screen_timeout_14m; press_enter ;;
            2) reset_screen_timeout; press_enter ;;
            3)
                local current_mode
                current_mode=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo "Light")
                echo -e "  Current mode: ${YELLOW}$current_mode${NC}"
                read -rp "  Switch to [d]ark / [l]ight? " dm < /dev/tty
                case "$dm" in
                    [Dd]*) osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to true'; log_ok "Dark mode enabled." ;;
                    [Ll]*) osascript -e 'tell app "System Events" to tell appearance preferences to set dark mode to false'; log_ok "Light mode enabled." ;;
                    *) log_warn "Cancelled." ;;
                esac
                press_enter ;;
            4)
                log_section "macOS SYSTEM INFO"
                sw_vers
                echo ""
                system_profiler SPHardwareDataType 2>/dev/null | grep -E "Model|Processor|Memory|Serial"
                echo ""
                log_info "Disk usage:"
                df -h / | tail -1
                echo ""
                log_info "Homebrew:"
                brew --version 2>/dev/null | head -1
                press_enter ;;
            5)
                log_warn "This allows apps from ANY source. Only do this for trusted software."
                read -rp "  Disable Gatekeeper? (y/N): " conf < /dev/tty
                if [[ "$conf" =~ ^[Yy]$ ]]; then
                    sudo spctl --master-disable
                    log_ok "Gatekeeper disabled. Apps from anywhere will be allowed."
                fi
                press_enter ;;
            6)
                sudo spctl --master-enable
                log_ok "Gatekeeper re-enabled (default security)."
                press_enter ;;
            0) return ;;
            *) log_warn "Invalid choice." ;;
        esac
    done
}

# ── [9] Network / WiFi Diagnose ───────────────────────────────────────────────
menu_network_diagnose() {
    while true; do
        clear
        echo -e "${CYAN}${BOLD}=== [9] NETWORK / WIFI DIAGNOSE ===${NC}\n"
        echo -e "  ${DIM}Diagnose and fix common macOS network issues.${NC}\n"

        local wifi_status
        wifi_status=$(networksetup -getairportpower en0 2>/dev/null || echo "unknown")
        echo -e "  WiFi Power (en0) : ${YELLOW}${wifi_status}${NC}\n"

        echo -e "  ${BOLD}[1]${NC} Flush DNS cache  (fixes DNS resolution issues)"
        echo -e "  ${BOLD}[2]${NC} Renew DHCP lease (fixes IP / connectivity issues)"
        echo -e "  ${BOLD}[3]${NC} Toggle WiFi off/on (quick reconnect)"
        echo -e "  ${BOLD}[4]${NC} Show network status & interfaces"
        echo -e "  ${BOLD}[5]${NC} Ping test (google.com + Tailscale)"
        echo -e "  ${BOLD}[6]${NC} Show active routing table"
        echo -e "  ${BOLD}[0]${NC} Back\n"

        read -rp "  Choice: " ch < /dev/tty
        case "$ch" in
            1)
                log_info "Flushing DNS cache..."
                sudo dscacheutil -flushcache
                sudo killall -HUP mDNSResponder 2>/dev/null || true
                log_ok "DNS cache flushed."
                press_enter ;;
            2)
                log_info "Renewing DHCP lease..."
                local iface
                iface=$(route get default 2>/dev/null | awk '/interface:/{print $2}')
                if [[ -n "$iface" ]]; then
                    sudo ipconfig set "$iface" DHCP
                    log_ok "DHCP lease renewed on interface: $iface"
                else
                    log_warn "Could not detect active network interface."
                fi
                press_enter ;;
            3)
                log_info "Toggling WiFi off then on..."
                networksetup -setairportpower en0 off
                sleep 2
                networksetup -setairportpower en0 on
                log_ok "WiFi toggled."
                press_enter ;;
            4)
                log_section "NETWORK STATUS"
                log_info "Active interfaces:"
                ifconfig | grep -E "^[a-z]|inet " | head -30
                echo ""
                log_info "Default gateway:"
                route get default 2>/dev/null | grep -E "gateway|interface"
                echo ""
                log_info "DNS servers:"
                scutil --dns 2>/dev/null | grep nameserver | head -5
                press_enter ;;
            5)
                log_section "PING TEST"
                log_info "Pinging google.com..."
                ping -c 4 google.com || log_warn "google.com unreachable"
                echo ""
                log_info "Pinging Tailscale relay (100.64.0.1)..."
                ping -c 3 100.64.0.1 2>/dev/null || log_warn "Tailscale relay unreachable (not connected?)"
                press_enter ;;
            6)
                log_section "ROUTING TABLE"
                netstat -rn | head -30
                press_enter ;;
            0) return ;;
            *) log_warn "Invalid choice." ;;
        esac
    done
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

    # Show macOS version & Homebrew status in header
    local_brew_ver=$(brew --version 2>/dev/null | head -1 | awk '{print $2}' || echo "not installed")
    local_mac_ver=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    echo -e "  ${DIM}macOS ${local_mac_ver}  |  Homebrew ${local_brew_ver}  |  $(uname -m)${NC}\n"

    echo -e "  ${BOLD}[1]${NC} Install Packages      — select & install tools"
    echo -e "  ${BOLD}[2]${NC} Uninstall Packages    — remove installed tools"
    echo -e "  ${BOLD}[3]${NC} System Status         — check what's installed"
    echo -e "  ${BOLD}[4]${NC} Update System         — brew update + upgrade"
    echo -e "  ${BOLD}[5]${NC} Tailscale VPN         — install / connect / diagnose / remove"
    echo -e "  ${BOLD}[6]${NC} System Config         — hostname & git setup"
    echo -e "  ${BOLD}[7]${NC} Time Doctor Setup     — check, install, uninstall"
    echo -e "  ${BOLD}[8]${NC} macOS Settings        — screen timeout, dark mode, Gatekeeper"
    echo -e "  ${BOLD}[9]${NC} Network / WiFi        — DNS flush, ping, diagnostics"
    echo -e "  ${BOLD}[0]${NC} Exit"
    echo -e "\n  ────────────────────────────────────────────────────────"

    read -rp "  Choice: " choice < /dev/tty
    case "$choice" in
        1) menu_install ;;
        2) menu_uninstall ;;
        3) menu_status ;;
        4) menu_update ;;
        5) menu_tailscale ;;
        6) menu_sysconfig ;;
        7) menu_timedoctor ;;
        8) menu_macos_settings ;;
        9) menu_network_diagnose ;;
        0) echo -e "\n  ${CYAN}Goodbye!${NC}\n"; exit 0 ;;
        *) log_warn "Invalid choice — enter 0-9."; sleep 1 ;;
    esac
done
