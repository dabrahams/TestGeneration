import PackagePlugin
import Foundation
#if os(Windows)
import WinSDK
#endif

@main
struct ResourceGeneratorPlugin: BuildToolPlugin {

  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    let inputs = (target as! SourceModuleTarget).sourceFiles(withSuffix: ".in").map {
      URL($0.path)
    }

    if inputs.isEmpty { return [] }

    let workDirectory = URL(context.pluginWorkDirectory)
    let outputDirectory = workDirectory.appendingPathComponent("GeneratedResources")

    let outputs = inputs.map {
      outputDirectory.appendingPathComponent(
        $0.deletingPathExtension().appendingPathExtension("out").lastPathComponent
      )
    }

    let script = URL(context.package.directory).appendingPathComponent("Sources/GenerateResource/GenerateResource.swift")
    let executable = workDirectory.appendingPathComponent("GenerateResource.exe")

    return [
            
       .buildCommand(
        displayName: "Compiling script",
        executable: Path(#"C:\Program Files\Swift\Toolchains\0.0.0+Asserts\usr\bin\swiftc.exe"#),
        arguments: [ script.path, "-o", executable.path, "-parse-as-library"],
        inputFiles: [ script.spmPath ],
        outputFiles: [ executable.spmPath ]),

       .buildCommand(
        displayName: "Running script",
        executable: executable.spmPath,
        arguments: inputs.map(\.path) + [ outputDirectory.path ],
        inputFiles: inputs.map(\.spmPath) + [ executable.spmPath ],
        outputFiles: outputs.map(\.spmPath)),
    ]

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

extension URL {

  init(_ path: Path) {
    #if os(Windows)
    self.init(fileURLWithPath: path.string.utf16Converted(by: GetFullPathNameW))
    #else
    return self.init(fileURLWithPath: path.string)
    #endif
  }

  var spmPath: Path { Path(self.path) } 

}
