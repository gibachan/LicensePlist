import Foundation
import PackagePlugin

@main
struct GenerateAcknowledgementsCommand: CommandPlugin {
    func performCommand(context: PluginContext, arguments externalArgs: [String]) async throws {
        let licensePlist = try context.tool(named: "license-plist")
        do {
            try licensePlist.run(arguments: externalArgs)
        } catch let error as RunError {
            Diagnostics.error(error.description)
        }
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension GenerateAcknowledgementsCommand: XcodeCommandPlugin {
    func performCommand(context: XcodePluginContext, arguments externalArgs: [String]) throws {        
        let licensePlist = try context.tool(named: "license-plist")
        let arguments = arguments(context: context, externalArgs: externalArgs)
        do {
            try licensePlist.run(arguments: arguments)
        } catch let error as RunError {
            Diagnostics.error(error.description)
        }
    }
    
    private func arguments(context: XcodePluginContext, externalArgs: [String]) -> [String] {
        var arguments = ["--sandbox-mode"]
        arguments += ["--package-sources-path", packageSourcesPath(context: context)]
        arguments += externalArgs.removing(arguments: ["--target", "--swift-package-sources-path", "--package-sources-path"])
        return arguments
    }
    
    // Returns default folder with checked out package sources
    private func packageSourcesPath(context: XcodePluginContext) -> String {
        return context.pluginWorkDirectory
            .removingLastComponent()
            .removingLastComponent()
            .string
    }
}
#endif

private extension Array where Element == String {    
    /// Filter out specified argument with its value.
    /// - Parameter skippedArgumentNames: names of the arguments, for example `["--target"]`.
    /// - Returns: array of arguments.
    ///
    /// The method assumes that the specified argument precedes its value.
    func removing(arguments skippedArgumentNames: [String]) -> [String] {
        var argumentIndex = 0
        var resultArguments = [String]()
        while argumentIndex < count {
            let currentArgumentName = self[argumentIndex]
            if skippedArgumentNames.contains(currentArgumentName) {
                argumentIndex += 2
            } else {
                resultArguments.append(currentArgumentName)
                argumentIndex += 1
            }
        }
        return resultArguments
    }
}

private struct RunError: Error {
    let description: String
}

private extension PluginContext.Tool {
    func run(arguments: [String]) throws {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path.string)
        process.arguments = arguments
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationReason == .exit && process.terminationStatus == 0 {
            return
        }

        let data = try pipe.fileHandleForReading.readToEnd()
        let stderr = data.flatMap { String(data: $0, encoding: .utf8) }

        if let stderr {
            throw RunError(description: stderr)
        } else {
            let problem = "\(process.terminationReason.rawValue):\(process.terminationStatus)"
            throw RunError(description: "\(name) invocation failed: \(problem)")
        }
    }
}
