#!/usr/bin/env bash
#
# ┌───────────────────────────────────────────────────────────────┐
# │               Blueprint One-Shot Installer          	  │
# │                                                               │
# │  For Pterodactyl / Jexactyl panels                            │
# │  Created by slayer                                            │
# │  GitHub: https://github.com/SlayerxRoot/blueprint-installer   │          
# └───────────────────────────────────────────────────────────────┘
# 2026 – Clean, colorful & user-friendly console experience
#

set -euo pipefail

# ────────────────────────────────────────────────
# Colors & styles (fallback-safe)
# ────────────────────────────────────────────────
if [[ -t 1 ]]; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    RED="" GREEN="" YELLOW="" BLUE="" CYAN="" BOLD="" RESET=""
fi

emoji_ok="✅"
emoji_warn="⚠️"
emoji_error="❌"
emoji_info="ℹ️"

# ────────────────────────────────────────────────
# Header
# ────────────────────────────────────────────────
clear
cat << 'EOF'
┌───────────────────────────────────────────────────────────────┐
│                                                               │
│     ██████╗ ██╗     ██╗   ██╗███████╗██████╗ ██╗███╗   ██╗    │
│     ██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██║████╗  ██║    │
│     ██████╔╝██║     ██║   ██║█████╗  ██████╔╝██║██╔██╗ ██║    │
│     ██╔══██╗██║     ╚██╗ ██╔╝██╔══╝  ██╔══██╗██║██║╚██╗██║    │
│     ██████╔╝███████╗ ╚████╔╝ ███████╗██║  ██║██║██║ ╚████║    │
│     ╚═════╝ ╚══════╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝    │
│                                                               │
│                  Blueprint Installer – latest Edition         │
│                     Created by slayer                         │
│                                                               │
└───────────────────────────────────────────────────────────────┘

EOF

echo "${CYAN}${BOLD}Welcome! Installing Blueprint for your Pterodactyl / Jexactyl panel...${RESET}"
echo ""

# Check root (recommended)
if [[ $EUID -ne 0 ]]; then
    echo "${YELLOW}${emoji_warn} Warning: Not running as root. Some steps may fail.${RESET}"
    echo "         It's best to run this with sudo or as root."
    echo ""
fi

# ────────────────────────────────────────────────
# 1. Detect panel directory
# ────────────────────────────────────────────────
POSSIBLE_DIRS=("/var/www/jexactyl" "/var/www/pterodactyl" "/var/www/panel" "/var/www/html")

PANEL_DIR=""
for dir in "${POSSIBLE_DIRS[@]}"; do
    if [[ -d "$dir" && -f "$dir/.env" ]]; then
        PANEL_DIR="$dir"
        break
    fi
done

if [[ -z "$PANEL_DIR" ]]; then
    echo "${RED}${emoji_error} Could not auto-detect panel directory.${RESET}"
    echo "   Checked: ${POSSIBLE_DIRS[*]}"
    read -p "${BLUE}Enter panel path manually (e.g. /var/www/jexactyl): ${RESET}" PANEL_DIR
    if [[ ! -d "$PANEL_DIR" || ! -f "$PANEL_DIR/.env" ]]; then
        echo "${RED}${emoji_error} Invalid path or missing .env file. Aborting.${RESET}"
        exit 1
    fi
fi

echo "${GREEN}${emoji_ok} Panel detected: ${BOLD}$PANEL_DIR${RESET}"
export PTERODACTYL_DIRECTORY="$PANEL_DIR"
cd "$PANEL_DIR" || { echo "${RED}${emoji_error} Cannot cd to $PANEL_DIR${RESET}"; exit 1; }

# ────────────────────────────────────────────────
# 2. Install dependencies
# ────────────────────────────────────────────────
echo ""
echo "${CYAN}→ Installing system dependencies...${RESET}"

apt update -yq >/dev/null 2>&1
apt install -y ca-certificates curl git gnupg unzip wget zip >/dev/null 2>&1

