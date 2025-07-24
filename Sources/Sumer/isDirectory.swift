import Foundation

extension URL {
    var isDirectory: Bool {
        get throws {
            try resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        }
    }
}
