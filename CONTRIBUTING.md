# Contributing to GitDesk

GitDesk is an early-stage native macOS Git client. Please open an issue before starting a large feature so the expected behavior and tests can be agreed on. For a focused change, a pull request is welcome.

## Build and check

Use an Apple-silicon Mac with macOS 27, Xcode 27.2 or newer, and Swift 6.4 or newer. From the repository root:

```sh
swift test
bash Scripts/build-app.sh
```

Add a disposable-repository test for a Git action's state transition and its failure or recovery path. Keep tests independent of personal Git configuration, credentials, and network accounts. For a UI change, check keyboard access and VoiceOver labels as well as appearance in light and dark mode.

## Source and evidence

Submit original code and artwork. Public Git documentation and behavior specifications in [Docs](Docs/implementation-plan.md) may guide implementation. Do not add Tower binaries, decompiled code, private assets, recordings, screenshots, or undocumented internal data to this repository. Mark inferred behavior as inferred; a passing GitDesk test does not prove Tower parity.

Keep secrets and private repository contents out of commits, issues, and pull requests. See [SECURITY.md](SECURITY.md) for reporting a vulnerability privately.

## Pull requests

Describe the user-visible behavior, affected Git state, tests run, and known limits. Keep changes scoped and avoid generated `.build`, `dist`, and Xcode files. Contributors agree that their contributions are licensed under the repository's [MIT license](LICENSE).
