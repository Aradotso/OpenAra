import Foundation

/// `perform_secondary_action` — invoke a non-click AX action on a specific
/// element (e.g. `Press`, `Raise`, `ShowMenu`). Element-targeted only.
public struct PerformSecondaryActionTool: Tool {
    public static let name = "perform_secondary_action"

    public init() {}

    public func run(arguments: [String: Any], service: ComputerUseService) throws -> ToolCallResult {
        try service.performSecondaryAction(
            app: requireToolString("app", in: arguments),
            elementIndex: requireToolString("element_index", in: arguments),
            action: requireToolString("action", in: arguments)
        )
    }
}
