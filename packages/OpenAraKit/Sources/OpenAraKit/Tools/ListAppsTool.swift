import Foundation

/// `list_apps` — return the running and recently used apps OpenAra can drive.
public struct ListAppsTool: Tool {
    public static let name = "list_apps"

    public init() {}

    public func run(arguments: [String: Any], service: ComputerUseService) throws -> ToolCallResult {
        service.listApps()
    }
}
