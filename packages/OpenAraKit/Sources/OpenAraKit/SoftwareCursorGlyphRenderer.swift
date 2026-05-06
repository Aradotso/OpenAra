import AppKit
import CoreGraphics
import Foundation

struct SoftwareCursorGlyphRenderState {
    let rotation: CGFloat
    let cursorBodyOffset: CGVector
    let fogOffset: CGVector
    let fogOpacity: CGFloat
    let fogScale: CGFloat
    let clickProgress: CGFloat

    init(
        rotation: CGFloat,
        cursorBodyOffset: CGVector,
        fogOffset: CGVector,
        fogOpacity: CGFloat,
        fogScale: CGFloat,
        clickProgress: CGFloat
    ) {
        self.rotation = rotation
        self.cursorBodyOffset = cursorBodyOffset
        self.fogOffset = fogOffset
        self.fogOpacity = fogOpacity
        self.fogScale = fogScale
        self.clickProgress = clickProgress
    }

    var appKitDrawingState: SoftwareCursorGlyphRenderState {
        SoftwareCursorGlyphRenderState(
            rotation: -rotation,
            cursorBodyOffset: CGVector(dx: cursorBodyOffset.dx, dy: -cursorBodyOffset.dy),
            fogOffset: CGVector(dx: fogOffset.dx, dy: -fogOffset.dy),
            fogOpacity: fogOpacity,
            fogScale: fogScale,
            clickProgress: clickProgress
        )
    }
}

enum SoftwareCursorGlyphMetrics {
    // Window + tip anchor were originally calibrated at 126x126 with the tip at
    // (60.35, 70.3). Shrunk uniformly by ~30% so the cursor reads as a
    // companion glyph instead of a giant overlay blob, while preserving the
    // tip-to-target alignment.
    static let windowSize = CGSize(width: 88, height: 88)
    static let tipAnchor = CGPoint(x: 42.15, y: 49.10)
    static let referenceImageResourceName = "official-software-cursor-window-252"

    static let pointerSize = CGSize(width: 21, height: 21)
    static let pointerOffset = CGPoint(x: 2.6, y: -3.2)
    static let targetNeutralHeading = -(3 * CGFloat.pi / 4)
    static let proceduralContourNeutralHeading = -(96.5 * CGFloat.pi / 180)
    static let pointerArtworkRotation = -(targetNeutralHeading - proceduralContourNeutralHeading)
}

private enum SoftwareCursorGlyphColors {
    static let pointerFill = NSColor(calibratedRed: 0.38, green: 0.36, blue: 0.35, alpha: 0.98)
    static let pointerStroke = NSColor(calibratedWhite: 0.90, alpha: 0.92)
}

public enum OpenAraCursorVariant {
    public static let all: [String] = ["orange", "blue", "green", "pink", "graphite", "white"]

