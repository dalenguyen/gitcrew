# Agent Task Board

## 🔒 Locked (In Progress)
<!-- Agents move tasks here and write their name + timestamp to claim them -->

## 📋 Backlog (Available)
<!-- Seed this with your actual work items using: gitcrew task add "description" -->

## ✅ Done
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
