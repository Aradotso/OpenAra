import AppKit
import Testing
@testable import OpenAraKit

@Suite final class MCPServerTests {
    @Test func initializeResponseContainsToolsCapability() throws {
        let server = StdioMCPServer(service: ComputerUseService())
        let response = server.handle(line: #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","clientInfo":{"name":"test","version":"0.1.36"},"capabilities":{}}}"#)
                #expect(response != nil)
                #expect(response!.contains(#""name":"openara""#))
                #expect(response!.contains(#""tools":{"listChanged":false}"#))
    }

    @Test func initializeResponseContainsComputerUseInstructions() throws {
        let server = StdioMCPServer(service: ComputerUseService())
        let response = try #require(
            server.handle(line: #"{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","clientInfo":{"name":"test","version":"0.1.36"},"capabilities":{}}}"#)
        )
        let data = try #require(response.data(using: .utf8))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let result = try #require(json["result"] as? [String: Any])
        let instructions = try #require(result["instructions"] as? String)

                #expect(instructions == computerUseServerInstructions)
    }

    @Test func mCPAcceptsTurnEndedNotificationWithoutResponse() {
        let server = StdioMCPServer(service: ComputerUseService())
        let response = server.handle(line: #"{"jsonrpc":"2.0","method":"notifications/turn-ended","params":{"type":"agent-turn-complete"}}"#)

                #expect(response == nil)
    }

}
