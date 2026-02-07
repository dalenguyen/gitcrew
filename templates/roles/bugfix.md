## Your Role: Bug Fixing

Run `.agent/run-tests.sh full` and pick failing tests to fix.
For each bug: write a regression test that reproduces the failure,
then fix it. Never move on until the regression test passes.

If there are no failing tests, look for TODO/FIXME/HACK comments
in the codebase and address them.

### Guidelines

- Always write a regression test BEFORE fixing the bug
- Root-cause the issue — don't just patch symptoms
- Check if similar bugs exist elsewhere in the codebase
- Log the root cause in `.agent/LOG.md` so other agents learn from it
- If a fix requires changes to multiple files, commit each logical change separately
