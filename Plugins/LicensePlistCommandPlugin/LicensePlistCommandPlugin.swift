import Foundation
import PackagePlugin

@main
struct LicensePlistCommandPlugin: CommandPlugin {
    func performCommand(context: PackagePlugin.PluginContext, arguments: [String]) async throws {
        let tool = try context.tool(named: "license-plist")
        let toolURL = URL(fileURLWithPath: tool.path.string)

        let process = Process()
        process.executableURL = toolURL
        process.arguments = arguments

        try process.run()
        process.waitUntilExit()

        if process.terminationReason == .exit, process.terminationStatus == 0 {
            print("license-plist invocation finished.")
        } else {
            let problem = "\(process.terminationReason):\(process.terminationStatus)"
            Diagnostics.error("license-plist invocation failed: \(problem)")
        }
    }
}
