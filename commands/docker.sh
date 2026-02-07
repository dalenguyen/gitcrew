#!/usr/bin/env bash
#
# gitcrew docker — Manage Docker-based agent containers
#

set -euo pipefail

AGENT_DIR=".agent"
IMAGE_NAME="gitcrew-agent"

print_docker_usage() {
    echo -e "${GITCREW_BOLD}USAGE${GITCREW_NC}"
    echo "    gitcrew docker <subcommand> [options]"
    echo ""
    echo -e "${GITCREW_BOLD}SUBCOMMANDS${GITCREW_NC}"
    echo -e "    ${GITCREW_GREEN}build${GITCREW_NC}       Build the agent Docker image for this project"
    echo -e "    ${GITCREW_GREEN}test${GITCREW_NC}        Run the project test suite inside a Docker container"
    echo -e "    ${GITCREW_GREEN}ps${GITCREW_NC}          List running gitcrew agent containers"
    echo -e "    ${GITCREW_GREEN}stop${GITCREW_NC}        Stop agent containers (all or by name)"
    echo -e "    ${GITCREW_GREEN}logs${GITCREW_NC}        Follow logs for an agent container"
    echo -e "    ${GITCREW_GREEN}clean${GITCREW_NC}       Remove stopped agent containers and images"
    echo ""
    echo -e "${GITCREW_BOLD}EXAMPLES${GITCREW_NC}"
    echo "    gitcrew docker build"
    echo "    gitcrew docker test"
    echo "    gitcrew docker ps"
    echo "    gitcrew docker stop Agent-A"
    echo "    gitcrew docker stop --all"
    echo "    gitcrew docker logs Agent-A"
    echo "    gitcrew docker clean"
    echo ""
}

# --- Helpers ---

require_docker() {
    if ! command -v docker &>/dev/null; then
        echo -e "${GITCREW_RED}Error: Docker is not installed or not in PATH.${GITCREW_NC}"
        echo "Install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi
    if ! docker info &>/dev/null 2>&1; then
        echo -e "${GITCREW_RED}Error: Docker daemon is not running.${GITCREW_NC}"
        echo "Start Docker Desktop or run: sudo systemctl start docker"
        exit 1
    fi
}

get_dockerfile() {
    # Check for project-specific Dockerfile first, then template
    if [ -f "${AGENT_DIR}/Dockerfile.agent" ]; then
        echo "${AGENT_DIR}/Dockerfile.agent"
    elif [ -f "${GITCREW_DIR}/templates/Dockerfile.agent" ]; then
        echo "${GITCREW_DIR}/templates/Dockerfile.agent"
    else
        echo ""
    fi
}

# --- Subcommands ---

cmd_build() {
    require_docker

    local dockerfile
    dockerfile=$(get_dockerfile)

    if [ -z "$dockerfile" ]; then
        echo -e "${GITCREW_RED}Error: No Dockerfile.agent found.${GITCREW_NC}"
        echo "Run 'gitcrew init' to create one in .agent/"
        exit 1
    fi

    echo -e "${GITCREW_CYAN}Building agent image '${IMAGE_NAME}'...${GITCREW_NC}"
    echo -e "${GITCREW_DIM}Using: ${dockerfile}${GITCREW_NC}"
    echo ""

    docker build -t "${IMAGE_NAME}" -f "$dockerfile" .

    echo ""
    echo -e "${GITCREW_GREEN}Image '${IMAGE_NAME}' built successfully.${GITCREW_NC}"
    docker images "${IMAGE_NAME}" --format "  Size: {{.Size}}  Created: {{.CreatedSince}}"
}

cmd_test() {
    require_docker

    # Build if image doesn't exist
    if ! docker image inspect "${IMAGE_NAME}" &>/dev/null; then
        echo -e "${GITCREW_YELLOW}Image '${IMAGE_NAME}' not found. Building...${GITCREW_NC}"
        echo ""
        cmd_build
        echo ""
    fi

    echo -e "${GITCREW_CYAN}Running tests inside Docker container...${GITCREW_NC}"
    echo ""

    # Mount the project as read-write so tests can run
    docker run --rm \
        --name "gitcrew-test-$$" \
        -v "$(pwd)":/workspace:ro \
        -w /workspace \
        "${IMAGE_NAME}" \
        bash -c '
            # Copy workspace to writable location (mount is read-only)
            cp -r /workspace /tmp/test-workspace
            cd /tmp/test-workspace

            # Configure git for test sandboxes
            git config --global user.name "Docker-Test"
            git config --global user.email "test@gitcrew.docker"
            git config --global init.defaultBranch main

            # Run tests
            bash tests/runner.sh full
        '

    local exit_code=$?
    echo ""
    if [ $exit_code -eq 0 ]; then
        echo -e "${GITCREW_GREEN}Docker tests passed.${GITCREW_NC}"
    else
        echo -e "${GITCREW_RED}Docker tests failed (exit code ${exit_code}).${GITCREW_NC}"
    fi
    return $exit_code
}

