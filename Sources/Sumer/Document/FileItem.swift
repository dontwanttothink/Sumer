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
    /// The item does not exist (ENOENT)
    case NoEntry
}

/// Represents an item in the file system. Internally, this uses a `Bookmark`,
/// if available, to follow the item even if it is moved or renamed.
///
/// Calls to instance methods may not work unless `.refreshLocation()` is
/// called after an item is moved or renamed.
///
/// The list of children (`.children`) may be stale unless `.updateChildren()`
/// is called.
class FileItem: Identifiable {
    private var root: FileItemIdentifier

    enum ChildrenState {
        /// The FileItem represents a file, and thus can't have children.
        case NotSupported
        /// Wraps an array of `FileItem`s representing the directory contents
        case Supported([FileItem])
        /// Wraps an error incurred while trying to determine the `FileItem`'s
        /// children.
        ///
        /// **Common errors:**
        ///
        /// * FileItemError.NoEntry: the file does not exist —it might suffice
        /// to try again after calling `.refreshLocation`.
        case Failed(Error)
    }

    private var latestChildren: ChildrenState?

    var children: ChildrenState {
        if latestChildren == nil {
            updateChildren()
        }
        return latestChildren!
    }

    /// a simplified `.children` property, suitable for Swift UI's
    /// `OutlineGroup`
    ///
    /// Errors are ignored. If a `ChildrenState.Failed` is encountered, this
    /// computed property yields `nil`.
    var simplifiedChildren: [FileItem]? {
        if case .Supported(let items) = children {
            return items
        }
        return nil
    }

    var id: URL {
        root.id
    }

    var name: String {
        root.path.lastPathComponent
    }

    init(root: URL) {
        self.root = FileItemIdentifier(path: root)
        self.latestChildren = nil
    }

    func refreshLocation() -> Bool {
        return root.updatePath()
    }

    func updateChildren() {
        defer { assert(latestChildren != nil) }

        let fm = FileManager.default
        do {
            let contents = try fm.contentsOfDirectory(
                at: root.path, includingPropertiesForKeys: nil)
            latestChildren = .Supported(contents.map({ FileItem(root: $0) }))
        } catch {
            let nsError = error as NSError
            if let posixCode = nsError.posixCode {
                if posixCode == ENOTDIR {
                    latestChildren = .NotSupported
                    return
                } else if posixCode == ENOENT {
                    latestChildren = .Failed(FileItemError.NoEntry)
                }
            }

            latestChildren = .Failed(error)
        }
    }
}
