import AppKit
import Testing
@testable import OpenAraKit

@Suite final class VisualCursorTests {
    @Test func cursorWindowGeometryAnchorsTipPosition() {
        let geometry = CursorWindowGeometry(
            windowSize: CGSize(width: 128, height: 128),
            tipAnchor: CGPoint(x: 44, y: 88)
        )
        let tipPosition = CGPoint(x: 1200, y: 800)

                #expect(geometry.origin(forTipPosition: tipPosition) == CGPoint(x: 1156, y: 712))
                #expect(geometry.tipPosition(forOrigin: CGPoint(x: 1156, y: 712)) == tipPosition)
    }

    @Test func softwareCursorGlyphMetricsMatchRuntimeProceduralCalibration() {
                #expect(SoftwareCursorGlyphMetrics.windowSize == CGSize(width: 88, height: 88))
                #expect(abs((SoftwareCursorGlyphMetrics.tipAnchor.x) - (42.15)) < 0.01)
                #expect(abs((SoftwareCursorGlyphMetrics.tipAnchor.y) - (49.10)) < 0.01)
                #expect(SoftwareCursorGlyphMetrics.referenceImageResourceName == "official-software-cursor-window-252")
    }

    @Test func softwareCursorGlyphLoadsCursorMotionReferenceImage() throws {
        let image = try #require(loadReferenceCursorWindowImage())
        let bitmap = try #require(image.representations.first)

                #expect(bitmap.pixelsWide == 252)
                #expect(bitmap.pixelsHigh == 252)
    }

    @Test func softwareCursorGlyphArtworkNeutralHeadingMatchesCursorMotionBaseline() {
        let correctedNeutralHeading = SoftwareCursorGlyphMetrics.proceduralContourNeutralHeading
            - SoftwareCursorGlyphMetrics.pointerArtworkRotation

                #expect(abs((correctedNeutralHeading) - (SoftwareCursorGlyphMetrics.targetNeutralHeading)) < 0.001)
                #expect(abs((SoftwareCursorGlyphMetrics.targetNeutralHeading) - (-(3 * CGFloat.pi / 4))) < 0.001)
    }

    @Test func softwareCursorGlyphConvertsScreenStateToAppKitDrawingState() {
        let screenState = SoftwareCursorGlyphRenderState(
            rotation: .pi / 3,
            cursorBodyOffset: CGVector(dx: 2, dy: -4),
            fogOffset: CGVector(dx: -3, dy: 5),
            fogOpacity: 0.2,
            fogScale: 1.1,
            clickProgress: 0.6
        )

        let drawingState = screenState.appKitDrawingState

                #expect(abs((drawingState.rotation) - (-.pi / 3)) < 0.0001)
                #expect(abs((drawingState.cursorBodyOffset.dx) - (2)) < 0.0001)
                #expect(abs((drawingState.cursorBodyOffset.dy) - (4)) < 0.0001)
                #expect(abs((drawingState.fogOffset.dx) - (-3)) < 0.0001)
                #expect(abs((drawingState.fogOffset.dy) - (-5)) < 0.0001)
                #expect(drawingState.fogOpacity == 0.2)
                #expect(drawingState.fogScale == 1.1)
                #expect(drawingState.clickProgress == 0.6)
    }

    @Test func defaultVisualCursorInitialTipMatchesZeroWindowOrigin() {
        let geometry = CursorWindowGeometry(
            windowSize: CGSize(width: 126, height: 126),
            tipAnchor: CGPoint(x: 60.35, y: 70.3)
        )
        let start = defaultVisualCursorInitialTipPosition(
            windowOrigin: .zero,
            tipAnchor: geometry.tipAnchor
        )

                #expect(geometry.origin(forTipPosition: start) == .zero)
                #expect(abs((start.x) - (geometry.tipAnchor.x)) < 0.0001)
                #expect(abs((start.y) - (geometry.tipAnchor.y)) < 0.0001)
    }

    @Test func visualCursorKeepsPostInteractionIdleStateLongEnoughForFollowupTools() {
                #expect(visualCursorPostInteractionIdleTimeout() == 30)
                #expect(visualCursorPostInteractionIdleTimeout() >= 30)
    }

