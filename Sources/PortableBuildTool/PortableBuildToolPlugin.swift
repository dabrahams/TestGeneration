import PackagePlugin
import Foundation

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

/// Defines functionality for all plugins having a `buildTool` capability.
public protocol PortableBuildToolPlugin: BuildToolPlugin {

    /// Invoked by SwiftPM to create build commands for a particular target.
    /// The context parameter contains information about the package and its
    /// dependencies, as well as other environmental inputs.
    ///
    /// This function should create and return build commands or prebuild
    /// commands, configured based on the information in the context. Note
    /// that it does not directly run those commands.
    func portableCommands(
      context: PackagePlugin.PluginContext,
      target: PackagePlugin.Target,
      invoker: String = #filePath
    ) async throws -> [Command]
}
