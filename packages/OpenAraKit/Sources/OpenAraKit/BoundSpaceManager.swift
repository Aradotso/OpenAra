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

    /// True iff every condition `withBoundSpace` actually checks at
    /// runtime is satisfied: env-var opt-in, every SkyLight symbol
    /// resolved, and the main display has a UUID. Callers (notably
    /// `AppDiscovery.openApplication`) take a different branch when
    /// this is true — setting `activates = false` and
    /// `createsNewApplicationInstance = true` — so a "true" that
    /// later gates inside `withBoundSpace` would launch the app as a
    /// non-activated background instance with no space flip, which
    /// is worse than the vanilla path. Keep the two checks aligned.
    public var isActive: Bool {
        boundSpaceId != nil
            && _setCurrentSpace != nil
            && _getCurrentSpace != nil
            && mainDisplayUUID != nil
    }

    private let cid: UInt32
    private let _setCurrentSpace: (@convention(c) (UInt32, CFString, UInt64) -> Void)?
    private let _getCurrentSpace: (@convention(c) (UInt32, CFString) -> UInt64)?
    private let _spaceForWindow: (@convention(c) (UInt32, UInt32) -> UInt64)?
    private let _addWindowsToSpaces: (@convention(c) (UInt32, CFArray, CFArray) -> Void)?
    private let _removeWindowsFromSpaces: (@convention(c) (UInt32, CFArray, CFArray) -> Void)?

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
            self._spaceForWindow = nil
            self._addWindowsToSpaces = nil
            self._removeWindowsFromSpaces = nil
            BoundSpaceTrace.emit("BoundSpaceManager.init dlopen-failed envRaw=\(raw)")
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
        self._spaceForWindow = sym("SLSGetSpaceForWindow", as: (@convention(c) (UInt32, UInt32) -> UInt64).self)
        self._addWindowsToSpaces = sym("SLSAddWindowsToSpaces", as: (@convention(c) (UInt32, CFArray, CFArray) -> Void).self)
        self._removeWindowsFromSpaces = sym("SLSRemoveWindowsFromSpaces", as: (@convention(c) (UInt32, CFArray, CFArray) -> Void).self)

        let active = (self.boundSpaceId != nil && self._setCurrentSpace != nil)
        BoundSpaceTrace.emit(
            "BoundSpaceManager.init envRaw=\(raw) " +
            "boundSpaceId=\(self.boundSpaceId.map(String.init) ?? "nil") " +
            "cid=\(self.cid) isActive=\(active)"
        )
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
            BoundSpaceTrace.emit("withBoundSpace.skip reason=inactive isActive=\(isActive)")
            return try await body()
        }

        let original = getCurrent(cid, uuid)
        if original == target {
            BoundSpaceTrace.emit("withBoundSpace.noop already-on-target target=\(target) original=\(original)")
            return try await body()
        }

        BoundSpaceTrace.emit("withBoundSpace.flip target=\(target) original=\(original) settleNanos=\(windowSettleNanos)")
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
            BoundSpaceTrace.emit("withBoundSpace.error-restore original=\(original) error=\(error.localizedDescription)")
            setCurrent(cid, uuid, original)
            throw error
        }

        // Hold the bookkeeping flip while the launched app finishes
        // placing its window on the bound space. Then restore.
        try? await Task.sleep(nanoseconds: windowSettleNanos)
        let beforeRestore = getCurrent(cid, uuid)
        setCurrent(cid, uuid, original)
        let afterRestore = getCurrent(cid, uuid)
        BoundSpaceTrace.emit(
            "withBoundSpace.restore target=\(target) original=\(original) " +
            "beforeRestore=\(beforeRestore) afterRestore=\(afterRestore)"
        )
        return result
    }

    /// Best-effort: which CGSSpaceIDs is `bundleIdentifier`'s app
    /// currently rendering windows on? Returns the empty array when
    /// the app isn't running or the private SLS symbol didn't
    /// resolve. Used by AppDiscovery to verify that a freshly-launched
    /// app actually landed on the bound space.
    ///
    /// Implementation: enumerate every on-screen window via the
    /// public `CGWindowListCopyWindowInfo`, filter to those owned by
    /// the app's pid, then look up each window's CGSSpaceID with the
    /// private `SLSGetSpaceForWindow`. Only `SLSGetSpaceForWindow` is
    /// private — the window list and pid match are public API.
    ///
    /// When the bundle has multiple running instances (Chrome with
    /// multiple profiles, Finder + a relaunch instance during the
    /// reused-instance fix path, etc.) we union the spaces across
    /// every pid so the verifier doesn't false-negative on the new
    /// instance because we picked the old one's pid.
    public func spaceIdsForApp(bundleIdentifier: String) -> [UInt64] {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        guard !running.isEmpty else { return [] }
        var seen = Set<UInt64>()
        for app in running {
            for sid in spaceIdsForPid(app.processIdentifier) {
                seen.insert(sid)
            }
        }
        return Array(seen)
    }

    /// Outcome of attempting to move every on-screen window owned by
    /// `pid` from its current space membership to `target`. The
    /// `relocate` operation is best-effort: on hardened SIP, the
    /// `SLSAddWindowsToSpaces` / `SLSRemoveWindowsFromSpaces` calls
    /// against windows owned by another connection silently no-op
    /// (`connection_holds_rights_on_window` gates the actual move).
    /// Callers use the post-move read to decide whether to fall back
    /// to relaunch.
    public struct RelocateResult: Sendable {
        public let attempted: [UInt32]
        public let landed: [UInt32]   // windows whose post-move space == target
        public let stuck: [UInt32]    // windows still on their original space
        public var allLanded: Bool { stuck.isEmpty && !landed.isEmpty }
    }

    /// Best-effort move of every on-screen window owned by `pid` to
    /// CGSSpaceID `target`. Used by `AppDiscovery.reconcileSpaceMembership`
    /// when the agent says "open Calculator" but Calculator is already
    /// running with its window on the user's desktop.
    ///
    /// Mechanism — same as `SpaceManager.pin` on the host side, but we
    /// don't own the windows here so it's a one-shot best-effort:
    ///   1. Enumerate windows via `CGWindowListCopyWindowInfo`.
    ///   2. For each window not already on `target`:
    ///      - `SLSAddWindowsToSpaces(target)`
    ///      - `SLSRemoveWindowsFromSpaces(<every other space the window
    ///        was on>)`
    ///   3. Re-read each window's space via `SLSGetSpaceForWindow` and
    ///      classify as `landed` (now on target) or `stuck` (no-op).
    ///
    /// On modern macOS with full SIP this often returns `stuck` for
    /// other-app windows. Callers that need stronger isolation should
    /// follow up with `NSRunningApplication.terminate()` + a fresh
    /// launch under `withBoundSpace`. See `AppRelaunchPolicy` in
    /// `AppDiscovery.swift` for the safety gate.
    public func relocateWindows(of pid: pid_t, to target: UInt64) -> RelocateResult {
        guard let add = _addWindowsToSpaces,
              let remove = _removeWindowsFromSpaces,
              let spaceFor = _spaceForWindow
        else {
            BoundSpaceTrace.emit("relocateWindows.skip pid=\(pid) target=\(target) reason=symbols-missing")
            return RelocateResult(attempted: [], landed: [], stuck: [])
        }

        let opts: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
            BoundSpaceTrace.emit("relocateWindows.skip pid=\(pid) target=\(target) reason=window-list-empty")
            return RelocateResult(attempted: [], landed: [], stuck: [])
        }

        var attempted: [UInt32] = []
        var landed: [UInt32] = []
        var stuck: [UInt32] = []

        for entry in info {
            guard let ownerNum = entry[kCGWindowOwnerPID as String] as? NSNumber,
                  ownerNum.int32Value == pid,
                  let widNum = entry[kCGWindowNumber as String] as? NSNumber
            else { continue }

            let wid = widNum.uint32Value
            let originalSpace = spaceFor(cid, wid)
            if originalSpace == target { continue }   // already correct

            attempted.append(wid)
            add(cid, [wid] as CFArray, [target] as CFArray)
            if originalSpace != 0 {
                remove(cid, [wid] as CFArray, [originalSpace] as CFArray)
            }

            let postMove = spaceFor(cid, wid)
            if postMove == target {
                landed.append(wid)
            } else {
                stuck.append(wid)
            }
        }

        BoundSpaceTrace.emit(
            "relocateWindows pid=\(pid) target=\(target) " +
            "attempted=\(attempted.count) landed=\(landed.count) stuck=\(stuck.count)"
        )
        return RelocateResult(attempted: attempted, landed: landed, stuck: stuck)
    }

    /// Same as `spaceIdsForApp` but keyed by pid.
    public func spaceIdsForPid(_ pid: pid_t) -> [UInt64] {
        guard let spaceFor = _spaceForWindow else { return [] }
        let opts: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        guard let info = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else { return [] }
        var seen = Set<UInt64>()
        for entry in info {
            guard let ownerNum = entry[kCGWindowOwnerPID as String] as? NSNumber,
                  ownerNum.int32Value == pid else { continue }
            guard let widNum = entry[kCGWindowNumber as String] as? NSNumber else { continue }
            let sid = spaceFor(cid, widNum.uint32Value)
            if sid != 0 { seen.insert(sid) }
        }
        return Array(seen)
    }
}

// MARK: - BoundSpaceTrace

/// Centralised trace channel for everything in the bound-space code
/// path. Writes through `OpenAraLogger` (file at
/// `~/Library/Logs/OpenAra/openara*.log`) AND to stderr so the parent
/// ACP bridge captures it into `/private/tmp/ara-dev.log`. Set
/// `OPENARA_TRACE_SPACES=0` to silence stderr only — the file log
/// stays on so it's always available for debugging.
public enum BoundSpaceTrace {
    private static let stderrEnabled: Bool = {
        let raw = ProcessInfo.processInfo.environment["OPENARA_TRACE_SPACES"] ?? "1"
        return raw != "0"
    }()

    public static func emit(_ message: String) {
        OpenAraLogger.info(message, category: "bound-space")
        guard stderrEnabled else { return }
        let line = "[bound-space] \(message)\n"
        if let data = line.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }
}
