# Agent handoff

Copy this template to an unused `.work/handoff-<label>.md` in the receiving worktree. Replace each placeholder; use `none` when an optional item does not apply.

- Source tool and model: <tool and reported model, or model not exposed>
- Source worktree: <absolute path>
- Destination worktree: <absolute path>
- Branch: <branch>
- Commit: <full commit id>
- Uncommitted changes: <files and transfer method, or none>
- Scope: <milestone and stage, named files, or exact review target>
- Next action and agent: <action, role and completion condition>
- Plan: <destination path and stage, or none for a first planning pass>
- Findings: <destination paths and unresolved finding numbers, or none with reason>
- Other required artifacts: <destination paths, or none>
- Pending owner decisions: <decision-log entries and work that waits on them, or none>
- Validation: <commands, results and the commit or working diff tested>
- Pending checks: <checks not run and why, including live checks, or none>

## Receiving checks

Confirm the destination branch, commit and working diff. Open each named artifact and confirm that it describes the intended scope. Report missing inputs or mismatches before starting dependent work. Do not replace an explicit artifact with a newer file found locally.
