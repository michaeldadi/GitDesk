import AppKit
import GitDeskCore
import SwiftUI

struct ContentView: View {
    @StateObject private var model = WorkspaceModel()
    @State private var showingBranchDialog = false
    @State private var showingQuickActions = false
    @State private var showingWorktreeDialog = false
    @State private var branchName = ""
    @State private var worktreeBranchName = ""

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
                        Button("Push") { model.push() }
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
        .alert("New Worktree", isPresented: $showingWorktreeDialog) {
            TextField("New branch name", text: $worktreeBranchName)
            Button("Choose Location…") { chooseWorktreeDestination() }
            Button("Cancel", role: .cancel) { worktreeBranchName = "" }
        } message: {
            Text("Create a separate working folder and branch from the current HEAD.")
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
                    Button("Choose Folder") { chooseRepository() }
                        .buttonStyle(.borderedProminent)
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
        Group {
            if model.stashes.isEmpty {
                ContentUnavailableView("No stashes", systemImage: "archivebox")
            } else {
                List(model.stashes, id: \.self) { stash in
                    Label(stash, systemImage: "archivebox")
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
            if model.selectedFile != nil || model.selectedCommitID != nil {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.selectedFile.map { ($0 as NSString).lastPathComponent }
                             ?? model.selectedCommit?.subject ?? "Details")
                            .font(.headline)
                            .lineLimit(1)
                        Text(model.selectedFile ?? model.selectedCommitID ?? "")
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
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                Divider()
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
}

private struct QuickActionsView: View {
    @ObservedObject var model: WorkspaceModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var actions: [(String, String, WorkspaceSection)] {
        [
            ("Show Changes", "square.stack.3d.up", .workingCopy),
            ("Show History", "clock", .history),
            ("Show Stashes", "archivebox", .stashes),
            ("Show Worktrees", "arrow.triangle.branch", .worktrees),
        ].filter { query.isEmpty || $0.0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "command")
                    .foregroundStyle(.tint)
                TextField("Jump to a view…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                Text("⌘K")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .padding(20)
            Divider()
            List {
                ForEach(actions, id: \.0) { title, symbol, section in
                    Button {
                        model.chooseSection(section)
                        dismiss()
                    } label: {
                        Label(title, systemImage: symbol)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
        }
    }
}
