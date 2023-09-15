import PackagePlugin
import Foundation
#if os(Windows)
import WinSDK
#endif

@main
struct ResourceGeneratorPlugin: BuildToolPlugin {

  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    let inputs = (target as! SourceModuleTarget).sourceFiles(withSuffix: ".in").map {
      URL(fileURLWithPath: $0.path.fixedForWindows)
    }

    if inputs.isEmpty { return [] }

    let outputDirectory = URL(
      fileURLWithPath: context.pluginWorkDirectory.appending("GeneratedResources").fixedForWindows)

    let outputs = inputs.map {
      outputDirectory.appendingPathComponent(
        $0.deletingPathExtension().appendingPathExtension("out").lastPathComponent
      )
    }

    return [
      .buildCommand(
        displayName: "Processing",
        executable: try Path(context.tool(named: "GenerateResource").path.fixedForWindows),
        arguments: inputs.map { $0.path } + [ outputDirectory.path ],
        inputFiles: inputs.map { Path($0.path) },
        outputFiles: outputs.map { Path($0.path) }
      )]
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
    by converter: (LPCWSTR, DWORD, LPWSTR, UnsafeMutablePointer<LPWSTR>?) -> DWORD
  ) -> String {
    return self.withCString(encodedAs: UTF16.self) { pwszPath in
      let resultLengthPlusTerminator = converter(pwszPath, 0, nil, nil)
      return withUnsafeTemporaryAllocation(
        of: UTF16.CodeUnit.self, capacity: Int(resultLengthPlusTerminator)
      ) {
        _ = converter(pwszPath, DWORD($0.count), $0.baseAddress, nil)
        return String(decoding: $0.dropLast(), as: UTF16.self)
      }
    }
  }
}

extension Path {
  /// `self` with its internal representation repaired for Windows systems.
  var fixedForWindows: String {
    #if os(Windows)
    return string.utf16Converted(by: GetFullPathNameW)
    #else
    return self.string
    #endif
  }

}
