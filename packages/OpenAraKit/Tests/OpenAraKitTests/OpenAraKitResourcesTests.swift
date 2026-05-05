import Foundation
import Testing
@testable import OpenAraKit

@Suite final class OpenAraKitResourcesTests {
    @Test func resolverFindsBundleInSwiftPMTestEnvironment() {
        // Default test run — SwiftPM packages OpenAraKit's resources somewhere
        // the resolver should find. Without this, every cursor-glyph or font
        // load would silently return nil.
        #expect(FileManager.default.fileExists(atPath: OpenAraKitResources.resourceContainerURL.path))
    }

    @Test func cursorPNGsAreReachableThroughResolver() {
        let url = OpenAraKitResources.url(forResource: "openara-cursor-blue-256", withExtension: "png")
        #expect(url != nil)
        if let url {
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    @Test func loaderRetrievesEachBundledCursorVariant() {
        for variant in ["blue", "orange", "green", "graphite", "pink", "white"] {
            let url = OpenAraKitResources.url(forResource: "openara-cursor-\(variant)-256", withExtension: "png")
            #expect(url != nil, "missing cursor variant png: \(variant)")
        }
    }

    @Test func referenceCursorImageIsResolvable() {
        let url = OpenAraKitResources.url(forResource: SoftwareCursorGlyphMetrics.referenceImageResourceName, withExtension: "png")
        #expect(url != nil)
    }

    @Test func bundledFontsAreResolvable() {
        // AppFonts.registerBundledFonts() reads through the same resolver.
        let interURL = OpenAraKitResources.url(forResource: "Inter-Variable", withExtension: "ttf")
        let garamondURL = OpenAraKitResources.url(forResource: "EBGaramond-Variable", withExtension: "ttf")
        #expect(interURL != nil)
        #expect(garamondURL != nil)
    }

    @Test func missingResourceReturnsNilWithoutCrashing() {
        // Regression for the original bug: SwiftPM's Bundle.module crashes
        // (Swift.fatalError) when the bundle can't be found. The replacement
        // must return nil for missing resources, never trap.
        let url = OpenAraKitResources.url(forResource: "definitely-not-a-real-resource", withExtension: "png")
        #expect(url == nil)
    }
}
