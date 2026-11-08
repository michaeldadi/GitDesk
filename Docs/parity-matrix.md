# GitDesk parity matrix: published Tower 18 for Mac surface

Frozen source set, 2026-11-07: [Tower feature overview](https://www.git-tower.com/features/all-features), [Tower 18.0 release notes](https://www.git-tower.com/release-notes), [Tower 18 CLI guide](https://www.git-tower.com/help/guides/integration/using-the-cli-tool/mac), and the linked Mac help topics. This inventory paraphrases the public feature claims. It is **not** a claim of observed Tower behavior. Every row starts with Tower evidence **D** (documented only). No row may receive **O** (observed) without a licensed, reproducible experiment using the [template](experiment-template.md). Add newly discovered settings, subcommands, shortcuts and error cases as child rows rather than hiding them in a parent row.

`P` means a GitDesk prototype surface exists but parity is unverified; `N` means no product implementation established. Each acceptance cell is a minimum independent GitDesk check, not an assertion that Tower behaves in precisely that way. Stages refer to the [implementation plan](implementation-plan.md). The current prototype states come from code and ten passing tests on 2026-11-07, not a completed product review.

| ID | Capability to build | Stage | GitDesk | Minimum acceptance check |
|---|---|---:|:---:|---|
| PRD-01 | Create and clone repositories | 2 | P | Empty/init and authenticated/local clone fixtures; progress, cancel, retry. |
| PRD-02 | Quick command and navigation palette | 4 | P | Keyboard search finds actions, views, refs, commits, files; disabled reasons shown. |
| PRD-03 | Optional automatic fetch and stash | 4 | N | Opt-in schedule, no surprise writes, visible activity and failures. |
| PRD-04 | Background clone | 2 | P | UI remains responsive; cancel cleans partial destination safely. |
| PRD-05 | Multiple repository windows and tabs | 5 | P | Independent selection state, shared Git write lock, reopen restoration. |
| PRD-06 | Commit message templates | 4 | N | Add/edit/delete/import; placeholder expansion and preview. |
| PRD-07 | Per-operation environment variables | 4 | N | Scoped configuration reaches hooks/tools without leaking secrets. |
| WC-01 | Changed-file list and full folder tree | 2 | P | Toggle view, preserve selection, show ignored/untracked and empty folders policy. |
| WC-02 | Staged and unstaged integrated diffs | 2 | P | Rename, binary, symlink, LFS, huge diff and encoding cases. |
| WC-03 | Commit and amend | 2 | P | Index-only commit, hook failure, signing failure, amend consequences. |
| WC-04 | AI-assisted commit text | 4 | N | Explicit opt-in, data preview/redaction, provider errors and cost display. |
| WC-05 | Stage file, hunk and individual line | 2 | P | Selected change only; index race rejected; unusual paths and mixed hunks. |
| WC-06 | Discard file, hunk and line changes | 2 | N | Preview exact loss, preserve unrelated changes, recovery classification. |
| WC-07 | Restore a file from a revision | 3 | N | Content/mode from selected revision, dirty-worktree collision path. |
| WC-08 | Edit ignore rules | 2 | N | Scope global/repo/local, escape patterns, verify target stops appearing. |
| WC-09 | Visual conflict resolution | 3 | N | All index stages visible; resolve, continue and abort without lost edits. |
| WC-10 | Create and apply patches | 3 | N | Binary/rename mode support, dry run, partial failure and reverse. |
| WC-11 | Add, delete, rename and untrack files | 2 | P | Exact path intent, case-only rename, symlink and filemode preservation. |
| WC-12 | Gitmoji message aid | 4 | N | Optional picker, keyboard and accessible names, no required network. |
| SVC-01 | Connect GitHub, GitLab, Bitbucket, Azure DevOps and Beanstalk | 4 | N | Account lifecycle, token scope, refresh, revoke, API error translation. |
| SVC-02 | Browse and one-click clone provider repositories | 4 | N | Search and pagination, duplicate destination, permission and network errors. |
| SVC-03 | Create a hosted repository | 4 | N | Visibility/default branch options, idempotent retry and remote readback. |
| PR-01 | List and inspect pull requests | 4 | N | Pagination, stale cache, status checks, reviews, changed files. |
| PR-02 | Create a pull request | 4 | N | Base/head validation, draft state, title/body, remote readback. |
| PR-03 | Comment or review a pull request | 4 | N | General/inline comment, outdated diff, duplicate-submit protection. |
| PR-04 | Merge, close and reopen where supported | 4 | N | Permission, protection, race and remote result verification. |
| LIB-01 | Repository groups, filtering and search | 2 | P | Persist order/groups, moved/deleted repo and 1k-library latency. |
| LIB-02 | Add existing, clone and create from library | 2 | P | Duplicate detection, nested repo and worktree recognition. |
| LIB-03 | Fast open by keyboard and drag and drop | 5 | P | Finder drop and keyboard search work from any window. |
| LIB-04 | Git-SVN workflows | 3 | N | Detect extension, checkout/fetch/commit path or clear unavailable state. |
| LIB-05 | Create, switch and manage worktrees | 2 | P | Add/list/move/remove/repair/lock, dirty or missing directory recovery. |
| ST-01 | Save worktree/index state in a stash | 2 | P | Include-untracked choice, staged state and clear success feedback. |
| ST-02 | Reapply a stash, including selected parts | 3 | P | Conflict handling; exact selected paths/hunks; no silent stash drop. |
| ST-03 | Inspect stash diffs | 2 | P | Staged/unstaged/untracked components and large/binary cases. |
| ST-04 | Temporary snapshot workflow | 3 | N | Create, restore and discard with explicit lifecycle and recovery. |
| EXT-01 | Git-flow presets | 3 | N | Start/finish feature/release/hotfix on disposable refs. |
| EXT-02 | Git LFS bundled workflow | 3 | N | Install/detect, track, fetch/checkout, pointer and missing-object errors. |
| EXT-03 | Committer identity profiles | 4 | N | Apply per repo, signing identity separation, no global surprise change. |
| EXT-04 | External diff and merge apps | 4 | N | Launch chosen app with safe temp files, capture exit and cleanup. |
| EXT-05 | SSH agent and commit/tag signing | 2 | P | SSH helper, GPG/SSH signing, passphrase and verification failure. |
| EXT-06 | 1Password SSH-agent option | 4 | N | Respect configured agent socket and explain unavailable agent. |
| EXT-07 | Companion command-line tool | 4 | P | View launcher contract below; installed executable updates with app. |
| EXT-08 | Syntax-colored diff and blame | 5 | N | Theme-aware token colors, huge-file fallback and accessibility. |
| EXT-09 | Dark appearance | 5 | P | Every custom surface works in system light/dark and high contrast. |
| EXT-10 | Full-screen mode | 5 | P | Window state and toolbar remain usable. |
| EXT-11 | Sharp display scaling | 5 | P | Icons, graph and diff legible at 1x/2x and external displays. |
| UX-01 | Fast, coherent native interaction | 5 | P | Usability review on key workflows, latency budget and error copy. |
| UX-02 | Undo local changes and recover commits | 3 | N | Operation-specific recovery; reflog route; remote writes excluded. |
| UX-03 | Drag to merge, cherry-pick and squash | 3 | N | Source/target preview, keyboard equivalent, conflict/abort path. |
| UX-04 | Guided conflict editor | 3 | N | Distinct base/ours/theirs/result, file mode, stage and abort. |
| UX-05 | Back/forward repository navigation | 5 | N | Selection and scroll restored across views and windows. |
| UX-06 | Unpushed and unpulled indicators | 2 | P | Ahead/behind uses upstream refs, missing/diverged upstream state. |
| REF-01 | Fetch, pull and push | 2 | P | Auth, force rejection, network fail, cancellation and remote readback. |
| REF-02 | Unsynced commits visualization | 3 | P | Identify exact unique commits for both sides of upstream. |
| REF-03 | One-step pull then push | 3 | N | Preview both steps, stop on conflict, never push after failed pull. |
| REF-04 | Optional background fetch | 4 | N | Schedule and account scope, offline backoff, visible freshness. |
| REF-05 | Create, delete and rename branches | 2 | P | Checked-out/worktree/protected ref cases and reflog effects. |
| REF-06 | Create, delete and rename tags | 2 | P | Lightweight/annotated/signed variants, remote distinction. |
| REF-07 | Create, delete and rename remotes | 2 | P | Remote config and tracking-ref effects; URL credential rejection. |
| REF-08 | Publish, track and checkout branches | 2 | P | Upstream setup, detached HEAD, worktree branch lock. |
| REF-09 | Branch from commit, tag or another branch | 2 | P | Start-point validation and source ref retained. |
| REF-10 | Merge and rebase branches | 3 | N | Clean/conflict/dirty, continue/skip/abort, reflog and hooks. |
| REF-11 | Drag-based ref operations | 3 | N | Preview exact operation, keyboard alternative and cancel. |
| REF-12 | Compare branches | 3 | P | Merge base, unique commits, file diff and unrelated histories. |
| REF-13 | Branches Review and stale status | 3 | P | Base selection, dates, mergeability, tracking errors, PR status. |
| REF-14 | Export a branch or tag's files | 3 | N | Archive tree/modes safely, path traversal and filename handling. |
| REF-15 | Force push with lease | 3 | N | Expected remote OID precondition, race rejection, explicit warning. |
| HIST-01 | History for branch, tag and stash | 3 | P | Correct ref scope, paging and deleted-ref behavior. |
| HIST-02 | Configurable graph, sort and row density | 3 | N | DAG lanes, merge commits, layout persistence and huge repo scroll. |
| HIST-03 | Commit metadata and precise diff | 2 | P | Parents, author/committer, signature, paths and full patch. |
| HIST-04 | Revert commit and reset/roll back | 3 | N | Dirty worktree, merge commit mainline, recovery and remote warning. |
| HIST-05 | File history across renames | 3 | P | Rename tracking, deleted file and path ambiguity. |
| HIST-06 | Interactive rebase editor | 3 | N | Reorder/squash/fixup/edit/drop, conflict, continue and abort. |
| HIST-07 | Browse a revision's tree and raw files | 3 | N | Tree paging, binary preview, submodule and large-file handling. |
| HIST-08 | Filter and search history | 3 | N | Author/date/message/path/ref query and cancel. |
| HIST-09 | Line blame | 3 | N | Rename-aware blame, raw file state, prior revision and huge file. |
| HIST-10 | Cherry-pick commits | 3 | N | Single/range, empty pick, conflict, continue/skip/abort. |
| HIST-11 | Export ZIP and save patch | 3 | N | File modes, symlinks, binary and path safety. |
| HIST-12 | Reveal ref or commit in graph | 3 | N | Page until visible, highlight exact OID and preserve context. |
| SUB-01 | Submodule management | 3 | N | Add/init/update/open/deinit, nested and auth failure paths. |
| LOG-01 | Reflog browsing and recovery | 3 | N | Ref/date paging, expired entry state, restore into new ref. |
| DIST-01 | No separate Git install required | 5 | N | Bundle versioned Git/LFS and verify clean Mac launch/licensing. |
| DOC-01 | In-app help and learning routes | 5 | N | Original task guidance, searchable help, offline essentials. |
| DOC-02 | Support and feedback route | 5 | N | Local diagnostics export with redaction and user-controlled send. |
| PRO-01 | Configurable branch workflows | 3 | N | Presets and custom rules drive start/finish with visible commands. |
| PRO-02 | Stacked branch creation and sync | 3 | N | Parent metadata, restack, conflict/abort and remote divergence. |
| PRO-03 | Automatic branch cleanup | 3 | N | Stale/merged criteria preview, protected/worktree exclusions. |
| PRO-04 | PR-aware merge detection | 4 | N | Squash/rebase merge evidence from provider, no false ancestry claim. |
| PRO-05 | Self-hosted provider accounts | 4 | N | Custom endpoint/TLS/auth, discovery and PR capability flags. |
| PRO-06 | Graphite workflow adapter | 4 | N | Optional connection, local stack remains usable when absent. |

## Tower 18 command-line surface

Tower's [published CLI guide](https://www.git-tower.com/help/guides/integration/using-the-cli-tool/mac) is the source for these rows. Its CLI is primarily a **launcher**. GitDesk's current CLI is a Git command tool, so a similar command name does not make these rows complete. Do not claim Tower CLI parity until argument and exit behavior is exercised against an authorized Tower install.

| ID | Capability to build | Stage | GitDesk | Minimum acceptance check |
|---|---|---:|:---:|---|
| CLI-01 | Open repo from path, nested folder or file | 4 | P | Resolve worktree root, non-repo offer/error and duplicate window. |
| CLI-02 | Choose new window or tab | 4 | N | Flags route to intended scene and preserve existing window. |
| CLI-03 | Open whole, branch, tag, file or historical file history | 4 | P | Explicit ref/path disambiguation; selected scope visible. |
| CLI-04 | Open a specific commit in history | 4 | N | Resolve short/full OID or Git revision and select exact commit. |
| CLI-05 | Open blame for current or old revision | 4 | N | Raw file and blame match selected revision. |
| CLI-06 | Open working copy, including `status` alias | 4 | P | View only; no Git mutation. |
| CLI-07 | Open stash view | 4 | P | Select repository and show current stash list. |
| CLI-08 | Open branch review with filter/base/branch/search/sort | 4 | P | All documented filters and sort flags applied in UI. |
| CLI-09 | Open pull requests and settings | 4 | N | Route to exact view; account errors shown there. |
| CLI-10 | Open clone dialog with remote URL | 4 | N | Prefill safely without cloning until user confirms destination. |
| CLI-11 | Read/set/clear branch parent and stacked flag | 4 | P | Namespaced Git config, valid parent, readback and exit semantics. |
| CLI-12 | `-C`, `--`, ref/path ambiguity and leading-dash files | 4 | N | Deterministic resolution and useful diagnostic. |
| CLI-13 | Version, help and documented exit codes | 4 | N | 0 success, answer-like 1, other errors; script fixtures. |
| CLI-14 | Installed launcher tracks app updates | 5 | N | Version matches app after update; no overwrite of foreign binary. |

## Evidence and closure rule

For every row, attach: an independent specification; fixture and exact preconditions; expected refs/index/worktree/UI state; a passing automated or manual acceptance result; error/abort/recovery evidence; accessibility/performance check where relevant; and a Tower evidence record or explicit `unobserved` reason. A row can be `GitDesk complete` while Tower observation remains open. The release claim “full observed Tower 18 parity” requires the latter to close for every applicable row.
