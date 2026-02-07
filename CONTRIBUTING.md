# Contributing to gitcrew

Thank you for your interest in contributing! This guide will help you get started.

## Getting Started

### Prerequisites

- **Bash 4+** (macOS ships with Bash 3; install newer via `brew install bash`)
- **Git** 2.x+
- No other dependencies required — gitcrew is zero-dependency by design

### Setup

```bash
# Clone the repo
git clone https://github.com/dalenguyen/gitcrew.git
cd gitcrew

# Link gitcrew into your PATH for development
ln -sf "$(pwd)/gitcrew" ~/.local/bin/gitcrew

# Bootstrap gitcrew's own agent directory
gitcrew init

# Run the test suite
bash tests/runner.sh full
```

## Project Structure

```
gitcrew/
├── gitcrew              # Main CLI entrypoint (bash)
├── commands/            # One file per subcommand (init, spawn, task, etc.)
├── templates/           # Files copied by `gitcrew init` into .agent/
│   ├── TASKS.md         # Agent task board template
│   ├── PROMPT.md        # Base agent prompt
│   ├── LOG.md           # Agent log template
│   ├── run-loop.sh      # Continuous agent loop
│   ├── run-tests.sh     # Project test wrapper
│   └── roles/           # Role-specific prompt fragments
├── completions/         # Shell completion scripts (bash, zsh)
├── tests/               # Test suite
│   ├── runner.sh        # Zero-dependency bash test runner
│   └── test_*.sh        # Test files (one per command)
├── docs/                # GitHub Pages site
└── install.sh           # One-line installer
```

## Development Workflow

### 1. Pick a task

```bash
gitcrew task list            # See available tasks
gitcrew task lock 1 YourName # Claim a task
```

### 2. Create a branch

Branch naming convention: `YourName/short-description`

```bash
git checkout -b YourName/fix-monitor-parsing
```

### 3. Write tests first

Every feature or bug fix should have tests. Add them in `tests/test_<command>.sh`:

```bash
test_my_new_feature() {
    sandbox=$(setup_sandbox)
    cd "$sandbox"

    "$GITCREW" init > /dev/null 2>&1

    local output
    output=$("$GITCREW" my-command --flag)
    assert_contains "$output" "expected text" "description of check"

    teardown_sandbox "$sandbox"
}
```

### 4. Run tests

```bash
# Run all tests (verbose output)
bash tests/runner.sh full

# Quick mode (stops on first failure)
bash tests/runner.sh fast
```

### 5. Mark task done and commit

```bash
gitcrew task done 1 "Brief summary of what you did"
git add -A
git commit -m "feat: short description of change"
```

### 6. Push and create a PR

The pre-push hook will run all tests automatically:

```bash
git push -u origin YourName/fix-monitor-parsing
gh pr create --title "Fix monitor parsing" --body "Closes #123"
```

## Writing Tests

### Test Helpers

The test runner (`tests/runner.sh`) provides:

| Helper | Description |
|--------|-------------|
| `setup_sandbox` | Creates isolated temp git repo, returns path |
| `teardown_sandbox "$path"` | Cleans up the temp repo |
| `assert_contains "$output" "needle" "msg"` | Checks output contains string |
| `assert_not_contains "$output" "needle" "msg"` | Checks output does NOT contain string |
| `assert_file_exists "$path" "msg"` | Checks file exists |
| `assert_exit_code "$code" "msg"` | Checks last exit code |

### Test Conventions

- One test file per command: `test_<command>.sh`
- Function names: `test_<command>_<scenario>()`
- Always use `setup_sandbox` / `teardown_sandbox` for isolation
- Test both success and failure paths

## Code Style

- **Shell**: Follow [Google's Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- Use `set -euo pipefail` in all scripts
- Quote all variables: `"$var"` not `$var`
- Use `local` for function variables
- Prefer `$(command)` over backticks
- Add `|| true` after `grep` in pipelines (exit code 1 on no match breaks `set -e`)
- Use `>/dev/null 2>&1` to silence output (order matters: stdout first, then stderr)

## Commit Messages

Follow conventional commits:

```
feat: add shell completion support
fix: monitor dashboard crash on empty repo
docs: update quickstart in README
test: add hooks command test coverage
chore: update install script for Apple Silicon
```

## Need Help?

- Check existing tests for examples of how things work
- Run `gitcrew doctor` to verify your setup
- Open an issue on GitHub if you're stuck