# Node.js 20.x
if ! command -v node >/dev/null 2>&1 || [[ $(node -v | cut -d. -f1) -lt 20 ]]; then
    echo "  ${emoji_info} Setting up Node.js 20..."
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list >/dev/null
    apt update -yq >/dev/null
    apt install -y nodejs >/dev/null 2>&1
fi

npm install -g yarn >/dev/null 2>&1 || true

echo "${GREEN}${emoji_ok} Dependencies ready.${RESET}"

# ────────────────────────────────────────────────
# 3. Download latest Blueprint
# ────────────────────────────────────────────────
echo ""
echo "${CYAN}→ Downloading latest Blueprint release...${RESET}"

LATEST_ZIP=$(curl -s https://api.github.com/repos/BlueprintFramework/framework/releases/latest | grep "browser_download_url.*release.zip" | cut -d '"' -f 4)

if [[ -z "$LATEST_ZIP" ]]; then
    echo "${RED}${emoji_error} Failed to fetch latest release URL.${RESET}"
    exit 1
fi

wget -q --show-progress -O release.zip "$LATEST_ZIP"
unzip -oq release.zip
rm -f release.zip

echo "${GREEN}${emoji_ok} Blueprint files extracted.${RESET}"

# ────────────────────────────────────────────────
# 4. Yarn install
# ────────────────────────────────────────────────
echo ""
echo "${CYAN}→ Installing frontend dependencies (yarn)...${RESET}"
echo "  This can take 1–3 minutes..."

yarn install --production --frozen-lockfile >/dev/null 2>&1 || {
    echo "${YELLOW}${emoji_warn} Frozen lockfile failed — retrying without...${RESET}"
    yarn install --production >/dev/null 2>&1
}

echo "${GREEN}${emoji_ok} Yarn dependencies installed.${RESET}"

# ────────────────────────────────────────────────
# 5. Make executable + symlink
# ────────────────────────────────────────────────
chmod +x blueprint.sh

if [[ ! -L /usr/local/bin/blueprint ]]; then
    ln -sf "$PANEL_DIR/blueprint.sh" /usr/local/bin/blueprint 2>/dev/null || true
fi

# ────────────────────────────────────────────────
# 6. .blueprintrc defaults
# ────────────────────────────────────────────────
if [[ ! -f .blueprintrc ]]; then
    cat << 'EOF' > .blueprintrc
WEBUSER="www-data"
OWNERSHIP="www-data:www-data"
USERSHELL="/bin/bash"
EOF
    chown www-data:www-data .blueprintrc 2>/dev/null || true
fi

# ────────────────────────────────────────────────
# 7. Run blueprint setup
# ────────────────────────────────────────────────
echo ""
echo "${CYAN}→ Running Blueprint setup...${RESET}"
bash blueprint.sh || {
    echo ""
    echo "${YELLOW}${emoji_warn} blueprint.sh returned non-zero exit code.${RESET}"
    echo "   Files are installed — you can run it manually later:"
    echo "     cd $PANEL_DIR && bash blueprint.sh"
}

# ────────────────────────────────────────────────
# Final box
# ────────────────────────────────────────────────
echo ""
cat << EOF
┌───────────────────────────────────────────────────────────────┐
│            ${GREEN}${BOLD}INSTALLATION COMPLETE${RESET}       │                
│                                                               │
│  ${emoji_ok} Blueprint by slayer – ready to use!              │        
│                                                               │
│  Next steps:                                                  │
│    1. Refresh admin panel → look for puzzle icon (top-right)  │
│    2. Clear cache if needed:                                  │
│       ${CYAN}php artisan optimize:clear${RESET}               │              
│       ${CYAN}php artisan queue:restart${RESET}                │             
│    3. Test CLI:                                               │
│       ${CYAN}blueprint --version${RESET}                      │              
│    4. Install a theme/addon example:                          │
│       ${CYAN}blueprint install theme:someone/nebula${RESET}   │              
│                                                               │
│  Issues? Check logs or visit https://blueprint.zip/docs       │
│  Created & maintained by slayer – enjoy!                      │
└───────────────────────────────────────────────────────────────┘

EOF

exit 0