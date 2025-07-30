import BridgedC
import SwiftUI

/// A `TrackedDirectory` connects a `ProjectView` to the file system.
@Observable class TrackedDirectory {

	final class FSEventStreamBox {
		private let stream: FSEventStreamRef
		private var context: UnsafeMutablePointer<FSEventStreamContext>

		private let callback: FSEventStreamCallback = {
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

			let flags = Array(
				UnsafeBufferPointer(start: eventFlags, count: eventsCount))
			let ids = Array(UnsafeBufferPointer(start: eventIDs, count: eventsCount))

			let pathsPointer = UnsafeRawPointer(eventPaths).assumingMemoryBound(
				to: UnsafePointer<CChar>.self)
			let pathsBuffer = UnsafeBufferPointer(
				start: pathsPointer, count: eventsCount)
			let eventURLs = pathsBuffer.map {
				URL(fileURLWithPath: String(cString: $0))
			}

			for i in (0..<eventsCount) {
				tracked.respondTo(
					event: FSEvent(
						id: ids[i], flags: flags[i], url: eventURLs[i]))

			}
		}

		init(
			info: UnsafeMutableRawPointer?,
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

	private var path: URL {
		self.root.path
	}
	private var root: FileItem
	private var fd: Int32

	var items: FileItem.Children.ChildrenState {
		guard case .NonLeaf(let children) = root.kind else {
			fatalError("The `TrackedDirectory`'s root is a leaf.")
		}
		return children.items
	}

	struct InitError: Error {
		let code: Int32
		var message: String
		var localizedDescription: String {
			message
		}
	}

	init(path: URL) throws {
		self.root = FileItem(path: path.standardized, isLeaf: false)

		self.fd = open(path.path, O_EVTONLY | O_RDONLY)
		if fd < 0 {
			let code = errno
			throw InitError(code: code, message: String(cString: strerror(code)))
		}

		self.fsEventStream = FSEventStreamBox(
			info: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
			pathsToWatch: [path]
		)
	}

	deinit {
		close(self.fd)
	}

	private func respondTo(event: FSEvent) {
		// MAYBE: Explore optimizations for very wide trees.

		if Int(event.flags) & kFSEventStreamEventFlagRootChanged != 0 {
			respondToRootChanged()
			return
		}

		print("sumer: debug: received a file system event for", event.url.path)

		let baseComponents = path.pathComponents
		let targetComponents = event.url.standardized.pathComponents

		guard
			baseComponents.count <= targetComponents.count
				&& targetComponents.starts(with: baseComponents)
		else {
			print(
				"sumer: debug warning: skipped an event for",
				event.url.path,
				"because it didn't look like it belonged to", path.path)
			return
		}

		let remaining = targetComponents.dropFirst(baseComponents.count)

		var current = self.root
		for component in remaining.dropLast() {
			guard case .NonLeaf(let children) = current.kind else {
				break
			}
			guard case .Available(let map) = children.items else {
				// we aren't responsible for errored-out
				// `ChildrenState`s —they get re-tried whenever
				// `.children` is accessed
				return
			}
			guard let next = map[component] else { return }
			current = next
		}

		let parent = current
		let parentChildren =
			{
				switch parent.kind {
				case .Leaf:
					let c = FileItem.Children(item: parent)
					parent.kind = .NonLeaf(c)
					return c
				case .NonLeaf(let c):
					return c
				}
			}()
		parentChildren.fetch()
	}

	private func respondToRootChanged() {
		let buffer = UnsafeMutableBufferPointer<CChar>.allocate(capacity: Int(PATH_MAX))
		defer { buffer.deallocate() }
		let rawPointer = UnsafeMutableRawPointer(buffer.baseAddress)

		let result = getpath_fcntl(fd, rawPointer)
		if result < 0 {
			fatalError("TODO: Handle this condition")
		}

		self.root.path = URL(fileURLWithPath: String(cString: buffer.baseAddress!))
		guard case .NonLeaf(let children) = self.root.kind else {
			fatalError("invariant unsatisfied")
		}
		children.fetch()
	}

	@Observable class FileItem: Identifiable {
		enum Kind {
			case Leaf
			case NonLeaf(Children)
		}

		/// The kind of `self`. You can use this property to access the children
		/// of a `FileItem.Kind.NonLeaf(Children)`.
		fileprivate(set) var kind: Kind = .Leaf

		let id: UUID = UUID()
		var path: URL

		init(path: URL, isLeaf: Bool) {
			self.path = path
			if !isLeaf {
				self.kind = .NonLeaf(Children(item: self))
			}
		}

		func move(to: URL, with trackedDir: TrackedDirectory) {}

		@Observable class Children {
			unowned let item: FileItem
			var areExpanded = false

			enum ChildrenState {
				case Failed(Error)
				/// The item is collapsed
				case Unavailable
				/// The wrapped `Dictionary` includes the `NonLeafItem`'s children,
				/// mapped by their path's final component (their name).
				case Available([String: FileItem])
			}

			// !!! TODO: Don't recreate existing children
			fileprivate func fetch() {
				var out: ChildrenState

				let fm = FileManager.default
				do {
					let contents = try fm.contentsOfDirectory(
						at: item.path,
						includingPropertiesForKeys: [.isDirectoryKey]
					)

					var childrenMap: [String: FileItem] = [:]
					for url in contents {
						let resourceValues = try url.resourceValues(
							forKeys: [
								.isDirectoryKey
							])
						let isDirectory =
							resourceValues.isDirectory ?? false

						if isDirectory {
							childrenMap[url.lastPathComponent] =
								FileItem(path: url, isLeaf: false)
						} else {
							childrenMap[url.lastPathComponent] =
								FileItem(
									path: url, isLeaf: true)
						}
					}

					out = .Available(childrenMap)
				} catch {
					out = .Failed(error)
				}

				latestChildren = out
			}

			/// If available, provides access to a collection of `FileItem`s
			/// representing the children. The items will not be available
			/// unless `areExpanded` is set to `true`.
			var items: ChildrenState {
				if !areExpanded {
					return .Unavailable
				}

				if case .Available = latestChildren {
					return latestChildren
				}
				fetch()
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

			init(item: FileItem) {
				self.item = item
			}
		}
	}
}
