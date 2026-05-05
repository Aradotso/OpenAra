import Foundation

/// `scroll` — scroll a target element by N pages in a cardinal direction.
public struct ScrollTool: Tool {
    public static let name = "scroll"

    public init() {}

    public func run(arguments: [String: Any], service: ComputerUseService) throws -> ToolCallResult {
        try service.scroll(
            app: requireToolString("app", in: arguments),
            direction: requireToolString("direction", in: arguments),
            elementIndex: requireToolString("element_index", in: arguments),
            pages: optionalToolDouble("pages", in: arguments) ?? 1
        )
    }
}
