import AppKit
import Testing
@testable import OpenAraKit

@Suite final class CursorMotionTests {
    @Test func cursorMotionPathStartsAndEndsAtExpectedPoints() {
        let path = CursorMotionPath(
            start: CGPoint(x: 10, y: 20),
            end: CGPoint(x: 210, y: 120)
        )

                #expect(path.point(at: 0) == CGPoint(x: 10, y: 20))
                #expect(path.point(at: 1) == CGPoint(x: 210, y: 120))

        let midpoint = path.point(at: 0.5)
                #expect(midpoint.x != 110)
                #expect(midpoint.y != 70)
    }

    @Test func cursorMotionPathSupportsStraightVariantForConservativeFallback() {
        let straightPath = CursorMotionPath(
            start: CGPoint(x: 10, y: 20),
            end: CGPoint(x: 210, y: 120),
            curveDirection: 0,
            curveScale: 0
        )

                #expect(straightPath.curveScale == 0)
                #expect(straightPath.point(at: 0) == CGPoint(x: 10, y: 20))
                #expect(straightPath.point(at: 1) == CGPoint(x: 210, y: 120))

        let midpoint = straightPath.point(at: 0.5)
                #expect(abs((midpoint.x) - (110)) < 0.001)
                #expect(abs((midpoint.y) - (70)) < 0.001)
    }

    @Test func officialCursorMotionModelBuildsTwentyCandidates() {
        let candidates = OfficialCursorMotionModel.makeCandidates(
            start: CGPoint(x: 100, y: 120),
            end: CGPoint(x: 720, y: 380),
            bounds: CGRect(x: 0, y: 0, width: 1280, height: 800)
        )

                #expect(candidates.count == 20)
    }

    @Test func officialCursorMotionModelChoosesScaledBaseForReferenceSample() {
        let candidates = OfficialCursorMotionModel.makeCandidates(
            start: CGPoint(x: 100, y: 120),
            end: CGPoint(x: 720, y: 380),
            bounds: CGRect(x: 0, y: 0, width: 1280, height: 800)
        )

        let chosen = OfficialCursorMotionModel.chooseBestCandidate(from: candidates)

                #expect(chosen?.identifier == "a1.05-b1.00-positive")
                #expect(chosen?.kind == .arched)
    }

