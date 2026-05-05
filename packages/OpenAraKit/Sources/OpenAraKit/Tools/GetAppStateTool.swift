import Foundation

/// `get_app_state` — capture and return an app's current accessibility tree
/// plus a screenshot of its key window.
public struct GetAppStateTool: Tool {
    public static let name = "get_app_state"

    public init() {}

    public func run(arguments: [String: Any], service: ComputerUseService) throws -> ToolCallResult {
        try service.getAppState(app: requireToolString("app", in: arguments))
    }
}
