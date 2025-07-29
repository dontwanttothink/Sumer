import SwiftUI

/// A `TrackedDirectory` connects a `ProjectView` to the file system.
@Observable class TrackedDirectory {

	final class FSEventStreamBox {
		private let stream: FSEventStreamRef
		private var context: UnsafeMutablePointer<FSEventStreamContext>

		init(
			info: UnsafeMutableRawPointer?, callback: FSEventStreamCallback,
			pathsToWatch: [URL]
		) {
			self.context = UnsafeMutablePointer<FSEventStreamContext>.allocate(
				capacity: 1)
			context.initialize(
				to: FSEventStreamContext(
					version: CFIndex(0),

					// Memory correctness:
					//
					// Below, 'us' is the `TrackedDirectory` instance.
					//
					// - We don't want Core Foundation to try to retain us,
					// because that would cause a reference cycle. We try to
					// stop that by passing `nil` to the `retain` and `release`
					// callbacks (and hopefully succeed).
					//
					// - The FSEventStream must never outlive us. Because we
					// own the FSEventStream and should KILL it as we are
					// deinitialized through normal Swift memory management,
					// everything will be OK.
					info: info,
					retain: nil, release: nil, copyDescription: nil
				))

			let pathsAsCFString: [CFString] = pathsToWatch.map { $0.path as CFString }

			// Memory correctness: see below
			var rawPointersToPathsAsCFString: [UnsafeRawPointer?] = pathsAsCFString.map
			{
				UnsafeRawPointer(Unmanaged.passUnretained($0).toOpaque())
			}

			// "The retain callback is used within this function, for example,
			// to retain all of the new values from the values C array."
			//
			// Later, "If the collection contains only CFType objects, then pass
			// a pointer to kCFTypeArrayCallBacks (&kCFTypeArrayCallBacks) to
			// use the default callback functions."
			//
			// https://developer.apple.com/documentation/corefoundation/cfarraycreate(_:_:_:_:)

			let pathsToWatch =
				rawPointersToPathsAsCFString.withUnsafeMutableBufferPointer {
					buffer in
					withUnsafePointer(to: kCFTypeArrayCallBacks) {
						callbacksPtr in
						CFArrayCreate(
							kCFAllocatorDefault,
							buffer.baseAddress,
							buffer.count,
							callbacksPtr
						)!
					}
				}

			self.stream = FSEventStreamCreate(
				kCFAllocatorDefault, callback, context, pathsToWatch,
				FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
				CFTimeInterval(1.0),
				FSEventStreamCreateFlags(
					kFSEventStreamCreateFlagNoDefer
						| kFSEventStreamCreateFlagWatchRoot
						| kFSEventStreamCreateFlagFileEvents))!

			// We need to modify an Observable, and the tree operations are
			// (supposed to be) fast. Thus, the callback is called on the main
			// thread.
			FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
			FSEventStreamStart(stream)
		}
		deinit {
			FSEventStreamStop(stream)
			FSEventStreamInvalidate(stream)
			FSEventStreamRelease(stream)

			context.deinitialize(count: 1)
			context.deallocate()
		}
	}

	private struct FSEvent {
		let id: FSEventStreamEventId
		let flags: FSEventStreamEventFlags
		let url: URL
	}

	private var fsEventStream: FSEventStreamBox!
	private let fsEventStreamCallback: FSEventStreamCallback = {
		(
			streamRef: ConstFSEventStreamRef,
			clientCallbackInfo: UnsafeMutableRawPointer?,
			eventsCount: Int,
			eventPaths: UnsafeMutableRawPointer,
			eventFlags: UnsafePointer<FSEventStreamEventFlags>,
			eventIDs: UnsafePointer<FSEventStreamEventId>
		) in

		let info = clientCallbackInfo!
		let tracked = Unmanaged<TrackedDirectory>.fromOpaque(info)
			.takeUnretainedValue()

		let flags = Array(UnsafeBufferPointer(start: eventFlags, count: eventsCount))
		let ids = Array(UnsafeBufferPointer(start: eventIDs, count: eventsCount))

		let pathsPointer = UnsafeRawPointer(eventPaths).assumingMemoryBound(
			to: UnsafePointer<CChar>.self)
		let pathsBuffer = UnsafeBufferPointer(start: pathsPointer, count: eventsCount)
		let eventURLs = pathsBuffer.map { URL(fileURLWithPath: String(cString: $0)) }

		tracked.respondTo(
			fsEvents: (0..<eventsCount).map { i in
				FSEvent(id: ids[i], flags: flags[i], url: eventURLs[i])
			}
		)
	}

