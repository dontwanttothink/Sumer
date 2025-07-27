observable directory

- unique identifier for each node that persists across moves and renames
    - only in memory; not for serialization
    - emit events when updates are necessary, with a diff
- for serialization, use bookmarks with URLs as fallbacks
