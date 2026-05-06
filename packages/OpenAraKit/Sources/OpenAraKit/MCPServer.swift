import Foundation

let computerUseServerInstructions = """
Computer Use tools let you interact with macOS apps by performing UI actions.

Some apps might have a separate dedicated plugin or skill. You may want to use that plugin or skill instead of Computer Use when it seems like a good fit for the task. While the separate plugin or skill may not expose every feature in the app, if the plugin can perform the task with its available features, prefer it. If the needed capability is not exposed there, use Computer Use may be appropriate for the missing interaction.

Begin by calling `get_app_state` every turn you want to use Computer Use to get the latest state before acting. Codex will automatically stop the session after each assistant turn, so this step is required before interacting with apps in a new assistant turn.

The available tools are list_apps, get_app_state, click, perform_secondary_action, scroll, drag, type_text, press_key, and set_value. If any of these are not available in your environment, use tool_search to surface one before calling any Computer Use action tools.

Computer Use tools allow you to use the user's apps in the background, so while you're using an app, the user can continue to use other apps on their computer. Avoid doing anything that would disrupt the user's active session, such as overwriting the contents of their clipboard, unless they asked you to!

After each action, use the action result or fetch the latest state to verify the UI changed as expected.
Prefer element-targeted interactions over coordinate clicks when an index for the targeted element is available. Note that element indices are the sequential integers from the app state's accessibility tree.
Avoid falling back to AppleScript during a computer use session. Prefer Computer Use tools as much as possible to complete tasks.
Ask the user before taking destructive or externally visible actions such as sending, deleting, or purchasing. If helpful, you can ask follow-up questions before taking action to make sure you’re understanding the user’s request correctly.
"""

public final class StdioMCPServer {
    private let registry: ToolRegistry
    public let sessionID: String
    public let pid: Int32
    private var clientName: String = "unknown"

    public init(service: ComputerUseService = ComputerUseService()) {
        self.registry = ToolRegistry(service: service)
        self.sessionID = StdioMCPServer.makeSessionID()
        self.pid = getpid()
        OpenAraLogger.info("\(logPrefix) session-start version=\(openAraVersion)", category: "mcp")
        if argumentRedactionDisabled(environment: ProcessInfo.processInfo.environment) {
            OpenAraLogger.warn(
                "\(logPrefix) OPENARA_LOG_RAW_ARGS is set — tool arguments (including typed text and field values) will be written to the log in plaintext. Unset OPENARA_LOG_RAW_ARGS to restore redaction.",
                category: "mcp"
            )
        }
    }

    public func run() throws {
        while let line = readLine(strippingNewline: true) {
            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            if let response = handle(line: line) {
                FileHandle.standardOutput.write((response + "\n").data(using: .utf8)!)
            }
        }
        CursorVariantRegistry.release(sessionID: sessionID)
        OpenAraLogger.info("\(logPrefix) session-end", category: "mcp")
    }

