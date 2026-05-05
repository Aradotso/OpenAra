import AppKit
import Darwin
import Foundation
import OpenAraKit

@main
enum OpenAraMain {
    @MainActor
    static func main() {
        do {
            try run()
        } catch let error as OpenAraCLIError {
            writeToStandardError(error.errorDescription ?? error.message)
            exit(EXIT_FAILURE)
        } catch let error as ComputerUseError {
            writeToStandardError(error.errorDescription ?? String(describing: error))
            exit(EXIT_FAILURE)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            writeToStandardError(message)
            exit(EXIT_FAILURE)
        }
    }

    @MainActor
    private static func run() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let command = try parseOpenAraCLI(arguments: arguments)

        switch command {
        case .mcp:
            let service = ComputerUseService()
            let server = StdioMCPServer(service: service)
            if VisualCursorSupport.isEnabled {
                try MainActor.assumeIsolated {
                    try MCPAppRuntime.run(server: server)
                }
            } else {
                try server.run()
            }
        case .doctor:
            let permissions = PermissionDiagnostics.current()
            print(permissions.summary)
            print("")
            print("Source breakdown:")
            print("  accessibility from TCC.db lookup:        \(formatTriState(permissions.rawAccessibilityFromTCC))")
            print("  accessibility from AXIsProcessTrusted(): \(formatTriState(permissions.rawAccessibilityFromSystemAPI))")
            print("  screenRecording from TCC.db lookup:      \(formatTriState(permissions.rawScreenCaptureFromTCC))")
            print("  screenRecording from CGPreflight*():     \(formatTriState(permissions.rawScreenCaptureFromSystemAPI))")
            print("")
            print("TCC client records being checked (revoke these in System Settings if you want to re-trigger onboarding):")
            for client in PermissionSupport.currentPermissionClients() {
                let kind = client.type == 0 ? "bundle-id" : "path"
                print("  [\(kind)] \(client.identifier)")
            }
            if !permissions.missingPermissions.isEmpty {
                PermissionOnboardingApp.launch()
            }
        case .listApps:
            let service = ComputerUseService()
            print(service.listApps().primaryText ?? "")
        case let .snapshot(app):
            let service = ComputerUseService()
            print(try service.getAppState(app: app).primaryText ?? "")
        case let .call(invocation):
            if VisualCursorSupport.isEnabled {
                _ = NSApplication.shared.setActivationPolicy(.accessory)
            }
            let output = try runOpenAraCall(invocation)
            print(try output.jsonText())
            if output.hasToolError {
                exit(EXIT_FAILURE)
            }
        case .turnEnded:
            postOpenAraTurnEndedNotification()
            print("turn-ended acknowledged")
        case let .help(command):
            print(openAraHelpText(command: command))
        case .version:
            print(resolvedOpenAraVersion())
        case .launchOnboarding:
            let permissions = PermissionDiagnostics.current()
            let forceOnboarding = ProcessInfo.processInfo.environment["OPENARA_FORCE_ONBOARDING"] == "1"
            if forceOnboarding || !permissions.allGranted {
                PermissionOnboardingApp.launch()
            } else {
                print("""
                OpenAra \(resolvedOpenAraVersion()) — macOS Computer Use MCP server.

                \(permissions.summary)

                You're all set. Next steps:
                  openara install-claude-mcp     # wire into Claude Code
                  openara install-codex-mcp      # wire into Codex CLI
                  openara install-codex-plugin   # install as Codex App plugin
                  openara install-gemini-mcp     # wire into Gemini CLI
                  openara install-opencode-mcp   # wire into OpenCode

                Or run the server directly:
                  openara mcp                    # stdio MCP server
                  openara call list_apps         # smoke-test a single tool
                  openara -h                     # full help
                """)
            }
        }
    }

    private static func writeToStandardError(_ message: String) {
        OpenAraLogger.error(message, category: "cli")
    }

    private static func formatTriState(_ value: Bool?) -> String {
        switch value {
        case .none: return "n/a (TCC.db unreadable — likely no Full Disk Access)"
        case .some(true): return "true"
        case .some(false): return "false"
        }
    }
}
