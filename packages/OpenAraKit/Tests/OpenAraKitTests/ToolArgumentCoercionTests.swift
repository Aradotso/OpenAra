import Foundation
import Testing
@testable import OpenAraKit

@Suite final class ToolArgumentCoercionTests {
    @Test func optionalStringAcceptsActualString() {
        #expect(optionalToolString("element_index", in: ["element_index": "8"]) == "8")
        #expect(optionalToolString("element_index", in: ["element_index": "AllClear"]) == "AllClear")
        #expect(optionalToolString("element_index", in: [:]) == nil)
    }

    @Test func optionalStringStringifiesIntegers() {
        // The natural JSON form for element_index is integer; agents and humans
        // both write `"element_index": 8`. Tools should not reject that.
        #expect(optionalToolString("element_index", in: ["element_index": 8]) == "8")
        #expect(optionalToolString("element_index", in: ["element_index": 0]) == "0")
        #expect(optionalToolString("element_index", in: ["element_index": -3]) == "-3")
    }

    @Test func optionalStringStringifiesWholeDoubles() {
        let json = "{\"element_index\": 8}"
        let parsed = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        #expect(parsed != nil)
        // JSONSerialization decodes integers as NSNumber, which casts to Int and Double.
        #expect(optionalToolString("element_index", in: parsed ?? [:]) == "8")

        let floatJson = "{\"x\": 12.5}"
        let floatParsed = try? JSONSerialization.jsonObject(with: Data(floatJson.utf8)) as? [String: Any]
        #expect(optionalToolString("x", in: floatParsed ?? [:]) == "12.5")
    }

    @Test func requireStringAcceptsIntegerForms() throws {
        let value = try requireToolString("element_index", in: ["element_index": 8])
        #expect(value == "8")
    }

    @Test func requireStringRejectsMissingAndEmpty() {
        do {
            _ = try requireToolString("element_index", in: [:])
            Issue.record("expected missingArgument throw")
        } catch let error as ComputerUseError {
            #expect(error.errorDescription?.contains("element_index") == true)
        } catch {
            Issue.record("expected ComputerUseError, got \(error)")
        }

        do {
            _ = try requireToolString("element_index", in: ["element_index": ""])
            Issue.record("expected missingArgument throw on empty")
        } catch let error as ComputerUseError {
            #expect(error.errorDescription?.contains("element_index") == true)
        } catch {
            Issue.record("expected ComputerUseError on empty, got \(error)")
        }
    }
}
