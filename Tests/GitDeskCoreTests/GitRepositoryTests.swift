import Foundation
import GitDeskCore
import XCTest

final class GitRepositoryTests: XCTestCase {
    private func fixture() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "gitdesk-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try GitRepository.create(at: url)
        let git = GitProcess()
        _ = try git.run(in: url, ["config", "user.name", "GitDesk Tests"])
        _ = try git.run(in: url, ["config", "user.email", "gitdesk-tests@example.invalid"])
        _ = try git.run(in: url, ["config", "commit.gpgsign", "false"])
        return url
    }

    func testStatusStageCommitAndHistory() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let repository = try GitRepository(location: url)
        let filename = "file with spaces and ; symbols.txt"
        try "hello\n".write(
            to: url.appending(path: filename), atomically: true, encoding: .utf8
        )

        let before = try await repository.snapshot()
        XCTAssertEqual(before.entries.map(\.path), [filename])
        XCTAssertEqual(before.entries.first?.kind, .untracked)

        try await repository.stage(paths: [filename])
        let staged = try await repository.snapshot()
        XCTAssertEqual(staged.entries.first?.code, "A.")

        try await repository.commit(message: "Initial commit")
        let after = try await repository.snapshot()
        XCTAssertTrue(after.entries.isEmpty)
        let history = try await repository.history()
        XCTAssertEqual(history.first?.subject, "Initial commit")
        XCTAssertNotNil(history.first?.date)
    }

    func testRenameAndUnstage() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let git = GitProcess()
        try "one\n".write(
            to: url.appending(path: "old.txt"), atomically: true, encoding: .utf8
        )
        _ = try git.run(in: url, ["add", "--", "old.txt"])
        _ = try git.run(in: url, ["commit", "-m", "Add file"])
        _ = try git.run(in: url, ["mv", "old.txt", "new.txt"])

        let repository = try GitRepository(location: url)
        let renamed = try await repository.snapshot()
        XCTAssertEqual(renamed.entries.first?.kind, .renamed)
        XCTAssertEqual(renamed.entries.first?.path, "new.txt")
        XCTAssertEqual(renamed.entries.first?.originalPath, "old.txt")

        try await repository.unstage(paths: ["new.txt", "old.txt"])
        let after = try await repository.snapshot()
        XCTAssertFalse(after.entries.isEmpty)
    }

    func testRepositoryLibrarySavesBookmark() throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let database = FileManager.default.temporaryDirectory
            .appending(path: "gitdesk-library-\(UUID().uuidString).sqlite3")
        defer { try? FileManager.default.removeItem(at: database) }
        let library = try RepositoryLibrary(databaseURL: database)
        try library.add(url)
        XCTAssertEqual(try library.all().map(\.path), [url.path])
        try library.remove(path: url.path)
        XCTAssertTrue(try library.all().isEmpty)
    }

    func testWorktreeCreationAndUntrackedDiff() async throws {
        let url = try fixture()
        let sibling = url.deletingLastPathComponent()
            .appending(path: "gitdesk-worktree-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer {
            try? FileManager.default.removeItem(at: sibling)
            try? FileManager.default.removeItem(at: url)
        }
        let git = GitProcess()
        try "base\n".write(to: url.appending(path: "base.txt"), atomically: true, encoding: .utf8)
        _ = try git.run(in: url, ["add", "--", "base.txt"])
        _ = try git.run(in: url, ["commit", "-m", "Base"])

        let repository = try GitRepository(location: url)
        try await repository.createWorktree(at: sibling, newBranch: "agent/review-one")
        let worktrees = try await repository.worktrees()
        XCTAssertEqual(worktrees.count, 2)
        XCTAssertEqual(worktrees.first(where: { $0.branch == "agent/review-one" })?.path.hasSuffix(sibling.lastPathComponent), true)

        try "new line\n".write(to: sibling.appending(path: "new.txt"), atomically: true, encoding: .utf8)
        let branchRepository = try GitRepository(location: sibling)
        let diff = try await branchRepository.untrackedDiff(path: "new.txt")
        XCTAssertTrue(diff.contains("+new line"))

        let base = try await repository.branchName()
        let review = try await repository.branchReview(base: base)
        XCTAssertEqual(review.first(where: { $0.name == "agent/review-one" })?.worktreePath?.hasSuffix(sibling.lastPathComponent), true)
        let before = try await repository.compareBranch("agent/review-one", withBase: base)
        XCTAssertEqual(before.branchOnly, 0)
        try await branchRepository.stage(paths: ["new.txt"])
        try await branchRepository.commit(message: "Agent work")
        let after = try await repository.compareBranch("agent/review-one", withBase: base)
        XCTAssertEqual(after.branchOnly, 1)
    }

    func testWorktreeParserPreservesUnusualPaths() {
        let path = "/tmp/a folder\nwith newline"
        let data = Data("worktree \(path)\0HEAD abc123\0branch refs/heads/agent/topic\0\0".utf8)
        let parsed = GitWorktreeParser.parse(data)
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed.first?.path, path)
        XCTAssertEqual(parsed.first?.branch, "agent/topic")
    }

    func testAppLinkRoundTripAndRejectsUnknownActions() throws {
        let path = URL(fileURLWithPath: "/tmp/a repo/branch & review", isDirectory: true)
        let link = try GitDeskLink(repository: path, view: .history)
        let parsed = try GitDeskLink.parse(link.url)
        XCTAssertEqual(parsed.repository.path, path.path)
        XCTAssertEqual(parsed.view, .history)
        XCTAssertThrowsError(try GitDeskLink.parse(URL(string: "gitdesk://push?repo=/tmp/repo&view=history")!))
    }

    func testStageAndUnstageOneHunkWithoutTakingOtherChanges() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let git = GitProcess()
        let file = url.appending(path: "many-lines.txt")
        let original = (1...30).map { "line \($0)" }.joined(separator: "\n") + "\n"
        try original.write(to: file, atomically: true, encoding: .utf8)
        _ = try git.run(in: url, ["add", "--", "many-lines.txt"])
        _ = try git.run(in: url, ["commit", "-m", "Base"])

        let changed = original.replacingOccurrences(of: "line 2\n", with: "changed 2\n")
            .replacingOccurrences(of: "line 25\n", with: "changed 25\n")
        try changed.write(to: file, atomically: true, encoding: .utf8)
        let repository = try GitRepository(location: url)
        let patch = try await repository.patch(path: "many-lines.txt")
        XCTAssertEqual(patch?.hunks.count, 2)
        try await repository.applyHunk(
            path: "many-lines.txt", staged: false, hunkID: 0,
            expectedDiff: try XCTUnwrap(patch?.raw)
        )
        let staged = try await repository.patch(path: "many-lines.txt", staged: true)
        XCTAssertEqual(staged?.hunks.count, 1)
        let index = try git.run(in: url, ["show", ":many-lines.txt"]).text
        XCTAssertTrue(index.contains("changed 2"))
        XCTAssertTrue(index.contains("line 25"))

        try await repository.applyHunk(
            path: "many-lines.txt", staged: true, hunkID: 0,
            expectedDiff: try XCTUnwrap(staged?.raw)
        )
        XCTAssertEqual(try git.run(in: url, ["show", ":many-lines.txt"]).text, original)

        let stalePatch = try await repository.patch(path: "many-lines.txt")
        let stale = try XCTUnwrap(stalePatch)
        try (changed + "another line\n").write(to: file, atomically: true, encoding: .utf8)
        do {
            try await repository.applyHunk(
                path: "many-lines.txt", staged: false, hunkID: 0, expectedDiff: stale.raw
            )
            XCTFail("A stale hunk must not be staged")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("diff changed"))
        }
    }

    func testCloneLocalRepositoryAndRejectCredentialURL() async throws {
        let source = try fixture()
        let destination = source.deletingLastPathComponent()
            .appending(path: "gitdesk-clone-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer {
            try? FileManager.default.removeItem(at: destination)
            try? FileManager.default.removeItem(at: source)
        }
        let git = GitProcess()
        try "content\n".write(to: source.appending(path: "file.txt"), atomically: true, encoding: .utf8)
        _ = try git.run(in: source, ["add", "--", "file.txt"])
        _ = try git.run(in: source, ["commit", "-m", "Source commit"])

        try GitRepository.clone(remote: source.path, destination: destination)
        let clone = try GitRepository(location: destination)
        let history = try await clone.history(limit: 1)
        XCTAssertEqual(history.first?.subject, "Source commit")
        _ = try git.run(in: destination, ["config", "user.name", "GitDesk Tests"])
        _ = try git.run(in: destination, ["config", "user.email", "gitdesk-tests@example.invalid"])
        _ = try git.run(in: destination, ["config", "commit.gpgsign", "false"])
        try "clone\n".write(to: destination.appending(path: "clone.txt"), atomically: true, encoding: .utf8)
        try await clone.stage(paths: ["clone.txt"])
        try await clone.commit(message: "Clone commit")
        let ahead = try await clone.snapshot()
        XCTAssertEqual(ahead.ahead, 1)
        XCTAssertEqual(ahead.behind, 0)
        XCTAssertNotNil(ahead.upstream)

        try "source\n".write(to: source.appending(path: "source.txt"), atomically: true, encoding: .utf8)
        _ = try git.run(in: source, ["add", "--", "source.txt"])
        _ = try git.run(in: source, ["commit", "-m", "Source advances"])
        try await clone.fetch()
        let diverged = try await clone.snapshot()
        XCTAssertEqual(diverged.ahead, 1)
        XCTAssertEqual(diverged.behind, 1)
        XCTAssertThrowsError(try GitRepository.clone(
            remote: "https://user:secret@example.invalid/repo.git", destination: destination
        ))
    }

    func testStashInspectAndApply() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let git = GitProcess()
        let file = url.appending(path: "notes.txt")
        try "base\n".write(to: file, atomically: true, encoding: .utf8)
        _ = try git.run(in: url, ["add", "--", "notes.txt"])
        _ = try git.run(in: url, ["commit", "-m", "Base"])
        try "base\nnew line\n".write(to: file, atomically: true, encoding: .utf8)

        let repository = try GitRepository(location: url)
        try await repository.stash(message: "Review later")
        let stashes = try await repository.stashes()
        XCTAssertEqual(stashes.first?.reference, "stash@{0}")
        XCTAssertTrue(stashes.first?.subject.contains("Review later") == true)
        let diff = try await repository.stashDiff("stash@{0}")
        XCTAssertTrue(diff.contains("+new line"))
        let clean = try await repository.snapshot()
        XCTAssertTrue(clean.entries.isEmpty)
        try await repository.applyStash("stash@{0}")
        let restored = try await repository.snapshot()
        XCTAssertEqual(restored.entries.first?.path, "notes.txt")
        do {
            try await repository.applyStash("stash@{nope}")
            XCTFail("Invalid stash references must be rejected")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Invalid stash reference"))
        }
    }

    func testLocalTagAndRemoteManagement() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let git = GitProcess()
        _ = try git.run(in: url, ["commit", "--allow-empty", "-m", "Base"])
        let repository = try GitRepository(location: url)

        try await repository.createTag("v1.0")
        let tags = try await repository.tags()
        XCTAssertEqual(tags, ["v1.0"])
        try await repository.deleteTag("v1.0")
        let deletedTags = try await repository.tags()
        XCTAssertTrue(deletedTags.isEmpty)

        try await repository.addRemote(name: "backup", url: url.path)
        let remotes = try await repository.remotes()
        XCTAssertEqual(remotes, ["backup"])
        try await repository.removeRemote("backup")
        let removedRemotes = try await repository.remotes()
        XCTAssertTrue(removedRemotes.isEmpty)
        do {
            try await repository.addRemote(
                name: "unsafe", url: "https://user:token@example.invalid/repo.git"
            )
            XCTFail("Credential-bearing remote URL must be rejected")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("password or token"))
        }
    }

    func testBranchParentAndStackedStateStayLocalAndRejectCycles() async throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let git = GitProcess()
        _ = try git.run(in: url, ["commit", "--allow-empty", "-m", "Base"])
        let repository = try GitRepository(location: url)
        let base = try await repository.branchName()
        try await repository.createBranch("topic/one.part", checkout: false)
        try await repository.createBranch("topic/two", checkout: false)

        try await repository.setBranchParent(base, for: "topic/one.part")
        try await repository.setBranchStacked(true, for: "topic/one.part")
        let first = try await repository.branchRelationship("topic/one.part")
        XCTAssertEqual(first.parent, base)
        XCTAssertTrue(first.isStacked)
        XCTAssertEqual(
            try git.run(in: url, ["config", "--local", "--get", "branch.topic/one.part.gitdeskparent"])
                .text.trimmingCharacters(in: .newlines), base
        )
        try await repository.setBranchParent("topic/one.part", for: "topic/two")
        do {
            try await repository.setBranchParent("topic/two", for: "topic/one.part")
            XCTFail("Parent relationships must not form a cycle")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("cycle"))
        }
        let afterRejectedCycle = try await repository.branchRelationship("topic/one.part")
        XCTAssertEqual(afterRejectedCycle.parent, base)

        try await repository.setBranchParent(nil, for: "topic/one.part")
        let cleared = try await repository.branchRelationship("topic/one.part")
        XCTAssertNil(cleared.parent)
        XCTAssertFalse(cleared.isStacked)
        do {
            try await repository.setBranchStacked(true, for: "topic/one.part")
            XCTFail("Stacking requires a parent")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("parent"))
        }
    }
}
