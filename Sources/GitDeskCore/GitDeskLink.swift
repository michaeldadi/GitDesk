import Foundation

public enum GitDeskView: String, CaseIterable, Sendable {
    case changes, history, stashes, worktrees
}

public struct GitDeskLink: Sendable {
    public let repository: URL
    public let view: GitDeskView

    public init(repository: URL, view: GitDeskView = .changes) throws {
        guard repository.isFileURL, repository.path.hasPrefix("/") else {
            throw GitDeskError.invalidInput("Choose an absolute repository path.")
        }
        self.repository = repository.standardizedFileURL
        self.view = view
    }

    public var url: URL {
        var components = URLComponents()
        components.scheme = "gitdesk"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "repo", value: repository.path),
            URLQueryItem(name: "view", value: view.rawValue),
        ]
        return components.url!
    }

    public static func parse(_ url: URL) throws -> GitDeskLink {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "gitdesk", components.host == "open",
              components.path.isEmpty, let items = components.queryItems,
              items.count == 2,
              let repo = items.first(where: { $0.name == "repo" })?.value,
              let viewName = items.first(where: { $0.name == "view" })?.value,
              let view = GitDeskView(rawValue: viewName), repo.hasPrefix("/") else {
            throw GitDeskError.invalidInput("Invalid GitDesk link.")
        }
        return try GitDeskLink(repository: URL(fileURLWithPath: repo, isDirectory: true), view: view)
    }
}
