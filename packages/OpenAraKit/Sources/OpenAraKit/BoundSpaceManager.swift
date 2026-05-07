import AppKit
import CoreGraphics
import Darwin
import Foundation

/// BoundSpaceManager — host integration for "per-thread Mission Control
/// space" features like Ara Desktop's tab→space binding. When the host
/// sets the `OPENARA_BOUND_SPACE_ID` env var, OpenAra wraps app launches
/// in a silent SLS-switch dance so the new app's windows land on the
/// host-specified Mission Control space without disrupting the user's
/// current view.
///
/// **The trick:**
/// - `SLSManagedDisplaySetCurrentSpace(cid, displayUUID, sid)` updates
///   WindowServer's bookkeeping current-space silently (no animation
///   when called from a non-frontmost background app like OpenAra's
///   MCP child).
/// - `NSWorkspace.openApplication(activates: false)` launches an app
///   without bringing it to the foreground.
/// - WindowServer places newly-created windows on the *bookkeeping*
///   current space, not the visually-rendered one.
/// - So: silent-switch to bound → open app → silent-switch back. The
///   app's window is on the bound space; the user never saw their
///   view change.
///
/// **Empirically verified** on macOS Tahoe (Darwin 25.x): Calculator
/// launched on space 3 while user view stayed on space 4, then the
/// bookkeeping current was restored to 4 with no visible flicker.
///
/// **Also handles direct window-move** as a fallback. If the app is
/// already running and reuses an existing window when the agent calls
/// "open Calculator" again, the window may already be on the user's
/// current space. We attempt `SLSAddWindowsToSpaces` + `SLSRemoveWindows…`
/// as a best-effort. On modern macOS with full SIP these are usually
/// entitlement-gated and silently no-op — the silent-switch dance is
/// the primary mechanism.
///
/// Disabled-state safety: every public method short-circuits when
/// `boundSpaceId` is nil. Callers can unconditionally invoke
/// `withBoundSpace { … }`; if the host hasn't opted in via the env
/// var, the closure runs unwrapped.
public final class BoundSpaceManager: @unchecked Sendable {
    public static let shared = BoundSpaceManager()

    /// CGSSpaceID set by the host via `OPENARA_BOUND_SPACE_ID`. Read
    /// once at init; subsequent host changes require a new OpenAra
    /// process (matches the existing OPENARA_CURSOR_INDEX lifecycle).
    public let boundSpaceId: UInt64?

    /// True iff every required private symbol resolved AND the host
    /// opted in via the env var. Drives the fast no-op path for
    /// hosts that don't use this feature.
    public var isActive: Bool { boundSpaceId != nil && _setCurrentSpace != nil }

    private let cid: UInt32
    private let _setCurrentSpace: (@convention(c) (UInt32, CFString, UInt64) -> Void)?
    private let _getCurrentSpace: (@convention(c) (UInt32, CFString) -> UInt64)?

    private init() {
        let raw = ProcessInfo.processInfo.environment["OPENARA_BOUND_SPACE_ID"] ?? ""
        let parsed = UInt64(raw.trimmingCharacters(in: .whitespaces))
        self.boundSpaceId = (parsed.map { $0 > 0 } == true) ? parsed : nil

        guard let handle = dlopen(
            "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight",
            RTLD_LAZY
        ) else {
            self.cid = 0
            self._setCurrentSpace = nil
            self._getCurrentSpace = nil
            return
        }

        func sym<T>(_ name: String, as type: T.Type) -> T? {
            guard let raw = dlsym(handle, name) else { return nil }
            return unsafeBitCast(raw, to: T.self)
        }

        let mainConn = sym("SLSMainConnectionID", as: (@convention(c) () -> UInt32).self)
        self.cid = mainConn?() ?? 0
        self._setCurrentSpace = sym("SLSManagedDisplaySetCurrentSpace", as: (@convention(c) (UInt32, CFString, UInt64) -> Void).self)
        self._getCurrentSpace = sym("SLSManagedDisplayGetCurrentSpace", as: (@convention(c) (UInt32, CFString) -> UInt64).self)
    }

    private var mainDisplayUUID: CFString? {
        let did = CGMainDisplayID()
        guard let cf = CGDisplayCreateUUIDFromDisplayID(did)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, cf)
    }

    /// Run `body` with WindowServer's bookkeeping current-space
    /// temporarily set to the host-bound space, then hold the flip
    /// for `windowSettleNanos` after `body` returns so the launched
    /// app has time to place its window on the bound space before we
    /// restore. Empirically a real Calculator launch needs ~1s
    /// between the NSWorkspace callback firing and the window being
    /// hooked into WindowServer's space registry; we use 1.5s to be
    /// safe on slower-launching apps.
    ///
    /// No-op fast path when the host hasn't opted in; the closure
    /// runs unwrapped with no SLS calls or sleeps.
    public func withBoundSpace<T>(
        windowSettleNanos: UInt64 = 1_500_000_000,
        _ body: () async throws -> T
    ) async rethrows -> T {
        guard isActive,
              let target = boundSpaceId,
              let setCurrent = _setCurrentSpace,
              let getCurrent = _getCurrentSpace,
              let uuid = mainDisplayUUID
        else {
            return try await body()
        }

        let original = getCurrent(cid, uuid)
        if original == target {
            return try await body()
        }

        setCurrent(cid, uuid, target)
        // Brief settle so WindowServer commits the bookkeeping change
        // before the app launch reads "current space" for placement.
        try? await Task.sleep(nanoseconds: 200_000_000)

        let result: T
        do {
            result = try await body()
        } catch {
            // Restore on the error path before rethrowing so we don't
            // leave the user's bookkeeping current-space pointing at a
            // hidden desktop.
            setCurrent(cid, uuid, original)
            throw error
        }

        // Hold the bookkeeping flip while the launched app finishes
        // placing its window on the bound space. Then restore.
        try? await Task.sleep(nanoseconds: windowSettleNanos)
        setCurrent(cid, uuid, original)
        return result
    }
}
