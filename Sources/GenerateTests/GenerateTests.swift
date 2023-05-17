import Foundation

@main
struct GenerateTests {
  static func main() throws {

    let inputs = CommandLine.arguments.dropFirst().dropLast()
      .lazy.map(URL.init(fileURLWithPath:))

    let output = URL(fileURLWithPath: CommandLine.arguments.last!)

    var generatedSource =
      """
      import XCTest

      final class GeneratedTests: XCTestCase {

      """

    for f in inputs {
      let testName = f.deletingPathExtension().lastPathComponent

      generatedSource += """

          func test_\(testName)() {
            XCTAssert(true, \(String(reflecting: testName)))
          }

        """
    }

    generatedSource += """
      }
      """

    try generatedSource.write(to: output, atomically: true, encoding: .utf8)
  }
}