	struct InitError: Error {
		let code: Int32
		var message: String
		var localizedDescription: String {
			message
		}
	}

	private(set) var path: URL
	private var fd: Int32

	private var root: NonLeafItem
	var items: [FileItem]? {
		if case .Available(let items) = root.children {
			return Array(items.values)
		}
		return nil
	}

	init(path: URL) throws {
		self.path = path.standardized
		self.root = NonLeafItem.init(path: path)

		self.fd = open(path.path, O_EVTONLY | O_RDONLY)
		if fd == -1 {
			let code = errno
			throw InitError(code: code, message: String(cString: strerror(code)))
		}

		// When we are notified that a file is deleted, we check whether its
		// parent exists in our tree. If it does, we invalidate (if
		// collapsed) or update (if parent is expanded) its `.children`
		// property without the item.

		// Moved or renamed files:
		//
		// The following applies if we hold a file descriptor for the moved or
		// renamed file:
		//
		//	We check whether the new and old parents (which may be the same)
		//	exist in our tree. If they do, we invalidate (if parent is collapsed)
		//	or update (if parent is expanded) the `.children` properties of each.
		//	We remove the item from the old parent or invalidate its `.children`.
		//	We keep a temporary copy of the old item's UUID, but delete its
		//	identity from the `identities` dictionary. Then, if the new parent is
		//	expanded, we add a new item to its `.children` initialize it with
		//	the old item's UUID. If the new parent is not expanded, we
		//	invalidate its `.children` and do not create any	new item or
		//	identity.
		//
		// Otherwise, we treat the event as a delete-create pair and the
		// continuity of the item's identity is broken.

		// "If you want to track the current location of a directory, it is best
		// to open the directory before creating the stream so that you have a
		// file descriptor for it and can issue an F_GETPATH fcntl() to find the
		// current path."
		// https://developer.apple.com/documentation/coreservices/1455376-fseventstreamcreateflags/kfseventstreamcreateflagwatchroot
		//
		// Open directory at BSD-level, keep file descriptor, recreate
		// FSEventStream with new path using fcntl()

		// No identity-tracking is attempted for folders, except the root.

		self.fsEventStream = FSEventStreamBox(
			info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
			callback: fsEventStreamCallback, pathsToWatch: [path])
	}

	deinit {
		close(self.fd)
	}

	private func respondTo(fsEvents: [FSEvent]) {
		for event in fsEvents {
			print("Received a file system event for", event.url.path)

			let baseComponents = path.pathComponents
			let targetComponents = event.url.standardized.pathComponents

			guard
				baseComponents.count <= targetComponents.count
					&& baseComponents.starts(with: baseComponents)
			else {
				print(
					"sumer: warning: skipped an event for", event.url.path,
					"because it couldn't be resolved relative to", path.path)
				continue
			}

			let remaining = targetComponents.dropFirst(baseComponents.count)

			if Int(event.flags) & kFSEventStreamEventFlagItemCreated != 0 {
				respondToCreated(components: remaining)
			} else if Int(event.flags) & kFSEventStreamEventFlagItemRemoved != 0 {
				print("item removed")
			} else if Int(event.flags) & kFSEventStreamEventFlagItemRenamed != 0 {
				print("item renamed")
			}

			print("(flags \(String(format: "%02x", event.flags)))")

			if Int(event.flags) & kFSEventStreamEventFlagRootChanged != 0 {
				print("!!!!!!! root changed; use fd")
			}
		}
	}

