import AppKit
import Testing
@testable import OpenAraKit

@Suite final class CoordinateGeometryTests {
    @Test func windowRelativeFrameUsesSharedGlobalCoordinates() {
        let window = CGRect(x: 1486, y: 556, width: 919, height: 644)
        let child = CGRect(x: 1486, y: 556, width: 919, height: 644)
        let textField = CGRect(x: 180, y: 176, width: 36, height: 18)
        let textFieldGlobal = CGRect(x: window.minX + textField.minX, y: window.minY + textField.minY, width: textField.width, height: textField.height)

                #expect(windowRelativeFrame(elementFrame: child, windowBounds: window) == CGRect(x: 0, y: 0, width: 919, height: 644))
                #expect(windowRelativeFrame(elementFrame: textFieldGlobal, windowBounds: window) == textField)
    }

    @Test func makeVisualCursorTargetUsesWindowRelativeElementCenter() {
        let screenMappings = [
            VisualCursorScreenMapping(
                screenStateFrame: CGRect(x: 0, y: 0, width: 1600, height: 1000),
                appKitFrame: CGRect(x: 0, y: 0, width: 1600, height: 1000)
            ),
        ]
        let target = makeVisualCursorTarget(
            localFrame: CGRect(x: 24, y: 32, width: 120, height: 48),
            windowBounds: CGRect(x: 400, y: 220, width: 900, height: 640),
            targetWindowID: 321,
            targetWindowLayer: 8,
            screenMappings: screenMappings
        )

                #expect(target == VisualCursorTarget( point: CGPoint(x: 484, y: 724), window: CursorTargetWindow(windowID: 321, layer: 8) ))
    }

    @Test func makeVisualCursorTargetReturnsNilWithoutWindowBounds() {
                #expect(makeVisualCursorTarget( localFrame: CGRect(x: 24, y: 32, width: 120, height: 48), windowBounds: nil, targetWindowID: 321, targetWindowLayer: 8 ) == nil)
    }

    @Test func visualCursorAppKitPointConvertsScreenStateYDownCoordinates() {
        let point = visualCursorAppKitPoint(
            fromScreenStatePoint: CGPoint(x: 2415, y: 181),
            screenMappings: [
                VisualCursorScreenMapping(
                    screenStateFrame: CGRect(x: 0, y: 0, width: 3024, height: 1964),
                    appKitFrame: CGRect(x: 0, y: 0, width: 3024, height: 1964)
                ),
            ]
        )

                #expect(point == CGPoint(x: 2415, y: 1783))
    }

    @Test func screenshotPixelScaleUsesRetinaSizedImageAgainstWindowBounds() {
        let scale = screenshotPixelScale(
            screenshotPixelSize: CGSize(width: 2048, height: 1266),
            windowBounds: CGRect(x: 1938, y: 236, width: 1024, height: 633)
        )

                #expect(abs((scale.width) - (2)) < 0.0001)
                #expect(abs((scale.height) - (2)) < 0.0001)
    }

    @Test func screenshotPixelScaleStaysAtOneForUnscaledDisplays() {
        let scale = screenshotPixelScale(
            screenshotPixelSize: CGSize(width: 1024, height: 633),
            windowBounds: CGRect(x: 1938, y: 236, width: 1024, height: 633)
        )

                #expect(abs((scale.width) - (1)) < 0.0001)
                #expect(abs((scale.height) - (1)) < 0.0001)
    }

    @Test func screenshotPixelToWindowPointConvertsScreenshotPixelsBackToWindowPoints() {
        let point = screenshotPixelToWindowPoint(
            CGPoint(x: 1060, y: 790),
            screenshotPixelSize: CGSize(width: 2048, height: 1266),
            windowBounds: CGRect(x: 1938, y: 236, width: 1024, height: 633)
        )

                #expect(abs((point.x) - (530)) < 0.0001)
                #expect(abs((point.y) - (395)) < 0.0001)
    }

    @Test func screenshotPixelToWindowPointKeepsCoordinatesOnUnscaledDisplays() {
        let point = screenshotPixelToWindowPoint(
            CGPoint(x: 530, y: 395),
            screenshotPixelSize: CGSize(width: 1024, height: 633),
            windowBounds: CGRect(x: 1938, y: 236, width: 1024, height: 633)
        )

                #expect(point == CGPoint(x: 530, y: 395))
    }

    @Test func screenshotPixelToWindowPointFallsBackToIdentityWithoutImageSize() {
        let point = screenshotPixelToWindowPoint(
            CGPoint(x: 530, y: 395),
            screenshotPixelSize: nil,
            windowBounds: CGRect(x: 1938, y: 236, width: 1024, height: 633)
        )

                #expect(point == CGPoint(x: 530, y: 395))
    }

}