    @Test func cursorPanelReordersWhenForcedEvenIfTargetWindowDidNotChange() {
        let targetWindow = CursorTargetWindow(windowID: 42, layer: 0)

                #expect(shouldReorderCursorPanel( activeTargetWindow: targetWindow, effectiveTargetWindow: targetWindow, panelIsVisible: true, forceReorder: true ))
    }

    @Test func cursorPanelDoesNotReorderWhenVisibleAndTargetWindowIsStable() {
        let targetWindow = CursorTargetWindow(windowID: 42, layer: 0)

                #expect(!(shouldReorderCursorPanel( activeTargetWindow: targetWindow, effectiveTargetWindow: targetWindow, panelIsVisible: true, forceReorder: false )))
    }

    @Test func visualCursorRuntimeMapsAppKitUpwardMotionToCursorMotionScreenState() {
        let renderBaseHeading = visualCursorRenderBaseHeading(
            artworkNeutralHeading: SoftwareCursorGlyphMetrics.targetNeutralHeading
        )
        let screenVelocity = visualCursorScreenStateVelocity(
            fromRuntimeVelocity: CGVector(dx: 0, dy: 1),
            yAxisMultiplier: visualCursorRuntimeRenderYAxisMultiplier()
        )
        let renderRotation = normalizedAngle(atan2(screenVelocity.dy, screenVelocity.dx) - renderBaseHeading)
        let appKitForwardHeading = visualCursorAppKitForwardHeading(
            renderRotation: renderRotation,
            artworkNeutralHeading: SoftwareCursorGlyphMetrics.targetNeutralHeading
        )

                #expect(abs((renderBaseHeading) - (-(3 * CGFloat.pi / 4))) < 0.0001)
                #expect(abs((screenVelocity.dx) - (0)) < 0.0001)
                #expect(abs((screenVelocity.dy) - (-1)) < 0.0001)
                #expect(abs((renderRotation) - (CGFloat.pi / 4)) < 0.0001)
                #expect(abs((normalizedAngle(appKitForwardHeading)) - (CGFloat.pi / 2)) < 0.0001)
                #expect(abs((visualCursorAppKitForwardHeading( renderRotation: 0, artworkNeutralHeading: SoftwareCursorGlyphMetrics.targetNeutralHeading )) - (3 * CGFloat.pi / 4)) < 0.0001)
    }

    @Test func cursorVariantResolveIsDeterministicForSameInputs() {
        let a = OpenAraCursorVariant.resolve(client: "claude-code", pid: 1234)
        let b = OpenAraCursorVariant.resolve(client: "claude-code", pid: 1234)
        #expect(a == b)
        #expect(OpenAraCursorVariant.all.contains(a))
    }

    @Test func cursorVariantResolveDiffersAcrossPIDsForSameClient() {
        let pids: [Int32] = [1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008]
        let assignments = Set(pids.map { OpenAraCursorVariant.resolve(client: "claude-code", pid: $0) })
        // 8 PIDs across 6 variants — at least 3 distinct colors should appear.
        #expect(assignments.count >= 3)
    }

    @Test func cursorVariantResolveHonorsEnvOverride() {
        setenv("OPENARA_CURSOR_COLOR", "green", 1)
        defer { unsetenv("OPENARA_CURSOR_COLOR") }
        #expect(OpenAraCursorVariant.resolve(client: "claude-code", pid: 1234) == "green")
    }

    @Test func cursorVariantResolveIgnoresInvalidEnvOverride() {
        setenv("OPENARA_CURSOR_COLOR", "chartreuse", 1)
        defer { unsetenv("OPENARA_CURSOR_COLOR") }
        let resolved = OpenAraCursorVariant.resolve(client: "claude-code", pid: 1234)
        #expect(OpenAraCursorVariant.all.contains(resolved))
        #expect(resolved != "chartreuse")
    }

    @Test func loadOpenAraCursorGlyphImageFindsBlueVariant() throws {
        let image = try #require(loadOpenAraCursorGlyphImage(variant: "blue"))
        let bitmap = try #require(image.representations.first)
        #expect(bitmap.pixelsWide >= 200)
    }

}
