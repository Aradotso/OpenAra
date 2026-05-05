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
            printStaleTCCFindings()
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
        case .sessions:
            printSessionsTable()
        case let .help(command):
            print(openAraHelpText(command: command))
        case .version:
            print(resolvedOpenAraVersion())
        case let .uninstall(includeLegacy):
            try runUninstall(includeLegacy: includeLegacy)
        case let .resetPermissions(includeLegacy, includeDev):
            try runResetPermissions(includeLegacy: includeLegacy, includeDev: includeDev)
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
                  openara install-claude-mcp     # wire into Claude Code + Claude Desktop
                  openara install-cursor-mcp     # wire into Cursor
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

    private static func printSessionsTable() {
        let claims = CursorVariantRegistry.activeClaims()
        if claims.isEmpty {
            print("No active OpenAra sessions.")
            return
        }
        let rows: [(String, String, String, String, String)] = claims
            .sorted(by: { $0.startedAt < $1.startedAt })
            .map { claim in
                (
                    claim.color,
                    truncate(claim.client, 14),
                    String(claim.pid),
                    claim.sessionID,
                    claim.startedAt
                )
            }
        let header = ("COLOR", "CLIENT", "PID", "SESSION", "STARTED")
        let widths = (
            max(header.0.count, rows.map(\.0.count).max() ?? 0),
            max(header.1.count, rows.map(\.1.count).max() ?? 0),
            max(header.2.count, rows.map(\.2.count).max() ?? 0),
            max(header.3.count, rows.map(\.3.count).max() ?? 0),
            max(header.4.count, rows.map(\.4.count).max() ?? 0)
        )
        let formatted: (String, String, String, String, String) -> String = { c, cl, p, s, st in
            [
                pad(c, widths.0),
                pad(cl, widths.1),
                pad(p, widths.2),
                pad(s, widths.3),
                pad(st, widths.4),
            ].joined(separator: "  ")
        }
        let headerLine = formatted(header.0, header.1, header.2, header.3, header.4)
        print(headerLine)
        print(String(repeating: "─", count: headerLine.count))
        for row in rows {
            print(formatted(row.0, row.1, row.2, row.3, row.4))
        }
    }

    private static func pad(_ s: String, _ width: Int) -> String {
        s.count >= width ? s : s + String(repeating: " ", count: width - s.count)
    }

    private static func truncate(_ s: String, _ n: Int) -> String {
        s.count <= n ? s : String(s.prefix(n - 1)) + "…"
    }

    @MainActor
    private static func runUninstall(includeLegacy: Bool) throws {
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

        runTccutilResets(includeLegacy: includeLegacy, includeDev: true)
        printStaleTCCFindings()

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
    private static func runResetPermissions(includeLegacy: Bool, includeDev: Bool) throws {
        runTccutilResets(includeLegacy: includeLegacy, includeDev: includeDev)
        printStaleTCCFindings()

        print("""

        Bundle-id TCC entries cleared. Path-based grants (rows that appear in
        System Settings as a /Users/... or /Applications/... path) can't be
        cleared from the CLI — remove each one manually under
        System Settings → Privacy & Security → Accessibility and
        Screen & System Audio Recording.

        Re-launching the onboarding flow now…
        """)

        PermissionOnboardingApp.launch()
    }

    @discardableResult
    @MainActor
    private static func runTccutilResets(includeLegacy: Bool, includeDev: Bool) -> Bool {
        var allOK = true
        let targets = PermissionSupport.tccutilResetTargets(includeLegacy: includeLegacy, includeDev: includeDev)
        for bundleID in targets {
            let status = runProcess("/usr/bin/tccutil", arguments: ["reset", "All", bundleID])
            if status == 0 {
                print("Reset bundle-id TCC entries for \(bundleID).")
            } else {
                allOK = false
                print("tccutil reset for \(bundleID) returned non-zero (\(status)). It may not have been registered with TCC, which is fine.")
            }
        }
        return allOK
    }

    @MainActor
    private static func printStaleTCCFindings() {
        guard let findings = PermissionSupport.staleTCCFindings() else {
            print("")
            print("Could not read TCC.db (no Full Disk Access for this process).")
            print("Open System Settings → Privacy & Security → Full Disk Access,")
            print("add your terminal, and re-run for stale-grant detection.")
            return
        }

        guard !findings.isEmpty else {
            return
        }

        print("")
        print("Stale TCC entries detected (these likely confuse onboarding — remove via System Settings → Privacy & Security):")
        for finding in findings {
            let serviceLabel = finding.entry.service == .accessibility ? "Accessibility" : "Screen Recording"
            let kindLabel = finding.entry.isPathBased ? "path" : "bundle-id"
            let reasonLabel = describeStaleReason(finding.reason)
            let grantLabel = finding.entry.isGranted ? "granted" : "denied/prompt"
            print("  [\(serviceLabel)] [\(kindLabel)] \(finding.entry.client) — \(reasonLabel) (\(grantLabel))")
        }
    }

    private static func describeStaleReason(_ reason: LegacyTCCStaleReason) -> String {
        switch reason {
        case .pathMissing:
            return "path no longer exists on disk"
        case .pathOutsideApplications:
            return "path is not /Applications/OpenAra.app — leftover from a previous install location"
        case .legacyUpstreamBundle:
            return "upstream Open Computer Use grant — re-run with --include-legacy to clear"
        case .devBundleOnReleaseSystem:
            return "dev-variant grant with no /Applications/OpenAra (Dev).app present"
        }
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
