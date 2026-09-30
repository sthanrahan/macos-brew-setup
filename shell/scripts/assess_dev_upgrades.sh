#!/usr/bin/env bash

# Terminal formatting
BOLD='\033[1m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
NC='\033[0m'

echo -e "${BOLD}=======================================================${NC}"
echo -e "${BOLD}   DEV ENVIRONMENT IMPACT & RISK ASSESSMENT           ${NC}"
echo -e "${BOLD}=======================================================${NC}"

# Variables to store updates needed
NEEDS_NODE=false; NODE_CUR=""; NODE_LAT=""
NEEDS_NPM=false; NPM_CUR=""; NPM_LAT=""
NEEDS_PY=false; PY_CUR=""; PY_LAT=""
NEEDS_PIP=false; PIP_CUR=""; PIP_LAT=""
NEEDS_UV=false; UV_CUR=""; UV_LAT=""
NEEDS_PIPX=false; PIPX_CUR=""; PIPX_LAT=""

check_status() {
    local name="$1"
    local current="$2"
    local latest="$3"
    
    if [ -z "$current" ]; then
        printf "%-15s : NOT INSTALLED\n" "$name"
    elif [ "$current" == "$latest" ]; then
        printf "%-15s : ${GREEN}%-10s (Up to date)${NC}\n" "$name" "$current"
    else
        printf "%-15s : ${YELLOW}%-10s (Latest: %s)${NC}\n" "$name" "$current" "$latest"
        case "$name" in
            "Node.js")  NEEDS_NODE=true; NODE_CUR="$current"; NODE_LAT="$latest" ;;
            "npm")      NEEDS_NPM=true; NPM_CUR="$current"; NPM_LAT="$latest" ;;
            "Python 3") NEEDS_PY=true; PY_CUR="$current"; PY_LAT="$latest" ;;
            "pip")      NEEDS_PIP=true; PIP_CUR="$current"; PIP_LAT="$latest" ;;
            "uv")       NEEDS_UV=true; UV_CUR="$current"; UV_LAT="$latest" ;;
            "pipx")     NEEDS_PIPX=true; PIPX_CUR="$current"; PIPX_LAT="$latest" ;;
        esac
    fi
}

get_risk_level() {
    local cur="$1"
    local lat="$2"
    local c_maj=$(echo "$cur" | cut -d. -f1)
    local l_maj=$(echo "$lat" | cut -d. -f1)
    local c_min=$(echo "$cur" | cut -d. -f2)
    local l_min=$(echo "$lat" | cut -d. -f2)

    if [ "$c_maj" != "$l_maj" ]; then
        echo -e "${RED}[HIGH RISK - MAJOR VERSION JUMP]${NC}"
    elif [ "$c_min" != "$l_min" ]; then
        echo -e "${YELLOW}[MEDIUM RISK - MINOR VERSION UPDATE]${NC}"
    else
        echo -e "${GREEN}[LOW RISK - PATCH / BUGFIX]${NC}"
    fi
}

# 1. NVM Check
if [ -d "$HOME/.nvm" ]; then
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

