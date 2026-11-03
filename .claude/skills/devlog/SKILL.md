---
name: devlog
description: Draft a devlog entry in docs/devlog/. Use when something notable happened, especially when the AI got something wrong and a check caught it.
argument-hint: <topic>
disable-model-invocation: true
---

Draft a devlog entry about "$ARGUMENTS".

1. Create `docs/devlog/YYYY-MM-DD-<short-name>.md` with today's date.
2. Gather facts from the linked issues, PRs, commits and reviews. Quote real numbers, test names and commit SHAs. Do not invent or round up.
3. Write it in plain language, under 500 words, in this shape:
   - **What we set out to do**
   - **What happened**, including what was hard
   - **Where the AI got it wrong**, if it did, and **which check caught it** (test, reviewer, playtest, CI). Be specific and unvarnished; these entries are the point of the devlog.
   - **What we changed** in the code or the process as a result
   - Links to the issue, PR and any ADR
4. Keep it about the game and how it is made. Australian spelling.
5. Show the maintainer the draft before committing it. The devlog is append-only: never edit a published entry except to fix a broken link.
