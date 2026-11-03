---
name: independent-review
description: Run the mandatory independent review on the current branch and record the result in the PR's "Independent review" section. Use before marking any PR ready for the maintainer.
argument-hint: [PR number]
disable-model-invocation: true
---

Run the independent review for this branch (PR #$ARGUMENTS if given).

1. **Prepare.** Make sure all work is committed and pushed. Identify the issue number and spec path from the branch name, PR body or `docs/specs/`.
2. **Review.** Launch the `reviewer` agent with only: the branch name, the base branch (`main`), the issue number, the spec path and the PR number. Do not give it your own view of the change, a summary of what you built, or what to look for; its value is that it starts fresh.
3. **Act on findings.** For each finding:
   - Blocker or major: fix it, or ask the maintainer whether to defer it.
   - Minor or nit: fix it, or open an issue and note the issue number.
   - Record the action next to the finding ("Fixed in abc1234", "Deferred to #57", "Not changed: <reason>").
   - If the `test-writer` agent is needed for test gaps, run it.
4. **Re-review if the code changed.** If you changed code or tests in response, run the `reviewer` again on the new commit. The recorded verdict must be the reviewer's verdict on the commit it reviewed. Never change the verdict yourself.
5. **Record.** Replace the PR's "Independent review" section with the reviewer's output plus your actions, using `gh pr edit <number> --body-file <file>`. Keep the rest of the PR body unchanged.
6. **Check.** Run `python tools/checks/check_independent_review.py` with `PR_BODY` set to the new body, and confirm it passes.
7. **Report** the verdict and findings to the maintainer in a few lines. If the verdict is "Changes needed", say what is blocking.
