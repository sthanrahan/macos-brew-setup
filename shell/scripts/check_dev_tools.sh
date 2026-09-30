#!/usr/bin/env bash

# Terminal formatting
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}=========================================${NC}"
echo -e "${BOLD}   DEVELOPMENT ENVIRONMENT CHECKUP       ${NC}"
echo -e "${BOLD}=========================================${NC}"

# Helper function to compare versions
check_status() {
    local name="$1"
    local current="$2"
    local latest="$3"
    
    if [ -z "$current" ]; then
        printf "%-15s : NOT INSTALLED\n" "$name"
    elif [ "$current" == "$latest" ]; then
        printf "%-15s : \033[32m%-10s (Up to date)\033[0m\n" "$name" "$current"
    else
        printf "%-15s : \033[33m%-10s (Latest: %s)\033[0m\n" "$name" "$current" "$latest"
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

# 2. Node.js (Homebrew / System)
if command -v node &> /dev/null; then
    NODE_CUR=$(node -v | tr -d 'v')
    NODE_LAT=$(curl -s https://nodejs.org/dist/index.json | grep -o '"version":"v[^"]*' | head -n1 | cut -d'v' -f3)
    check_status "Node.js" "$NODE_CUR" "$NODE_LAT"
else
    check_status "Node.js" "" ""
fi

# 3. npm Global
if command -v npm &> /dev/null; then
    NPM_CUR=$(npm -v)
    NPM_LAT=$(npm view npm version 2>/dev/null)
    check_status "npm" "$NPM_CUR" "$NPM_LAT"
else
    check_status "npm" "" ""
fi

# 4. Python 3
if command -v python3 &> /dev/null; then
    PY_CUR=$(python3 -c 'import sys; print(".".join(map(str, sys.version_info[:3])))')
    PY_LAT=$(curl -s https://endoflife.date/api/python.json | grep -o '"latest":"[0-9.]*' | head -n1 | cut -d'"' -f4)
    check_status "Python 3" "$PY_CUR" "$PY_LAT"
else
    check_status "Python 3" "" ""
fi

# 5. Pip
if command -v pip3 &> /dev/null; then
    PIP_CUR=$(pip3 --version | cut -d' ' -f2)
    PIP_LAT=$(curl -s https://pypi.org/pypi/pip/json | grep -o '"version":"[^"]*' | head -n1 | cut -d'"' -f4)
    check_status "pip" "$PIP_CUR" "$PIP_LAT"
else
    check_status "pip" "" ""
fi

# 6. UV (Python package manager)
if command -v uv &> /dev/null; then
    UV_CUR=$(uv --version | cut -d' ' -f2)
    UV_LAT=$(curl -s https://api.github.com/repos/astral-sh/uv/releases/latest | grep -o '"tag_name": "[^"]*' | cut -d'"' -f4 | tr -d 'v')
    check_status "uv" "$UV_CUR" "$UV_LAT"
else
    check_status "uv" "" ""
fi

# 7. Pipx
if command -v pipx &> /dev/null; then
    PIPX_CUR=$(pipx --version)
    PIPX_LAT=$(curl -s https://pypi.org/pypi/pipx/json | grep -o '"version":"[^"]*' | head -n1 | cut -d'"' -f4)
    check_status "pipx" "$PIPX_CUR" "$PIPX_LAT"
else
    check_status "pipx" "" ""
fi

echo -e "${BOLD}=========================================${NC}"
