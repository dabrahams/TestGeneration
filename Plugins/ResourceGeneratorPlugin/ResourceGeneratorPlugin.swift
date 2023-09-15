import PackagePlugin
import Foundation
#if os(Windows)
import WinSDK
#endif

#if os(Windows)
fileprivate let pathEnvironmentVariable = "Path"
/// The separator between elements of the executable search path.
fileprivate let pathEnvironmentSeparator: Character = ";"
#else
fileprivate let pathEnvironmentVariable = "PATH"
fileprivate let pathEnvironmentSeparator: Character = ":"
#endif

///
fileprivate let pluginAPISuffix = ["lib", "swift", "pm", "PluginAPI"]

extension URL {
  /// Returns the URL given by removing the entire `suffix`, if
  /// present, from the tail of `self.pathComponents`; returns `nil`
  /// otherwise.
  func sansPathComponentSuffix<Suffix: BidirectionalCollection<String>>(_ suffix: Suffix) -> URL? {
    var r = self
    var remainingSuffix = suffix[...]
    while let x = remainingSuffix.popLast() {
      if r.lastPathComponent != x { return nil }
      r.deleteLastPathComponent()
    }
    return r
  }
}

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

    let script = URL(context.package.directory)
      .appendingPathComponent("Sources/GenerateResource/GenerateResource.swift")
    let executable = workDirectory.appendingPathComponent("GenerateResource.exe")

    var searchPath = ProcessInfo.processInfo.environment[pathEnvironmentVariable]!
      .split(separator: pathEnvironmentSeparator).map { URL(fileURLWithPath: String($0)) }

    // SwiftPM plugins seem to put this PluginAPI directory in the
    // path.  We prefer to find the swiftc from the same toolchain,
    // rather than whatever was first in the path, so prepend it to
    // searchPath.
    if let p = searchPath.lazy.compactMap({ $0.sansPathComponentSuffix(pluginAPISuffix) }).first {
      searchPath = [ p.appendingPathComponent("bin") ] + searchPath
    }

    let swiftc = searchPath.lazy.map { $0.appendingPathComponent("swiftc") }
      .first { FileManager().isExecutableFile(atPath: $0.path) }!

    return [
            
       .buildCommand(
        displayName: "Compiling script",
        executable: swiftc.spmPath,
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
    self.init(fileURLWithPath: path.string)
    #endif
  }

  var spmPath: Path { Path(self.path) } 

}
