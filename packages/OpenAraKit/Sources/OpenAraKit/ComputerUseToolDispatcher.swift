import Foundation

/// Thin compatibility shim that forwards to ``ToolRegistry``. The previous
/// monolithic switch-on-tool-name has been split into per-tool files under
/// ``Tools/``; this type stays so existing call sites (MCP server, tests,
/// embedders) keep compiling without churn.
///
/// New code should prefer ``ToolRegistry`` directly.
public final class ComputerUseToolDispatcher {
    private let registry: ToolRegistry

    public init(service: ComputerUseService = ComputerUseService()) {
        self.registry = ToolRegistry(service: service)
    }

    public func callTool(name: String, arguments: [String: Any]) throws -> ToolCallResult {
        try registry.callTool(name: name, arguments: arguments)
    }

    public func callToolAsResult(name: String, arguments: [String: Any]) -> ToolCallResult {
        registry.callToolAsResult(name: name, arguments: arguments)
    }
}
