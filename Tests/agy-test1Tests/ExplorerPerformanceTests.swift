import XCTest
import Foundation
@testable import agy_test1

final class ExplorerPerformanceTests: XCTestCase {
    
    var tempDirectory: URL!
    var largeTextFile: URL!
    var largeImageFile: URL!
    
    override func setUpWithError() throws {
        super.setUp()
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // 1. Create a large text file (~1.5MB)
        largeTextFile = tempDirectory.appendingPathComponent("perf_test_large.txt")
        let textPiece = "Agy Finder UI speed performance test. "
        let largeContent = String(repeating: textPiece, count: 50_000)
        try largeContent.write(to: largeTextFile, atomically: true, encoding: .utf8)
        
        // 2. Create a mock large image file (~5MB of random bytes saved with .jpg extension)
        largeImageFile = tempDirectory.appendingPathComponent("perf_test_large_image.jpg")
        let randomData = Data((0..<5_000_000).map { _ in UInt8.random(in: 0...255) })
        try randomData.write(to: largeImageFile)
    }
    
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }
    
    @MainActor
    func testFileSelectionModelPerformance() throws {
        let model = FileManagerModel(startDirectory: tempDirectory)
        let item1 = FileItem(url: largeTextFile)
        let item2 = FileItem(url: largeImageFile)
        
        // The selection state update in the model must be extremely fast
        // because it no longer triggers synchronous preview loading.
        measure {
            for _ in 0..<100 {
                model.selectedItem = item1
                model.selectedItem = item2
            }
        }
    }
    
    func testAsyncTextPreviewSpeed() async throws {
        // Measure the time to fetch the preview content asynchronously in a detached task
        let url = largeTextFile!
        
        let measurement = try await Task.detached(priority: .userInitiated) { () -> TimeInterval in
            let start = Date()
            
            // This replicates the ContentPreviewView async task body
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            let previewSize = min(data.count, 8 * 1024)
            let subdata = data.subdata(in: 0..<previewSize)
            let text = String(data: subdata, encoding: .utf8)
            XCTAssertNotNil(text)
            
            return Date().timeIntervalSince(start)
        }.value
        
        // Reading only 8KB chunk should be extremely fast (< 50ms)
        XCTAssertLessThan(measurement, 0.05, "Async text preview extraction took too long: \(measurement)s")
    }
}
