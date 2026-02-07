# gitcrew

[![Tests](https://github.com/dalenguyen/gitcrew/actions/workflows/test.yml/badge.svg)](https://github.com/dalenguyen/gitcrew/actions/workflows/test.yml)
[![Docs](https://github.com/dalenguyen/gitcrew/actions/workflows/deploy-docs.yml/badge.svg)](https://dalenguyen.github.io/gitcrew/)

Parallel & Continuous AI Agent Teams for Any Codebase.

A zero-dependency CLI toolkit for running multiple AI agents in parallel on a shared git repo. Inspired by [Anthropic's parallel Claude agent teams](https://www.anthropic.com/engineering/building-c-compiler) pattern, generalized for any language, framework, or existing project.

```
┌──────────────────────────────────────────────────┐
│                  Shared Git Repo                  │
│          (main branch = source of truth)          │
└──────────┬───────────┬───────────┬───────────────┘
           │           │           │
     ┌─────┴──┐  ┌─────┴──┐  ┌────┴───┐
     │Agent A │  │Agent B │  │Agent C │
     │Feature │  │Bug Fix │  │Quality │
     │Worker  │  │Worker  │  │& Docs  │
     └────────┘  └────────┘  └────────┘
```

Each agent: clones repo → reads task board → picks a task → locks it → works on a branch → runs tests → merges → repeats.

---

## Install

**One-line install:**

```bash
curl -fsSL https://raw.githubusercontent.com/dalenguyen/gitcrew/main/install.sh | bash
```

**Or clone manually:**

```bash
git clone https://github.com/dalenguyen/gitcrew.git ~/.gitcrew
ln -s ~/.gitcrew/gitcrew ~/.local/bin/gitcrew
```

**Requirements:** bash, git. No other dependencies.

---

## Quickstart

```bash
# 1. Go to your project
cd your-project/

# 2. Bootstrap the .agent/ directory
gitcrew init

# 3. Check everything is ready
gitcrew doctor

# 4. Seed the task board
gitcrew task add "Fix: login redirect fails on expired tokens"
gitcrew task add "Feature: add CSV export to reports page"
gitcrew task add "Chore: increase test coverage on utils/"

# 5. Start agents
gitcrew spawn Agent-A feature
gitcrew spawn Agent-B bugfix
gitcrew spawn Agent-C quality

# 6. Monitor in another terminal
gitcrew monitor
```

---

## Commands

### `gitcrew init`

Bootstraps the `.agent/` directory in your current repo with all coordination files, role templates, test wrapper, and monitoring scripts.

```bash
gitcrew init              # Standard setup
gitcrew init --force      # Overwrite existing .agent/
gitcrew init --no-roles   # Skip role files
gitcrew init --no-docker  # Skip Docker files
gitcrew init --no-hooks   # Skip git hooks
```

**What it creates:**

```
.agent/
├── TASKS.md              # Shared task board (agents read/write)
├── LOG.md                # Shared memory across sessions
├── PROMPT.md             # System instructions for every agent
├── detect-project.sh     # Auto-detects your stack
├── run-tests.sh          # Agent-friendly test wrapper
├── run-loop.sh           # Continuous agent loop script
├── monitor.sh            # Standalone monitoring dashboard
├── spawn-docker.sh       # Docker-based agent spawner
├── docker-compose.agents.yml
├── logs/                 # Agent session logs
└── roles/
    ├── feature.md        # Feature implementation role
    ├── bugfix.md         # Bug fixing role
    ├── quality.md        # Code quality & refactoring role
    ├── docs.md           # Documentation role
    └── integration.md    # CI / merge gatekeeper role
```

### `gitcrew spawn`

Starts an agent loop. The agent reads the task board, claims a task, works on it, and loops.

```bash
gitcrew spawn Agent-A feature              # Claude Code (default)
gitcrew spawn Agent-B bugfix --cli cursor  # Use Cursor Agent
gitcrew spawn Agent-C quality --cli aider  # Use Aider
gitcrew spawn Agent-D docs --cli codex     # Use Codex CLI
gitcrew spawn Agent-A feature --once       # Single session (no loop)
gitcrew spawn Agent-A feature --dry-run    # Preview without executing
gitcrew spawn Agent-A feature --docker     # Run in Docker container
```

**Supported CLI tools:** `claude` (Claude Code), `cursor` (Cursor Agent), `aider`, `codex`

### `gitcrew task`

Manage the shared task board.

```bash
gitcrew task list                               # Show all tasks
gitcrew task add "Fix: login redirect bug"      # Add to backlog
gitcrew task lock 1 Agent-A                     # Lock task #1 for Agent-A
gitcrew task done 1 "Fixed with token refresh"  # Mark as completed
gitcrew task unlock 1                           # Move back to backlog
gitcrew task import tasks.txt                   # Bulk import from file
gitcrew task clear-done                         # Archive completed tasks
```

### `gitcrew monitor`

Live dashboard showing task status, active branches, recent commits, and agent log.

```bash
gitcrew monitor               # Auto-refresh every 15s
gitcrew monitor --interval 5  # Refresh every 5s
gitcrew monitor --once        # Print once and exit
```

### `gitcrew doctor`

Checks your project's readiness for running agents.

```bash
gitcrew doctor        # Run all checks
gitcrew doctor --fix  # Auto-fix common issues
```

Checks: git repo, remote, `.agent/` files, test infrastructure, role files, git hooks, CLI tools.

### `gitcrew hooks`

Installs git hooks that prevent pushing broken code.

```bash
gitcrew hooks           # Install pre-push hook
gitcrew hooks --remove  # Remove hooks
```

### `gitcrew log`

Append to or view the shared agent log.

```bash
gitcrew log Agent-A "Refactored auth module, all tests pass"
gitcrew log show          # Show last 20 lines
gitcrew log show -n 50    # Show last 50 lines
```

### `gitcrew status`

Quick one-line summary of task counts, branches, hooks, and working tree state.

```bash
gitcrew status
```

---

## How It Works

### Coordination via Git

There is **no orchestrator agent**. Agents coordinate through:

1. **Task board** (`.agent/TASKS.md`) — agents claim tasks by writing their name and pushing. Git conflicts act as a mutex.
2. **Shared log** (`.agent/LOG.md`) — agents write observations, decisions, and warnings for other agents.
3. **Git branches** — each agent works on its own branch and merges to main when done.
4. **Tests** — the test suite is the source of truth. If tests pass, the code is good.

### Agent Lifecycle

```
1. git pull origin main
2. Read .agent/LOG.md (context from other agents)
3. Read .agent/TASKS.md (pick an available task)
4. Lock the task (commit + push to main)
5. Create feature branch
6. Work: edit code → run tests → commit (loop)
7. Merge main → resolve conflicts → run full tests
8. Merge to main, mark task done, log what happened
9. Go to step 1
```

### Three Deployment Approaches

| Approach | Setup | Isolation | Best For |
|----------|-------|-----------|----------|
| **Chat sessions** | Zero | Shared filesystem | Quick experiments, 2-3 agents |
| **Terminal loops** | Minimal | Shared filesystem | Production use, any scale |
| **Docker containers** | Moderate | Full isolation | Maximum safety, CI/CD |

---

## Customization

### Edit the Test Wrapper

After `gitcrew init`, edit `.agent/run-tests.sh` to match your project's actual commands. The auto-detection handles common stacks, but you may need to customize.

### Create Custom Roles

Add files to `.agent/roles/`:

```bash
# .agent/roles/security.md
## Your Role: Security Auditor
Review code for security vulnerabilities. Check for:
- SQL injection, XSS, CSRF
- Hardcoded secrets
- Missing input validation
- Insecure dependencies
Log findings in .agent/LOG.md with severity ratings.
```

Then spawn with: `gitcrew spawn Agent-S security`

### Seed Tasks from Your Issue Tracker

Create a file with one task per line and import:

```bash
# tasks.txt
Fix: login redirect fails on expired tokens
Feature: add CSV export to reports page
Chore: increase test coverage on utils/
Refactor: consolidate duplicate API client wrappers

gitcrew task import tasks.txt
```

---

## Best Practices

1. **Start with 2 agents, not 16.** Get coordination working before scaling.
2. **Invest in tests.** Agents are only as good as the test harness. Fast, deterministic, greppable, comprehensive.
3. **Decompose large tasks.** Break monolithic failures into independent sub-tasks.
4. **Use the log.** `.agent/LOG.md` is how agents communicate. Be specific.
5. **Set timeouts.** The test wrapper has 5-minute timeouts to prevent agents from hanging.
6. **Review git hooks.** The pre-push hook prevents broken code from reaching main.

---

## Troubleshooting

**Agents claim the same task:**
Git's conflict resolution handles this. When two agents try to lock the same task, one push will fail. The agent prompt instructs them to pull and pick a different task.

**Tests are too slow:**
Edit `.agent/run-tests.sh` to use a faster subset for `fast` mode. Only run full tests before merging.

**Agent context window fills up:**
The test wrapper uses `tail -20` to limit output. The `SUMMARY:` line tells agents the result without reading all output.

**Agent loops on the same error:**
The prompt instructs agents to stop after 3 attempts, log what they tried, and move to a different task.

Run `gitcrew doctor` to diagnose common setup issues.

---

## License

MIT