    public func handle(line: String) -> String? {
        do {
            guard let payload = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
                return try encodeJSONRPCError(id: nil, code: -32700, message: "Invalid JSON-RPC payload")
            }

            let method = payload["method"] as? String
            let id = payload["id"]
            let params = payload["params"] as? [String: Any] ?? [:]

            switch method {
            case "initialize":
                if let info = params["clientInfo"] as? [String: Any], let name = info["name"] as? String {
                    clientName = name
                }
                let envOverride = ProcessInfo.processInfo.environment["OPENARA_CURSOR_COLOR"]?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                let variant = CursorVariantRegistry.claim(
                    client: clientName,
                    sessionID: sessionID,
                    pid: pid,
                    envOverride: envOverride
                )
                // OPENARA_CURSOR_INDEX is set by acp-bridge when it spawns
                // this MCP child for a specific tab — when present it pins
                // the cursor tint to that tab's colour-index for the whole
                // life of this MCP session, so a click/drag visibly
                // belongs to the tab that initiated it. When absent we
                // fall through to the legacy random-variant behaviour.
                let tabTint = OpenAraCursorPalette.resolveTintFromEnvironment()
                VisualCursorSupport.performOnMain {
                    setOpenAraCursorVariant(variant)
                    setOpenAraCursorTint(tabTint)
                }
                let tintLabel = tabTint == nil ? "none" : (ProcessInfo.processInfo.environment[OpenAraCursorPalette.envIndexKey] ?? "?")
                OpenAraLogger.info("\(logPrefix) initialize cursor_variant=\(variant) tab_tint_index=\(tintLabel)", category: "mcp")
                return try encodeJSONRPCResult(
                    id: id,
                    result: [
                        "protocolVersion": "2025-03-26",
                        "serverInfo": [
                            "name": "openara",
                            "version": openAraVersion,
                        ],
                        "capabilities": [
                            "tools": [
                                "listChanged": false,
                            ],
                        ],
                        "instructions": computerUseServerInstructions,
                    ]
                )
            case "notifications/initialized":
                return nil
            case "notifications/turn-ended":
                OpenAraLogger.info("\(logPrefix) turn-ended", category: "mcp")
                VisualCursorSupport.performOnMain {
                    SoftwareCursorOverlay.reset()
                }
                return nil
            case "ping":
                return try encodeJSONRPCResult(id: id, result: [:])
            case "tools/list":
                return try encodeJSONRPCResult(
                    id: id,
                    result: [
                        "tools": ToolDefinitions.all.map(\.asDictionary),
                    ]
                )
            case "tools/call":
                let name = params["name"] as? String ?? ""
                let arguments = params["arguments"] as? [String: Any] ?? [:]
                let argsRendered = renderArguments(toolName: name, arguments: arguments)
                OpenAraLogger.info("\(logPrefix) tool-call name=\(name) args=\(argsRendered)", category: "mcp")
                let targetApp = (arguments["app"] as? String) ?? (arguments["app_id"] as? String)
                VisualCursorSupport.performOnMain {
                    signalOpenAraToolCallStart(targetApp: targetApp)
                }
                let started = Date()
                let result = try registry.callTool(name: name, arguments: arguments)
                let duration = Int(Date().timeIntervalSince(started) * 1000)
                let status = result.isError ? "error" : "ok"
                let level: OpenAraLogger.Level = result.isError ? .warn : .info
                let outcome = "\(logPrefix) tool-result name=\(name) status=\(status) duration_ms=\(duration)"
                switch level {
                case .warn: OpenAraLogger.warn(outcome, category: "mcp")
                default: OpenAraLogger.info(outcome, category: "mcp")
                }
                return try encodeJSONRPCResult(
                    id: id,
                    result: result.asDictionary
                )
            default:
                if method == nil {
                    return nil
                }

                return try encodeJSONRPCError(id: id, code: -32601, message: "Method not found: \(method ?? "")")
            }
        } catch let error as ComputerUseError {
            let payload = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
            let id = payload?["id"]
            let result = ToolCallResult.text(error.errorDescription ?? String(describing: error), isError: error.toolResultIsError)
            return try? encodeJSONRPCResult(id: id, result: result.asDictionary)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            let payload = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]
            let id = payload?["id"]
            return try? encodeJSONRPCResult(
                id: id,
                result: [
                    "content": [
                        [
                            "type": "text",
                            "text": message,
                        ],
                    ],
                    "isError": true,
                ]
            )
        }
    }

    private func encodeJSONRPCResult(id: Any?, result: [String: Any]) throws -> String {
        try encode([
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "result": result,
        ])
    }

    private func encodeJSONRPCError(id: Any?, code: Int, message: String) throws -> String {
        try encode([
            "jsonrpc": "2.0",
            "id": id ?? NSNull(),
            "error": [
                "code": code,
                "message": message,
            ],
        ])
    }

    private func encode(_ object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.withoutEscapingSlashes])
        guard let text = String(data: data, encoding: .utf8) else {
            throw ComputerUseError.message("Failed to encode JSON-RPC response.")
        }

        return text
    }

    private var logPrefix: String {
        "session=\(sessionID) pid=\(pid) client=\(clientName)"
    }

    private static func makeSessionID() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8))
    }

    private func renderArguments(toolName: String, arguments: [String: Any]) -> String {
        let payload: [String: Any]
        if argumentRedactionDisabled(environment: ProcessInfo.processInfo.environment) {
            payload = arguments
        } else {
            payload = ArgumentRedactor.redact(toolName: toolName, arguments: arguments)
        }

        guard
            let data = try? JSONSerialization.data(withJSONObject: payload, options: [.withoutEscapingSlashes, .sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }

        let limit = 400
        if text.count > limit {
            let truncated = text.prefix(limit)
            return "\(truncated)…(+\(text.count - limit) chars)"
        }
        return text
    }
}
