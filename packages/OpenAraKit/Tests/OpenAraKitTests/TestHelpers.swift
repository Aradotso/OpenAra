import AppKit
@testable import OpenAraKit

// Shared helpers used across the split OpenAraKit test files.

func makeSampleSnapshot(
    treeLines: [String],
    focusedSummary: String?,
    selectedText: String? = nil
) -> AppSnapshot {
    AppSnapshot(
        app: RunningAppDescriptor(
            name: "Sample Chat",
            bundleIdentifier: "com.example.SampleChat",
            pid: 18_465,
            runningApplication: NSRunningApplication.current
        ),
        windowTitle: "Sample Chat",
        windowBounds: nil,
        targetWindowID: nil,
        targetWindowLayer: nil,
        screenshotPNGData: nil,
        mode: .accessibility,
        treeLines: treeLines,
        focusedSummary: focusedSummary,
        selectedText: selectedText,
        elements: [:]
    )
}

func simulateCursorVisualDynamics(
    stopTime: CGFloat,
    targetDistance: CGFloat,
    totalTime: CGFloat,
    stepCount: Int = 240
) -> [CursorVisualRenderState] {
    var state = CursorVisualDynamicsAnimator.state(at: CGPoint(x: 0, y: 0))
    var samples: [CursorVisualRenderState] = []

    for step in 1...stepCount {
        let time = totalTime * (CGFloat(step) / CGFloat(stepCount))
        let targetX: CGFloat
        if time < stopTime {
            targetX = targetDistance * (time / stopTime)
        } else {
            targetX = targetDistance
        }

        let result = CursorVisualDynamicsAnimator.advance(
            state: state,
            targetTipPosition: CGPoint(x: targetX, y: 0),
            targetTime: time,
            baseHeading: -(3 * .pi / 4)
        )
        state = result.state
        samples.append(result.renderState)
    }

    return samples
}

func normalizedAngle(_ angle: CGFloat) -> CGFloat {
    var value = angle
    while value > .pi {
        value -= 2 * .pi
    }
    while value < -.pi {
        value += 2 * .pi
    }
    return value
}

func normalizedVector(from start: CGPoint, to end: CGPoint) -> CGVector {
    let dx = end.x - start.x
    let dy = end.y - start.y
    let length = max(hypot(dx, dy), 0.001)
    return CGVector(dx: dx / length, dy: dy / length)
}
