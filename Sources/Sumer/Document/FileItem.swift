import Foundation

// Performance: repeated IO calls are maybe unnecessary, though
// I think the Outline thing is lazy.

struct FileItem: Hashable, Identifiable, CustomStringConvertible {
    let id = UUID()
    let initialPath: URL
    private var bookmarkData: Data?

    private func findNewPath() -> URL? {
        if let bookmarkData = bookmarkData {
            var isStale = false
            let bookmarkURL = try? URL(
                resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)

            if isStale {
                // ?
            }

            return bookmarkURL
        }
        return nil
    }

    private func latestPath() -> URL {
        return findNewPath() ?? initialPath
    }

    private let fileManager: FileManager

    var isDirectory: Bool {
        get throws {
            try latestPath().isDirectory
        }
    }

    init(path: URL) {
        self.initialPath = path
        self.bookmarkData = try? path.bookmarkData()
        self.fileManager = FileManager.default
    }

    /**
     * Accessing this property incurs file system operations.
     */
    var children: [FileItem]? {
        let contents = try? fileManager.contentsOfDirectory(
            at: latestPath(), includingPropertiesForKeys: [.nameKey])

        if let contents {
            return contents.map({ FileItem(path: $0) })
        }
        return nil
    }

    var description: String {
        return "\(latestPath().lastPathComponent)"
    }
}
