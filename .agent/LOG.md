# Agent Log

Agents write observations, decisions, blockers, and warnings here.
New agent sessions should read this first to inherit context.

---

### 2026-02-07 01:00 — Agent-Claude
- Bootstrapped gitcrew in its own repo (dogfooding)
- Created .gitignore for agent logs and editor files
- Built docs site at docs/index.html — dark theme, single-page, zero dependencies
- Created GitHub Actions workflow (.github/workflows/deploy-docs.yml) to auto-deploy docs/ to GitHub Pages on push to main
- All 3 tasks completed and tracked via gitcrew task board

### 2026-02-07 01:35 — Agent-Claude
- Added bash test suite: 43 tests across 7 test files covering all 6 CLI commands
- Zero-dependency test runner (tests/runner.sh) with sandbox isolation using temp git repos
- Configured .agent/run-tests.sh to call the test runner
- Installed pre-push hook via `gitcrew hooks` — pushes now blocked if tests fail
- Added .github/workflows/test.yml for CI on every push
- Fixed sandbox isolation bug: setup_sandbox cd was lost in $() subshell

### 2026-02-07 01:49 — Agent-A
- Added 'gitcrew log' command with append/show. 4 new tests.

### 2026-02-07 01:49 — Agent-B
- Added 'gitcrew status' command. Shows tasks, branches, hooks, working tree. 3 new tests.

### 2026-02-07 01:49 — Agent-C
- Added CI badges (Tests + Docs) to README.md header

### 2026-02-07 — Agent (Bug Fix)
- **Fix: gitcrew init and existing .agent/** — init previously refused to run whenever `.agent/` existed. It now only refuses when `.agent/` looks like a gitcrew setup (has `TASKS.md` and `PROMPT.md`). If `.agent/` exists for another tool, init proceeds and adds gitcrew files without requiring `--force`. Root cause: the check was `[ -d .agent ]` only. Change: added `is_gitcrew_agent_dir()` and require both marker files. Regression tests: `test_init_succeeds_when_agent_dir_exists_but_not_gitcrew`, `test_init_refuses_overwrite_when_agent_dir_is_gitcrew`.

### 2026-02-07 — Agent (Bug Fix)
- Orientation: read PROMPT, README, LOG, TASKS. Backlog empty; no locked tasks. Could not run `.agent/run-tests.sh full` or `bash tests/runner.sh` in this environment (invocation rejected). Reviewed `commands/init.sh` and `tests/test_init.sh` for consistency with init fix: logic and regression tests align; no bug found. Grep for TODO/FIXME/HACK: only match is doctor.sh check for uncustomized run-tests.sh (intentional). No failing tests identified; no task claimed. **Next agent:** run `bash tests/runner.sh full` locally or in CI to confirm suite health; add tasks to Backlog if needed.

### 2026-02-07 — Agent (Bug Fix)
- **Fix: test redirect order for silencing.** Many tests used `2>&1 >/dev/null`, which sends stderr to the terminal (stdout is redirected first, then stderr is redirected to the old stdout). Correct order is `>/dev/null 2>&1` so both streams are silenced. Updated test_init.sh, test_spawn.sh, test_hooks.sh, test_status.sh, test_log.sh, test_monitor.sh, test_doctor.sh, test_task.sh. test_pr.sh already used the correct order. Added CONTRIBUTING note: "Use `>/dev/null 2>&1` to silence output (order matters)."

### 2026-02-07 — Agent (Bug Fix)
- **Fix: doctor "uncustomized run-tests.sh" warning never appeared.** Doctor checked for `# TODO: Replace` in `.agent/run-tests.sh`, but the template did not contain that string. Added the line to `templates/run-tests.sh` so new installs get the warning until they customize. Regression tests: `test_doctor_warns_uncustomized_run_tests` (doctor output contains "uncustomized" and "run-tests.sh"), `test_doctor_run_tests_configured_when_customized` (after removing the TODO line, doctor reports "run-tests.sh configured"). Could not run test suite in this environment (invocation rejected); run `bash tests/runner.sh full` locally or in CI to confirm.

### 2026-02-07 — Agent (Bug Fix)
- Orientation: git pull rejected (likely offline/local only). Read PROMPT, README, LOG, TASKS, CONTRIBUTING. No ARCHITECTURE.md. Backlog empty. Role: bug fixing — run full tests, fix failures (regression test first), else TODO/FIXME/HACK.
- Could not run `.agent/run-tests.sh full` or `bash tests/runner.sh full` (invocation rejected in this environment). Static review: (1) No wrong redirect order (`2>&1 >/dev/null`) in tests; correct `>/dev/null 2>&1` used. (2) Doctor vs template: `templates/run-tests.sh` line 6 has `# TODO: Replace`; `commands/doctor.sh` checks for that string; test_doctor.sh regression tests align. (3) Grep for TODO/FIXME/HACK: only intentional doctor/template usage. No bugs identified; no task claimed. **Next agent:** run `bash tests/runner.sh full` locally or in CI to confirm suite health; add backlog tasks if needed.

### 2026-02-07 — Agent (Bug Fix)
- Orientation: git pull rejected; read PROMPT, README, LOG, TASKS, CONTRIBUTING. Backlog empty. Role: bug fixing. Could not run `bash tests/runner.sh full` (invocation rejected).
- **Fix: CONTRIBUTING.md documented `assert_not_contains` but tests/runner.sh did not define it.** Implemented `assert_not_contains` in `tests/runner.sh` (mirrors assert_contains, fails when needle is found) and added it to the exported helpers. Added regression test `test_init_success_output_has_no_error` in `tests/test_init.sh` that uses `assert_not_contains` to ensure init success output does not contain "Error:". Run `bash tests/runner.sh full` locally or in CI to confirm all tests pass.
