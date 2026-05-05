import AppKit
import Testing
@testable import OpenAraKit

@Suite final class CLITests {
    @Test func recognizesGlobalHelpAndVersionFlags() throws {
        #expect(try parseOpenAraCLI(arguments: ["-h"]) == .help(command: nil))
        #expect(try parseOpenAraCLI(arguments: ["--help"]) == .help(command: nil))
        #expect(try parseOpenAraCLI(arguments: ["-v"]) == .version)
        #expect(try parseOpenAraCLI(arguments: ["--version"]) == .version)
    }

    @Test func recognizesCommandSpecificHelp() throws {
        #expect(try parseOpenAraCLI(arguments: ["help", "snapshot"]) == .help(command: "snapshot"))
        #expect(try parseOpenAraCLI(arguments: ["snapshot", "--help"]) == .help(command: "snapshot"))
        #expect(try parseOpenAraCLI(arguments: ["doctor", "-h"]) == .help(command: "doctor"))
        #expect(try parseOpenAraCLI(arguments: ["call", "--help"]) == .help(command: "call"))
    }

    @Test func recognizesSingleToolCallCommand() throws {
        #expect(
            try parseOpenAraCLI(arguments: ["call", "list_apps"])
                == .call(.single(toolName: "list_apps", argumentsJSON: nil, argumentsFile: nil))
        )

        #expect(
            try parseOpenAraCLI(arguments: ["call", "get_app_state", "--args", #"{"app":"TextEdit"}"#])
                == .call(.single(toolName: "get_app_state", argumentsJSON: #"{"app":"TextEdit"}"#, argumentsFile: nil))
        )
    }

    @Test func recognizesJSONSequenceCallCommand() throws {
        let calls = #"[{"tool":"get_app_state","args":{"app":"TextEdit"}},{"tool":"press_key","args":{"app":"TextEdit","key":"Return"}}]"#

        #expect(
            try parseOpenAraCLI(arguments: ["call", "--calls", calls])
                == .call(.sequence(
                    callsJSON: calls,
                    callsFile: nil,
                    interCallDelay: openAraDefaultInterCallDelay
                ))
        )
    }

    @Test func recognizesJSONSequenceCallCommandWithCustomSleep() throws {
        let calls = #"[{"tool":"get_app_state","args":{"app":"TextEdit"}},{"tool":"press_key","args":{"app":"TextEdit","key":"Return"}}]"#

        #expect(
            try parseOpenAraCLI(arguments: ["call", "--calls", calls, "--sleep", "0.5"])
                == .call(.sequence(callsJSON: calls, callsFile: nil, interCallDelay: 0.5))
        )
    }

    @Test func recognizesTurnEndedNotifyPayload() throws {
        let payload = #"{"type":"agent-turn-complete","turn-id":"12345"}"#

        #expect(try parseOpenAraCLI(arguments: ["turn-ended"]) == .turnEnded(payload: nil))
        #expect(try parseOpenAraCLI(arguments: ["turn-ended", payload]) == .turnEnded(payload: payload))
        #expect(
            try parseOpenAraCLI(arguments: ["turn-ended", "--previous-notify", #"["/bin/true"]"#, payload])
                == .turnEnded(payload: payload)
        )
    }

    @Test func requiresSnapshotArgument() {
        #expect(throws: OpenAraCLIError(
            message: "snapshot requires an app name or bundle identifier",
            helpCommand: "snapshot"
        )) {
            _ = try parseOpenAraCLI(arguments: ["snapshot"])
        }
    }

    @Test func rejectsMixedCallSequenceInputs() {
        #expect(throws: OpenAraCLIError(
            message: "call sequence does not accept a tool name, --args, or --args-file",
            helpCommand: "call"
        )) {
            _ = try parseOpenAraCLI(arguments: ["call", "list_apps", "--calls", "[]"])
        }
    }

    @Test func rejectsSleepForSingleToolCall() {
        #expect(throws: OpenAraCLIError(
            message: "--sleep is only supported with --calls or --calls-file",
            helpCommand: "call"
        )) {
            _ = try parseOpenAraCLI(arguments: ["call", "list_apps", "--sleep", "0.5"])
        }
    }

    @Test func rejectsInvalidSequenceSleepValue() {
        #expect(throws: OpenAraCLIError(
            message: "--sleep requires a non-negative number of seconds",
            helpCommand: "call"
        )) {
            _ = try parseOpenAraCLI(arguments: ["call", "--calls", "[]", "--sleep", "-1"])
        }
    }

    @Test func rejectsUnknownOption() {
        #expect(throws: OpenAraCLIError(
            message: "Unknown option: --verbose",
            helpCommand: nil
        )) {
            _ = try parseOpenAraCLI(arguments: ["--verbose"])
        }
    }

    @Test func generalHelpListsCommandsAndGlobalFlags() {
        let help = openAraHelpText()

        #expect(help.contains("openara [command] [options]"))
        #expect(help.contains("snapshot <app>"))
        #expect(help.contains("call <tool>"))
        #expect(help.contains("-h, --help"))
        #expect(help.contains("-v, --version"))
    }

    @Test func resolvedVersionFallsBackWhenBundleHasNoVersionMetadata() {
        #expect(resolvedOpenAraVersion(bundle: Bundle(for: Self.self)) == openAraVersion)
    }
}
