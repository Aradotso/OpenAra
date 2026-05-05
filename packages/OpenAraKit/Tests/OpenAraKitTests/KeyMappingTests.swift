import AppKit
import Testing
@testable import OpenAraKit

@Suite final class KeyMappingTests {
    @Test func keyPressParserSupportsCommandStyleChord() throws {
        let parsed = try KeyPressParser.parse("super+c")
                #expect(parsed.displayValue == "c")
                #expect(parsed.modifiers.count == 1)
    }

    @Test func keyPressParserSupportsOfficialXdotoolAliases() throws {
                #expect(try KeyPressParser.parse("BackSpace").displayValue == "backspace")
                #expect(try KeyPressParser.parse("Page_Up").displayValue == "page_up")
                #expect(try KeyPressParser.parse("Prior").displayValue == "prior")
                #expect(try KeyPressParser.parse("KP_9").displayValue == "kp_9")
                #expect(try KeyPressParser.parse("KP_Enter").displayValue == "kp_enter")
                #expect(try KeyPressParser.parse("F12").displayValue == "f12")
    }

}
