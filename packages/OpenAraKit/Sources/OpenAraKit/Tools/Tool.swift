import Foundation

/// A single Computer Use tool. Each tool is its own type so that adding,
/// removing, or rewriting one is a localized change instead of a switch-case
/// edit on a 1000-line dispatcher.
///
/// Tools are dispatched via ``ToolRegistry``. The registry handles argument
/// extraction errors, missing-tool errors, and result wrapping so individual
/// implementations can stay focused on the actual interaction work.
public protocol Tool: Sendable {
    /// The wire name used by MCP clients (e.g. `"click"`). Frozen by the
    /// OpenAI Computer Use spec — do not change.
    static var name: String { get }

    /// Execute the tool against the supplied service and return a tool result.
    /// Implementations should throw ``ComputerUseError`` for argument or
    /// service-level failures; ``ToolRegistry`` converts those into the right
    /// MCP error envelope.
    func run(arguments: [String: Any], service: ComputerUseService) throws -> ToolCallResult
}

extension Tool {
    /// Forwards ``Self/name`` so call sites can write `tool.name` instead of
    /// `type(of: tool).name`. Useful in registry iterations.
    public var name: String { Self.name }
}

// MARK: - Argument helpers

/// Read a required string argument. Throws ``ComputerUseError/missingArgument``
/// when the key is missing or empty so the MCP client gets a uniform message.
public func requireToolString(_ key: String, in arguments: [String: Any]) throws -> String {
    guard let value = arguments[key] as? String, !value.isEmpty else {
        throw ComputerUseError.missingArgument(key)
    }
    return value
}

/// Read an optional string argument; returns nil when the key is absent or has
/// the wrong type. Empty strings are returned as-is — emptiness matters for
/// some tools and not others.
public func optionalToolString(_ key: String, in arguments: [String: Any]) -> String? {
    arguments[key] as? String
}

/// Read a required numeric argument as Double. Accepts JSON numbers in any
/// underlying representation (Double, Int, NSNumber).
public func requireToolDouble(_ key: String, in arguments: [String: Any]) throws -> Double {
    guard let value = optionalToolDouble(key, in: arguments) else {
        throw ComputerUseError.missingArgument(key)
    }
    return value
}

/// Read an optional numeric argument as Double.
public func optionalToolDouble(_ key: String, in arguments: [String: Any]) -> Double? {
    if let double = arguments[key] as? Double {
        return double
    }
    if let integer = arguments[key] as? Int {
        return Double(integer)
    }
    if let number = arguments[key] as? NSNumber {
        return number.doubleValue
    }
    return nil
}
