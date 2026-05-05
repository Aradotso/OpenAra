import Foundation

/// `set_value` — write a string value into a settable AX element directly,
/// without going through keyboard event synthesis.
public struct SetValueTool: Tool {
    public static let name = "set_value"

    public init() {}

    public func run(arguments: [String: Any], service: ComputerUseService) throws -> ToolCallResult {
        try service.setValue(
            app: requireToolString("app", in: arguments),
            elementIndex: requireToolString("element_index", in: arguments),
            value: requireToolString("value", in: arguments)
        )
    }
}
