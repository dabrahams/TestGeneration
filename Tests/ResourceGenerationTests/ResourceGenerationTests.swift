import XCTest
import LibWithResource
import Foundation

final class ResourceGenerationTests: XCTestCase {

  func testIt() throws {
    guard let _ = resourceBundle.url(forResource: "Test1.in", withExtension: nil) else {
      XCTFail("Test1.in not found.")
      return
    }

    guard let _ = resourceBundle.url(forResource: "Test2.in", withExtension: nil) else {
      XCTFail("Test2.in not found.")
      return
    }
  }
}
