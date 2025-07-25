import Foundation
import Testing

@testable import Sumer

@Suite("Handles .children updates correctly")
struct ChildrenAssignment {
    @Test(".updateChildren() doesn't fail if item is a file")
    func initializeWithFile()
        throws
    {
        let fileURL = URL(fileURLWithPath: #filePath)
        let item = FileItem(root: fileURL)

        try item.updateChildren()
        #expect(item.children.count == 0)
    }

    @Test(".updateChildren() fails if the item does not exist")
    func initializeWithNonExistentItem() throws {
        let fm = FileManager.default
        let nonExistentURL = fm.temporaryDirectory.appending(
            component:
                UUID().uuidString)
        let item = FileItem(root: nonExistentURL)

        #expect(throws: FileItemError.NoEntry) {
            try item.updateChildren()
        }
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
        try item.updateChildren()

        #expect(item.children.count == 3)
        for (expected, found) in zip(filenames, item.children.map({ $0.name }).sorted()) {
            #expect(expected == found)
        }
        try FileManager.default.removeItem(at: tempDir)
    }

    @Test(
        ".updateChildren() fails if a nonexistent path inside an existing file is passed")
    func nonExistentInsideFile() throws {
        let nonExistent = URL(fileURLWithPath: #filePath).appending(component: "lorem")

        withKnownIssue {
            let item = FileItem(root: nonExistent)
            #expect(throws: FileItemError.NoEntry) {
                try item.updateChildren()
            }
        }
    }
}
