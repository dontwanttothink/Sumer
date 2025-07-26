import Foundation
import Testing

@testable import Sumer

@Suite("Handles .children updates correctly")
struct ChildrenAssignment {
    @Test(
        "`.children` is set to FileItem.ChildrenState.NotSupported if the FileItem represents a file"
    )
    func initializeWithFile()
        throws
    {
        let fileURL = URL(fileURLWithPath: #filePath)
        let item = FileItem(root: fileURL)
        #expect(
            {
                guard case .NotSupported = item.children else { return false }
                return true
            }())
    }

    @Test(".updateChildren() fails if the item does not exist")
    func initializeWithNonExistentItem() {
        let fm = FileManager.default
        let nonExistentURL = fm.temporaryDirectory.appending(
            component:
                UUID().uuidString)
        let item = FileItem(root: nonExistentURL)
        #expect(
            {
                if case .Failed(FileItemError.NoEntry) = item.children {
                    return true
                }
                return false
            }())
    }

    @Test(".updateChildren() sets .children correctly") func initializeWithDirectory()
        throws
    {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appending(
            component:
                UUID().uuidString)
        try fm.createDirectory(
            at: tempDir, withIntermediateDirectories: true, attributes: nil)

        let filenames = ["file1.txt", "file2.txt", "file3.txt"]
        for filename in filenames {
            let fileURL = tempDir.appendingPathComponent(filename)

            let contents = Data()
            try contents.write(to: fileURL)
        }

        let item = FileItem(root: tempDir)

        guard case .Supported(let childItems) = item.children else {
            #expect(Bool(false))
            return
        }

        for (expected, provided) in zip(childItems.map { $0.name }.sorted(), filenames) {
            #expect(expected == provided)
        }

        try fm.removeItem(at: tempDir)
    }

    @Test(
        ".updateChildren() fails if a nonexistent path inside an existing file is passed")
    func nonExistentInsideFile() throws {
        let nonExistent = URL(fileURLWithPath: #filePath).appending(component: "lorem")

        withKnownIssue {
            let item = FileItem(root: nonExistent)
            #expect(
                {
                    if case .Failed = item.children {
                        return true
                    }
                    return false
                }())
        }
    }
}