cmd_ps() {
    require_docker

    local containers
    containers=$(docker ps --filter "name=gitcrew-" --format "table {{.Names}}\t{{.Status}}\t{{.CreatedAt}}" 2>/dev/null || true)

    if [ -z "$containers" ] || [ "$(echo "$containers" | wc -l)" -le 1 ]; then
        echo -e "${GITCREW_DIM}No running gitcrew containers.${GITCREW_NC}"
        echo ""
        echo "Start one with: gitcrew spawn Agent-A feature --docker"
        return 0
    fi

    echo -e "${GITCREW_BOLD}Running gitcrew containers:${GITCREW_NC}"
    echo "$containers"
}

cmd_stop() {
    require_docker
    local target="${1:-}"

    if [ "$target" = "--all" ] || [ -z "$target" ]; then
        local containers
        containers=$(docker ps -q --filter "name=gitcrew-" 2>/dev/null || true)

        if [ -z "$containers" ]; then
            echo -e "${GITCREW_DIM}No running gitcrew containers to stop.${GITCREW_NC}"
            return 0
        fi

        echo -e "${GITCREW_YELLOW}Stopping all gitcrew containers...${GITCREW_NC}"
        docker stop $containers 2>/dev/null || true
        echo -e "${GITCREW_GREEN}All gitcrew containers stopped.${GITCREW_NC}"
    else
        local container_name="gitcrew-${target}"
        if docker ps -q --filter "name=${container_name}" | grep -q .; then
            echo -e "${GITCREW_YELLOW}Stopping ${container_name}...${GITCREW_NC}"
            docker stop "${container_name}" 2>/dev/null || true
            echo -e "${GITCREW_GREEN}${container_name} stopped.${GITCREW_NC}"
        else
            echo -e "${GITCREW_RED}Container '${container_name}' not found or not running.${GITCREW_NC}"
            return 1
        fi
    fi
}

cmd_logs() {
    require_docker
    local target="${1:-}"

    if [ -z "$target" ]; then
        echo -e "${GITCREW_RED}Error: Agent name required.${GITCREW_NC}"
        echo "Usage: gitcrew docker logs <agent-name>"
        return 1
    fi

    local container_name="gitcrew-${target}"
    if docker ps -q --filter "name=${container_name}" | grep -q .; then
        docker logs -f "${container_name}"
    else
        echo -e "${GITCREW_RED}Container '${container_name}' not found or not running.${GITCREW_NC}"
        return 1
    fi
}

cmd_clean() {
    require_docker

    echo -e "${GITCREW_YELLOW}Cleaning up gitcrew Docker resources...${GITCREW_NC}"

    # Stop running containers
    local running
    running=$(docker ps -q --filter "name=gitcrew-" 2>/dev/null || true)
    if [ -n "$running" ]; then
        echo -e "  Stopping running containers..."
        docker stop $running 2>/dev/null || true
    fi

    # Remove stopped containers
    local stopped
    stopped=$(docker ps -aq --filter "name=gitcrew-" 2>/dev/null || true)
    if [ -n "$stopped" ]; then
        echo -e "  ${GITCREW_GREEN}+${GITCREW_NC} Removed $(echo "$stopped" | wc -l | tr -d ' ') container(s)"
        docker rm $stopped 2>/dev/null || true
    fi

    # Remove image
    if docker image inspect "${IMAGE_NAME}" &>/dev/null 2>&1; then
        docker rmi "${IMAGE_NAME}" 2>/dev/null || true
        echo -e "  ${GITCREW_GREEN}+${GITCREW_NC} Removed image '${IMAGE_NAME}'"
    fi

    echo -e "${GITCREW_GREEN}Cleanup complete.${GITCREW_NC}"
}

# --- Main dispatch ---

if [ $# -eq 0 ]; then
    print_docker_usage
    exit 0
fi

SUBCMD="$1"
shift

case "$SUBCMD" in
    build)  cmd_build "$@" ;;
    test)   cmd_test "$@" ;;
    ps)     cmd_ps "$@" ;;
    stop)   cmd_stop "$@" ;;
    logs)   cmd_logs "$@" ;;
    clean)  cmd_clean "$@" ;;
    -h|--help) print_docker_usage; exit 0 ;;
    *)
        echo -e "${GITCREW_RED}Error: Unknown docker subcommand '$SUBCMD'${GITCREW_NC}"
        print_docker_usage
        exit 1
        ;;
esac