	private func respondToCreated<C: BidirectionalCollection>(components: C)
	where C.Element == String {
		var current = self.root

		for component in components.dropLast() {
			if case .Unavailable = current.latestChildren {
				// We should stop because we're not tracking this deep
				// into the tree.
				return
			}

			guard case .Available(var children) = current.latestChildren
			else {
				// we aren't responsible for errored-out
				// `ChildrenState`s —they get re-tried whenever
				// `.children` is accessed
				return
			}

			if children[component] == nil {
				children[component] = .NonLeaf(
					NonLeafItem(
						path: current.path.appending(component: component)))
			}
			let next = children[component]!

			if case .NonLeaf(let nextNonLeaf) = next {
				current = nextNonLeaf
			} else {
				// A file was created under a path where we thought
				// a file —and not a folder— existed.
				current.latestChildren =
					current.fetchChildren()
				// This makes me want to change my mind about this whole
				// approach :(
				//
				// It might be more robust to keep expansion state by filename
				// and not attempt these surgical changes. Honestly sounds like
				// a good idea
			}
		}
		if let last = components.last {

		}

		// When we are notified that a new file is added, we check whether
		// its parent exists in our tree.
		//
		// If it does, we invalidate (if
		// parent is collapsed) or update (if parent is expanded) its
		// `.children` property with the new item. Invalidating the `.children`
		// of a collapsed item  stops us from needlessly updating any state
		// deeper in the tree. When creating a new item, we generate a UUID
		// through the `FileItem` constructor.
		//
		// If it doesn't, we instead follow the same logic for the parent
		// directories of the new file: starting from the uppermost ones, we
		// ensure that each either exists in its parent or that its parent is
		// invalidated due to the change. The representation for the file itself
		// is never created, because the new file is hidden in the UI and is not
		// being tracked in this case.
	}

	enum FileItem: Identifiable {
		case Leaf(LeafItem)
		case NonLeaf(NonLeafItem)

		/// A unique identifier for the `FileItem`.
		var id: UUID {
			switch self {
			case .Leaf(let item):
				return item.id
			case .NonLeaf(let item):
				return item.id
			}
		}

		var path: URL {
			switch self {
			case .Leaf(let item):
				return item.path
			case .NonLeaf(let item):
				return item.path
			}
		}
	}

	@Observable class LeafItem: Identifiable {
		let id: UUID
		fileprivate(set) var path: URL

		convenience init(path: URL) {
			self.init(path: path, id: UUID())
		}
		init(path: URL, id: UUID) {
			self.path = path
			self.id = id
		}
	}

	@Observable class NonLeafItem: Identifiable {
		var isExpanded = false
		let id: UUID = UUID()
		fileprivate(set) var path: URL

		enum ChildrenState {
			/// The item is collapsed
			case Unavailable

			/// The wrapped `Dictionary` includes the `NonLeafItem`'s children,
			/// mapped by their path's final component (their name).
			case Available([String: FileItem])
			case Failed(Error)
		}

		fileprivate func fetchChildren() -> ChildrenState {
			let fm = FileManager.default
			do {
				let contents = try fm.contentsOfDirectory(
					at: path, includingPropertiesForKeys: [.isDirectoryKey])

				var childrenMap: [String: FileItem] = [:]
				for url in contents {
					let resourceValues = try url.resourceValues(forKeys: [
						.isDirectoryKey
					])
					let isDirectory = resourceValues.isDirectory ?? false

					if isDirectory {
						childrenMap[url.lastPathComponent] =
							FileItem.NonLeaf(
								NonLeafItem(
									path: url))
					} else {
						childrenMap[url.lastPathComponent] = FileItem.Leaf(
							LeafItem(
								path: url))
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

		/// The latest known state of the `NonLeafItem`'s children.
		///
		/// This property is accurate if available. It is always available while
		/// the item is expanded. If the item is not expanded, it may be
		/// unavailable until the item is expanded again.
		///
		/// **Details**
		///
		/// This property is `.Unavailable` until the item is expanded. While it
		/// is expanded, it is kept up to date.
		///
		/// It may also be available even if the item is collapsed, in which
		/// case the data is not stale. If a file system event that makes this
		/// property inaccurate occurs, the property is set back to
		/// `.Unavailable`.
		fileprivate var latestChildren: ChildrenState = .Unavailable

		init(path: URL) {
			self.path = path
		}
	}
}
