import AppKit
import Testing
@testable import OpenAraKit

@Suite final class EnvFlagsTests {
    @Test func visualCursorEnvFlagDefaultsToEnabled() {
                #expect(visualCursorEnabled(environment: [:]))
                #expect(visualCursorEnabled(environment: ["OPENARA_VISUAL_CURSOR": "1"]))
                #expect(!(visualCursorEnabled(environment: ["OPENARA_VISUAL_CURSOR": "0"])))
                #expect(!(visualCursorEnabled(environment: ["OPENARA_VISUAL_CURSOR": "false"])))
    }

    @Test func inputFallbackDebugFlagDefaultsToDisabled() {
                #expect(!(inputFallbackDebugEnabled(environment: [:])))
                #expect(inputFallbackDebugEnabled(environment: ["OPENARA_DEBUG_INPUT_FALLBACKS": "1"]))
                #expect(inputFallbackDebugEnabled(environment: ["OPENARA_DEBUG_INPUT_FALLBACKS": "true"]))
                #expect(!(inputFallbackDebugEnabled(environment: ["OPENARA_DEBUG_INPUT_FALLBACKS": "0"])))
                #expect(!(inputFallbackDebugEnabled(environment: ["OPENARA_DEBUG_INPUT_FALLBACKS": "off"])))
    }

    @Test func globalPointerFallbackFlagDefaultsToDisabled() {
                #expect(!(globalPointerFallbacksEnabled(environment: [:])))
                #expect(globalPointerFallbacksEnabled(environment: ["OPENARA_ALLOW_GLOBAL_POINTER_FALLBACKS": "1"]))
                #expect(globalPointerFallbacksEnabled(environment: ["OPENARA_ALLOW_GLOBAL_POINTER_FALLBACKS": "yes"]))
                #expect(!(globalPointerFallbacksEnabled(environment: ["OPENARA_ALLOW_GLOBAL_POINTER_FALLBACKS": "0"])))
                #expect(!(globalPointerFallbacksEnabled(environment: ["OPENARA_ALLOW_GLOBAL_POINTER_FALLBACKS": "false"])))
    }

}
