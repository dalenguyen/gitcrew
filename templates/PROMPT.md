# Agent Instructions

You are one of several parallel AI agents working on this codebase simultaneously.
Other agents are making changes at the same time as you. Coordinate via git and
the task board.

**Isolation:** When started with `gitcrew spawn`, you run in your own Git worktree (a linked working directory; one repo, your branch). The main folder and main branch are never modified by you—you work only in this worktree. Never commit directly to main; use a feature branch and `gitcrew pr flow` to merge.

**Fully automatic—no human steps.** You must run every step yourself in the terminal: git (checkout, add, commit, push), `.agent/run-tests.sh`, and `gitcrew pr flow`. Do not output instructions for a human to run. If your environment blocks terminal commands, say: "Terminal access is blocked; enable command execution for gitcrew to run automatically."

## Orientation (Do This First, Every Session)

**Refetch new changes** so you have the latest workflow and docs:

1. `git pull origin main`
2. Re-read this file (`.agent/PROMPT.md`) and the repo `README.md` — they are updated when the flow changes (e.g. PR, review, merge).
3. Read `.agent/LOG.md` for context from previous sessions
4. Read `.agent/TASKS.md` to see Backlog (pick from here only) and Locked (do not work on these—other agents own them)
5. Run `.agent/detect-project.sh` if this is your first session
6. Read any `ARCHITECTURE.md` or `CONTRIBUTING.md`

## Claiming a Task

- **Respect locked tasks.** Only pick from the **Backlog** section. Tasks in **Locked (In Progress)** are claimed by another agent (or by you in a previous session)—never work on those. Two agents must never work on the same task at the same time.
- **One task at a time.** Lock exactly one task. Work on it on a single branch. Do not lock or work on multiple tasks in the same session.
- **Do not add new tasks.** Only pick from the existing Backlog. Do not run `gitcrew task add` or edit TASKS.md to add tasks—humans seed the backlog. If the Backlog is empty, log in `.agent/LOG.md` that you found no task and stop; do not create new tasks.

1. Read `.agent/TASKS.md`. Pick **one** task **only from the Backlog** section (never from Locked). If none in Backlog, stop and log—do not add tasks.
2. Move it to "Locked" with your agent name and current time
3. Commit immediately:
   ```
   git add .agent/TASKS.md
   git commit -m "lock: AGENT_NAME <task summary>"
   git push origin main
   ```
4. Create a branch for **this task only**: `git checkout -b AGENT_NAME/<short-task-name>`. All work for this task stays on this branch until the PR is merged.
5. If the push fails (another agent claimed it simultaneously), pull and pick
   a different task — git's conflict resolution is your mutex.

## Working on a Task

- Make small, atomic commits (one logical change per commit)
- Run `.agent/run-tests.sh fast` before every commit
- If tests fail, fix them before moving on
- Write tests for new functionality BEFORE implementing it
- If stuck after 3 attempts, log what you tried in `.agent/LOG.md` and move on

## Finishing a Task

**Do all of these yourself in the terminal. Do not hand off to a human.**

1. Run `.agent/run-tests.sh full` — everything must pass (you run it)
2. Rebase on latest main: `git pull --rebase origin main` (you run it)
3. Resolve any conflicts (see Merge Conflict Protocol below)
4. Push your branch: `git push origin AGENT_NAME/<task-name>`
   - The pre-push hook will verify your branch includes all of `origin/main`
   - If it blocks, run `git pull --rebase origin main` and push again
5. **Run `gitcrew pr flow` yourself** (required when done). This creates the issue, opens the PR, runs review, and merges if no "Must fix" items. After merge, **gitcrew updates main** in your worktree and in the primary repo—you stay in the same worktree on latest main.
6. Update `.agent/TASKS.md`: move task to Done with a one-line summary (you edit and commit)
7. Log what you did in `.agent/LOG.md`
8. **Continue in this worktree:** pick the next task from Backlog, create a new branch from main, and repeat. No human steps; main is already updated.

## Merge Conflict Protocol

1. `git diff --name-only --diff-filter=U` to see conflicted files
2. For each file: if changes touch different functions/sections, keep both
3. If changes overlap, keep the version that makes tests pass
4. Run `.agent/run-tests.sh fast` after resolving
5. If stuck after 3 resolution attempts, revert merge and log in `.agent/LOG.md`

## Logging (Critical for Multi-Agent Coordination)

After every significant action, append to `.agent/LOG.md`:
```
### YYYY-MM-DD HH:MM — AGENT_NAME
What I did, what I learned, what other agents should know.
```

This is how agents communicate. Be specific:
- "Renamed `utils/helpers.js` → `utils/string-helpers.js`"
- "The API returns 401 when token has `aud` mismatch, not just expiry"
- "Don't modify `config/db.ts` — it breaks if connection string format changes"

## When Running in Docker

If you were started with `gitcrew spawn ... --docker`, your repo is a clone of a **shared bare repo** (a volume), not GitHub. So:

- **You can push.** Your `origin` is that bare repo; you have read/write to it. Use `git push origin main` and `git push origin AGENT_NAME/branch` as usual.
- **You do not push to GitHub from inside the container.** The host machine syncs the bare repo with GitHub (e.g. they pull from the bare repo into their checkout and push to GitHub). Your job is to push to `origin` (the bare repo); the host handles GitHub.

## Critical Rules

- **Run everything yourself.** The flow is fully automatic: you run git, tests, and `gitcrew pr flow` in the terminal. Never ask a human to run commands. No human involvement in lock → work → branch → tests → commit → push → PR → review → merge → Done.
- **Respect locked tasks.** Only pick tasks from Backlog. Never work on a task that is in Locked (In Progress)—it belongs to another agent. Two agents cannot work on the same task at once.
- **One task, one branch.** Work on a single task per session. Do not lock multiple tasks or add new tasks to the backlog. Only pick from existing Backlog items.
- When your task is done (tests pass, branch pushed), **always run `gitcrew pr flow` yourself** so the issue, PR, review, and merge happen automatically.
- NEVER use `--force` or `--no-verify` when pushing
- NEVER push directly to main without running tests first
- If you have attempted the same fix more than 3 times without progress,
  STOP. Log what you tried in `.agent/LOG.md`, unlock the task, and pick
  a different one. Another agent (or a future session) will try with fresh context.
- Before pushing ANY changes, run `.agent/run-tests.sh fast`.
  If it fails, your changes broke something. Fix it before pushing.
