import AppKit
import Testing
@testable import OpenAraKit

@Suite final class CallSequenceTests {
    @Test func toolDefinitionCount() {
                #expect(ToolDefinitions.all.count == 9)
    }

    @Test func readToolArgumentsAcceptsJSONObject() throws {
        let arguments = try readOpenAraToolArguments(
            json: #"{"app":"TextEdit","pages":2}"#,
            file: nil
        )

                #expect(arguments["app"] as? String == "TextEdit")
                #expect((arguments["pages"] as? NSNumber)?.intValue == 2)
    }

    @Test func readToolArgumentsRejectsNonObject() {
        #expect(throws: OpenAraCLIError(message: "--args must be a JSON object", helpCommand: "call")) {
            _ = try readOpenAraToolArguments(json: #"["TextEdit"]"#, file: nil)
        }
    }

    @Test func readCallSequenceAcceptsJSONArrays() throws {
        let calls = try readOpenAraCallSequence(
            json: #"[{"tool":"get_app_state","args":{"app":"TextEdit"}},{"name":"press_key","arguments":{"app":"TextEdit","key":"Return"}}]"#,
            file: nil
        )

                #expect(calls.count == 2)
                #expect(calls[0].tool == "get_app_state")
                #expect(calls[0].arguments["app"] as? String == "TextEdit")
                #expect(calls[1].tool == "press_key")
                #expect(calls[1].arguments["key"] as? String == "Return")
    }

    @Test func runCallSequenceStopsAfterFirstToolError() throws {
        let output = try runOpenAraCall(
            .sequence(
                callsJSON: #"[{"tool":"not_a_tool"},{"tool":"list_apps"}]"#,
                callsFile: nil,
                interCallDelay: openAraDefaultInterCallDelay
            )
        )

        let outputs = try #require(output.jsonObject as? [[String: Any]])
                #expect(outputs.count == 1)
                #expect(output.hasToolError)
    }

    @Test func runCallSequenceSleepsBetweenSuccessfulOperations() throws {
        var recordedSleeps: [TimeInterval] = []

        let output = try runOpenAraCall(
            .sequence(
                callsJSON: #"[{"tool":"list_apps"},{"tool":"list_apps"},{"tool":"list_apps"}]"#,
                callsFile: nil,
                interCallDelay: openAraDefaultInterCallDelay
            ),
            sleepHandler: { recordedSleeps.append($0) }
        )

        let outputs = try #require(output.jsonObject as? [[String: Any]])
                #expect(outputs.count == 3)
                #expect(recordedSleeps == [openAraDefaultInterCallDelay, openAraDefaultInterCallDelay])
                #expect(!(output.hasToolError))
    }
}
