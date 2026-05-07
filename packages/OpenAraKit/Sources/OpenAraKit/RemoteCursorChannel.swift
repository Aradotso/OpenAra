import AppKit
import CoreGraphics
import Foundation

/// Distributed-notification names the openara overlay listens on when
/// `OPENARA_REMOTE_CURSOR=1` is set. The host (Ara Desktop's acp-bridge)
/// posts these to drive the existing `SoftwareCursorOverlay` from outside
/// the openara process — e.g. to narrate Playwright/CDP browser clicks
/// alongside the AX/native clicks the openara MCP server already animates
/// internally. The cursor stays a single coherent presence regardless of
/// which mechanism fired the action underneath.
public enum OpenAraRemoteCursorNotification {
    public static let move = Notification.Name("so.ara.openara.remote-cursor.move")
    public static let pulse = Notification.Name("so.ara.openara.remote-cursor.pulse")
    public static let reset = Notification.Name("so.ara.openara.remote-cursor.reset")
}

/// UserInfo keys for the remote-cursor notifications. Values are NSNumber
/// (Double for coords, Int for clicks) and NSString (button). Distributed
/// notifications allow plist types only — keep this in sync with the
/// host-side narrator.
public enum OpenAraRemoteCursorKey {
    public static let x = "x"
    public static let y = "y"
    public static let clicks = "clicks"
    public static let button = "button"
}

/// Build the per-process `object` filter for remote-cursor notifications.
/// Mirrors `openAraTurnEndedNotificationObject(pid:)` so the host can
/// address a specific openara child (one per tab) without every running
/// openara honoring every host post.
public func openAraRemoteCursorNotificationObject(pid: Int32) -> String {
    "pid:\(pid)"
}

/// Convenience for the host: returns true when the openara process should
/// register the remote-cursor observer. Off by default; the host opts in
/// per child via `OPENARA_REMOTE_CURSOR=1`.
public func openAraRemoteCursorEnabled(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
    let raw = environment["OPENARA_REMOTE_CURSOR"]?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    guard let raw, !raw.isEmpty else { return false }
    return !["0", "false", "no", "off"].contains(raw)
}

/// Register the three remote-cursor observers for this process. Returns
/// the observer tokens so the caller can remove them on teardown.
/// Coordinates are interpreted in AppKit global screen space (origin
/// bottom-left, y-up) — the same space `SoftwareCursorOverlay.moveCursor`
/// already accepts.
@MainActor
public func startOpenAraRemoteCursorChannel(pid: Int32) -> [NSObjectProtocol] {
    guard VisualCursorSupport.isEnabled else {
        return []
    }

    let center = DistributedNotificationCenter.default()
    let object = openAraRemoteCursorNotificationObject(pid: pid)

    let move = center.addObserver(
        forName: OpenAraRemoteCursorNotification.move,
        object: object,
        queue: .main
    ) { note in
        guard let info = note.userInfo,
              let x = (info[OpenAraRemoteCursorKey.x] as? NSNumber)?.doubleValue,
              let y = (info[OpenAraRemoteCursorKey.y] as? NSNumber)?.doubleValue
        else { return }
        Task { @MainActor in
            SoftwareCursorOverlay.moveCursor(to: CGPoint(x: x, y: y), in: nil)
        }
    }

    let pulse = center.addObserver(
        forName: OpenAraRemoteCursorNotification.pulse,
        object: object,
        queue: .main
    ) { note in
        guard let info = note.userInfo,
              let x = (info[OpenAraRemoteCursorKey.x] as? NSNumber)?.doubleValue,
              let y = (info[OpenAraRemoteCursorKey.y] as? NSNumber)?.doubleValue
        else { return }
        let clicks = (info[OpenAraRemoteCursorKey.clicks] as? NSNumber)?.intValue ?? 1
        let buttonRaw = (info[OpenAraRemoteCursorKey.button] as? String)?.lowercased() ?? "left"
        let button: MouseButtonKind = (buttonRaw == "right") ? .right : .left
        Task { @MainActor in
            SoftwareCursorOverlay.pulseClick(
                at: CGPoint(x: x, y: y),
                clickCount: max(clicks, 1),
                mouseButton: button,
                in: nil
            )
        }
    }

    let reset = center.addObserver(
        forName: OpenAraRemoteCursorNotification.reset,
        object: object,
        queue: .main
    ) { _ in
        Task { @MainActor in
            SoftwareCursorOverlay.reset()
        }
    }

    return [move, pulse, reset]
}

/// Symmetric remove helper. Safe to call with the array returned from
/// `startOpenAraRemoteCursorChannel` even if some entries are stale.
public func stopOpenAraRemoteCursorChannel(_ observers: [NSObjectProtocol]) {
    let center = DistributedNotificationCenter.default()
    for observer in observers {
        center.removeObserver(observer)
    }
}

/// Post helper for the host (and tests). Sends one of the three remote-cursor
/// notifications targeted at a specific openara child. Use the typed
/// wrappers below in normal code; this exists for tests and tooling that
/// want to drive the channel from a generic call site.
public func postOpenAraRemoteCursorNotification(
    _ name: Notification.Name,
    targetPID: Int32,
    userInfo: [String: Any]? = nil
) {
    DistributedNotificationCenter.default().postNotificationName(
        name,
        object: openAraRemoteCursorNotificationObject(pid: targetPID),
        userInfo: userInfo,
        deliverImmediately: true
    )
}

public func postOpenAraRemoteCursorMove(targetPID: Int32, x: Double, y: Double) {
    postOpenAraRemoteCursorNotification(
        OpenAraRemoteCursorNotification.move,
        targetPID: targetPID,
        userInfo: [
            OpenAraRemoteCursorKey.x: NSNumber(value: x),
            OpenAraRemoteCursorKey.y: NSNumber(value: y),
        ]
    )
}

public func postOpenAraRemoteCursorPulse(
    targetPID: Int32,
    x: Double,
    y: Double,
    clicks: Int = 1,
    button: String = "left"
) {
    postOpenAraRemoteCursorNotification(
        OpenAraRemoteCursorNotification.pulse,
        targetPID: targetPID,
        userInfo: [
            OpenAraRemoteCursorKey.x: NSNumber(value: x),
            OpenAraRemoteCursorKey.y: NSNumber(value: y),
            OpenAraRemoteCursorKey.clicks: NSNumber(value: clicks),
            OpenAraRemoteCursorKey.button: button,
        ]
    )
}

public func postOpenAraRemoteCursorReset(targetPID: Int32) {
    postOpenAraRemoteCursorNotification(
        OpenAraRemoteCursorNotification.reset,
        targetPID: targetPID
    )
}
