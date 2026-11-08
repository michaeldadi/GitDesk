import CSQLite
import Foundation

public struct SavedRepository: Identifiable, Hashable, Sendable {
    public let path: String
    public let name: String
    public let lastOpened: Date

    public var id: String { path }
    public var url: URL { URL(fileURLWithPath: path, isDirectory: true) }
}

public final class RepositoryLibrary {
    private let database: OpaquePointer

    public init(databaseURL: URL? = nil) throws {
        let url: URL
        if let databaseURL {
            url = databaseURL
        } else {
            let support = FileManager.default.urls(
                for: .applicationSupportDirectory, in: .userDomainMask
            )[0].appending(path: "GitDesk", directoryHint: .isDirectory)
            url = support.appending(path: "library.sqlite3")
        }
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        var handle: OpaquePointer?
        guard sqlite3_open(url.path, &handle) == SQLITE_OK, let handle else {
            throw GitDeskError.invalidInput("Could not open the repository library.")
        }
        database = handle
        let schema = """
            CREATE TABLE IF NOT EXISTS repositories (
              path TEXT PRIMARY KEY NOT NULL,
              name TEXT NOT NULL,
              last_opened REAL NOT NULL
            );
            """
        guard sqlite3_exec(handle, schema, nil, nil, nil) == SQLITE_OK else {
            sqlite3_close(handle)
            throw GitDeskError.invalidInput("Could not initialize the repository library.")
        }
    }

    deinit { sqlite3_close(database) }

    public func add(_ url: URL) throws {
        let resolved = url.standardizedFileURL.resolvingSymlinksInPath()
        let repository = try GitRepository(location: resolved)
        _ = repository
        let statement = try prepare("""
            INSERT INTO repositories(path, name, last_opened) VALUES (?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET
              name=excluded.name, last_opened=excluded.last_opened
            """)
        defer { sqlite3_finalize(statement) }
        let result = resolved.path.withCString { path in
            resolved.lastPathComponent.withCString { name in
                sqlite3_bind_text(statement, 1, path, -1, nil)
                sqlite3_bind_text(statement, 2, name, -1, nil)
                sqlite3_bind_double(statement, 3, Date().timeIntervalSince1970)
                return sqlite3_step(statement)
            }
        }
        guard result == SQLITE_DONE else {
            throw GitDeskError.invalidInput("Could not save the repository.")
        }
    }

    public func all() throws -> [SavedRepository] {
        let statement = try prepare(
            "SELECT path, name, last_opened FROM repositories ORDER BY last_opened DESC"
        )
        defer { sqlite3_finalize(statement) }
        var repositories: [SavedRepository] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let path = sqlite3_column_text(statement, 0),
                  let name = sqlite3_column_text(statement, 1) else { continue }
            repositories.append(SavedRepository(
                path: String(cString: path),
                name: String(cString: name),
                lastOpened: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
            ))
        }
        return repositories
    }

    public func remove(path: String) throws {
        let statement = try prepare("DELETE FROM repositories WHERE path = ?")
        defer { sqlite3_finalize(statement) }
        let result = path.withCString { pointer in
            sqlite3_bind_text(statement, 1, pointer, -1, nil)
            return sqlite3_step(statement)
        }
        guard result == SQLITE_DONE else {
            throw GitDeskError.invalidInput("Could not remove the repository bookmark.")
        }
    }

    private func prepare(_ query: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            throw GitDeskError.invalidInput("Could not read the repository library.")
        }
        return statement
    }
}
