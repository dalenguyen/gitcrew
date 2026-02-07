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
    echo -e "    ${GITCREW_GREEN}flow${GITCREW_NC}     Create PR (if needed) → review → merge if no 'Must fix' items (or exit 1)"
    echo -e "    ${GITCREW_GREEN}merge${GITCREW_NC}     Merge the PR for current branch (no review)"
    echo ""
    echo -e "${GITCREW_BOLD}OPTIONS (flow)${GITCREW_NC}"
    echo "    --skip-review   Skip AI review and merge immediately (e.g. CI or after manual review)"
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
    echo "    gitcrew pr flow              # create → review → merge if OK"
    echo "    gitcrew pr flow --skip-review   # create → merge (no AI review)"
    echo "    gitcrew pr merge             # merge current branch PR"
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
    require_gh
    check_gh_version

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

# Run code review in an isolated temp directory (outside repo). Cleaned up after.
# Parallel-safe: each invocation gets its own dir. Writes review output to absolute path $3.
# Usage: run_review_isolated "<prompt_content>" "<cli>" "<output_file_absolute>"
run_review_isolated() {
    local prompt_content="$1"
    local cli="$2"
    local output_file="$3"
    local output_abs="$output_file"
    [[ "$output_abs" != /* ]] && output_abs="${PWD}/${output_file}"

    (
        local review_dir
        review_dir=$(mktemp -d -t gitcrew-review.XXXXXX 2>/dev/null) || review_dir=$(mktemp -d 2>/dev/null)
        if [ -z "$review_dir" ] || [ ! -d "$review_dir" ]; then
            echo -e "${GITCREW_RED}Error: Could not create temporary directory for review.${GITCREW_NC}" >&2
            exit 1
        fi
        trap 'rm -rf "$review_dir"' EXIT

        local prompt_path="${review_dir}/prompt.md"
        local out_path="${review_dir}/out.txt"
        echo "$prompt_content" > "$prompt_path"

        case "$cli" in
            claude)
                (cd "$review_dir" && claude --dangerously-skip-permissions -p "$prompt_path" 2>/dev/null > "$out_path") || true
                ;;
            cursor|agent)
                (cd "$review_dir" && agent -p "$prompt_path" 2>/dev/null > "$out_path") || true
                ;;
            aider)
                (cd "$review_dir" && aider --message "$(cat "$prompt_path")" --no-auto-commits 2>/dev/null > "$out_path") || true
                ;;
            *)
                echo -e "${GITCREW_RED}Error: Unsupported CLI '${cli}'.${GITCREW_NC}" >&2
                exit 1
                ;;
        esac

        [ -f "$out_path" ] && cp "$out_path" "$output_abs"
    )
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

    echo -e "${GITCREW_CYAN}Running code review agent (${cli}) in isolated directory...${GITCREW_NC}"
    echo ""

    local review_output
    review_output=$(mktemp)
    trap "rm -f ${review_output}" EXIT
    run_review_isolated "$review_prompt" "$cli" "$review_output"

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

# Returns 0 if review has no blocking "Must fix" items, 1 if it has any Must fix items.
# Blocks on any list item in the Must fix section (numbered "1." or "- ..." or "- [ ]").
review_has_blocking_issues() {
    local review_file="$1"
    local in_must_fix=0
    while IFS= read -r line; do
        if echo "$line" | grep -qE '^##? .*[Mm]ust fix'; then
            in_must_fix=1
            continue
        fi
        if [ "$in_must_fix" = 1 ]; then
            if echo "$line" | grep -qE '^##? '; then
                break
            fi
            # Numbered list item (1. 2. ...)
            if echo "$line" | grep -qE '^[0-9]+\.'; then
                return 1
            fi
            # Dash list item (- ... or - [ ]); allow "- None" / "- None." as non-blocking
            if echo "$line" | grep -qE '^[[:space:]]*-[[:space:]]+'; then
                if ! echo "$line" | grep -qE '^[[:space:]]*-[[:space:]]+None\.?[[:space:]]*$'; then
                    return 1
                fi
            fi
        fi
    done < "$review_file"
    return 0
}

# After a PR is merged: update current worktree to main, and the main worktree if different (so main branch is current everywhere).
update_main_after_merge() {
    git fetch origin 2>/dev/null || true
    local top
    top=$(git rev-parse --show-toplevel 2>/dev/null) || return 0
    # Current worktree: switch to main and pull (so agent can continue on latest main in same worktree)
    (cd "$top" && git checkout main 2>/dev/null || git checkout master 2>/dev/null) || true
    (cd "$top" && git pull origin main 2>/dev/null || git pull origin master 2>/dev/null) || true
    # If we're in a linked worktree, also update the primary worktree that has main checked out
    local main_wt
    main_wt=$(git worktree list 2>/dev/null | awk '/\[main\]$/{print $1; exit}')
    if [ -n "$main_wt" ] && [ -d "$main_wt" ] && [ "$(cd "$main_wt" && git rev-parse --show-toplevel 2>/dev/null)" != "$top" ]; then
        (git -C "$main_wt" fetch origin 2>/dev/null; git -C "$main_wt" checkout main 2>/dev/null; git -C "$main_wt" merge origin/main 2>/dev/null || git -C "$main_wt" pull origin main 2>/dev/null) || true
        echo -e "${GITCREW_GREEN}Main branch updated in primary worktree.${GITCREW_NC}"
    fi
    # This worktree is now on main. It will be removed and recreated on next spawn, or run 'gitcrew worktree cleanup' from main repo to remove it now.
    case "$top" in
        */.agent/workspaces/*) echo -e "${GITCREW_DIM}Run 'gitcrew worktree cleanup' from the main repo to remove this agent worktree, or it will be replaced on next spawn.${GITCREW_NC}" ;;
    esac
}

# --- pr merge ---
cmd_merge() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            -h|--help) print_pr_usage; exit 0 ;;
        esac
    done
    require_gh
    check_gh_version

    local branch
    branch=$(git branch --show-current 2>/dev/null || true)
    if [ -z "$branch" ] || [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
        echo -e "${GITCREW_RED}Error: Not on a feature branch.${GITCREW_NC}"
        exit 1
    fi

    if ! gh pr view "$branch" &>/dev/null 2>&1; then
        echo -e "${GITCREW_RED}Error: No open PR for branch '${branch}'.${GITCREW_NC}"
        echo "Create one with: gitcrew pr create"
        exit 1
    fi

    echo -e "${GITCREW_CYAN}Merging PR for ${branch}...${GITCREW_NC}"
    gh pr merge "$branch" --squash --delete-branch || {
        echo -e "${GITCREW_RED}Merge failed. Try: gh pr merge ${branch}${GITCREW_NC}"
        exit 1
    }
    echo -e "${GITCREW_GREEN}PR merged.${GITCREW_NC}"
    update_main_after_merge
}

# --- pr flow: create (if needed) → review → merge if no Must fix ---
cmd_flow() {
    local skip_review=false
    while [ $# -gt 0 ]; do
        case "$1" in
            --skip-review) skip_review=true ;;
            -h|--help) print_pr_usage; exit 0 ;;
            *) ;;
        esac
        shift
    done
    require_gh
    check_gh_version

    local branch
    branch=$(git branch --show-current 2>/dev/null || true)
    if [ -z "$branch" ] || [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
        echo -e "${GITCREW_RED}Error: Create a feature branch first.${GITCREW_NC}"
        exit 1
    fi

    # 1. Ensure PR exists
    if ! gh pr view "$branch" &>/dev/null 2>&1; then
        echo -e "${GITCREW_CYAN}Step 1: No PR yet. Creating...${GITCREW_NC}"
        cmd_create
        echo ""
    else
        echo -e "${GITCREW_CYAN}Step 1: PR exists for ${branch}.${GITCREW_NC}"
        echo ""
    fi

    if [ "$skip_review" = true ]; then
        echo -e "${GITCREW_CYAN}Step 2: Skipping review (--skip-review). Merging...${GITCREW_NC}"
        gh pr merge "$branch" --squash --delete-branch || {
            echo -e "${GITCREW_RED}Merge failed.${GITCREW_NC}"
            exit 1
        }
        echo -e "${GITCREW_GREEN}PR merged.${GITCREW_NC}"
        update_main_after_merge
        return 0
    fi

    # 2. Run review in isolated temp dir (outside repo, cleaned up; parallel-safe)
    echo -e "${GITCREW_CYAN}Step 2: Running code review in isolated directory...${GITCREW_NC}"
    local review_file
    review_file=$(mktemp)
    trap "rm -f ${review_file}" EXIT

    local diff pr_num pr_title cli=""
    pr_num=$(gh pr view "$branch" --json number --jq '.number')
    pr_title=$(gh pr view "$branch" --json title --jq '.title')
    diff=$(gh pr diff "$branch" 2>/dev/null) || true

    if [ -z "$diff" ]; then
        echo -e "${GITCREW_YELLOW}No diff in PR. Merging.${GITCREW_NC}"
        gh pr merge "$branch" --squash --delete-branch 2>/dev/null && echo -e "${GITCREW_GREEN}PR merged.${GITCREW_NC}" || exit 1
        update_main_after_merge
        return 0
    fi

    [ -f "${AGENT_DIR}/agent.env" ] && source "${AGENT_DIR}/agent.env" 2>/dev/null || true
    cli="${AGENT_CLI:-cursor}"

    local review_prompt
    review_prompt=$(printf 'You are performing a **code review**. Output your review in the required format (summary, Must fix, Should fix, Suggestions). Be specific.\n\n**PR:** #%s — %s\n**Branch:** %s\n\n---\nDIFF:\n```\n%s\n```\n---' "$pr_num" "$pr_title" "$branch" "$diff")
    [ -f "${AGENT_DIR}/roles/review.md" ] && review_prompt=$(cat "${AGENT_DIR}/roles/review.md")$'\n\n'"$review_prompt"

    run_review_isolated "$review_prompt" "$cli" "$review_file"

    if [ ! -s "$review_file" ]; then
        echo -e "${GITCREW_YELLOW}Review agent produced no output. Merge anyway? (flow requires review)${GITCREW_NC}"
        exit 1
    fi

    cat "$review_file"
    echo ""
    gh pr comment "$branch" --body-file "$review_file" 2>/dev/null || true

    # 3. Check for Must fix
    if ! review_has_blocking_issues "$review_file"; then
        echo -e "${GITCREW_RED}========================================${GITCREW_NC}"
        echo -e "${GITCREW_RED}  Review found 'Must fix' items. Address them, then run:${GITCREW_NC}"
        echo -e "    ${GITCREW_BOLD}git add -A && git commit -m \"...\" && git push && gitcrew pr flow${GITCREW_NC}"
        echo -e "${GITCREW_RED}========================================${GITCREW_NC}"
        exit 1
    fi

    # 4. Merge
    echo -e "${GITCREW_CYAN}Step 3: No blocking issues. Merging PR...${GITCREW_NC}"
    gh pr merge "$branch" --squash --delete-branch || {
        echo -e "${GITCREW_RED}Merge failed.${GITCREW_NC}"
        exit 1
    }
    echo -e "${GITCREW_GREEN}PR merged.${GITCREW_NC}"
    # 5. Update main in this worktree and in primary worktree so main branch is current; agent continues in same worktree on latest main
    update_main_after_merge
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
    flow)  cmd_flow "$@" ;;
    merge) cmd_merge "$@" ;;
    -h|--help) print_pr_usage; exit 0 ;;
    *)
        echo -e "${GITCREW_RED}Error: Unknown subcommand '$SUBCMD'. Use 'create', 'review', 'flow', or 'merge'.${GITCREW_NC}"
        print_pr_usage
        exit 1
        ;;
esac
