import Foundation

/// Registry of all OpenAra Computer Use tools. Owns the static lookup table
/// (`tool name -> Tool instance`) and the dispatch path used by the MCP server.
///
/// The registry is intentionally a plain dictionary — there's no plug-in
/// loading at this layer. Adding a tool is: (a) write a new file under
/// `Tools/`, (b) add it to ``ToolRegistry/standardTools``. That's it.
public final class ToolRegistry {
    /// Snapshot of every tool in the OpenAI Computer Use surface, in dispatch
    /// order. Order isn't load-bearing for execution but is observable in
    /// `tools/list` MCP responses; we keep it close to the wire-name spec.
    public static let standardTools: [Tool] = [
        ListAppsTool(),
        GetAppStateTool(),
        ClickTool(),
        PerformSecondaryActionTool(),
        ScrollTool(),
        DragTool(),
        TypeTextTool(),
        PressKeyTool(),
        SetValueTool(),
    ]

    private let toolsByName: [String: Tool]
    private let service: ComputerUseService

    public convenience init(service: ComputerUseService = ComputerUseService()) {
        self.init(tools: ToolRegistry.standardTools, service: service)
    }

    /// Build a registry from an explicit tool list. Useful for tests and for
    /// embedders that want a subset of tools or a custom extension tool.
    public init(tools: [Tool], service: ComputerUseService) {
        var byName: [String: Tool] = [:]
        for tool in tools {
            byName[tool.name] = tool
        }
        self.toolsByName = byName
        self.service = service
    }

    /// All registered tool names, sorted for deterministic output.
    public var registeredToolNames: [String] {
        toolsByName.keys.sorted()
    }

    /// Dispatch a tool call. Throws ``ComputerUseError/unsupportedTool`` for
    /// unknown names; tool implementations may throw any ``ComputerUseError``.
    public func callTool(name: String, arguments: [String: Any]) throws -> ToolCallResult {
        guard let tool = toolsByName[name] else {
            throw ComputerUseError.unsupportedTool(name)
        }
        return try tool.run(arguments: arguments, service: service)
    }

    /// Same as ``callTool(name:arguments:)`` but converts thrown errors into a
    /// ``ToolCallResult`` carrying the error text. Mirrors the MCP "tool error"
    /// envelope that clients expect.
    public func callToolAsResult(name: String, arguments: [String: Any]) -> ToolCallResult {
        do {
            return try callTool(name: name, arguments: arguments)
        } catch let error as ComputerUseError {
            return ToolCallResult.text(
                error.errorDescription ?? String(describing: error),
                isError: error.toolResultIsError
            )
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            return ToolCallResult.text(message, isError: true)
        }
    }
}
