import AppKit
import GitDeskCore
import SwiftUI

private enum ReferenceTab: String, CaseIterable, Identifiable {
    case branches = "Branches"
    case tags = "Tags"
    case remotes = "Remotes"
    var id: String { rawValue }
}

struct ContentView: View {
    @StateObject private var model = WorkspaceModel()
    @State private var showingBranchDialog = false
    @State private var showingQuickActions = false
    @State private var showingWorktreeDialog = false
    @State private var showingPushConfirmation = false
    @State private var showingCloneDialog = false
    @State private var showingTagDialog = false
    @State private var showingRemoteDialog = false
    @State private var tagToDelete: String?
    @State private var remoteToRemove: String?
    @State private var referenceTab: ReferenceTab = .branches
    @State private var branchName = ""
    @State private var worktreeBranchName = ""
    @State private var cloneRemote = ""
    @State private var tagName = ""
    @State private var remoteName = ""
    @State private var remoteURL = ""

    var body: some View {
        NavigationSplitView {
            repositorySidebar
                .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 320)
        } content: {
            workspaceContent
                .navigationSplitViewColumnWidth(min: 320, ideal: 410, max: 600)
        } detail: {
            detailPane
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    chooseRepository()
                } label: {
                    Label("Open Repository", systemImage: "folder.badge.plus")
                }
                .help("Open a local Git repository")
                .keyboardShortcut("o", modifiers: [.command])
            }
            ToolbarItem(placement: .navigation) {
                Menu {
                    Button("Create Repository…") { chooseNewRepositoryDestination() }
                    Button("Clone Repository…") { showingCloneDialog = true }
                } label: {
                    Label("New Repository", systemImage: "plus")
                }
                .help("Create or clone a repository")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                if model.selectedRepositoryPath != nil {
                    Button { model.refresh() } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh repository")
                    .keyboardShortcut("r", modifiers: [.command])

                    Menu {
                        Button("Fetch") { model.fetch() }
                        Button("Pull (fast forward)") { model.pull() }
                        Button("Push…") { showingPushConfirmation = true }
                    } label: {
                        Label("Sync", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .help("Fetch, pull, or push")

                    Menu {
                        Button("New Branch…") { showingBranchDialog = true }
                        Divider()
                        ForEach(model.branches, id: \.self) { branch in
                            Button(branch) { model.checkout(branch) }
                        }
                    } label: {
                        Label(model.snapshot?.branch ?? "Branch", systemImage: "arrow.triangle.branch")
                    }
                    .help("Switch or create a branch")
                }

                Button { showingQuickActions = true } label: {
                    Label("Quick Actions", systemImage: "command")
                }
                .help("Search commands and views")
                .keyboardShortcut("k", modifiers: [.command])
            }
        }
        .alert("New Branch", isPresented: $showingBranchDialog) {
            TextField("Branch name", text: $branchName)
            Button("Create") {
                model.createBranch(branchName)
                branchName = ""
            }
            Button("Cancel", role: .cancel) { branchName = "" }
        } message: {
            Text("Create and switch to a new branch.")
        }
        .alert("Clone Repository", isPresented: $showingCloneDialog) {
            TextField("Remote URL", text: $cloneRemote)
            Button("Choose Destination…") { chooseCloneDestination() }
            Button("Cancel", role: .cancel) { cloneRemote = "" }
        } message: {
            Text("Enter an HTTPS, SSH, or local Git remote.")
        }
        .alert("Create Tag", isPresented: $showingTagDialog) {
            TextField("Tag name", text: $tagName)
            Button("Create") {
                model.createTag(tagName.trimmingCharacters(in: .whitespacesAndNewlines))
                tagName = ""
            }
            Button("Cancel", role: .cancel) { tagName = "" }
        } message: {
            Text("Create a lightweight local tag at HEAD.")
        }
        .alert("Add Remote", isPresented: $showingRemoteDialog) {
            TextField("Name", text: $remoteName)
            TextField("URL", text: $remoteURL)
            Button("Add") {
                model.addRemote(
                    name: remoteName.trimmingCharacters(in: .whitespacesAndNewlines),
                    url: remoteURL.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                remoteName = ""
                remoteURL = ""
            }
            Button("Cancel", role: .cancel) {
                remoteName = ""
                remoteURL = ""
            }
        } message: {
            Text("Use an SSH or HTTPS URL without embedded credentials.")
        }
        .confirmationDialog(
            "Delete local tag?", isPresented: Binding(
                get: { tagToDelete != nil }, set: { if !$0 { tagToDelete = nil } }
            ), titleVisibility: .visible
        ) {
            if let tag = tagToDelete {
                Button("Delete \(tag)", role: .destructive) {
                    model.deleteTag(tag)
                    tagToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { tagToDelete = nil }
        } message: {
            Text("This removes the local tag. It does not delete a tag on any remote.")
        }
        .confirmationDialog(
            "Remove remote?", isPresented: Binding(
                get: { remoteToRemove != nil }, set: { if !$0 { remoteToRemove = nil } }
            ), titleVisibility: .visible
        ) {
            if let remote = remoteToRemove {
                Button("Remove \(remote)", role: .destructive) {
                    model.removeRemote(remote)
                    remoteToRemove = nil
                }
            }
            Button("Cancel", role: .cancel) { remoteToRemove = nil }
        } message: {
            Text("This removes the remote configuration and its remote-tracking refs. It does not delete the hosted repository.")
        }
        .alert("New Worktree", isPresented: $showingWorktreeDialog) {
            TextField("New branch name", text: $worktreeBranchName)
            Button("Choose Location…") { chooseWorktreeDestination() }
            Button("Cancel", role: .cancel) { worktreeBranchName = "" }
        } message: {
            Text("Create a separate working folder and branch from the current HEAD.")
        }
        .confirmationDialog(
            "Push this branch?", isPresented: $showingPushConfirmation,
            titleVisibility: .visible
        ) {
            Button("Push to Remote") { model.push() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This updates the remote repository. A local undo cannot reverse the push.")
        }
        .alert(
            "Git Error",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .sheet(isPresented: $showingQuickActions) {
            QuickActionsView(model: model)
                .frame(width: 520, height: 470)
        }
        .onOpenURL { url in
            do {
                let link = try GitDeskLink.parse(url)
                model.addRepository(link.repository)
                let section: WorkspaceSection = switch link.view {
                case .changes: .workingCopy
                case .history: .history
                case .branches: .branches
                case .stashes: .stashes
                case .worktrees: .worktrees
                }
                model.chooseSection(section)
            } catch {
                model.errorMessage = error.localizedDescription
            }
        }
    }

    private var repositorySidebar: some View {
        VStack(spacing: 0) {
            List(selection: $model.selectedRepositoryPath) {
                Section {
                    ForEach(model.repositories) { repository in
                        Label(repository.name, systemImage: "folder")
                            .tag(repository.path)
                            .help(repository.path)
                    }
                } header: {
                    HStack {
                        Text("REPOSITORIES")
                        Spacer()
                        Button {
                            chooseRepository()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                        .help("Add repository")
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: model.selectedRepositoryPath) { _, path in
                model.selectRepository(path)
            }

            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.tint)
                Text("Your Git workspace")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
    }

    private var workspaceContent: some View {
        VStack(spacing: 0) {
            if model.selectedRepositoryPath == nil {
                ContentUnavailableView {
                    Label("Open a repository", systemImage: "folder.badge.plus")
                } description: {
                    Text("Bring an existing Git project into your workspace.")
                } actions: {
                    HStack {
                        Button("Choose Folder") { chooseRepository() }
                            .buttonStyle(.borderedProminent)
                        Button("Clone…") { showingCloneDialog = true }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.selectedRepositoryName)
                                .font(.title2.weight(.semibold))
                                .lineLimit(1)
                            Text(model.snapshot?.branch ?? "Loading repository…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let upstream = model.snapshot?.upstream {
                                HStack(spacing: 8) {
                                    Text(upstream)
                                    if let ahead = model.snapshot?.ahead,
                                       let behind = model.snapshot?.behind {
                                        Text("↑ \(ahead)  ↓ \(behind)")
                                            .fontDesign(.monospaced)
                                            .accessibilityLabel("\(ahead) ahead, \(behind) behind")
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        if model.isBusy {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel("Git operation in progress")
                        }
                    }

                    Picker("View", selection: Binding(
                        get: { model.section },
                        set: { model.chooseSection($0) }
                    )) {
                        ForEach(WorkspaceSection.allCases) { section in
                            Label(section.rawValue, systemImage: section.symbol)
                                .tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(.horizontal, 18)
                .padding(.top, 17)
                .padding(.bottom, 13)

                Divider()
                switch model.section {
                case .workingCopy: workingCopyContent
                case .history: historyContent
                case .branches: branchesContent
                case .stashes: stashesContent
                case .worktrees: worktreesContent
                }
            }
        }
    }

    private var workingCopyContent: some View {
        VStack(spacing: 0) {
            if let entries = model.snapshot?.entries, !entries.isEmpty {
                HStack {
                    Text("\(entries.count) changed \(entries.count == 1 ? "file" : "files")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Stage All") { model.stageAll() }
                        .buttonStyle(.plain)
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 10)

                List(selection: $model.selectedFile) {
                    ForEach(entries) { entry in
                        HStack(spacing: 11) {
                            Image(systemName: symbol(for: entry))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(color(for: entry))
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text((entry.path as NSString).lastPathComponent)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                Text(entry.path)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 8)
                            Text(entry.code)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .tag(entry.path)
                        .contextMenu {
                            Button("Stage") { model.stage(entry.path) }
                            Button("Unstage") { model.unstage(entry.path) }
                        }
                    }
                }
                .listStyle(.inset)
                .onChange(of: model.selectedFile) { _, path in
                    model.selectFile(path)
                }
            } else {
                ContentUnavailableView {
                    Label("Working tree is clean", systemImage: "checkmark.circle")
                } description: {
                    Text("Changes to this repository will appear here.")
                }
                .frame(maxHeight: .infinity)
            }

            Divider()
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("COMMIT")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Stage changes before committing")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                TextField("Describe this change…", text: $model.commitMessage)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.commit() }
                HStack {
                    Button("Commit Changes") { model.commit() }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.commitMessage.trimmingCharacters(in: .whitespaces).isEmpty || model.isBusy)
                    Spacer()
                }
            }
            .padding(16)
        }
    }

    private var historyContent: some View {
        Group {
            if model.commits.isEmpty {
                ContentUnavailableView("No commits yet", systemImage: "clock")
            } else {
                VStack(spacing: 0) {
                    List(selection: $model.selectedCommitID) {
                        ForEach(model.commits) { commit in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 7))
                                .foregroundStyle(.tint)
                                .frame(width: 10)
                                .padding(.top, 6)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(commit.subject)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(2)
                                HStack {
                                    Text(commit.author)
                                    Text(commit.id.prefix(8))
                                        .fontDesign(.monospaced)
                                    if let date = commit.date {
                                        Text(date, style: .relative)
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .tag(commit.id)
                        }
                    }
                    .listStyle(.inset)
                    .onChange(of: model.selectedCommitID) { _, id in
                        model.selectCommit(id)
                    }
                    if model.historyHasMore {
                        Button("Load More Commits") { model.loadMoreHistory() }
                            .buttonStyle(.plain)
                            .disabled(model.isBusy)
                            .padding(12)
                    }
                }
            }
        }
    }

    private var stashesContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Save and inspect temporary work")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Save Stash") { model.saveStash() }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.medium))
                    .disabled(model.snapshot?.entries.isEmpty ?? true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            if model.stashes.isEmpty {
                ContentUnavailableView("No stashes", systemImage: "archivebox")
            } else {
                List(selection: $model.selectedStashReference) {
                    ForEach(model.stashes) { stash in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stash.reference)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                            Text(stash.subject)
                                .font(.system(size: 13))
                                .lineLimit(2)
                        }
                        .padding(.vertical, 5)
                        .tag(stash.reference)
                        .contextMenu {
                            Button("Apply Stash") { model.applyStash(stash.reference) }
                        }
                    }
                }
                .onChange(of: model.selectedStashReference) { _, reference in
                    model.selectStash(reference)
                }
            }
        }
    }

    private var branchesContent: some View {
        VStack(spacing: 0) {
            Picker("References", selection: $referenceTab) {
                ForEach(ReferenceTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            Divider()
            switch referenceTab {
            case .branches: branchReviewContent
            case .tags: tagsContent
            case .remotes: remotesContent
            }
        }
    }

    private var branchReviewContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Compare with")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let base = model.branchReviewBase {
                    Picker("Base branch", selection: Binding(
                        get: { base }, set: { model.chooseReviewBase($0) }
                    )) {
                        ForEach(model.branches, id: \.self) { branch in
                            Text(branch).tag(branch)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 190)
                }
                Spacer()
                Text("\(model.branchReview.count) branches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            if model.branchReview.isEmpty {
                ContentUnavailableView("No branches", systemImage: "arrow.triangle.branch")
            } else {
                List(selection: $model.selectedReviewBranch) {
                    ForEach(model.branchReview) { branch in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: branch.isMergedIntoBase
                                ? "checkmark.circle.fill" : "circle.dotted")
                                .foregroundStyle(branch.isMergedIntoBase ? .green : .orange)
                                .frame(width: 18)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(branch.name).font(.system(size: 13, weight: .medium))
                                    if branch.worktreePath != nil {
                                        Image(systemName: "folder.badge.gearshape")
                                            .accessibilityLabel("Checked out in a worktree")
                                    }
                                }
                                Text(branch.subject)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if let date = branch.lastCommit {
                                Text(date, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.vertical, 5)
                        .tag(branch.name)
                        .contextMenu {
                            Menu("Parent Branch") {
                                ForEach(model.branches.filter { $0 != branch.name }, id: \.self) { parent in
                                    Button(parent) { model.setBranchParent(parent, for: branch.name) }
                                }
                                Divider()
                                Button("Clear Parent") {
                                    model.setBranchParent(nil, for: branch.name)
                                }
                            }
                            Button("Mark as Stacked") {
                                model.setBranchStacked(true, for: branch.name)
                            }
                            Button("Unstack Branch") {
                                model.setBranchStacked(false, for: branch.name)
                            }
                            if let path = branch.worktreePath {
                                Button("Open Worktree") {
                                    model.addRepository(URL(fileURLWithPath: path, isDirectory: true))
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
                .onChange(of: model.selectedReviewBranch) { _, name in
                    model.selectReviewBranch(name)
                }
            }
        }
    }

    private var tagsContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Local tags")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("New Tag…") { showingTagDialog = true }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            if model.tags.isEmpty {
                ContentUnavailableView("No tags", systemImage: "tag")
            } else {
                List(model.tags, id: \.self) { tag in
                    Label(tag, systemImage: "tag")
                        .contextMenu {
                            Button("Delete Local Tag…", role: .destructive) {
                                tagToDelete = tag
                            }
                        }
                }
            }
        }
    }

    private var remotesContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Remote names")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Add Remote…") { showingRemoteDialog = true }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            if model.remotes.isEmpty {
                ContentUnavailableView("No remotes", systemImage: "network")
            } else {
                List(model.remotes, id: \.self) { remote in
                    Label(remote, systemImage: "network")
                        .contextMenu {
                            Button("Remove Remote…", role: .destructive) {
                                remoteToRemove = remote
                            }
                        }
                }
            }
        }
    }

    private var worktreesContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Separate branches for focused work")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("New Worktree…") { showingWorktreeDialog = true }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            if model.worktrees.isEmpty {
                ContentUnavailableView("No worktrees", systemImage: "arrow.triangle.branch")
            } else {
                List(model.worktrees) { worktree in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Label(worktree.displayName, systemImage: "folder")
                            Text(worktree.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        if worktree.lockReason != nil {
                            Image(systemName: "lock")
                                .accessibilityLabel("Locked worktree")
                        }
                    }
                    .help(worktree.path)
                    .contextMenu {
                        Button("Open in GitDesk") {
                            model.addRepository(URL(fileURLWithPath: worktree.path, isDirectory: true))
                        }
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([
                                URL(fileURLWithPath: worktree.path, isDirectory: true)
                            ])
                        }
                    }
                }
            }
        }
    }

    private var detailPane: some View {
        VStack(spacing: 0) {
            if model.selectedFile != nil || model.selectedCommitID != nil || model.selectedReviewBranch != nil || model.selectedStashReference != nil {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.selectedFile.map { ($0 as NSString).lastPathComponent }
                             ?? model.selectedCommit?.subject ?? model.selectedReviewBranch
                             ?? model.selectedStashReference ?? "Details")
                            .font(.headline)
                            .lineLimit(1)
                        Text(model.selectedFile ?? model.selectedCommitID
                             ?? model.branchReviewBase ?? model.selectedStashReference ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if let path = model.selectedFile {
                        Button("Stage") { model.stage(path) }
                            .buttonStyle(.bordered)
                        Button("Unstage") { model.unstage(path) }
                            .buttonStyle(.bordered)
                    }
                    if let reference = model.selectedStashReference {
                        Button("Apply Stash") { model.applyStash(reference) }
                            .buttonStyle(.bordered)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                Divider()
                if model.selectedFile != nil,
                   model.stagedPatch != nil || model.unstagedPatch != nil {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if let patch = model.unstagedPatch {
                                ForEach(patch.hunks) { hunk in
                                    hunkAction(hunk, staged: false)
                                }
                            }
                            if let patch = model.stagedPatch {
                                ForEach(patch.hunks) { hunk in
                                    hunkAction(hunk, staged: true)
                                }
                            }
                        }
                        .padding(12)
                    }
                    .frame(maxHeight: 155)
                    Divider()
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(model.detail.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                            Text(line.isEmpty ? " " : line)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(diffColor(line))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 1)
                                .background(diffBackground(line))
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.vertical, 10)
                }
            } else {
                ContentUnavailableView {
                    Label("Inspect your work", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Select a file or commit to see its details.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func hunkAction(_ hunk: GitDiffHunk, staged: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: staged ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(staged ? .green : .secondary)
                .accessibilityHidden(true)
            Text(hunk.heading)
                .font(.caption.monospaced())
                .lineLimit(1)
                .help(hunk.heading)
            Spacer(minLength: 8)
            Button(staged ? "Unstage Hunk" : "Stage Hunk") {
                model.applyHunk(hunk.id, staged: staged)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(model.isBusy)
        }
    }

    private func symbol(for entry: GitStatusEntry) -> String {
        switch entry.kind {
        case .renamed: "arrow.right.doc.on.clipboard"
        case .untracked: "plus.circle"
        case .unmerged: "exclamationmark.triangle"
        case .ignored: "minus.circle"
        case .tracked: "doc.text"
        }
    }

    private func color(for entry: GitStatusEntry) -> Color {
        switch entry.kind {
        case .renamed: .blue
        case .untracked: .green
        case .unmerged: .orange
        case .ignored: .secondary
        case .tracked: .primary
        }
    }

    private func diffColor(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") { return .green }
        if line.hasPrefix("-") && !line.hasPrefix("---") { return .red }
        if line.hasPrefix("@@") { return .blue }
        return .primary
    }

    private func diffBackground(_ line: String) -> Color {
        if line.hasPrefix("+") && !line.hasPrefix("+++") { return .green.opacity(0.08) }
        if line.hasPrefix("-") && !line.hasPrefix("---") { return .red.opacity(0.08) }
        return .clear
    }

    private func chooseRepository() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Open Repository"
        panel.message = "Choose a folder containing a Git repository."
        if panel.runModal() == .OK, let url = panel.url {
            model.addRepository(url)
        }
    }

    private func chooseWorktreeDestination() {
        let branch = worktreeBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !branch.isEmpty else {
            model.errorMessage = "Enter a branch name for the new worktree."
            return
        }
        let panel = NSSavePanel()
        panel.prompt = "Create Worktree"
        panel.message = "Choose a new folder for this branch."
        panel.nameFieldStringValue = branch.replacingOccurrences(of: "/", with: "-")
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let destination = panel.url {
            model.createWorktree(at: destination, branch: branch)
            worktreeBranchName = ""
        }
    }

    private func chooseNewRepositoryDestination() {
        let panel = NSSavePanel()
        panel.prompt = "Create Repository"
        panel.message = "Choose a new folder for the repository."
        panel.nameFieldStringValue = "New Repository"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let destination = panel.url {
            model.createRepository(at: destination)
        }
    }

    private func chooseCloneDestination() {
        let remote = cloneRemote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !remote.isEmpty else {
            model.errorMessage = "Enter a remote URL to clone."
            return
        }
        let panel = NSSavePanel()
        panel.prompt = "Clone Repository"
        panel.message = "Choose a new folder for this clone."
        panel.nameFieldStringValue = "Repository"
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let destination = panel.url {
            model.cloneRepository(remote: remote, to: destination)
            cloneRemote = ""
        }
    }
}

private struct QuickActionsView: View {
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private struct Action: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let symbol: String
        let perform: () -> Void
    }

    private var actions: [Action] {
        var all: [Action] = WorkspaceSection.allCases.map { section in
            Action(
                id: "view:\(section.id)", title: "Show \(section.rawValue)",
                subtitle: "Repository view", symbol: section.symbol,
                perform: { model.chooseSection(section) }
            )
        }
        all += model.repositories.map { repository in
            Action(
                id: "repo:\(repository.path)", title: repository.name,
                subtitle: repository.path, symbol: "folder",
                perform: { model.selectRepository(repository.path) }
            )
        }
        all += model.branches.map { branch in
            Action(
                id: "branch:\(branch)", title: "Switch to \(branch)",
                subtitle: "Local branch", symbol: "arrow.triangle.branch",
                perform: { model.checkout(branch) }
            )
        }
        return Array(all.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query)
                || $0.subtitle.localizedCaseInsensitiveContains(query)
        }.prefix(100))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "command")
                    .foregroundStyle(.tint)
                TextField("Jump to a view…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .onSubmit {
                        if let first = actions.first {
                            first.perform()
                            dismiss()
                        }
                    }
                Text("⌘K")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            Divider()
            List {
                ForEach(actions) { action in
                    Button {
                        action.perform()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: action.symbol)
                                .frame(width: 18)
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.title)
                                Text(action.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
        }
    }
}
