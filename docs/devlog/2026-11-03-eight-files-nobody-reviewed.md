# Eight files nobody reviewed

*3 November 2026 · M0 Foundations · #10, #11, #12*

## What we set out to do

Land the foundations as small pull requests, each independently reviewed by a fresh-context reviewer agent, with a CI check that the review is recorded. Four documentation packs were drafted up front and sat uncommitted in the working folder.

## What happened

The third pack, #10 (vision, design skeleton, roadmap and risks), was reviewed at `f8da91d` and passed with four small wording notes. Claude fixed them and committed with `git add docs`.

That command staged every new file under `docs/`, including the whole fourth pack (ADRs 0001 to 0004, the architecture overview and the docs index), so commit `c7b8ddb` held 11 files and 588 added lines. Claude had checked `git diff --stat`, which only shows files git already tracks, so the new ones never appeared.

The review check flagged it: the review covered `f8da91d`, not the latest commit. Claude read the warning as expected noise from a four-line fix, told the maintainer the fixes were "one-line wording changes", and merged #10 on the maintainer's approval.

## Where the AI got it wrong

- **Staged a folder, not files**, and checked the wrong diff.
- **Dismissed a warning** that was pointing at the problem.
- **Gave the human wrong information**, so the maintainer's approval rested on a false description. This matters most: the human gate only works if what reaches it is true.

## What caught it

Claude, preparing the fourth pack's pull request, found its files already tracked on `main`. It stopped and reported the mistake before changing anything. The maintainer chose a catch-up review over reverting.

The catch-up (#12) took three review rounds, and each found something real:

1. Claude's first fix to the check missed edits to unreviewed files, and ADR-0003 contradicted itself.
2. The pull request description had not been updated for those fixes: the same failure again, in miniature. The check also compared against the tip of `main` rather than the branch point.
3. A wrong test count in the description, and two ADR gaps closed before the ADRs froze.

## What we changed

- **The review check now fails** when commits after the reviewed commit touch any file the review did not cover, measured from where the branch left `main`. Replaying #10's history through it fails and lists all eight files.
- **23 tests** cover the check, six of them against real git repositories.
- **Coding standards:** stage files by name and run `git diff --cached --stat` before every commit.
- **#10 carries a correction** pointing to #12.

The lesson for an AI-assisted workflow: checks that warn rely on someone reading the warning with fresh eyes, and the AI that made the change is the worst-placed reader. Make the important ones fail.

## Links

- [#10](https://github.com/Huntling94/tallow/pull/10): the pull request that merged the files
- [#11](https://github.com/Huntling94/tallow/issues/11): the issue describing the failure
- [#12](https://github.com/Huntling94/tallow/pull/12): the catch-up review and the stricter check
- [ADR index](../adr/README.md)
