# Agent Instructions

You are one of several parallel AI agents working on this codebase simultaneously.
Other agents are making changes at the same time as you. Coordinate via git and
the task board.

## Orientation (Do This First, Every Session)

**Refetch new changes** so you have the latest workflow and docs:

1. `git pull origin main`
2. Re-read this file (`.agent/PROMPT.md`) and the repo `README.md` — they are updated when the flow changes (e.g. PR, review, merge).
3. Read `.agent/LOG.md` for context from previous sessions
4. Read `.agent/TASKS.md` to see what's available and locked
5. Run `.agent/detect-project.sh` if this is your first session
6. Read any `ARCHITECTURE.md` or `CONTRIBUTING.md`

## Claiming a Task

1. Pick an unlocked task from the Backlog section of `.agent/TASKS.md`
2. Move it to "Locked" with your agent name and current time
3. Commit immediately:
   ```
   git add .agent/TASKS.md
   git commit -m "lock: AGENT_NAME <task summary>"
   git push origin main
   ```
4. Create a branch: `git checkout -b AGENT_NAME/<short-task-name>`
5. If the push fails (another agent claimed it simultaneously), pull and pick
   a different task — git's conflict resolution is your mutex.

## Working on a Task

- Make small, atomic commits (one logical change per commit)
- Run `.agent/run-tests.sh fast` before every commit
- If tests fail, fix them before moving on
- Write tests for new functionality BEFORE implementing it
- If stuck after 3 attempts, log what you tried in `.agent/LOG.md` and move on

## Finishing a Task

1. Run `.agent/run-tests.sh full` — everything must pass
2. Rebase on latest main: `git pull --rebase origin main`
3. Resolve any conflicts (see Merge Conflict Protocol below)
4. Push your branch: `git push origin AGENT_NAME/<task-name>`
   - The pre-push hook will verify your branch includes all of `origin/main`
   - If it blocks, run `git pull --rebase origin main` and push again
5. **Run `gitcrew pr flow` (required when done).** This creates the GitHub issue (if none yet), opens the PR, runs the code review in an isolated directory (parallel-safe), posts the review as a PR comment, and **merges if there are no "Must fix" items**. Do this automatically every time you finish a task. If the review finds blocking issues, fix them, then run `gitcrew pr flow` again. (Only if you cannot use `gh` or the flow fails: use `gitcrew pr flow --skip-review` to merge without review, or do steps manually.)
6. Update `.agent/TASKS.md`: move task to Done with a one-line summary
7. Log what you did in `.agent/LOG.md`
8. Pick the next task. Repeat.

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

- When your task is done (tests pass, branch pushed), **always run `gitcrew pr flow`** so the issue, PR, review, and merge happen automatically.
- NEVER use `--force` or `--no-verify` when pushing
- NEVER push directly to main without running tests first
- If you have attempted the same fix more than 3 times without progress,
  STOP. Log what you tried in `.agent/LOG.md`, unlock the task, and pick
  a different one. Another agent (or a future session) will try with fresh context.
- Before pushing ANY changes, run `.agent/run-tests.sh fast`.
  If it fails, your changes broke something. Fix it before pushing.
