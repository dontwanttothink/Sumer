import Foundation

extension NSError {
    var posixCode: Int? {
        if self.domain == NSCocoaErrorDomain,
            let underlying = self.userInfo[NSUnderlyingErrorKey] as? NSError,
            underlying.domain == NSPOSIXErrorDomain
        {
            return underlying.code
        }
        return nil
    }
}

enum FileItemError: Error {
    case NoEntry
}

class FileItem {
    private var root: FileItemIdentifier
    private(set) var children: [FileItem]

    var name: String {
        root.path.lastPathComponent
    }

    init(root: URL) {
        self.root = FileItemIdentifier(path: root)

        self.children = []
    }

    func refreshLocation() -> Bool {
        return root.updatePath()
    }

    func updateChildren() throws {
        let fm = FileManager.default
        do {
            let contents = try fm.contentsOfDirectory(
                at: root.path, includingPropertiesForKeys: nil)
            children = contents.map({ FileItem(root: $0) })
        } catch {
            let nsError = error as NSError
            if let posixCode = nsError.posixCode {
                if posixCode == ENOTDIR {
                    self.children = []
                    return
                } else if posixCode == ENOENT {
                    throw FileItemError.NoEntry
                }
            }

            throw error
        }
    }
}
