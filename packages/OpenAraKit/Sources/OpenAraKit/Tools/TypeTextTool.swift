import Foundation

/// `type_text` — type a string into the focused element of an app, preferring
/// AX `EditableText` writes before falling back to keyboard event synthesis.
public struct TypeTextTool: Tool {
    public static let name = "type_text"

    public init() {}

    public func run(arguments: [String: Any], service: ComputerUseService) throws -> ToolCallResult {
        try service.typeText(
            app: requireToolString("app", in: arguments),
            text: requireToolString("text", in: arguments)
        )
    }
}
