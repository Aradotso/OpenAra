import Foundation

/// `drag` — drag the cursor from one window-relative coordinate to another.
public struct DragTool: Tool {
    public static let name = "drag"

    public init() {}

    public func run(arguments: [String: Any], service: ComputerUseService) throws -> ToolCallResult {
        try service.drag(
            app: requireToolString("app", in: arguments),
            fromX: requireToolDouble("from_x", in: arguments),
            fromY: requireToolDouble("from_y", in: arguments),
            toX: requireToolDouble("to_x", in: arguments),
            toY: requireToolDouble("to_y", in: arguments)
        )
    }
}