    public static func resolve(client: String?, pid: Int32) -> String {
        let env = ProcessInfo.processInfo.environment["OPENARA_CURSOR_COLOR"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if let env, all.contains(env) {
            return env
        }
        let trimmed = (client ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        var seed: UInt64 = UInt64(bitPattern: Int64(pid))
        for byte in trimmed.utf8 {
            seed = seed &* 1099511628211 &+ UInt64(byte)
        }
        return all[Int(seed % UInt64(all.count))]
    }
}

/// Per-tab tint applied on top of the bundled cursor glyph. The 10 entries
/// here mirror `FloatingChatTab.palette` in the AraDesktop app one-to-one
/// — when a tab spawns a computer-use tool call, the openara MCP child is
/// launched with `OPENARA_CURSOR_INDEX=<idx>` in its env, the renderer
/// looks up `colors[idx]`, and the cursor body is recoloured to match
/// the tab's border. **Keep these RGB values in lockstep with
/// `FloatingChatTab.palette` in
/// `AraDesktop/Desktop/Sources/FloatingControlBar/FloatingControlBarState.swift`.**
public enum OpenAraCursorPalette {
    public static let envIndexKey = "OPENARA_CURSOR_INDEX"

    public static let colors: [NSColor] = [
        NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.95, alpha: 1.0),  // 0 blue
        NSColor(calibratedRed: 0.95, green: 0.50, blue: 0.20, alpha: 1.0),  // 1 orange
        NSColor(calibratedRed: 0.40, green: 0.75, blue: 0.40, alpha: 1.0),  // 2 green
        NSColor(calibratedRed: 0.85, green: 0.35, blue: 0.65, alpha: 1.0),  // 3 pink
        NSColor(calibratedRed: 0.60, green: 0.40, blue: 0.85, alpha: 1.0),  // 4 purple
        NSColor(calibratedRed: 0.95, green: 0.75, blue: 0.20, alpha: 1.0),  // 5 amber
        NSColor(calibratedRed: 0.20, green: 0.70, blue: 0.70, alpha: 1.0),  // 6 teal
        NSColor(calibratedRed: 0.90, green: 0.30, blue: 0.30, alpha: 1.0),  // 7 red
        NSColor(calibratedRed: 0.30, green: 0.40, blue: 0.85, alpha: 1.0),  // 8 indigo
        NSColor(calibratedRed: 0.85, green: 0.25, blue: 0.85, alpha: 1.0),  // 9 magenta
    ]

    /// Pull the tab colour-index from the process env (set by acp-bridge
    /// when it spawns the openara MCP child for a given tab/session).
    /// Returns `nil` when unset, malformed, or out of range — caller falls
    /// back to the legacy variant-PNG path so old plumbing keeps working.
    public static func resolveTintFromEnvironment() -> NSColor? {
        guard let raw = ProcessInfo.processInfo.environment[envIndexKey],
              let idx = Int(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              colors.indices.contains(idx)
        else {
            return nil
        }
        return colors[idx]
    }
}

@MainActor
enum SoftwareCursorGlyphRenderer {
    private static var openAraGlyph: NSImage? = loadOpenAraCursorGlyphImage(variant: currentVariant)
    private static let referenceImage = loadReferenceCursorWindowImage()
    private static var currentVariant: String = OpenAraCursorVariant.resolve(client: nil, pid: getpid())

    /// Tab-derived tint applied on top of the bundled cursor PNG.
    /// `nil` = no tint, glyph renders in its natural colours. Set at MCP
    /// `initialize` from `OPENARA_CURSOR_INDEX` and never changes
    /// afterwards (each MCP child belongs to exactly one tab for its
    /// whole lifetime).
    /// **Scope:** the tint is only applied in the PNG-glyph draw path
    /// (`drawOpenAraGlyph`). The reference-image and procedural-pointer
    /// fallbacks below keep their original hard-coded fill, since those
    /// paths only fire when the bundled glyph PNGs are missing — i.e.
    /// during local development on a stripped build, where matching the
    /// host tab's colour is not load-bearing.
    private static var currentTint: NSColor? = OpenAraCursorPalette.resolveTintFromEnvironment()

    static func setCursorVariant(_ variant: String) {
        guard variant != currentVariant else { return }
        currentVariant = variant
        openAraGlyph = loadOpenAraCursorGlyphImage(variant: variant)
    }

    /// Override the per-tab tint. Pass `nil` to clear and fall back to
    /// the variant PNG's natural colour.
    static func setCursorTint(_ tint: NSColor?) {
        currentTint = tint
    }

    static var activeVariant: String {
        currentVariant
    }

    static func draw(
        in bounds: CGRect,
        context: CGContext,
        state: SoftwareCursorGlyphRenderState
    ) {
        let drawingState = state.appKitDrawingState

        if let openAraGlyph {
            drawOpenAraGlyph(
                openAraGlyph,
                in: bounds,
                context: context,
                state: drawingState
            )
            return
        }

        if let referenceImage {
            drawReferenceImage(
                referenceImage,
                in: bounds,
                context: context,
                state: drawingState
            )
            return
        }

        let pulse = drawingState.clickProgress
        let fogCenter = CGPoint(
            x: bounds.midX + drawingState.fogOffset.dx,
            y: bounds.midY + drawingState.fogOffset.dy
        )
        let pointerCenter = CGPoint(
            x: bounds.midX + SoftwareCursorGlyphMetrics.pointerOffset.x + drawingState.cursorBodyOffset.dx,
            y: bounds.midY + SoftwareCursorGlyphMetrics.pointerOffset.y + drawingState.cursorBodyOffset.dy + (pulse * 0.35)
        )

        drawFog(
            in: context,
            center: fogCenter,
            pulse: pulse,
            fogOpacity: state.fogOpacity,
            fogScale: state.fogScale
        )
        drawPointer(
            in: context,
            center: pointerCenter,
            rotation: drawingState.rotation,
            clickProgress: pulse,
            cursorBodyOffset: drawingState.cursorBodyOffset,
            boundsMidpoint: CGPoint(x: bounds.midX, y: bounds.midY)
        )
    }

    private static func drawOpenAraGlyph(
        _ image: NSImage,
        in bounds: CGRect,
        context: CGContext,
        state: SoftwareCursorGlyphRenderState
    ) {
        let pulseCompression = state.clickProgress * 0.04
        let motionCompression = min(hypot(state.cursorBodyOffset.dx, state.cursorBodyOffset.dy) * 0.005, 0.012)

        context.saveGState()
        context.interpolationQuality = .high
        context.translateBy(
            x: bounds.midX + state.cursorBodyOffset.dx,
            y: bounds.midY + state.cursorBodyOffset.dy
        )
        let scale = 1 - motionCompression - pulseCompression
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.midX, y: -bounds.midY)
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)

        // Tab-tint overlay: paint the tint over the just-drawn glyph using
        // `.sourceAtop` so the colour clips to the glyph's alpha (no bleed
        // outside the cursor silhouette). This replaces the variant PNG's
        // hue wholesale — we lose the original colour's highlights, but the
        // cursor reliably reads as the tab's colour, which is the whole
        // point. Skipped when no tint is set so the original variant PNG
        // renders untouched.
        if let tint = currentTint {
            NSGraphicsContext.saveGraphicsState()
            tint.setFill()
            bounds.fill(using: .sourceAtop)
            NSGraphicsContext.restoreGraphicsState()
        }

        context.restoreGState()
    }

