# GitDesk

GitDesk is an independent, native macOS Git workspace for reviewing changes and moving between repositories and worktrees. It is in early development and is currently intended for macOS 27 on Apple Silicon.

## Current features

- Repository library backed by local SQLite
- Working-copy status and staged/unstaged text diffs, including untracked files
- File staging, unstaging, commits, local branches, fetch, fast-forward pull, push, and stashes
- Paged commit history and commit details
- Worktree listing and creation from the current commit
- A command-line companion for common local operations and opening a repository in the app

GitDesk currently uses the system Git executable. It does not yet bundle Git or Git LFS. Hosting account connections, pull-request management, fine-grained staging, conflict tools, and release packaging are planned but not implemented.

## Build

Requirements: macOS 27, Xcode 27.2 or newer, and Swift 6.4 or newer.

```sh
swift test
bash Scripts/build-app.sh
open dist/GitDesk.app
```

The build script creates an ad-hoc signed app bundle at `dist/GitDesk.app`. It is for local development and is not notarized for public distribution.

## CLI

After building, the companion executable is at `dist/GitDesk.app/Contents/MacOS/gitdesk`.

```sh
gitdesk --repo /path/to/repository status
gitdesk --repo /path/to/repository open --view history
gitdesk --repo /path/to/repository worktree create agent/review /path/to/new-worktree
```

The `open` command uses the app's `gitdesk:` URL handler. Launch the app once to register it with macOS.

## Development

The Swift package separates Git operations and local storage in `GitDeskCore` from the `GitDeskApp` interface and `gitdesk` CLI. Git commands are passed as argument arrays, without a shell. New Git actions should include disposable-repository integration tests for their state changes and failure paths.

Contributions are welcome. Please do not include credentials, repository content, or third-party artwork in issues or pull requests.

## License

MIT. See [LICENSE](LICENSE).