if command -v nvm &> /dev/null; then
    NVM_CUR=$(nvm --version)
    NVM_LAT=$(git ls-remote --tags --refs https://github.com/nvm-sh/nvm.git | tail -n1 | cut -d/ -f3 | tr -d 'v')
    check_status "NVM" "$NVM_CUR" "$NVM_LAT"
else
    check_status "NVM" "" ""
fi

# 2. Node.js
if command -v node &> /dev/null; then
    N_CUR=$(node -v | tr -d 'v')
    N_LAT=$(curl -s https://nodejs.org/dist/index.json | grep -o '"version":"v[^"]*' | head -n1 | cut -d'v' -f3)
    check_status "Node.js" "$N_CUR" "$N_LAT"
else
    check_status "Node.js" "" ""
fi

# 3. npm Global
if command -v npm &> /dev/null; then
    P_CUR=$(npm -v)
    P_LAT=$(npm view npm version 2>/dev/null)
    check_status "npm" "$P_CUR" "$P_LAT"
else
    check_status "npm" "" ""
fi

# 4. Python 3
if command -v python3 &> /dev/null; then
    PY_C=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')
    PY_L=$(curl -s https://endoflife.date/api/python.json | grep -o '"latest":"[0-9.]*' | head -n1 | cut -d'"' -f4)
    check_status "Python 3" "$PY_C" "$PY_L"
else
    check_status "Python 3" "" ""
fi

# 5. Pip
if command -v pip3 &> /dev/null; then
    PP_C=$(pip3 --version | cut -d' ' -f2)
    PP_L=$(curl -s https://pypi.org/pypi/pip/json | grep -o '"version":"[^"]*' | head -n1 | cut -d'"' -f4)
    check_status "pip" "$PP_C" "$PP_L"
else
    check_status "pip" "" ""
fi

# 6. UV
if command -v uv &> /dev/null; then
    U_C=$(uv --version | cut -d' ' -f2)
    U_L=$(curl -s https://api.github.com/repos/astral-sh/uv/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4 | tr -d 'v')
    check_status "uv" "$U_C" "$U_L"
else
    check_status "uv" "" ""
fi

# 7. Pipx
if command -v pipx &> /dev/null; then
    PX_C=$(pipx --version)
    PX_L=$(curl -s https://pypi.org/pypi/pipx/json | grep -o '"version":"[^"]*' | head -n1 | cut -d'"' -f4)
    check_status "pipx" "$PX_C" "$PX_L"
else
    check_status "pipx" "" ""
fi

echo -e "${BOLD}=======================================================${NC}"

# -------------------------------------------------------------
# IMPACT ASSESSMENT & TARGETED INTERACTIVE UPGRADES
# -------------------------------------------------------------

if [ "$NEEDS_NODE" = true ] || [ "$NEEDS_NPM" = true ] || [ "$NEEDS_PY" = true ] || [ "$NEEDS_PIP" = true ] || [ "$NEEDS_UV" = true ] || [ "$NEEDS_PIPX" = true ]; then
    echo -e "\n${CYAN}${BOLD}IMPACT ASSESSMENT & UPGRADE OPT-IN${NC}\n"

    # NODE / NPM SECTION
    if [ "$NEEDS_NODE" = true ] || [ "$NEEDS_NPM" = true ]; then
        echo -e "${BOLD}1. Node.js / npm Assessment:${NC}"
        echo -e "   Dependencies at risk (Global CLI Tools):"
        if command -v npm &> /dev/null; then
            npm list -g --depth=0 2>/dev/null | sed 's/^/      /'
        fi
        
        if [ "$NEEDS_NODE" = true ]; then
            RISK=$(get_risk_level "$NODE_CUR" "$NODE_LAT")
            echo -e "   Node.js Upgrade: $NODE_CUR -> $NODE_LAT $RISK"
            read -p "   --> Upgrade Node.js via Homebrew? (y/N) " -n 1 -r; echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                brew upgrade node
            fi
        fi

        if [ "$NEEDS_NPM" = true ]; then
            RISK=$(get_risk_level "$NPM_CUR" "$NPM_LAT")
            echo -e "   npm Upgrade: $NPM_CUR -> $NPM_LAT $RISK"
            read -p "   --> Upgrade global npm package? (y/N) " -n 1 -r; echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                npm install -g npm@latest
            fi
        fi
        echo ""
    fi

    # PYTHON / PIP SECTION
    if [ "$NEEDS_PY" = true ] || [ "$NEEDS_PIP" = true ] || [ "$NEEDS_PIPX" = true ] || [ "$NEEDS_UV" = true ]; then
        echo -e "${BOLD}2. Python Ecosystem Assessment:${NC}"
        echo -e "   Dependencies at risk (Isolated Pipx Environments):"
        if command -v pipx &> /dev/null; then
            pipx list --short 2>/dev/null | sed 's/^/      /'
        fi

        if [ "$NEEDS_PY" = true ]; then
            RISK=$(get_risk_level "$PY_CUR" "$PY_LAT")
            echo -e "   Python 3 Upgrade: $PY_CUR -> $PY_LAT $RISK"
            echo -e "   ${YELLOW}Note: Minor/Major jumps require running 'pipx reinstall-all' after updating.${NC}"
            read -p "   --> Upgrade Python 3 via Homebrew? (y/N) " -n 1 -r; echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                brew upgrade python
            fi
        fi

        if [ "$NEEDS_PIP" = true ]; then
            RISK=$(get_risk_level "$PIP_CUR" "$PIP_LAT")
            echo -e "   pip Upgrade: $PIP_CUR -> $PIP_LAT $RISK"
            read -p "   --> Upgrade pip via Python? (y/N) " -n 1 -r; echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                python3 -m pip install --upgrade pip
            fi
        fi

        if [ "$NEEDS_UV" = true ]; then
            RISK=$(get_risk_level "$UV_CUR" "$UV_LAT")
            echo -e "   uv Upgrade: $UV_CUR -> $UV_LAT $RISK"
            read -p "   --> Upgrade uv via Homebrew? (y/N) " -n 1 -r; echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                brew upgrade uv
            fi
        fi

        if [ "$NEEDS_PIPX" = true ]; then
            RISK=$(get_risk_level "$PIPX_CUR" "$PIPX_LAT")
            echo -e "   pipx Upgrade: $PIPX_CUR -> $PIPX_LAT $RISK"
            read -p "   --> Upgrade pipx via Homebrew? (y/N) " -n 1 -r; echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                brew upgrade pipx
            fi
        fi
        echo ""
    fi
fi

echo -e "${GREEN}${BOLD}Assessment complete.${NC}"
