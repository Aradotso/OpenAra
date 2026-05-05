import Foundation

/// One entry in an OpenAra `call --calls` sequence.
public struct OpenAraCallSpec {
    public let tool: String
    public let arguments: [String: Any]

    public init(tool: String, arguments: [String: Any]) {
        self.tool = tool
        self.arguments = arguments
    }
}

/// Output of running a single OpenAra invocation (single tool or sequence).
public struct OpenAraCallOutput {
    public let jsonObject: Any
    public let hasToolError: Bool

    public init(jsonObject: Any, hasToolError: Bool) {
        self.jsonObject = jsonObject
        self.hasToolError = hasToolError
    }

    public func jsonText() throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: jsonObject,
            options: [.prettyPrinted, .withoutEscapingSlashes]
        )
        guard let text = String(data: data, encoding: .utf8) else {
            throw ComputerUseError.message("Failed to encode call output as JSON.")
        }
        return text
    }
}

/// Sleep callback used between successful sequence steps. Tests inject a
/// recorder to verify pacing; production passes through to ``Thread/sleep``.
public typealias OpenAraSleepHandler = (TimeInterval) -> Void

/// Run a single tool invocation or a sequence of them, returning their
/// combined JSON output. Sequence runs stop after the first tool error.
public func runOpenAraCall(
    _ invocation: OpenAraCallInvocation,
    service: ComputerUseService = ComputerUseService(),
    sleepHandler: OpenAraSleepHandler = { Thread.sleep(forTimeInterval: $0) }
) throws -> OpenAraCallOutput {
    let registry = ToolRegistry(service: service)

    switch invocation {
    case let .single(toolName, argumentsJSON, argumentsFile):
        let arguments = try readOpenAraToolArguments(json: argumentsJSON, file: argumentsFile)
        let result = registry.callToolAsResult(name: toolName, arguments: arguments)
        return OpenAraCallOutput(jsonObject: result.asDictionary, hasToolError: result.isError)

    case let .sequence(callsJSON, callsFile, interCallDelay):
        let calls = try readOpenAraCallSequence(json: callsJSON, file: callsFile)
        var outputs: [[String: Any]] = []
        var hasToolError = false

        for (index, call) in calls.enumerated() {
            let result = registry.callToolAsResult(name: call.tool, arguments: call.arguments)
            outputs.append([
                "tool": call.tool,
                "result": result.asDictionary,
            ])

            if result.isError {
                hasToolError = true
                break
            }

            if index < calls.count - 1, interCallDelay > 0 {
                sleepHandler(interCallDelay)
            }
        }

        return OpenAraCallOutput(jsonObject: outputs, hasToolError: hasToolError)
    }
}

// MARK: - JSON readers

public func readOpenAraToolArguments(
    json: String?,
    file: String?
) throws -> [String: Any] {
    guard let source = try readOpenAraJSONSource(json: json, file: file) else {
        return [:]
    }

    let object = try decodeOpenAraJSONObject(source)
    guard let arguments = object as? [String: Any] else {
        throw OpenAraCLIError(message: "--args must be a JSON object", helpCommand: "call")
    }

    return arguments
}

public func readOpenAraCallSequence(
    json: String?,
    file: String?
) throws -> [OpenAraCallSpec] {
    guard let source = try readOpenAraJSONSource(json: json, file: file) else {
        throw OpenAraCLIError(message: "call sequence requires --calls or --calls-file", helpCommand: "call")
    }

    let object = try decodeOpenAraJSONObject(source)
    guard let array = object as? [Any] else {
        throw OpenAraCLIError(message: "--calls must be a JSON array", helpCommand: "call")
    }

    return try array.enumerated().map { index, item in
        guard let dictionary = item as? [String: Any] else {
            throw OpenAraCLIError(
                message: "call sequence item #\(index + 1) must be a JSON object",
                helpCommand: "call"
            )
        }

        guard let tool = (dictionary["tool"] ?? dictionary["name"]) as? String, !tool.isEmpty else {
            throw OpenAraCLIError(
                message: "call sequence item #\(index + 1) requires a non-empty tool",
                helpCommand: "call"
            )
        }

        let rawArguments = dictionary["args"] ?? dictionary["arguments"] ?? [:]
        guard let arguments = rawArguments as? [String: Any] else {
            throw OpenAraCLIError(
                message: "call sequence item #\(index + 1) args must be a JSON object",
                helpCommand: "call"
            )
        }

        return OpenAraCallSpec(tool: tool, arguments: arguments)
    }
}

private func readOpenAraJSONSource(json: String?, file: String?) throws -> String? {
    if json != nil, file != nil {
        throw OpenAraCLIError(message: "Use either inline JSON or a JSON file, not both", helpCommand: "call")
    }

    if let json {
        return json
    }

    guard let file else {
        return nil
    }

    do {
        return try String(contentsOfFile: file, encoding: .utf8)
    } catch {
        throw OpenAraCLIError(
            message: "Unable to read JSON file \(file): \(error.localizedDescription)",
            helpCommand: "call"
        )
    }
}

private func decodeOpenAraJSONObject(_ source: String) throws -> Any {
    guard let data = source.data(using: .utf8) else {
        throw OpenAraCLIError(message: "JSON input must be UTF-8 text", helpCommand: "call")
    }

    do {
        return try JSONSerialization.jsonObject(with: data)
    } catch {
        throw OpenAraCLIError(
            message: "Invalid JSON input: \(error.localizedDescription)",
            helpCommand: "call"
        )
    }
}