    private static func drawReferenceImage(
        _ image: NSImage,
        in bounds: CGRect,
        context: CGContext,
        state: SoftwareCursorGlyphRenderState
    ) {
        let motionCompression = min(hypot(state.cursorBodyOffset.dx, state.cursorBodyOffset.dy) * 0.008, 0.018)
        let pulseCompression = state.clickProgress * 0.03

        context.saveGState()
        context.interpolationQuality = .high
        context.translateBy(
            x: bounds.midX + state.cursorBodyOffset.dx,
            y: bounds.midY + state.cursorBodyOffset.dy
        )
        context.rotate(by: state.rotation)
        context.scaleBy(
            x: 1 - motionCompression - pulseCompression,
            y: 1 + (pulseCompression * 0.4)
        )
        context.translateBy(x: -bounds.midX, y: -bounds.midY)
        image.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
        context.restoreGState()
    }

    private static func drawFog(
        in context: CGContext,
        center: CGPoint,
        pulse: CGFloat,
        fogOpacity: CGFloat,
        fogScale: CGFloat
    ) {
        let radius = ((66 * fogScale) / 2) + (pulse * 1.2)
        let glowRadius = radius * (0.30 + (pulse * 0.025))
        let opacityMultiplier = max(0.28, min(fogOpacity / 0.12, 2.2))
        let colors = [
            NSColor(calibratedRed: 0.38, green: 0.36, blue: 0.35, alpha: (0.40 + (pulse * 0.02)) * opacityMultiplier).cgColor,
            NSColor(calibratedRed: 0.43, green: 0.41, blue: 0.40, alpha: (0.28 + (pulse * 0.015)) * opacityMultiplier).cgColor,
            NSColor(calibratedRed: 0.46, green: 0.44, blue: 0.43, alpha: 0.11 * opacityMultiplier).cgColor,
            NSColor(calibratedWhite: 0.60, alpha: 0.0).cgColor,
        ] as CFArray
        let locations: [CGFloat] = [0, 0.50, 0.82, 1]
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) else {
            return
        }

        context.saveGState()
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        context.restoreGState()

        let coreColors = [
            NSColor(calibratedRed: 0.41, green: 0.39, blue: 0.38, alpha: (0.020 + (pulse * 0.006)) * opacityMultiplier).cgColor,
            NSColor(calibratedRed: 0.44, green: 0.41, blue: 0.40, alpha: 0.008 * opacityMultiplier).cgColor,
            NSColor(calibratedWhite: 0.80, alpha: 0.0).cgColor,
        ] as CFArray
        let coreLocations: [CGFloat] = [0, 0.62, 1]
        guard let coreGradient = CGGradient(colorsSpace: colorSpace, colors: coreColors, locations: coreLocations) else {
            return
        }