    @Test func officialCursorMotionGuideProjectionFollowsPathBasisInsteadOfFixedScreenBias() throws {
        let rightUpCandidates = OfficialCursorMotionModel.makeCandidates(
            start: CGPoint(x: 120, y: 620),
            end: CGPoint(x: 960, y: 140),
            bounds: CGRect(x: 0, y: 0, width: 1280, height: 800)
        )
        let leftUpCandidates = OfficialCursorMotionModel.makeCandidates(
            start: CGPoint(x: 960, y: 620),
            end: CGPoint(x: 120, y: 140),
            bounds: CGRect(x: 0, y: 0, width: 1280, height: 800)
        )

        let rightUpStartControl = try #require(
            rightUpCandidates.first(where: { $0.identifier == "base-full-guide" })?.path.startControl
        )
        let leftUpStartControl = try #require(
            leftUpCandidates.first(where: { $0.identifier == "base-full-guide" })?.path.startControl
        )

                #expect(rightUpStartControl.x < 120)
                #expect(leftUpStartControl.x > 960)
    }

    @Test func officialCursorMotionSpringCloseEnoughTimeMatchesRecoveredReference() {
                #expect(abs((OfficialCursorMotionModel.closeEnoughTime) - (1.429166666666663)) < 0.000_001)
    }

    @Test func officialCursorMotionTravelDurationUsesRecoveredEndpointLockTiming() {
        let curvedMeasurement = CursorMotionMeasurement(
            length: 1280,
            angleChangeEnergy: 8,
            maxAngleChange: 1.2,
            totalTurn: 4,
            staysInBounds: true
        )

                #expect(abs((OfficialCursorMotionModel.calibratedTravelDuration(distance: 140, measurement: curvedMeasurement)) - (OfficialCursorMotionModel.closeEnoughTime)) < 0.000_001)
                #expect(OfficialCursorMotionModel.calibratedTravelDuration(distance: 900, measurement: curvedMeasurement) > 1.0)
    }

    @Test func headingDrivenMotionPrefersNearDirectPathWhenHeadingsAlreadyAlign() throws {
        let start = CGPoint(x: 120, y: 120)
        let end = CGPoint(x: 920, y: 320)
        let direction = normalizedVector(from: start, to: end)

        let candidates = HeadingDrivenCursorMotionModel.makeCandidates(
            start: start,
            end: end,
            bounds: CGRect(x: 0, y: 0, width: 1280, height: 800),
            startForward: direction,
            endForward: direction
        )
        let chosen = try #require(HeadingDrivenCursorMotionModel.chooseBestCandidate(from: candidates))
        let directDistance = hypot(end.x - start.x, end.y - start.y)

                #expect(chosen.side == 0)
                #expect(chosen.measurement.totalTurn < 0.45)
                #expect(chosen.measurement.length < directDistance * 1.03)
    }

    @Test func headingDrivenMotionPrefersTurnaroundArcWhenStartHeadingOpposesTravel() throws {
        let start = CGPoint(x: 220, y: 520)
        let end = CGPoint(x: 900, y: 280)
        let direction = normalizedVector(from: start, to: end)
        let opposite = CGVector(dx: -direction.dx, dy: -direction.dy)

        let directReference = try #require(
            HeadingDrivenCursorMotionModel.chooseBestCandidate(
                from: HeadingDrivenCursorMotionModel.makeCandidates(
                    start: start,
                    end: end,
                    bounds: CGRect(x: 0, y: 0, width: 1280, height: 800),
                    startForward: direction,
                    endForward: direction
                )
            )
        )
        let turnaround = try #require(
            HeadingDrivenCursorMotionModel.chooseBestCandidate(
                from: HeadingDrivenCursorMotionModel.makeCandidates(
                    start: start,
                    end: end,
                    bounds: CGRect(x: 0, y: 0, width: 1280, height: 800),
                    startForward: opposite,
                    endForward: direction
                )
            )
        )

                #expect(turnaround.side != 0)
                #expect(turnaround.measurement.totalTurn > directReference.measurement.totalTurn + 0.8)
                #expect(turnaround.measurement.length > directReference.measurement.length * 1.04)
    }

    @Test func cursorVisualDynamicsOvershootsAfterTargetStops() {
        let samples = simulateCursorVisualDynamics(
            stopTime: 0.18,
            targetDistance: 320,
            totalTime: 0.75
        )

        let maxX = samples.map(\.tipPosition.x).max() ?? 0
                #expect(maxX > 320.5)
                #expect(samples[32].fogOffset.dx < -0.25)
    }

    @Test func cursorVisualDynamicsKeepsAngleInertiaAfterTargetStops() {
        let samples = simulateCursorVisualDynamics(
            stopTime: 0.16,
            targetDistance: 280,
            totalTime: 0.92
        )

        let rotationJustAfterStop = abs(samples[42].rotation)
        let finalRotation = abs(samples.last?.rotation ?? 0)

                #expect(rotationJustAfterStop > 0.03)
                #expect(finalRotation < 0.02)
    }

    @Test func cursorVisualDynamicsTracksMovementHeadingInsteadOfOnlyWiggling() {
        let samples = simulateCursorVisualDynamics(
            stopTime: 0.45,
            targetDistance: 360,
            totalTime: 0.50
        )

        let peakRotation = samples.prefix(120).map { abs($0.rotation) }.max() ?? 0

                #expect(peakRotation > 1.5)
    }

    @Test func visualCursorIdlePoseKeepsTipAnchoredAndOnlyRotates() {
        let restingTipPosition = CGPoint(x: 184, y: 92)
        let positivePose = visualCursorIdlePose(restingTipPosition: restingTipPosition, phase: .pi / 2)
        let negativePose = visualCursorIdlePose(
            restingTipPosition: restingTipPosition,
            phase: (.pi / 2) + (.pi / CGFloat(0.8))
        )

                #expect(abs((positivePose.tipPosition.x) - (restingTipPosition.x)) < 0.0001)
                #expect(abs((positivePose.tipPosition.y) - (restingTipPosition.y)) < 0.0001)
                #expect(positivePose.angleOffset > 0)
                #expect(abs(positivePose.angleOffset) <= visualCursorIdleRotationAmplitude() + 0.0001)
                #expect(abs(positivePose.angleOffset) > 0.08)

                #expect(abs((negativePose.tipPosition.x) - (restingTipPosition.x)) < 0.0001)
                #expect(abs((negativePose.tipPosition.y) - (restingTipPosition.y)) < 0.0001)
                #expect(negativePose.angleOffset < 0)
                #expect(abs(negativePose.angleOffset) <= visualCursorIdleRotationAmplitude() + 0.0001)
                #expect(abs(negativePose.angleOffset) > 0.08)
    }

}
