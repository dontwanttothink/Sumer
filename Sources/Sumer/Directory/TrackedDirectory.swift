import SwiftUI

@Observable class TrackedDirectory {
    private(set) var path: URL
    private(set) var items: [FileItem] = []
    fileprivate var identities: [URL: UUID] = [:]

    init(path: URL) {
        self.path = path

        // When we are notified that a new file is added, we check whether
        // its parent exists in our tree. If it does, we invalidate (if
        // parent is collapsed) or update (if parent is expanded) its
        // `.children` property with the new item. Invalidating the `.children`
        // of a collapsed item  stops us from needlessly updating any state
        // deeper in the tree. When creating a new item, we generate a UUID and
        // register it in the  `identities` dictionary.

        // When we are notified that a file is deleted, we check whether its
        // parent exists in our tree. If it does, we invalidate (if
        // collapsed) or update (if parent is expanded) its `.children`
        // property without the item. We make sure to get rid of the item's
        // entry in the `identities` dictionary, so that we don't leak memory.

        // When we are notified that a file is moved or renamed, we check
        // whether the new and old parents (which may be the same) exist in our
        // tree. If they do, we invalidate (if parent is collapsed) or update
        // (if parent is expanded) the `.children` properties of each. We remove
        // the item from the old parent or invalidate its `.children`. We keep
        // a temporary copy of the old item's UUID, but delete its identity from
        // the `identities` dictionary. Then, if the new parent is expanded,
        // we add a new item to its `.children` and register it in the
        // `identities` dictionary with the old item's UUID. If the new parent
        // is not expanded, we invalidate its `.children` and do not create any
        // new item or identity.
    }

    enum FileItem: Identifiable {
        case Leaf(LeafItem)
        case NonLeaf(NonLeafItem)

        var id: UUID {
            switch self {
            case .Leaf(let item):
                return item.id
            case .NonLeaf(let item):
                return item.id
            }
        }
    }

    @Observable class LeafItem: Identifiable {
        private var trackedDirectory: TrackedDirectory
        fileprivate(set) var path: URL

        init(path: URL, trackedDirectory: TrackedDirectory) {
            self.path = path
            self.trackedDirectory = trackedDirectory
        }

        var id: UUID {
            trackedDirectory.identities[path]!
        }
    }

    @Observable class NonLeafItem: Identifiable {
        private var trackedDirectory: TrackedDirectory
        var isExpanded = false
        fileprivate(set) var path: URL

        enum ChildrenState {
            /// The item is collapsed
            case Unavailable
            case Available([URL: FileItem])
            case Failed(Error)
        }

        private func fetchChildren() -> ChildrenState {
            let fm = FileManager.default
            do {
                let contents = try fm.contentsOfDirectory(
                    at: path, includingPropertiesForKeys: [.isDirectoryKey])

                var childrenMap: [URL: FileItem] = [:]
                for url in contents {
                    let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                    let isDirectory = resourceValues.isDirectory ?? false

                    if isDirectory {
                        childrenMap[url] = FileItem.NonLeaf(
                            NonLeafItem(path: url, trackedDirectory: trackedDirectory))
                    }
                }

                return .Available(childrenMap)
            } catch {
                return .Failed(error)
            }
        }

        /// unavailable unless expanded
        var children: ChildrenState {
            if !isExpanded {
                return .Unavailable
            }

            if case .Available = latestChildren {
                return latestChildren
            }
            latestChildren = fetchChildren()
            return latestChildren
        }

        /// This property is accurate if available. It is always available while
        /// the item is expanded. If the item is not expanded, it may be
        /// unavailable until the item is expanded again.
        ///
        ///
        /// **Details**
        ///
        /// This property is `.Unavailable` until the item is expanded. While it
        /// is expanded, it is kept up to date.
        ///
        /// It may also be available even if the item is collapsed, in which
        /// case the data is not stale. If a file system event that makes this
        /// property inaccurate occurs, the property is set back to `nil`.
        fileprivate(set) var latestChildren: ChildrenState = .Unavailable

        init(path: URL, trackedDirectory: TrackedDirectory, ) {
            self.path = path
            self.trackedDirectory = trackedDirectory
        }

        var id: UUID {
            trackedDirectory.identities[path]!
        }
    }
}
