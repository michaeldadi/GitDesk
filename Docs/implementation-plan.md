# GitDesk: Tower 18 study and independent macOS client

Status: working plan, 2026-11-07. Target: installed Tower 18.0 (564) for Mac.

## Outcome and scope

Build a native, local-first Git client that covers the useful Tower 18 workflows with GitDesk's own UI, code, iconography, and terminology. A user must be able to perform local Git work without a GitDesk subscription or account. Hosting providers, AI models, and signing services can have their own costs, which the app must disclose before connecting to them. The [parity matrix](parity-matrix.md) is the acceptance ledger; a feature is complete only when its behavior, failure and recovery paths, and relevant accessibility and performance checks pass.

The current product baseline is **macOS 27 on Apple silicon**. macOS 27 is [Apple silicon only](https://developer.apple.com/news/?id=k1mtkt1k). Supporting older macOS or Intel is conditional: evaluate it after the native UI and Git engine work, and do not constrain a better macOS 27 implementation to keep that support. The installed Tower target supports macOS 14+, but that is a property of Tower, not a GitDesk requirement.

## Verified baseline and current GitDesk state

| Item | Evidence on 2026-11-07 | Consequence |
|---|---|---|
| Tower app | `/Applications/Tower.app`, bundle `com.fournova.Tower3`, version 18.0, build 564 | Freeze observations against this build, not later updates. |
| Tower executable | Universal x86_64/arm64; SHA-256 `166e5391e640cbdd3a2885fc2feed6ba050766b89a73f6f42cde80b54d0ef00e` | Rehash before every experiment; an update starts a new target revision. |
| Tower signature | Developer ID Application: fournova Software GmbH, team `UN97WY764J`; notarization ticket stapled | Identity observation only; this does not grant analysis rights. |
| Study machine | macOS 27.2, build 26B123 | UI observations are specific to this OS unless reproduced elsewhere. |
| GitDesk | Standalone Swift package and ad-hoc signed `.app`; current `Package.swift` and bundle require macOS 27 | Keep 27 as baseline. Existing prototype is not a release build. |
| Local prototype validation | `swift test` passed 11 disposable-repository tests on this machine | This confirms those tested Git transitions, not Tower parity or broad reliability. |

The prototype already has a repository library, status, text diffs, file and hunk staging, commits, basic branches/tags/remotes, fetch/fast-forward pull/push, stashes, worktrees, history, local branch-parent/stacked metadata, and a CLI. It uses the system Git. The pre-existing uncommitted changes must be preserved. The README and current tests are the implementation inventory, but each matrix row remains open until its acceptance evidence is attached.

## Rights and access gates

1. **Public behavior study may proceed now.** Use Tower's published [feature overview](https://www.git-tower.com/features/all-features), [18.0 release notes](https://www.git-tower.com/release-notes), and [Mac help](https://www.git-tower.com/help). Independently implement Git behavior using Git's public documentation and disposable repositories.
2. **Restricted analysis is gated.** Tower's [EULA](https://www.git-tower.com/legal/eula) expressly restricts reverse engineering, decompilation, and disassembly. Obtain a qualified review of applicable rights or written vendor authorization that identifies the allowed methods and scope before examining executable internals, symbols, private assets, configuration formats, or runtime internals. Record the decision and its basis in a private rights record. Do not assume possession of the app or an Apple Developer membership satisfies this gate.
3. **Live Tower experiments need lawful access.** The reported trial is expired. Obtain a valid Tower entitlement or vendor-authorized extension before exercising disabled features. Do not reset the trial, alter signatures, patch binaries, intercept credentials, or disable macOS protections. Use disposable Git repositories and test provider accounts.
4. **Clean-room output.** Record observable behavior and independent specifications. Keep Tower code, decompiled material, and artwork out of the GitDesk repository. If restricted analysis is authorized, store raw analysis separately with access controls and publish only behavioral findings needed to implement and test GitDesk.

These gates affect *claims of observed parity*, not the ability to build the independent client from public Git and product documentation. The right to study a program and the right to use a paid Tower feature are separate questions.

## Evidence system and study protocol

Create one evidence record per matrix row using the [experiment template](experiment-template.md). Give every record a unique ID, target build hash, OS, fixture SHA or generator version, exact initial refs/index/worktree state, UI path and options, timing, command/ref/filesystem/network observations where permitted, expected vs actual result, error/abort path, screenshots or recordings with timestamps, and a confidence tag:

- **Documented**: official Tower page describes the behavior; no direct experiment.
- **Observed**: reproducible result in the licensed Tower build, with before/after evidence.
- **Inferred**: plausible interpretation, awaiting a discriminating experiment.
- **GitDesk verified**: independent client passes its acceptance fixture; this is not Tower observation.

Never promote documented or inferred behavior to observed. For each action, run at least a clean case, dirty-worktree case, conflict or failure case, cancel/abort case, and repeat after restarting the app where state persistence matters. Capture Git refs, `HEAD`, index stages, worktree hashes, reflog, config, and remote refs before and after. Test offline and slow network paths for provider operations. Compare with the same intended Git action performed by CLI in a separate clone. Avoid capturing private repositories, credentials, or provider tokens.

Once rights and access permit, study Tower in this order: (a) screen and menu inventory and keyboard/VoiceOver traversal, (b) controlled Git state transitions, (c) system-level process and network behavior permitted by the rights review, (d) targeted static analysis only where an unresolved behavior cannot be established from the UI and Git state. Record each static finding as a hypothesis to verify, not a specification by itself. If rights or access do not arrive, mark the affected matrix cells open and continue independent implementation.

## Product architecture

### Application and state

- SwiftUI scene and command structure for repository windows, Settings, quick actions, menus, drag and drop, theme adaptation, and keyboard navigation. Each window owns selection and navigation state; repository facts come from a shared repository service. Use AppKit-backed graph, table, or diff surfaces when profiling demonstrates SwiftUI cost or missing interaction fidelity. SwiftUI's `WindowGroup` supports independent window state; a `Settings` scene provides the macOS Settings command ([Apple SwiftUI documentation](https://developer.apple.com/documentation/swiftui/windowgroup), [Settings](https://developer.apple.com/documentation/swiftui/settings)).
- A repository library stores bookmarks, groups, ordering, recently opened items, templates, profiles, and view preferences in versioned local SQLite. Store security-scoped bookmarks if distribution or sandbox choices require them; handle stale bookmarks and moved repos. Never store provider secrets there.
- One repository actor serializes every ref/index/worktree mutation and provides read snapshots with generation IDs. Long reads, clones, fetches, and provider calls are cancellable and report progress. File watchers coalesce changes and refresh affected panes, while a full refresh reconciles missed events. Multiple windows share the same write coordinator for a repository.
- Split UI components by domain: library/sidebar, working copy, history graph and inspector, branch review, conflicts, stashes, worktrees, PRs, settings. Every state has loading, empty, error, and recovery presentations. A destructive action shows the exact affected refs/files and a recovery route where one exists.

### Git engine contract

- Git is authoritative. Invoke a pinned Git runtime as an executable with argument arrays, a controlled environment and working directory, no shell interpolation, bounded output and timeouts, and streaming stdout/stderr for long operations. Bundle Git and LFS after the binary packaging and license obligations are reviewed; preserve system Git as a development fallback only. Validate git-flow and git-svn availability separately because a generic Git binary does not guarantee those extensions.
- Prefer machine-oriented NUL-delimited formats (`status --porcelain=v2 -z`, `for-each-ref` formatting, `ls-files -z`, `diff --raw -z`, `worktree list --porcelain -z`). Preserve path bytes where possible; do not parse user-facing output by lines for paths. Disable external diff and textconv for patches intended for `git apply`. Treat renames, submodules, symlinks, binary files, sparse checkouts, case-only renames, and Unicode normalization explicitly.
- Reads are snapshot based. Before staging or discarding a file, hunk, or line, compare the expected index tree, worktree content and patch context with the current state. Run `git apply --check` before mutation, then refresh and report any race. Never silently widen a selected hunk. For untracked files use a temporary index or controlled `--no-index` path, not an implicit blanket add.
- A mutation result includes changed refs/index/worktree and a recovery classification. Local inverse operations are offered only when safe. Pushes and provider actions are labeled remote and cannot be presented as locally undoable. Preserve Git hooks, commit signing, SSH agent and credential helper behavior with explicit environment handling and no token logging.
- Model operations that can pause: merge, rebase, cherry-pick, revert, conflict resolution, and interrupted network tasks. The UI must detect and reopen the in-progress state, expose continue/skip/abort as appropriate, and never infer completion from a process exit alone.

### Services, security, and extension boundaries

- Define a provider protocol for account identity, repository discovery/create, PR list/detail/create/comment/merge/close, pagination, status checks, review metadata, and rate-limit/error translation. Implement GitHub, GitLab, Bitbucket, Azure DevOps, Beanstalk, and documented self-hosted variants behind separate adapters with contract fixtures and available test-account smoke tests. Capability flags hide unavailable provider actions; do not pretend all APIs are identical.
- Store OAuth/PAT secrets in Keychain, prefer system/browser authorization, and scope tokens minimally. Redact process args, logs, crash reports, URLs, and support bundles. Do not put tokens into Git remote URLs. Test revocation, expiration, rate limits, 2FA and proxy/certificate cases.
- AI commit generation and Graphite are opt-in adapters. Local Git workflows work without either. Explain any external account or usage fee before enabling an adapter. Keep provider-specific state separate from the core Git model.
- A `gitdesk` launcher follows Tower 18's **view-oriented** CLI surface where useful: open repository or file, history for branch/tag/file, selected commit, blame, working copy, stashes, branch review with filters, PRs, settings, clone dialog, and branch-parent/stack metadata. Preserve GitDesk's existing mutation CLI only as a clearly distinct command group or executable; Tower's documented `gittower` is a launcher and its `branch` command is the documented config-writing exception ([Tower CLI guide](https://www.git-tower.com/help/guides/integration/using-the-cli-tool/mac)). Define exit codes, ambiguity handling, `--` path separation, `-C`, new window/tab flags, URL handoff, and stale-app errors before claiming CLI parity.

## Work packages and exit gates

| Stage | Work that must ship | Exit evidence |
|---|---|---|
| 0 — Inventory and foundation | Freeze Tower and public docs; rights review record; matrix and experiment fixtures; split UI/engine/provider interfaces; set macOS 27 Apple-silicon baseline; establish licensing inventory for bundled tools. | Every published feature has a matrix row and owner; no unsupported claim is marked observed; reproducible build and fixture generator. |
| 1 — Behavioral study | Perform licensed UI experiments and only authorized static/system study; reconcile docs with observed controls, shortcuts, settings, Git changes and errors. | Each applicable row has observed evidence or a named open question; rights/access blocks remain explicit. |
| 2 — Dependable local client | Repository library, clone/create/open, status, diff, precise stage/unstage/discard, commits/amend, branches/tags/remotes, sync, stashes and worktrees; robust progress, cancellation and credential handling. | Golden fixtures match Git CLI refs/index/worktree/reflog; dirty, error, cancel and restart tests pass; no data-loss bug open. |
| 3 — Advanced Git | History graph/tree/search, file history/blame/reflog, patches, merge/rebase/cherry-pick/revert, conflict wizard, undo/snapshots, submodules, LFS, git-flow/git-svn, branch review and local stacks. | State-transition and abort/recovery suites pass for every operation; large-repo budgets met. |
| 4 — Providers and automation | Provider adapters, PR workflow, self-hosted configuration, Graphite and AI adapters, external diff tools, templates/profiles, Quick Actions and view-oriented CLI. | Provider contract tests plus test-account smoke tests; rate-limit/offline/revocation paths; explicit external costs. |
| 5 — Native release | Visual and interaction review, accessibility, localization readiness, crash diagnostics, performance, bundled runtime licensing, signed/notarized personal-use artifact. | Matrix has no unresolved applicable row; user review passes; fresh-install smoke on supported hardware; release artifact independently verified. |

Stages are dependency gates, not a promise that every stage will finish on a calendar date. Existing prototype code belongs to stage 2 work but does not waive its exit gate. Stage 1 can run in parallel with independent Git implementation only where the rights/access gates permit it.

## Test and quality plan

1. **Fixture generator:** create deterministic empty, ordinary, 100k-commit and 100k-file repositories. Add unusual filenames (tabs/newlines, leading dash, non-ASCII), renames, binary and large files, symlinks, submodules, LFS pointers, worktrees, detached HEAD, sparse checkout, shallow clone, unborn branch, corrupt/locked index, dirty worktree, merge and rebase conflicts, interrupted operations, and bare remotes.
2. **Transition oracle:** for each mutation, compare `HEAD`, all affected refs, index stages, worktree file hashes and modes, and reflog against an equivalent Git CLI fixture. Assert unrelated paths/refs are unchanged. Run the same tests with bundled Git and the system fallback during the transition.
3. **UI and accessibility:** automate critical flows (open, review, stage hunk, commit, merge conflict, abort, PR review). Check keyboard-only completion, focus restoration, VoiceOver names/actions/announcements, contrast and reduced motion. Perform a manual usability review of the history graph and conflict editor.
4. **Performance budgets (initial targets):** on a documented reference Apple-silicon Mac, warm launch to interactive library under 1 second; first 100 history rows under 1.5 seconds on 100k commits; visible status under 3 seconds on 100k files; smooth 60 Hz scroll; no sustained main-thread block over 100 ms during Git/network work. Profile with Instruments, record p50/p95 and memory, and revise budgets only with evidence. Keep large outputs paged and cancellable.
5. **Release:** test a fresh user account and a clean Mac; verify the exact app/CLI/bundled Git versions and hashes, Keychain and credential workflows, Developer ID signature, hardened runtime, notarization ticket and stapling. Apple's [distribution guidance](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) supports the renewed developer account path; do not sign or submit a release until the artifact and entitlements are reviewed.

## Immediate next sequence

1. Preserve and review the existing uncommitted GitDesk prototype changes; finish their focused tests and app smoke test before further engine work.
2. Use the [matrix](parity-matrix.md) to add exact fixtures and acceptance tests for stage 2 features, starting with path safety, hunk staging races, clone cancellation, worktree lifecycle, and remote error handling.
3. Resolve the rights and Tower entitlement gates. Until then, write independent specifications from public docs and Git behavior; do not mark any Tower-specific interaction as observed.
4. Convert the current CLI design into a separate, view-oriented contract and expand app navigation to support it. Keep the current mutation commands available under an explicitly documented GitDesk-specific interface.
5. Reassess release packaging after the engine and UI contract stabilizes; use the renewed Apple Developer account for signing/notarization at that point.
