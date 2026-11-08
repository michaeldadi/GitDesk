import Foundation

public enum GitDeskError: Error, LocalizedError, Sendable {
    case invalidRepository(String)
    case commandFailed(Int32, String)
    case outputTooLarge
    case invalidInput(String)

    public var errorDescription: String? {
        switch self {
        case .invalidRepository(let path): "Not a Git repository: \(path)"
        case .commandFailed(_, let message): message
        case .outputTooLarge: "Git returned more data than this view can display."
        case .invalidInput(let message): message
        }
    }
}

public struct GitStatusEntry: Identifiable, Hashable, Sendable {
    public enum Kind: String, Sendable {
        case tracked, renamed, unmerged, untracked, ignored
    }

    public let path: String
    public let originalPath: String?
    public let code: String
    public let kind: Kind

    public var id: String { path }
    public var isStaged: Bool { code.first != nil && code.first != "." && code.first != "?" }
    public var isUnstaged: Bool { code.last != nil && code.last != "." }

    public init(path: String, originalPath: String? = nil, code: String, kind: Kind) {
        self.path = path
        self.originalPath = originalPath
        self.code = code
        self.kind = kind
    }
}

public struct GitCommit: Identifiable, Hashable, Sendable {
    public let id: String
    public let author: String
    public let date: Date?
    public let subject: String

    public init(id: String, author: String, date: Date?, subject: String) {
        self.id = id
        self.author = author
        self.date = date
        self.subject = subject
    }
}

public struct GitRepositorySnapshot: Sendable {
    public let branch: String
    public let entries: [GitStatusEntry]

    public init(branch: String, entries: [GitStatusEntry]) {
        self.branch = branch
        self.entries = entries
    }
}

public struct GitWorktree: Identifiable, Hashable, Sendable {
    public let path: String
    public let head: String?
    public let branch: String?
    public let isDetached: Bool
    public let isBare: Bool
    public let lockReason: String?

    public var id: String { path }
    public var displayName: String { branch ?? (isDetached ? "Detached HEAD" : "No branch") }

    public init(
        path: String, head: String?, branch: String?, isDetached: Bool,
        isBare: Bool, lockReason: String?
    ) {
        self.path = path
        self.head = head
        self.branch = branch
        self.isDetached = isDetached
        self.isBare = isBare
        self.lockReason = lockReason
    }
}

public enum GitWorktreeParser {
    public static func parse(_ data: Data) -> [GitWorktree] {
        var result: [GitWorktree] = []
        var fields: [String] = []
        func finish() {
            guard let pathField = fields.first(where: { $0.hasPrefix("worktree ") }) else {
                fields.removeAll()
                return
            }
            let path = String(pathField.dropFirst("worktree ".count))
            let head = fields.first(where: { $0.hasPrefix("HEAD ") }).map { String($0.dropFirst(5)) }
            let ref = fields.first(where: { $0.hasPrefix("branch ") }).map { String($0.dropFirst(7)) }
            let branch = ref?.hasPrefix("refs/heads/") == true
                ? String(ref!.dropFirst("refs/heads/".count)) : ref
            let locked = fields.first(where: { $0 == "locked" || $0.hasPrefix("locked ") })
            result.append(GitWorktree(
                path: path, head: head, branch: branch,
                isDetached: fields.contains("detached"), isBare: fields.contains("bare"),
                lockReason: locked.map { $0 == "locked" ? "Locked" : String($0.dropFirst(7)) }
            ))
            fields.removeAll()
        }
        for token in data.split(separator: 0, omittingEmptySubsequences: false) {
            if token.isEmpty {
                if !fields.isEmpty { finish() }
            } else {
                fields.append(String(decoding: token, as: UTF8.self))
            }
        }
        if !fields.isEmpty { finish() }
        return result
    }
}

public enum GitStatusParser {
    public static func branch(from data: Data) -> String? {
        var head: String?
        var oid: String?
        for token in data.split(separator: 0, omittingEmptySubsequences: true) {
            let record = String(decoding: token, as: UTF8.self)
            if record.hasPrefix("# branch.head ") {
                head = String(record.dropFirst("# branch.head ".count))
            } else if record.hasPrefix("# branch.oid ") {
                oid = String(record.dropFirst("# branch.oid ".count))
            }
        }
        if let head, head != "(detached)" { return head }
        if let oid, oid != "(initial)" { return "Detached at " + String(oid.prefix(8)) }
        return nil
    }

    public static func parse(_ data: Data) -> [GitStatusEntry] {
        let records = data.split(separator: 0, omittingEmptySubsequences: true)
        var entries: [GitStatusEntry] = []
        var index = 0

        while index < records.count {
            let record = String(decoding: records[index], as: UTF8.self)
            defer { index += 1 }

            if record.hasPrefix("? ") {
                entries.append(.init(path: String(record.dropFirst(2)), code: "??", kind: .untracked))
            } else if record.hasPrefix("! ") {
                entries.append(.init(path: String(record.dropFirst(2)), code: "!!", kind: .ignored))
            } else if record.hasPrefix("1 ") {
                let fields = record.split(separator: " ", maxSplits: 8, omittingEmptySubsequences: false)
                if fields.count == 9 {
                    entries.append(.init(path: String(fields[8]), code: String(fields[1]), kind: .tracked))
                }
            } else if record.hasPrefix("2 ") {
                let fields = record.split(separator: " ", maxSplits: 9, omittingEmptySubsequences: false)
                if fields.count == 10 {
                    let oldPath = index + 1 < records.count
                        ? String(decoding: records[index + 1], as: UTF8.self) : nil
                    entries.append(.init(
                        path: String(fields[9]), originalPath: oldPath,
                        code: String(fields[1]), kind: .renamed
                    ))
                    index += 1
                }
            } else if record.hasPrefix("u ") {
                let fields = record.split(separator: " ", maxSplits: 10, omittingEmptySubsequences: false)
                if fields.count == 11 {
                    entries.append(.init(path: String(fields[10]), code: String(fields[1]), kind: .unmerged))
                }
            }
        }
        return entries
    }
}
