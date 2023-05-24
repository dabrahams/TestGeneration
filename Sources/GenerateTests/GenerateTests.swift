import Foundation

@main
struct GenerateTests {
    static func main() {
        do {
            guard CommandLine.argc > 2 else {
                throw NSError(domain: "com.example.GenerateTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Input and output file paths are required"])
            }
            
            let inputs = CommandLine.arguments.dropFirst().dropLast().map { URL(fileURLWithPath: $0) }
            let output = URL(fileURLWithPath: CommandLine.arguments.last!)

            let generatedSource = try generateTestSource(from: inputs)
            try writeTestSource(generatedSource, to: output)
        } catch {
            print("Error: \(error)")
        }
    }
    
    static func generateTestSource(from files: [URL]) throws -> String {
        var source =
        """
        import XCTest

        final class GeneratedTests: XCTestCase {

        """
        
        for file in files {
            let testName = file.deletingPathExtension().lastPathComponent
            source += """

                func test_\(testName)() throws {
                    XCTAssert(true, "\(testName)")
                }

            """
        }
        
        source += """
        }
        """
        
        return source
    }
    
    static func writeTestSource(_ source: String, to url: URL) throws {
        try source.write(to: url, atomically: true, encoding: .utf8)
    }
}
