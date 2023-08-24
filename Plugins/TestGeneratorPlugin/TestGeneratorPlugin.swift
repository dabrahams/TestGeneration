import PackagePlugin
#if os(Windows)
import WinSDK
#endif

@main
struct TestGeneratorPlugin: BuildToolPlugin {

  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    guard let target = target as? SourceModuleTarget else { return [] }
    let inputPaths = target.sourceFiles(withSuffix: "testgen").map(\.path.fixedForWindows)
    let outputPath = context.pluginWorkDirectory.appending("GeneratedTests.swift").fixedForWindows

    let cmd: Command = .buildCommand(
        displayName: "Generating XCTestCases for \(inputPaths.map(\.stem)) into \(outputPath)",
        executable: try context.tool(named: "GenerateTests").path,
        arguments: inputPaths + [ outputPath ],
        inputFiles: inputPaths,
        outputFiles: [ outputPath ]
    )
    return [cmd]
  }

}

typealias DWORD = UInt32
typealias LPCWSTR = UnsafePointer<UTF16.CodeUnit>?
typealias LPWSTR = UnsafeMutablePointer<UTF16.CodeUnit>?

extension String {
  /// Applies `converter` to the UTF-16 representation and returns the
  /// result, where converter has the signature and general semantics
  /// of Windows'
  /// [`GetFullPathNameW`](https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getfullpathnamew).
  func utf16Converted(
    by converter: (LPCWSTR, DWORD, LPWSTR, UnsafeMutablePointer<LPWSTR?>?) -> DWORD
  ) -> String {
    return self.withCString(encodedAs: UTF16.self) { pwszPath in
      let resultLength = converter(pwszPath, 0, nil, nil)
      return withUnsafeTemporaryAllocation(
        of: UTF16.CodeUnit.self, capacity: Int(resultLength)
      ) {
        _ = converter(pwszPath, DWORD($0.count), $0.baseAddress, nil)
        return String(decoding: $0, as: UTF16.self)
      }
    }
  }
}

extension Path {
  /// `self` with its internal representation repaired for Windows systems.
  var fixedForWindows: Path {
    #if os(Windows)
    return Self(string.utf16Converted(by: GetFullPathNameW))
    #else
    return self
    #endif
  }
}
