import Foundation

/// `press_key` — press a key chord (xdotool-compatible syntax) against the
/// focused element of an app.
public struct PressKeyTool: Tool {
    public static let name = "press_key"

    public init() {}

    public func run(arguments: [String: Any], service: ComputerUseService) throws -> ToolCallResult {
        try service.pressKey(
            app: requireToolString("app", in: arguments),
            key: requireToolString("key", in: arguments)
        )
    }
}
