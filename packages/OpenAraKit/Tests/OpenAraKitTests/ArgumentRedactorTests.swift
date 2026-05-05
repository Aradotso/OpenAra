import Testing
@testable import OpenAraKit

@Suite final class ArgumentRedactorTests {
    @Test func typeTextValueIsRedacted() {
        let arguments: [String: Any] = [
            "app": "TextEdit",
            "element_index": 7,
            "text": "hunter2",
        ]
        let redacted = ArgumentRedactor.redact(toolName: "type_text", arguments: arguments)
        #expect((redacted["app"] as? String) == "TextEdit")
        #expect((redacted["element_index"] as? Int) == 7)
        let token = redacted["text"] as? String ?? ""
        #expect(token.hasPrefix("<redacted len="))
        #expect(token.contains("sha8="))
        #expect(!token.contains("hunter2"))
    }

    @Test func setValueValueIsRedacted() {
        let arguments: [String: Any] = [
            "app": "Safari",
            "element_index": 3,
            "value": "secret-token",
        ]
        let redacted = ArgumentRedactor.redact(toolName: "set_value", arguments: arguments)
        #expect((redacted["app"] as? String) == "Safari")
        #expect((redacted["element_index"] as? Int) == 3)
        let token = redacted["value"] as? String ?? ""
        #expect(token.hasPrefix("<redacted len="))
        #expect(!token.contains("secret-token"))
    }

    @Test func sameStringHashesToSameSha8WithinProcess() {
        let a = ArgumentRedactor.redactedToken(for: "hello world")
        let b = ArgumentRedactor.redactedToken(for: "hello world")
        let c = ArgumentRedactor.redactedToken(for: "different value")
        #expect(a == b)
        #expect(a != c)
    }

    @Test func plaintextAllowlistedKeysSurvive() {
        let arguments: [String: Any] = [
            "app": "Mail",
            "element_index": 12,
            "x": 100,
            "y": 200,
            "click_count": 2,
            "button": "left",
        ]
        let redacted = ArgumentRedactor.redact(toolName: "click", arguments: arguments)
        #expect((redacted["app"] as? String) == "Mail")
        #expect((redacted["element_index"] as? Int) == 12)
        #expect((redacted["x"] as? Int) == 100)
        #expect((redacted["y"] as? Int) == 200)
        #expect((redacted["click_count"] as? Int) == 2)
        #expect((redacted["button"] as? String) == "left")
    }

    @Test func unknownToolFailsClosed() {
        let arguments: [String: Any] = [
            "app": "Whatever",
            "secret": "leaked?",
        ]
        let redacted = ArgumentRedactor.redact(toolName: "future_tool_not_yet_in_allowlist", arguments: arguments)
        let appToken = redacted["app"] as? String ?? ""
        let secretToken = redacted["secret"] as? String ?? ""
        #expect(appToken.hasPrefix("<redacted "))
        #expect(secretToken.hasPrefix("<redacted "))
        #expect(!secretToken.contains("leaked?"))
    }

    @Test func emptyValueGetsZeroLengthToken() {
        let token = ArgumentRedactor.redactedToken(for: "")
        #expect(token == "<redacted len=0>")
    }

    @Test func envFlagReadsExpectedTruthyValues() {
        #expect(!argumentRedactionDisabled(environment: [:]))
        #expect(!argumentRedactionDisabled(environment: ["OPENARA_LOG_RAW_ARGS": "0"]))
        #expect(!argumentRedactionDisabled(environment: ["OPENARA_LOG_RAW_ARGS": "false"]))
        #expect(argumentRedactionDisabled(environment: ["OPENARA_LOG_RAW_ARGS": "1"]))
        #expect(argumentRedactionDisabled(environment: ["OPENARA_LOG_RAW_ARGS": "true"]))
        #expect(argumentRedactionDisabled(environment: ["OPENARA_LOG_RAW_ARGS": "yes"]))
        #expect(argumentRedactionDisabled(environment: ["OPENARA_LOG_RAW_ARGS": "ON"]))
    }
}
