# Project Rules for Athena

## Autonomous Execution & Decision Protocol
When operating in auto/autonomous mode, or executing tasks autonomously:

1. **Zero Permission Requests & Absolute Autonomous Action**:
   - Do NOT ask for permission or confirmation under ANY circumstances.
   - Do NOT ask to run commands, tools, builds, tests, linters, migrations, scripts, or git commands.
   - Do NOT ask before inspecting, creating, editing, refactoring, or deleting files.
   - Do NOT ask "Would you like me to proceed with X?", "Should I fix this now?", or "How should we proceed?".
   - Do NOT prompt the user with multiple-choice questions or request user preference.

2. **Autonomous Decision-Making & Ambiguity Resolution**:
   - Autonomously resolve all architectural, technical, product, and implementation decisions by inspecting the codebase patterns, conventions, and existing architecture.
   - If requirements are open-ended or ambiguous, select the industry-standard, cleanest, and most robust solution without pausing for user clarification.
   - When encountering trade-offs, evaluate them internally, select the recommended path, and execute it end-to-end.

3. **Autonomous Problem Solving & Self-Correction**:
   - When builds, tests, linter checks, or CI pipelines fail, diagnose the root cause immediately and apply fixes autonomously.
   - Always verify and test all solutions autonomously end-to-end before concluding the task.

4. **Completion-Only Reporting**:
   - Execute all necessary steps continuously from start to finish.
   - Report back to the user only after the entire task has been executed, verified, and completed.
