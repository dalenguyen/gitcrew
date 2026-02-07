#!/bin/bash
# gitcrew installer
#
# One-line install:
#   curl -fsSL https://raw.githubusercontent.com/dalenguyen/gitcrew/main/install.sh | bash
#
# Or with a custom install directory:
#   curl -fsSL https://raw.githubusercontent.com/dalenguyen/gitcrew/main/install.sh | INSTALL_DIR=~/.local/bin bash

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

REPO="dalenguyen/gitcrew"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.gitcrew}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

echo -e "${CYAN}"
cat << 'EOF'
          _ _
    __ _ (_) |_ ___ _ __ _____      __
   / _` || | __/ __| '__/ _ \ \ /\ / /
  | (_| || | || (__| | |  __/\ V  V /
   \__, ||_|\__\___|_|  \___| \_/\_/
   |___/
EOF
echo -e "${NC}"
echo "Installing gitcrew..."
echo ""

# Check for git
if ! command -v git &>/dev/null; then
    echo -e "${RED}Error: git is required but not installed.${NC}"
    exit 1
fi

# Clone or update
if [ -d "$INSTALL_DIR" ]; then
    echo "Updating existing installation..."
    cd "$INSTALL_DIR"
    git pull origin main --quiet
else
    echo "Cloning gitcrew..."
    git clone --quiet "https://github.com/${REPO}.git" "$INSTALL_DIR"
fi

# Make scripts executable
chmod +x "${INSTALL_DIR}/gitcrew"
find "${INSTALL_DIR}/commands" -name "*.sh" -exec chmod +x {} \;
find "${INSTALL_DIR}/templates" -name "*.sh" -exec chmod +x {} \;

# Create symlink in bin directory
mkdir -p "$BIN_DIR"
ln -sf "${INSTALL_DIR}/gitcrew" "${BIN_DIR}/gitcrew"

echo ""
echo -e "${GREEN}gitcrew installed successfully!${NC}"
echo ""
echo "  Location: ${INSTALL_DIR}"
echo "  Binary:   ${BIN_DIR}/gitcrew"
echo ""

# Check if BIN_DIR is in PATH
if ! echo "$PATH" | tr ':' '\n' | grep -q "^${BIN_DIR}$"; then
    echo -e "${YELLOW}Note: ${BIN_DIR} is not in your PATH.${NC}"
    echo ""
    echo "Add it by running one of:"
    echo ""
    echo "  # bash"
    echo "  echo 'export PATH=\"${BIN_DIR}:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
    echo ""
    echo "  # zsh"
    echo "  echo 'export PATH=\"${BIN_DIR}:\$PATH\"' >> ~/.zshrc && source ~/.zshrc"
    echo ""
fi

echo "Get started:"
echo ""
echo "  cd your-project/"
echo "  gitcrew init"
echo "  gitcrew doctor"
echo ""
