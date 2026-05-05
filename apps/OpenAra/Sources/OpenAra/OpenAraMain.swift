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
        case .uninstall:
            try runUninstall()
        case .update:
            try runUpdate()
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

    @MainActor
    private static func runUninstall() throws {
        let installedApp = "/Applications/OpenAra.app"

        if FileManager.default.fileExists(atPath: installedApp) {
            do {
                try FileManager.default.removeItem(atPath: installedApp)
                print("Removed \(installedApp).")
            } catch {
                print("Could not remove \(installedApp): \(error.localizedDescription)")
                print("Try: sudo rm -rf '\(installedApp)'")
            }
        } else {
            print("/Applications/OpenAra.app is not present (nothing to remove).")
        }

        let tccutilResult = runProcess("/usr/bin/tccutil", arguments: ["reset", "All", "so.ara.openara"])
        if tccutilResult == 0 {
            print("Reset bundle-id TCC entries for so.ara.openara.")
        } else {
            print("tccutil reset returned non-zero (\(tccutilResult)). Some bundle-id entries may not have been cleared.")
        }

        print("""

        OpenAra macOS-side cleanup complete. Path-based TCC grants (e.g., from
        old /Users/.../OpenAra.app or node_modules locations) can't be cleared
        from the CLI — open System Settings → Privacy & Security → Accessibility
        and Screen & System Audio Recording, click each OpenAra row and hit "−".

        To finish removing the npm package itself:
          npm uninstall -g @openara/cli

        To reinstall fresh:
          npm i -g @openara/cli && openara
        """)
    }

    @MainActor
    private static func runUpdate() throws {
        print("Updating to the latest @openara/cli from npm…")
        let status = runProcess("/usr/bin/env", arguments: ["npm", "install", "-g", "@openara/cli@latest"], inheritStandardIO: true)
        if status == 0 {
            print("")
            print("Update complete. Run `openara --version` to confirm, or `openara` for the welcome screen.")
        } else {
            print("")
            print("npm install -g @openara/cli@latest exited with status \(status).")
            print("If npm needs sudo on your setup, try: sudo npm install -g @openara/cli@latest")
        }
    }

    @discardableResult
    private static func runProcess(_ launchPath: String, arguments: [String], inheritStandardIO: Bool = false) -> Int32 {
        let process = Process()
        process.launchPath = launchPath
        process.arguments = arguments
        if !inheritStandardIO {
            process.standardOutput = Pipe()
            process.standardError = Pipe()
        }
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
