#!/bin/bash
# .agent/detect-project.sh — profiles a repo for agent onboarding
# Run this to discover test commands, languages, and project structure.

set -euo pipefail

echo "=== Language / Framework ==="
[ -f "package.json" ] && echo "Node.js project (package.json found)"
[ -f "requirements.txt" ] && echo "Python project (requirements.txt)"
[ -f "setup.py" ] && echo "Python project (setup.py)"
[ -f "pyproject.toml" ] && echo "Python project (pyproject.toml)"
[ -f "Cargo.toml" ] && echo "Rust project (Cargo.toml)"
[ -f "go.mod" ] && echo "Go project (go.mod)"
[ -f "Gemfile" ] && echo "Ruby project (Gemfile)"
[ -f "pom.xml" ] && echo "Java/JVM project (pom.xml)"
[ -f "build.gradle" ] && echo "Java/JVM project (build.gradle)"
[ -f "Makefile" ] && echo "Makefile found"
[ -f "Dockerfile" ] && echo "Dockerfile found"
[ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ] && echo "Docker Compose found"

echo ""
echo "=== Test Infrastructure ==="
if [ -f "package.json" ]; then
    echo "npm scripts with test/lint/check:"
    node -e "
        const p = require('./package.json');
        Object.keys(p.scripts || {})
            .filter(s => s.match(/test|lint|check|format/))
            .forEach(s => console.log('  ' + s + ': ' + p.scripts[s]));
    " 2>/dev/null || echo "  (could not read package.json scripts)"
fi

if [ -f "Makefile" ]; then
    echo "Make targets (test/lint/check):"
    grep -E '^[a-zA-Z_-]+:' Makefile 2>/dev/null | grep -iE "test|lint|check|format" | while IFS= read -r line; do
        echo "  $line"
    done
fi

if [ -f "pyproject.toml" ]; then
    echo "Python config (pyproject.toml):"
    grep -E "^\[tool\." pyproject.toml 2>/dev/null | head -10 | while IFS= read -r line; do
        echo "  $line"
    done
fi

echo ""
echo "=== Project Structure ==="
echo "Top-level directories:"
find . -maxdepth 1 -type d ! -name '.' ! -name '.git' ! -name 'node_modules' ! -name '.agent' ! -name '__pycache__' ! -name '.venv' ! -name 'venv' | sort | while IFS= read -r dir; do
    echo "  ${dir#./}/"
done

echo ""
echo "Documentation files:"
find . -maxdepth 2 -type f -name "*.md" ! -path "./.agent/*" ! -path "./node_modules/*" 2>/dev/null | head -20 | while IFS= read -r f; do
    echo "  ${f#./}"
done

echo ""
echo "=== Existing Docs ==="
[ -f "README.md" ] && echo "README.md: $(wc -l < README.md) lines"
[ -f "CONTRIBUTING.md" ] && echo "CONTRIBUTING.md found"
[ -f "ARCHITECTURE.md" ] && echo "ARCHITECTURE.md found"
[ -f "CHANGELOG.md" ] && echo "CHANGELOG.md found"

echo ""
echo "=== Git Info ==="
if git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "Branches: $(git branch -a 2>/dev/null | wc -l | tr -d ' ')"
    echo "Recent commits:"
    git log --oneline -5 2>/dev/null || echo "  (no commits yet)"
else
    echo "(not a git repository)"
fi
