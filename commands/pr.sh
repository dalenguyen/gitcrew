#!/usr/bin/env bash
#
# gitcrew pr — Create issue + PR and run code review before merge
#

set -euo pipefail

AGENT_DIR=".agent"

print_pr_usage() {
    echo -e "${GITCREW_BOLD}USAGE${GITCREW_NC}"
    echo "    gitcrew pr <subcommand> [options]"
    echo ""
    echo -e "${GITCREW_BOLD}SUBCOMMANDS${GITCREW_NC}"
    echo -e "    ${GITCREW_GREEN}create${GITCREW_NC}   Create GitHub issue (if none exists) and open a PR for current branch"
    echo -e "    ${GITCREW_GREEN}review${GITCREW_NC}    Run code review on the PR for current branch (AI agent, best practices)"
    echo ""
    echo -e "${GITCREW_BOLD}OPTIONS (create)${GITCREW_NC}"
    echo "    --title <t>     Issue/PR title (default: from branch name or last commit)"
    echo "    --body <b>      Issue/PR body (default: from last commit message)"
    echo "    --no-issue     Skip creating/linking an issue; create PR only"
    echo ""
    echo -e "${GITCREW_BOLD}OPTIONS (review)${GITCREW_NC}"
    echo "    --cli <tool>   CLI for review agent: cursor, claude, aider (default: from .agent/agent.env or cursor)"
    echo "    --post         Post review as a PR comment (requires gh)"
    echo "    --branch <b>   Review PR for branch (default: current branch)"
    echo ""
    echo -e "${GITCREW_BOLD}EXAMPLES${GITCREW_NC}"
    echo "    gitcrew pr create"
    echo "    gitcrew pr create --title \"Add login retry\" --body \"Fixes #42\""
    echo "    gitcrew pr review"
    echo "    gitcrew pr review --post"
    echo ""
}

require_gh() {
    if ! command -v gh &>/dev/null; then
        echo -e "${GITCREW_RED}Error: GitHub CLI 'gh' is required.${GITCREW_NC}"
        echo "Install: https://cli.github.com/"
        echo "Then: gh auth login"
        exit 1
    fi
    if ! gh auth status &>/dev/null 2>&1; then
        echo -e "${GITCREW_RED}Error: Not authenticated with GitHub. Run: gh auth login${GITCREW_NC}"
        exit 1
    fi
}

# gh 2.0+ required for --json/--jq (issue list, pr view, issue create)
check_gh_version() {
    if ! gh issue list --limit 1 --json number &>/dev/null 2>&1; then
        echo -e "${GITCREW_RED}Error: GitHub CLI 2.0+ is required for 'gitcrew pr'.${GITCREW_NC}"
        echo "Your version: $(gh --version 2>/dev/null | head -1)"
        echo "Install or upgrade: https://github.com/cli/cli/releases"
        exit 1
    fi
}

# --- pr create ---
cmd_create() {
    require_gh
    check_gh_version

    local title="" body="" no_issue=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --title) title="$2"; shift ;;
            --body)  body="$2"; shift ;;
            --no-issue) no_issue=true ;;
            -h|--help) print_pr_usage; exit 0 ;;
            *) ;;
        esac
        shift
    done

    local branch
    branch=$(git branch --show-current 2>/dev/null || true)
    if [ -z "$branch" ] || [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
        echo -e "${GITCREW_RED}Error: Create a feature branch first (e.g. git checkout -b Agent-A/my-feature).${GITCREW_NC}"
        exit 1
    fi

    [ -z "$title" ] && title=$(echo "$branch" | sed 's/^[A-Za-z0-9_-]*\///' | sed 's/-/ /g')
    [ -z "$body" ] && body=$(git log -1 --pretty=%B 2>/dev/null || true)

    local issue_num=""
    if [ "$no_issue" = false ]; then
        # Look for existing open issue with similar title
        issue_num=$(gh issue list --state open --limit 20 --json number,title --jq ".[] | select(.title | test(\"${title}\"; \"i\")) | .number" 2>/dev/null | head -1 || true)
        if [ -z "$issue_num" ]; then
            echo -e "${GITCREW_CYAN}Creating issue: ${title}${GITCREW_NC}"
            issue_num=$(gh issue create --title "$title" --body "$body" --json number --jq '.number') || {
                echo -e "${GITCREW_RED}Failed to create issue. Run 'gh auth login' if needed.${GITCREW_NC}"
                exit 1
            }
            echo -e "  ${GITCREW_GREEN}+${GITCREW_NC} Issue #${issue_num}"
        else
            echo -e "${GITCREW_CYAN}Using existing issue #${issue_num}${GITCREW_NC}"
        fi
        [ -n "$issue_num" ] && body="Fixes #${issue_num}

${body}"
    fi

    if gh pr view --head "$branch" &>/dev/null 2>&1; then
        echo -e "${GITCREW_YELLOW}PR already exists for branch '${branch}'.${GITCREW_NC}"
        gh pr view --web 2>/dev/null || gh pr view
        return 0
    fi

    echo -e "${GITCREW_CYAN}Creating PR for ${branch}...${GITCREW_NC}"
    gh pr create --title "$title" --body "$body" --head "$branch" || {
        echo -e "${GITCREW_RED}Failed to create PR. Check branch is pushed and 'gh auth login' is done.${GITCREW_NC}"
        exit 1
    }
    echo -e "${GITCREW_GREEN}PR created.${GITCREW_NC}"
}

