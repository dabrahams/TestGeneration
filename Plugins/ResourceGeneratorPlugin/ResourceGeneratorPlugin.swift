import PackagePlugin
import Foundation
#if os(Windows)
import WinSDK
#endif

#if os(Windows)
/// The name of the environment variable containing the executable search path.
fileprivate let pathEnvironmentVariable = "Path"
/// The separator between elements of the executable search path.
fileprivate let pathEnvironmentSeparator: Character = ";"
/// The file extension applied to binary executables
fileprivate let executableSuffix = ".exe"

/// A path component suffix used to guess at the right directory in
/// which to find Swift when compiling build tool plugin executables.
///
/// SwiftPM seems to put a descendant of the current Swift Toolchain
/// directory having this component suffix into the executable search
/// path when plugins are run.
fileprivate let pluginAPISuffix = ["lib", "swift", "pm", "PluginAPI"]

extension URL {

  /// Returns the URL given by removing all the elements of `suffix`
  /// from the tail of `pathComponents`, or` `nil` if `suffix` is not
  /// a suffix of `pathComponents`.
  func sansPathComponentSuffix<Suffix: BidirectionalCollection<String>>(_ suffix: Suffix)
    -> URL?
  {
    var r = self
    var remainingSuffix = suffix[...]
    while let x = remainingSuffix.popLast() {
      if r.lastPathComponent != x { return nil }
      r.deleteLastPathComponent()
    }
    return r
  }

}
#endif

// Workarounds for SPM's buggy `Path` type on Windows.
//
// SPM `PackagePlugin.Path` uses a representation that—if not
// repaired before used by a `BuildToolPlugin` on Windows—will cause
// files not to be found.
extension Path {

  /// A string representation appropriate to the platform
  private var platformString: String {
    #if os(Windows)
    string.withCString(encodedAs: UTF16.self) { pwszPath in
      // Allocate a buffer for the repaired UTF-16.
      let bufferSize = Int(GetFullPathNameW(pwszPath, 0, nil, nil))
      var buffer = Array<UTF16.CodeUnit>(repeating: 0, count: bufferSize)
      // Actually do the repair
      _ = GetFullPathNameW(pwszPath, DWORD(bufferSize), &buffer, nil)
      // Drop the zero terminator and convert back to a Swift string.
      return String(decoding: buffer.dropLast(), as: UTF16.self)
    }
    #else
    string
    #endif
  }

  /// A `URL` referring to the same location.
  fileprivate var url: URL { URL(fileURLWithPath: platformString) }
}

extension URL {

  /// A Swift Package Manager-compatible representation.
  var spmPath: Path { Path(self.path) }

}

@main
struct ResourceGeneratorPlugin: BuildToolPlugin {

  func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
    // Rather than trust operations on `PackagePlugin.Path`, we
    // immediately convert them to `URL`s and do all manipulations
    // through `URL`'s API, converting back to `Path`s at the last
    // possible moment.
    let inputs = (target as! SourceModuleTarget)
      .sourceFiles(withSuffix: ".in").map(\.path.url)

    if inputs.isEmpty { return [] }

    let workDirectory = context.pluginWorkDirectory.url
    let outputDirectory = workDirectory.appendingPathComponent("GeneratedResources")

    let outputs = inputs.map {
      outputDirectory.appendingPathComponent(
        $0.deletingPathExtension().appendingPathExtension("out").lastPathComponent
      )
    }

    #if os(Windows)
    // Instead of depending on the GenerateResoure tool, which causes
    // Link errors on Windows (See Package.swift), "manually" assemble
    // a build command that builds the GenerateResoure tool into the
    // plugin work directory and add it to the returned commands.

    // We have to know where the converter sources are relative to this package.
    let converterSource = context.package.directory.url
      .appendingPathComponent("Sources/GenerateResource/GenerateResource.swift")

    let converter = workDirectory.appendingPathComponent(
      "GenerateResource" + executableSuffix)

    //
    // Find an appropriate Swift executable with which to compile the converter.
    //
    var searchPath = ProcessInfo.processInfo.environment[pathEnvironmentVariable]!
      .split(separator: pathEnvironmentSeparator).map { URL(fileURLWithPath: String($0)) }

    // Attempt to prepend the path to the toolchain executables running this plugin
    if let p = searchPath.lazy.compactMap({ $0.sansPathComponentSuffix(pluginAPISuffix) }).first {
      searchPath = [ p.appendingPathComponent("bin") ] + searchPath
    }

    let swiftc = searchPath.lazy.map { $0.appendingPathComponent("swiftc" + executableSuffix) }
      .first { FileManager().isExecutableFile(atPath: $0.path) }!

    let buildConverter: [Command] = [
      Command.buildCommand(
        displayName: "Compiling converter",
        executable: swiftc.spmPath,
        arguments: [ converterSource.path, "-o", converter.path, "-parse-as-library"],
        inputFiles: [ converterSource.spmPath ],
        outputFiles: [ converter.spmPath ])]

    #else

    //  Building the tool will be taken care of automatically by SPM.
    let buildConverter: [Command] = []
    let converter = try context.tool(named: "GenerateResource").path.url

    #endif

    return buildConverter + [
      .buildCommand(
        displayName: "Running converter",
        executable: converter.spmPath,
        arguments: inputs.map(\.path) + [ outputDirectory.path ],
        inputFiles: inputs.map(\.spmPath) + [ converter.spmPath ],
        outputFiles: outputs.map(\.spmPath))
    ]
  }

}

