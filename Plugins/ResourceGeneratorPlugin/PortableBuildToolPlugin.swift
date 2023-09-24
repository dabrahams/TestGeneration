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

extension PackagePlugin.Target {

  /// The source files.
  var allSourceFiles: [URL] {
    return (self as? PackagePlugin.SourceModuleTarget)?.sourceFiles(withSuffix: "").map(\.path.url) ?? []
  }

}

extension PackagePlugin.Package {

  /// The source files in this package on which the given executable depends.
  func sourceDependencies(ofProductNamed productName: String) throws -> Set<URL> {
    var result: Set<URL> = []
    let p = products.first { $0.name == productName }!
    var visitedTargets = Set<PackagePlugin.Target.ID>()

    for t0 in p.targets {
      if visitedTargets.insert(t0.id).inserted {
        result.formUnion(t0.allSourceFiles)
      }

      for t1 in t0.recursiveTargetDependencies {
        if visitedTargets.insert(t1.id).inserted {
          result.formUnion(t1.allSourceFiles)
        }
      }
    }
    return result
  }

}
#endif

// Workarounds for SPM's buggy `Path` type on Windows.
//
// SPM `PackagePlugin.Path` uses a representation that—if not repaired before used by a
// `BuildToolPlugin` on Windows—will cause files not to be found.
extension Path {

  /// A string representation appropriate to the platform.
  var portableString: String {
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
  var url: URL { URL(fileURLWithPath: portableString) }

  /// A representation of `Self` that works on all platforms.
  var repaired: Self {
    #if os(Windows)
    Path(self.portableString)
    #else
    self
    #endif
  }
}

extension URL {

  /// A Swift Package Manager-compatible representation.
  var spmPath: Path { Path(self.path) }

}

/// Defines functionality for all plugins having a `buildTool` capability.
protocol PortableBuildToolPlugin: BuildToolPlugin {

  /// Returns the build commands for `target` in `context`.
  func portableBuildCommands(
    context: PackagePlugin.PluginContext,
    target: PackagePlugin.Target
  ) async throws -> [PortableBuildCommand]

}

extension PortableBuildToolPlugin {