# --- pr review ---
cmd_review() {
    require_gh

    local post=false review_branch="" cli=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --post)   post=true ;;
            --branch) review_branch="$2"; shift ;;
            --cli)    cli="$2"; shift ;;
            -h|--help) print_pr_usage; exit 0 ;;
            *) ;;
        esac
        shift
    done

    [ -z "$review_branch" ] && review_branch=$(git branch --show-current 2>/dev/null || true)
    if [ -z "$review_branch" ]; then
        echo -e "${GITCREW_RED}Error: Could not determine branch.${GITCREW_NC}"
        exit 1
    fi

    local pr_num pr_title
    pr_num=$(gh pr view "$review_branch" --json number --jq '.number' 2>/dev/null) || {
        echo -e "${GITCREW_RED}Error: No open PR found for branch '${review_branch}'.${GITCREW_NC}"
        echo "Create one with: gitcrew pr create"
        exit 1
    }
    pr_title=$(gh pr view "$review_branch" --json title --jq '.title' 2>/dev/null)

    echo -e "${GITCREW_CYAN}Fetching diff for PR #${pr_num}: ${pr_title}${GITCREW_NC}"
    local diff
    diff=$(gh pr diff "$review_branch" 2>/dev/null) || {
        echo -e "${GITCREW_RED}Error: Could not get PR diff.${GITCREW_NC}"
        exit 1
    }

    if [ -z "$diff" ]; then
        echo -e "${GITCREW_YELLOW}No diff in this PR.${GITCREW_NC}"
        return 0
    fi

    [ -z "$cli" ] && [ -f "${AGENT_DIR}/agent.env" ] && source "${AGENT_DIR}/agent.env" 2>/dev/null || true
    [ -z "$cli" ] && cli="${AGENT_CLI:-cursor}"

    local review_prompt
    review_prompt=$(cat << EOF
You are performing a **code review** for this pull request. Follow the code review best practices and checklist in your instructions.

**PR:** #${pr_num} — ${pr_title}
**Branch:** ${review_branch}

Review the following diff and output your review in the required format (summary, Must fix, Should fix, Suggestions). Be specific with file names and line areas.

---
DIFF:
\`\`\`
${diff}
\`\`\`
---
EOF
)

    if [ -f "${AGENT_DIR}/roles/review.md" ]; then
        review_prompt=$(printf "%s\n\n%s" "$(cat "${AGENT_DIR}/roles/review.md")" "$review_prompt")
    fi

    echo -e "${GITCREW_CYAN}Running code review agent (${cli})...${GITCREW_NC}"
    echo ""

    local prompt_file review_output
    prompt_file=$(mktemp)
    review_output=$(mktemp)
    trap "rm -f ${prompt_file} ${review_output}" EXIT
    echo "$review_prompt" > "$prompt_file"

    case "$cli" in
        claude)
            claude --dangerously-skip-permissions -p "$prompt_file" 2>/dev/null > "$review_output" || true
            ;;
        cursor|agent)
            agent -p "$prompt_file" 2>/dev/null > "$review_output" || true
            ;;
        aider)
            aider --message "$(cat "$prompt_file")" --no-auto-commits 2>/dev/null > "$review_output" || true
            ;;
        *)
            echo -e "${GITCREW_RED}Error: Unsupported CLI '${cli}'. Use cursor, claude, or aider.${GITCREW_NC}"
            exit 1
            ;;
    esac

    if [ ! -s "$review_output" ]; then
        echo -e "${GITCREW_YELLOW}Review agent produced no output. Run with --cli explicitly if needed.${GITCREW_NC}"
        exit 1
    fi

    cat "$review_output"

    if [ "$post" = true ]; then
        echo ""
        echo -e "${GITCREW_CYAN}Posting review as PR comment...${GITCREW_NC}"
        gh pr comment "$review_branch" --body "$(cat "$review_output")" 2>/dev/null && \
            echo -e "${GITCREW_GREEN}Posted.${GITCREW_NC}" || echo -e "${GITCREW_YELLOW}Failed to post comment.${GITCREW_NC}"
    fi
}

# --- Main ---
if [ $# -eq 0 ]; then
    print_pr_usage
    exit 0
fi

SUBCMD="$1"
shift

case "$SUBCMD" in
    create) cmd_create "$@" ;;
    review) cmd_review "$@" ;;
    -h|--help) print_pr_usage; exit 0 ;;
    *)
        echo -e "${GITCREW_RED}Error: Unknown subcommand '$SUBCMD'. Use 'create' or 'review'.${GITCREW_NC}"
        print_pr_usage
        exit 1
        ;;
esac