        context.saveGState()
        context.drawRadialGradient(
            coreGradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: glowRadius,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    private static func drawPointer(
        in context: CGContext,
        center: CGPoint,
        rotation: CGFloat,
        clickProgress: CGFloat,
        cursorBodyOffset: CGVector,
        boundsMidpoint: CGPoint
    ) {
        let pointerRect = CGRect(
            x: center.x - (SoftwareCursorGlyphMetrics.pointerSize.width / 2),
            y: center.y - (SoftwareCursorGlyphMetrics.pointerSize.height / 2),
            width: SoftwareCursorGlyphMetrics.pointerSize.width,
            height: SoftwareCursorGlyphMetrics.pointerSize.height
        )
        let outerPath = pointerPath(in: pointerRect)

        context.saveGState()
        context.translateBy(
            x: boundsMidpoint.x + cursorBodyOffset.dx,
            y: boundsMidpoint.y + cursorBodyOffset.dy
        )
        context.rotate(by: rotation)
        context.scaleBy(x: 1 - (clickProgress * 0.04), y: 1 + (clickProgress * 0.02))
        context.translateBy(
            x: -(boundsMidpoint.x + cursorBodyOffset.dx),
            y: -(boundsMidpoint.y + cursorBodyOffset.dy)
        )
        context.translateBy(x: center.x, y: center.y)
        context.rotate(by: SoftwareCursorGlyphMetrics.pointerArtworkRotation)
        context.translateBy(x: -center.x, y: -center.y)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 3.2 + (clickProgress * 1.4)
        shadow.shadowOffset = CGSize(width: 0, height: -0.35)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.11)
        shadow.set()
        NSColor.black.withAlphaComponent(0.05).setFill()
        outerPath.fill()
        NSGraphicsContext.restoreGraphicsState()

        SoftwareCursorGlyphColors.pointerFill.setFill()
        outerPath.fill()

        SoftwareCursorGlyphColors.pointerStroke.setStroke()
        outerPath.lineWidth = 1.55
        outerPath.lineJoinStyle = .round
        outerPath.lineCapStyle = .round
        outerPath.stroke()

        context.restoreGState()
    }

    private static func pointerPath(in rect: CGRect) -> NSBezierPath {
        let contourRows: [(y: CGFloat, minX: CGFloat, maxX: CGFloat)] = [
            (39, 17, 21), (38, 16, 22), (37, 15, 22), (36, 15, 23), (35, 15, 24),
            (34, 15, 24), (33, 14, 25), (32, 14, 25), (31, 14, 26), (30, 14, 27),
            (29, 13, 29), (28, 13, 31), (27, 13, 34), (26, 13, 36), (25, 13, 37),
            (24, 12, 37), (23, 12, 37), (22, 12, 37), (21, 12, 37), (20, 12, 36),
            (19, 11, 36), (18, 11, 34), (17, 11, 32), (16, 11, 30), (15, 10, 27),
            (14, 10, 25), (13, 10, 23), (12, 11, 21), (11, 11, 19), (10, 13, 16),
        ]
        let sourceMinX: CGFloat = 10
        let sourceMaxX: CGFloat = 38
        let sourceMinY: CGFloat = 10
        let sourceMaxY: CGFloat = 39

        func mappedPoint(x: CGFloat, y: CGFloat) -> CGPoint {
            CGPoint(
                x: rect.minX + ((x - sourceMinX) / (sourceMaxX - sourceMinX) * rect.width),
                y: rect.minY + ((y - sourceMinY) / (sourceMaxY - sourceMinY) * rect.height)
            )
        }

        let leftBoundary = contourRows.map { mappedPoint(x: $0.minX, y: $0.y) }
        let rightBoundary = contourRows.reversed().map { mappedPoint(x: $0.maxX, y: $0.y) }

        let path = NSBezierPath()
        path.move(to: leftBoundary[0])
        leftBoundary.dropFirst().forEach { path.line(to: $0) }
        rightBoundary.forEach { path.line(to: $0) }
        path.close()
        path.lineJoinStyle = .round
        return path
    }
}

func loadOpenAraCursorGlyphImage(variant: String = "orange") -> NSImage? {
    let candidates = [
        "openara-cursor-\(variant)-256",
        "openara-cursor-256",
    ]

    for name in candidates {
        if let url = OpenAraKitResources.url(forResource: name, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = OpenAraKitResources.url(forResource: "cursors/\(name)", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
    }

    return nil
}

func loadReferenceCursorWindowImage() -> NSImage? {
    let resourceName = SoftwareCursorGlyphMetrics.referenceImageResourceName

    if let url = OpenAraKitResources.url(forResource: resourceName, withExtension: "png"),
       let image = NSImage(contentsOf: url) {
        return image
    }

    if let url = Bundle.main.url(forResource: resourceName, withExtension: "png"),
       let image = NSImage(contentsOf: url) {
        return image
    }

    return nil
}
