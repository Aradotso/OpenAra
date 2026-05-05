import Foundation

/// `click` — click an element by index or by coordinate. Element-targeted
/// clicks go through the Accessibility action path first; coordinate clicks
/// fall back to HID input when AX hit-testing fails.
public struct ClickTool: Tool {
    public static let name = "click"

    public init() {}

    public func run(arguments: [String: Any], service: ComputerUseService) throws -> ToolCallResult {
        try service.click(
            app: requireToolString("app", in: arguments),
            elementIndex: optionalToolString("element_index", in: arguments),
            x: optionalToolDouble("x", in: arguments),
            y: optionalToolDouble("y", in: arguments),
            clickCount: Int(optionalToolDouble("click_count", in: arguments) ?? 1),
            mouseButton: optionalToolString("mouse_button", in: arguments) ?? "left"
        )
    }
}