  func createBuildCommands(context: PluginContext, target: Target) async throws
    -> [PackagePlugin.Command]
  {

    /// Guess at files that constitute this plugin, the changing of which should cause outputs to be
    /// regenerated (workaround for https://github.com/apple/swift-package-manager/issues/6936).
    let pluginSources = try FileManager()
      .subpathsOfDirectory(atPath: URL(fileURLWithPath: #filePath).deletingLastPathComponent().path)
      .map(URL.init(fileURLWithPath:))
      .filter { !$0.hasDirectoryPath }

    return try await portableBuildCommands(context: context, target: target).map {
      $0.spmCommand(context: context, pluginSources: pluginSources)
    }

  }

}

extension PackagePlugin.Context {
  struct ProductInvocation {
    let executable: PackagePlugin.Path
    let argumentPrefix: [String]
    let additionalSources: [URL]
  }

  func invocation(ofExecutableProduct productName: String) -> ProductInvocation {
    #if os(Windows)
    // Instead of depending on context.tool(named:), which demands a declared dependency on the
    // tool, which causes link errors on Windows
    // (https://github.com/apple/swift-package-manager/issues/6859#issuecomment-1720371716),
    // Invoke swift reentrantly to run the GenerateResoure tool.

    //
    // If a likely candidate for the current toolchain can be found in the `Path`, prepend its
    // `bin/` dfirectory.
    //
    var searchPath = ProcessInfo.processInfo.environment[pathEnvironmentVariable]!
      .split(separator: pathEnvironmentSeparator).map { URL(fileURLWithPath: String($0)) }

    // SwiftPM seems to put a descendant of the currently-running Swift Toolchain/ directory having
    // this component suffix into the executable search path when plugins are run.
    fileprivate let pluginAPISuffix = ["lib", "swift", "pm", "PluginAPI"]

    if let p = searchPath.lazy.compactMap({ $0.sansPathComponentSuffix(pluginAPISuffix) }).first {
      searchPath = [ p.appendingPathComponent("bin") ] + searchPath
    }

    // Try searchPath first, then fall back to SPM's `tool(named:)`
    let swift = try searchPath.lazy.map { $0.appendingPathComponent("swift" + executableSuffix) }
      .first { FileManager().isExecutableFile(atPath: $0.path) }
      ?? context.tool(named: "swift").path.url

    let scratchPath = FileManager().temporaryDirectory
      .appendingPathComponent(UUID().uuidString).path

    return .init(
      executable: swift, argumentPrefix: [
          "run",
          // Only Macs currently use sandboxing, but nested sandboxes are prohibited, so for future
          // resilience in case Windows gets a sandbox, disable it on these reentrant builds.
          //
          // Currently if we run this code on a Mac, disabling the sandbox on this inner build is
          // enough to allow us to write on the scratchPath, which is outside any _outer_ sandbox.
          // I think that's an SPM bug. If they fix it, we'll need to nest scratchPath in
          // context.workDirectory and add an explicit build step to delete it to keep its contents
          // from being incorporated into the resources of the target we're building.
          "--disable-sandbox",
          "--scratch-path", scratchPath,
          "--package-path", context.package.directory.url.path,
          productName ],
      additionalSources: context.package.sourceDependencies(ofProductNamed: productName))

    #else
    return .init(
      executable: context.tool(named: productName), argumentPrefix: [], additionalSources: [])
    #endif
  }
}

extension PortableBuildCommand {

  /// Returns a representation of `self` for the result of a `BuildToolPlugin.createBuildCommands`
  /// invocation with the given `context` parameter.
  func spmCommand(
    context: PackagePlugin.PluginContext, pluginSources: [URL]
  ) -> PackagePlugin.Command {

    let spmPluginSources = pluginSources.lazy.map(\.spmPath)

    switch self {
    case .buildCommand_(
           displayName: let displayName,
           preInstalledExecutable: let preInstalledExecutable,
           arguments: let arguments,
           environment: let environment,
           inputFiles: let inputFiles,
           outputFiles: let outputFiles):

      return .buildCommand(
        displayName: displayName,
        executable: preInstalledExecutable.repaired,
        arguments: arguments,
        inputFiles: inputFiles.map(\.repaired) + spmPluginSources,
        outputFiles: outputFiles.map(\.repaired))

    case .buildCommand(
           displayName: let displayName,
           executableProductName: let executableProductName,
           arguments: let arguments,
           environment: let environment,
           inputFiles: let inputFiles,
           outputFiles: let outputFiles):

      let i = context.invocation(ofProductNamed: executableProductName)
      return Self.buildCommand_(
        displayName: displayName, preInstalledExecutable: i.executable,
        arguments: i.argumentPrefix + arguments,
        environment: environment,
        inputFiles: inputFiles

      )

      return .buildCommand(
        displayName: displayName,
        executable: executablePath,
        arguments: arguments,
        inputFiles: inputFiles.map(\.repaired) + pluginSources.map(\.spmPath),
        outputFiles: outputFiles.map(\.repaired))

    case .prebuildCommand_(
           displayName: let displayName,
           preInstalledExecutable: let preInstalledExecutable,
           arguments: let arguments,
           environment: let environment,
           outputFilesDirectory: let outputFilesDirectory):
      fatalError()

    case .prebuildCommand(
           displayName: let displayName,
           executableProductName: let executableProductName,
           arguments: let arguments,
           environment: let environment,
           outputFilesDirectory: let outputFilesDirectory):
      fatalError()
    }
  }

}


/// A command to run during the build.
public enum PortableBuildCommand {

  /// A command that runs when any of its ouput files are needed by
  /// the build, but out-of-date.
  ///
  /// An output file is out-of-date if it doesn't exist, or if any
  /// input files have changed since the command was last run.
  ///
  /// - Note: the paths in the list of output files may depend on the list of
  ///   input file paths, but **must not** depend on reading the contents of
  ///   any input files. Such cases must be handled using a `prebuildCommand`.
  ///
  /// - Parameters:
  ///   - displayName: An optional string to show in build logs and other
  ///     status areas.
  ///   - preInstalledExecutable: The absolute path to the executable to be
  ///     invoked, which should be outside the build directory of the package
  ///     being built.
  ///   - arguments: Command-line arguments to be passed to the executable.
  ///   - environment: Environment variable assignments visible to the
  ///     executable.
  ///   - inputFiles: Files on which the contents of output files may depend.
  ///     Any paths passed as `arguments` should typically be passed here as
  ///     well.
  ///   - outputFiles: Files to be generated or updated by the executable.
  ///     Any files recognizable by their extension as source files
  ///     (e.g. `.swift`) are compiled into the target for which this command
  ///     was generated as if in its source directory; other files are treated
  ///     as resources as if explicitly listed in `Package.swift` using
  ///     `.process(...)`.
  case buildCommand_(
        displayName: String?,
        preInstalledExecutable: Path,
        arguments: [String],
        environment: [String: String] = [:],
        inputFiles: [Path] = [],
        outputFiles: [Path] = [])

  /// A command that runs when any of its ouput files are needed by
  /// the build, but out-of-date.
  ///
  /// An output file is out-of-date if it doesn't exist, or if any
  /// input files have changed since the command was last run.
  ///
  /// - Note: the paths in the list of output files may depend on the list of
  ///   input file paths, but **must not** depend on reading the contents of
  ///   any input files. Such cases must be handled using a `prebuildCommand`.
  ///
  /// - Parameters:
  ///   - displayName: An optional string to show in build logs and other
  ///     status areas.
  ///   - executableProductName: The name of the executable product to be
  ///     invoked.
  ///   - arguments: Command-line arguments to be passed to the executable.
  ///   - environment: Environment variable assignments visible to the
  ///     executable.
  ///   - inputFiles: Files on which the contents of output files may depend.
  ///     Any paths passed as `arguments` should typically be passed here as
  ///     well.
  ///   - outputFiles: Files to be generated or updated by the executable.
  ///     Any files recognizable by their extension as source files
  ///     (e.g. `.swift`) are compiled into the target for which this command
  ///     was generated as if in its source directory; other files are treated
  ///     as resources as if explicitly listed in `Package.swift` using
  ///     `.process(...)`.
  case buildCommand(
        displayName: String?,
        executableProductName: String,
        arguments: [String],
        environment: [String: String] = [:],
        inputFiles: [Path] = [],
        outputFiles: [Path] = [])

  /// A command that runs unconditionally before every build.
  ///
  /// Prebuild commands can have a significant performance impact
  /// and should only be used when there would be no way to know the
  /// list of output file paths without first reading the contents
  /// of one or more input files. Typically there is no way to
  /// determine this list without first running the command, so
  /// instead of encoding that list, the caller supplies an
  /// `outputFilesDirectory` parameter, and all files in that
  /// directory after the command runs are treated as output files.
  ///
  /// - Parameters:
  ///   - displayName: An optional string to show in build logs and other
  ///     status areas.
  ///   - executable: The absolute path to the executable to be
  ///     invoked, which should be outside the build directory of the
  ///     package being built.
  ///   - arguments: Command-line arguments to be passed to the executable.
  ///   - environment: Environment variable assignments visible to the executable.
  ///   - workingDirectory: Optional initial working directory when the executable
  ///     runs.
  ///   - outputFilesDirectory: A directory into which the command writes its
  ///     output files.  Any files there recognizable by their extension as
  ///     source files (e.g. `.swift`) are compiled into the target for which
  ///     this command was generated as if in its source directory; other
  ///     files are treated as resources as if explicitly listed in
  ///     `Package.swift` using `.process(...)`.
  case prebuildCommand_(
         displayName: String?,
         preInstalledExecutable: Path,
         arguments: [String],
         environment: [String: String] = [:],
         outputFilesDirectory: Path)

  /// A command that runs unconditionally before every build.
  ///
  /// Prebuild commands can have a significant performance impact
  /// and should only be used when there would be no way to know the
  /// list of output file paths without first reading the contents
  /// of one or more input files. Typically there is no way to
  /// determine this list without first running the command, so
  /// instead of encoding that list, the caller supplies an
  /// `outputFilesDirectory` parameter, and all files in that
  /// directory after the command runs are treated as output files.
  ///
  /// - Parameters:
  ///   - displayName: An optional string to show in build logs and other
  ///     status areas.
  ///   - executableProductName: The name of the executable product to be
  ///     invoked.
  ///   - arguments: Command-line arguments to be passed to the executable.
  ///   - environment: Environment variable assignments visible to the executable.
  ///   - workingDirectory: Optional initial working directory when the executable
  ///     runs.
  ///   - outputFilesDirectory: A directory into which the command writes its
  ///     output files.  Any files there recognizable by their extension as
  ///     source files (e.g. `.swift`) are compiled into the target for which
  ///     this command was generated as if in its source directory; other
  ///     files are treated as resources as if explicitly listed in
  ///     `Package.swift` using `.process(...)`.
  case prebuildCommand(
         displayName: String?,
         executableProductName: String,
         arguments: [String],
         environment: [String: String] = [:],
         outputFilesDirectory: Path)

}
