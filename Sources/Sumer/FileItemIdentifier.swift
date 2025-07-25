import Foundation

struct FileItemIdentifier {
    private var bookmarkData: Data?
    private(set) var path: URL

    init(path: URL) {
        self.path = path
        self.bookmarkData = try? path.bookmarkData()
    }

    private mutating func fetchPathFromBookmark() -> URL? {
        if let bookmarkData = bookmarkData {
            var isStale = false

            guard
                let bookmarkURL = try? URL(
                    resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
            else {
                return nil
            }

            if isStale {
                self.bookmarkData = try? bookmarkURL.bookmarkData()
            }

            return bookmarkURL
        }
        return nil
    }

    mutating func updatePath() -> Bool {
        let newPath = fetchPathFromBookmark()
        if let newPath {
            if path != newPath {
                path = newPath
                return true
            }
        }
        return false
    }
}
