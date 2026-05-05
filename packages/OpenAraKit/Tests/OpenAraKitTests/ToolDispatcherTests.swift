import AppKit
import Testing
@testable import OpenAraKit

@Suite final class ToolDispatcherTests {
    @Test func toolDescriptionsMatchOfficialComputerUseSurface() {
        let tools = Dictionary(uniqueKeysWithValues: ToolDefinitions.all.map { ($0.name, $0) })

                #expect(tools["get_app_state"]?.description == "Start an app use session if needed, then get the state of the app's key window and return a screenshot and accessibility tree. This must be called once per assistant turn before interacting with the app. This tool is part of plugin `Computer Use`.")
                #expect(tools["press_key"]?.description.contains("xdotool") == true)
                #expect(tools["click"]?.annotations["destructiveHint"] as? Bool == false)
                #expect(tools["get_app_state"]?.annotations["readOnlyHint"] as? Bool == true)
                #expect(tools["click"]?.inputSchema["additionalProperties"] as? Bool == false)
                #expect(((tools["click"]?.inputSchema["properties"] as? [String: [String: Any]])?["mouse_button"]?["enum"] as? [String]) ?? [] == ["left", "right", "middle"])
        let scrollPages = (tools["scroll"]?.inputSchema["properties"] as? [String: [String: Any]])?["pages"]
                #expect(scrollPages?["type"] as? String == "number")
                #expect(scrollPages?["description"] as? String == "Number of pages to scroll. Fractional values are supported. Defaults to 1")
    }

    @Test func dispatcherMissingArgumentsMatchOfficialToolText() {
        let dispatcher = ComputerUseToolDispatcher()
        let result = dispatcher.callToolAsResult(name: "type_text", arguments: ["app": "Sublime Text"])
        let emptyResult = dispatcher.callToolAsResult(name: "type_text", arguments: ["app": "Sublime Text", "text": ""])

                #expect(result.isError)
                #expect(result.primaryText == "Missing required argument: text")
                #expect(emptyResult.isError)
                #expect(emptyResult.primaryText == "Missing required argument: text")
    }

    @Test func scrollRejectsInvalidDirectionWithOfficialMessage() {
        let dispatcher = ComputerUseToolDispatcher()
        let result = dispatcher.callToolAsResult(
            name: "scroll",
            arguments: ["app": "Sublime Text", "element_index": "14", "direction": "sideways", "pages": 1]
        )

                #expect(result.isError)
                #expect(result.primaryText == "Invalid scroll direction: sideways")
    }

    @Test func scrollRejectsNonPositivePagesWithOfficialMessage() {
        let dispatcher = ComputerUseToolDispatcher()
        let result = dispatcher.callToolAsResult(
            name: "scroll",
            arguments: ["app": "Sublime Text", "element_index": "14", "direction": "down", "pages": 0.0]
        )

                #expect(result.isError)
                #expect(result.primaryText == "pages must be > 0")
    }

    @Test func secondaryActionInvalidMessageMatchesOfficialShape() {
                #expect(invalidSecondaryActionErrorMessage(action: "NoSuchAction", elementIndex: 14) == "NoSuchAction is not a valid secondary action for 14")
    }

    @Test func snapshotRenderedTextStartsDirectlyWithAppHeader() {
        let snapshot = makeSampleSnapshot(
            treeLines: ["\t0 standard window Sample Chat"],
            focusedSummary: "247 text entry area"
        )

        let rendered = snapshot.renderedText(style: .actionResult)
        let lines = rendered.components(separatedBy: "\n")

                #expect(lines.first == "App=com.example.SampleChat (pid 18465)")
                #expect(lines.dropFirst().first == "Window: \"Sample Chat\", App: Sample Chat.")
                #expect(!(rendered.contains("Computer Use state (CUA App Version: 750)")))
                #expect(!(rendered.contains("<app_state>")))
                #expect(!(rendered.contains("</app_state>")))
    }

    @Test func snapshotSelectedTextUsesOfficialSingleLineFormat() {
        let snapshot = makeSampleSnapshot(
            treeLines: ["\t38 search text field (settable, string) Codex"],
            focusedSummary: nil,
            selectedText: "Codex"
        )

        let rendered = snapshot.renderedText(style: .actionResult)

                #expect(rendered.contains("Selected text: [Codex]"))
                #expect(!(rendered.contains("Selected text: ```")))
                #expect(!(rendered.contains("Pay special attention to the content selected by the user")))
    }

    @Test func computerUseErrorsFormatLikeToolText() {
                #expect(ComputerUseError.appNotFound("Sublime Text").errorDescription == #"appNotFound("Sublime Text")"#)
                #expect(ComputerUseError.appNotFound("Sublime Text").toolResultIsError)
                #expect(ComputerUseError.invalidArguments("bad").toolResultIsError)
    }
    @Test func setValueAttributeGateMatchesOfficialSettableBoundary() throws {
                #expect(try setValueAttributeIsSettable(result: .success, settable: true, attribute: kAXValueAttribute))
                #expect(!(try setValueAttributeIsSettable(result: .success, settable: false, attribute: kAXValueAttribute)))
                #expect(nonSettableSetValueErrorMessage == "Cannot set a value for an element that is not settable")

        do {
            _ = try setValueAttributeIsSettable(result: .attributeUnsupported, settable: false, attribute: kAXValueAttribute)
            Issue.record("expected setValueAttributeIsSettable to throw")
        } catch let error as ComputerUseError {
            #expect(error.errorDescription == "AXUIElementIsAttributeSettable(AXValue) failed with -25205")
        }
    }

}

