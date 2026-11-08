# Tower 18 Pro branch archiving: observed behavior

Observed on 2026-11-07 with Tower for Mac 18.0 (564), macOS 27.2, and a vendor-issued trial activated through Tower's documented license CLI. The study used a disposable local Git repository with no remote or private content. These observations cover this fixture and do not establish complete feature parity.

## Fixture and actions

- `main` started at a base commit. `topic/merged` pointed to that same commit and had no branch-specific commit.
- `topic/stale` had one unmerged commit dated 2025-01-01. `topic/current` had a recent unmerged commit.
- A later `topic/integrated` branch had one commit that was merged into `main` with a merge commit.
- In Branches Review, `topic/merged` and `topic/integrated` both showed a fully merged indicator; `topic/stale` showed an old last-updated date.

The Archive Branches dialog initially listed only `topic/stale` as **Stale**. After the merge, it listed `topic/stale` and `topic/integrated`, the latter as **Fully Merged**. It did not list `topic/merged` in this fixture, despite its fully merged indicator. The exact rule for a branch with no branch-specific commits remains unresolved.

The dialog allowed selecting individual candidates or all candidates. It offered **Automatically archive branches** with an explanation that eligible branches are archived once per day. The sidebar setting **Stale Branch Time Interval** had **1 Month** selected and offered 1, 2, 3, 4, 6, 9, 12, 18, and 24 months.

Archiving `topic/integrated` moved it into the sidebar's **Archived Branches** section, while it remained visible in Branches Review and its `refs/heads/topic/integrated` ref remained present. Its context menu still offered checkout and **Unarchive**. Unarchiving moved it back to the normal sidebar branch group. No branch deletion was observed.

## GitDesk follow-up

- Use reversible archive metadata; retain refs and checkout access.
- Match the observed month choices and 1-month default.
- GitDesk now records the last automatic check in repository-local configuration and checks at most once per UTC day while the Branches view loads. Its merged-candidate filter excludes tips on the comparison base's first-parent history. The disposable-repository test covers restart and pin, skip, parent, and worktree protection; performance and more branch shapes remain open.
- Investigate why Tower excludes the zero-work `topic/merged` branch and verify pin, skip, workflow-base, worktree, and remote cases in Tower on disposable fixtures. GitDesk's first-parent filter is a heuristic, not a verified Tower rule.

Tower's [published Pro description](https://www.git-tower.com/pro/automatic-branch-management) provides the broader feature claim. This record distinguishes its claims from the specific UI and Git-state observations above.
