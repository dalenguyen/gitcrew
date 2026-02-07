# Agent Task Board

## 🔒 Locked (In Progress)
- [ ] Chore: complete doctor test coverage PR — Run from repo root: `bash .agent/finish-doctor-coverage.sh` (creates branch, tests, commit, push, gitcrew pr flow); then move this line to Done (Agent-C 2026-02-07)

## 📋 Backlog (Available)
<!-- Seed this with your actual work items using: gitcrew task add "description" -->

## ✅ Done
- [x] Chore: add missing test coverage for doctor (--help, unknown option, --fix) — Added test_doctor_help_shows_usage, test_doctor_unknown_option_fails, test_doctor_fix_makes_script_executable (Agent-C 2026-02-07)
- [x] Fix: monitor --interval N leaves N as next argv — `--interval` now uses `shift 2; continue` so the numeric value is consumed; added test_monitor_interval_consumes_argument (Agent-C 2026-02-07)
- [x] Chore: consolidate duplicate dashboard logic in monitor.sh — watch now runs `gitcrew monitor --once` so single code path (render_dashboard), removed ~50-line heredoc (Agent-C 2026-02-07)
- [x] Chore: improve gitcrew monitor — shortened Recent Agent Log to 5 lines and added "full log: gitcrew log show" hint so dashboard stays scannable (Agent-C 2026-02-07)
- [x] Fix: gitcrew init should check for other folders rather than just .agent folder since it may exist but it's not for gitcrew — init now treats .agent as gitcrew only when TASKS.md and PROMPT.md exist; otherwise init proceeds (regression tests added) (2026-02-07)
<!-- Agents move completed tasks here with a short summary -->
- [x] Feature: workflow to create issue + PR + code review before merge (review agent follows best practices) — Added gitcrew pr create (issue+PR) and pr review (code review agent with best-practices role); gh in Docker image; 6 tests; PROMPT/README updated (2026-02-07)
- [x] Feature: add bash/zsh shell completion for gitcrew — Added CONTRIBUTING.md with full dev guide — Agent-B (2026-02-07)
- [x] Chore: add CONTRIBUTING.md with development guide — Added bash/zsh completions, --completions flag, 4 tests — Agent-A (2026-02-07)
- [x] Chore: add CI test badge to README — Added Tests + Docs CI badges to README header (2026-02-07)
- [x] Feature: add 'gitcrew status' command for quick project overview — Created status command showing tasks, branches, hooks, git state, 3 tests (2026-02-07)
- [x] Feature: add 'gitcrew log' command to append entries to .agent/LOG.md — Created log command with append and show subcommands, 4 tests (2026-02-07)
- [x] Feature: add Cursor agent CLI support to spawn and run-loop — Added cursor (agent CLI) as supported tool in spawn, run-loop, doctor, docs, and README (2026-02-07)
- [x] Feature: add bash test suite for gitcrew CLI — 43 tests covering all 6 commands with zero-dep bash runner (2026-02-07)
- [x] Chore: configure .agent/run-tests.sh for this repo — Configured to call bash tests/runner.sh (2026-02-07)
- [x] Chore: install gitcrew hooks with working test harness — Installed pre-push hook via gitcrew hooks (2026-02-07)
- [x] Fix: install bar text overflow and center alignment on docs page — Fixed with margin auto, ellipsis, flex-shrink (2026-02-07)
- [x] Feature: create GitHub Actions workflow to auto-deploy docs to Pages (2026-02-07)
- [x] Feature: create beautiful docs site for GitHub Pages (2026-02-07)
- [x] Chore: add .gitignore for agent logs (2026-02-07)
