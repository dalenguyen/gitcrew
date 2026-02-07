#!/usr/bin/env bash
#
# gitcrew init — Bootstrap .agent/ directory in current repo
#

set -euo pipefail

AGENT_DIR=".agent"
TEMPLATES_DIR="${GITCREW_DIR}/templates"

print_init_usage() {
    echo -e "${GITCREW_BOLD}USAGE${GITCREW_NC}"
    echo "    gitcrew init [options]"
    echo ""
    echo -e "${GITCREW_BOLD}OPTIONS${GITCREW_NC}"
    echo "    --force         Overwrite existing .agent/ directory"
    echo "    --no-roles      Skip creating role files"
    echo "    --no-docker     Skip creating Docker files"
    echo "    --no-hooks      Skip installing git hooks"
    echo "    -h, --help      Show this help"
    echo ""
}

# Parse flags
FORCE=false
NO_ROLES=false
NO_DOCKER=false
NO_HOOKS=false

while [ $# -gt 0 ]; do
    case "$1" in
        --force)    FORCE=true ;;
        --no-roles) NO_ROLES=true ;;
        --no-docker) NO_DOCKER=true ;;
        --no-hooks) NO_HOOKS=true ;;
        -h|--help)  print_init_usage; exit 0 ;;
        *)
            echo -e "${GITCREW_RED}Error: Unknown option '$1'${GITCREW_NC}"
            print_init_usage
            exit 1
            ;;
    esac
    shift
done

# --- Pre-flight checks ---

# Check we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "${GITCREW_RED}Error: Not a git repository.${GITCREW_NC}"
    echo "Run 'git init' first, or cd into an existing repo."
    exit 1
fi

# Check if .agent/ already exists
if [ -d "$AGENT_DIR" ] && [ "$FORCE" = false ]; then
    echo -e "${GITCREW_YELLOW}Warning: ${AGENT_DIR}/ already exists.${GITCREW_NC}"
    echo "Use 'gitcrew init --force' to overwrite."
    exit 1
fi

# --- Create directory structure ---

echo -e "${GITCREW_CYAN}Initializing .agent/ directory...${GITCREW_NC}"
echo ""

mkdir -p "${AGENT_DIR}/roles"
mkdir -p "${AGENT_DIR}/logs"

# --- Copy core files ---

copy_template() {
    local src="$1"
    local dest="$2"
    local label="$3"

    if [ -f "$src" ]; then
        cp "$src" "$dest"
        echo -e "  ${GITCREW_GREEN}+${GITCREW_NC} ${label}"
    else
        echo -e "  ${GITCREW_RED}!${GITCREW_NC} Missing template: ${src}"
    fi
}

echo -e "${GITCREW_BOLD}Core files:${GITCREW_NC}"
copy_template "${TEMPLATES_DIR}/TASKS.md"            "${AGENT_DIR}/TASKS.md"            ".agent/TASKS.md"
copy_template "${TEMPLATES_DIR}/LOG.md"              "${AGENT_DIR}/LOG.md"              ".agent/LOG.md"
copy_template "${TEMPLATES_DIR}/PROMPT.md"           "${AGENT_DIR}/PROMPT.md"           ".agent/PROMPT.md"
copy_template "${TEMPLATES_DIR}/detect-project.sh"   "${AGENT_DIR}/detect-project.sh"   ".agent/detect-project.sh"
copy_template "${TEMPLATES_DIR}/run-tests.sh"        "${AGENT_DIR}/run-tests.sh"        ".agent/run-tests.sh"
copy_template "${TEMPLATES_DIR}/run-loop.sh"         "${AGENT_DIR}/run-loop.sh"         ".agent/run-loop.sh"
copy_template "${TEMPLATES_DIR}/monitor.sh"          "${AGENT_DIR}/monitor.sh"          ".agent/monitor.sh"

# Make scripts executable
chmod +x "${AGENT_DIR}"/*.sh 2>/dev/null || true

# --- Copy role files ---

if [ "$NO_ROLES" = false ]; then
    echo ""
    echo -e "${GITCREW_BOLD}Role files:${GITCREW_NC}"
    for role_file in "${TEMPLATES_DIR}/roles/"*.md; do
        if [ -f "$role_file" ]; then
            role_name=$(basename "$role_file")
            copy_template "$role_file" "${AGENT_DIR}/roles/${role_name}" ".agent/roles/${role_name}"
        fi
    done
fi

# --- Copy Docker files ---

if [ "$NO_DOCKER" = false ]; then
    echo ""
    echo -e "${GITCREW_BOLD}Docker files:${GITCREW_NC}"
    copy_template "${TEMPLATES_DIR}/spawn-docker.sh"            "${AGENT_DIR}/spawn-docker.sh"            ".agent/spawn-docker.sh"
    copy_template "${TEMPLATES_DIR}/docker-compose.agents.yml"  "${AGENT_DIR}/docker-compose.agents.yml"  ".agent/docker-compose.agents.yml"
    chmod +x "${AGENT_DIR}/spawn-docker.sh" 2>/dev/null || true
fi

# --- Install git hooks ---

if [ "$NO_HOOKS" = false ]; then
    echo ""
    echo -e "${GITCREW_BOLD}Git hooks:${GITCREW_NC}"
    mkdir -p .githooks
    copy_template "${TEMPLATES_DIR}/githooks/pre-push" ".githooks/pre-push" ".githooks/pre-push"
    chmod +x .githooks/pre-push 2>/dev/null || true
    git config core.hooksPath .githooks 2>/dev/null || true
    echo -e "  ${GITCREW_GREEN}+${GITCREW_NC} Git hooks path set to .githooks/"
fi

# --- Run project detection ---

echo ""
echo -e "${GITCREW_BOLD}Detecting project...${GITCREW_NC}"
bash "${AGENT_DIR}/detect-project.sh" 2>/dev/null | while IFS= read -r line; do
    echo "  $line"
done

# --- Summary ---

echo ""
echo -e "${GITCREW_GREEN}${GITCREW_BOLD}Done!${GITCREW_NC} .agent/ directory initialized."
echo ""
echo -e "${GITCREW_BOLD}Next steps:${GITCREW_NC}"
echo "  1. Review and customize .agent/PROMPT.md for your project"
echo "  2. Edit .agent/run-tests.sh with your actual test commands"
echo "  3. Seed tasks:  gitcrew task add \"Fix: your first task\""
echo "  4. Check setup: gitcrew doctor"
echo "  5. Start agent: gitcrew spawn Agent-A feature"
echo ""
