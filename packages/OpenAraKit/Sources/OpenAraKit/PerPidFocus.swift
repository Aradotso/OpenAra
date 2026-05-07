import AppKit
import CoreGraphics
import Darwin
import Foundation

/// PerPidFocus — yabai's "focus without raise" pattern, ported as a
/// drop-in replacement for `NSRunningApplication.activate(...)` in the
/// bound-space hot path.
///
/// **Why this exists.** Today `InputSimulation.prepareAppForGlobalPointerInput`
/// calls `NSRunningApplication.activate` to make the target app key-focused
/// before posting events. On a non-active Mission Control space that
/// triggers a visible Mission Control swap — the user's screen moves.
/// That is the breach of the dedicated-Ara-workspace promise.
///
/// **What it does instead.** Two `SLPSPostEventRecordTo` calls with a
/// hand-rolled 0xf8-byte event record, flipping `bytes[0x08]` from
/// `0x01` to `0x02` between calls. WindowServer treats the target window
/// as key-focused (text fields accept input, NSTableView selection
/// advances, NSPopUpButton menus open) but never raises it.
///
/// **Provenance.** yabai is the canonical reference — its
/// `window_manager_make_key_window` in `src/window_manager.c` ships the
/// exact byte layout we mirror here. trycua's April 2026 blog
/// "Inside macOS Window Internals" describes the same technique but
/// has the call pair wrong (claims one call to previously-frontmost,
/// one to target — yabai source proves both go to the target). We
/// trust yabai over the blog.
///   - yabai externs: github.com/koekeishiya/yabai/blob/master/src/misc/extern.h
///   - yabai impl:    github.com/koekeishiya/yabai/blob/master/src/window_manager.c
///                    function `window_manager_make_key_window`
///
/// **Fragility.** The wire format has crashed historically:
/// paneru #123 (Sonoma 14.2.1 arm64) — `SLPSPostEventRecordTo →
/// CGSEncodeEventRecord → NSKeyedArchiver` aborts when bytes 0x20..0x30
/// are 0xff and a class lookup fails. We mirror yabai's exact byte
/// pattern (which has not crashed on Tahoe in field testing) and probe
/// the symbol on every init — `dlsym` returning nil is a hard
/// "fallback to activate()" signal.
///
/// **Scope.** This type only enables the silent path. The decision of
/// when to use it (only when target window is on the bound space)
/// lives in `InputSimulation.prepareAppForGlobalPointerInput`. Default
/// off behind `OPENARA_USE_PER_PID_FOCUS=1` until the canary
/// (`01-bound-space-silent-flip`) has caught at least one OS minor
/// without regression.
public final class PerPidFocus: @unchecked Sendable {
    public static let shared = PerPidFocus()

    /// True iff the env opt-in is set AND the SkyLight symbol resolved.
    /// Callers gate on this and fall back to `NSRunningApplication.activate`
    /// when false — same observable behavior as before this file existed.
    public var isAvailable: Bool {
        envEnabled && _postEventRecordTo != nil && _getProcessForPID != nil
    }

    private let envEnabled: Bool
    private let _postEventRecordTo: (@convention(c) (
        UnsafeMutablePointer<ProcessSerialNumber>,
        UnsafeMutablePointer<UInt8>
    ) -> Int32)?
    /// `GetProcessForPID` is marked unavailable in Swift even though
    /// the C symbol is alive and shipping — it is the only public way
    /// to translate a pid_t to a ProcessSerialNumber, which is what
    /// `SLPSPostEventRecordTo` needs. Resolved via dlsym from
    /// CoreServices's AE subframework. Same path yabai takes.
    private let _getProcessForPID: (@convention(c) (
        pid_t,
        UnsafeMutablePointer<ProcessSerialNumber>
    ) -> Int32)?

    private init() {
        let raw = ProcessInfo.processInfo.environment["OPENARA_USE_PER_PID_FOCUS"] ?? "0"
        self.envEnabled = (raw == "1" || raw.lowercased() == "true")

        let slHandle = dlopen(
            "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight",
            RTLD_LAZY
        )
        let aeHandle = dlopen(
            "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/AE.framework/Versions/A/AE",
            RTLD_LAZY
        )

        if let h = slHandle, let raw = dlsym(h, "SLPSPostEventRecordTo") {
            self._postEventRecordTo = unsafeBitCast(
                raw,
                to: (@convention(c) (
                    UnsafeMutablePointer<ProcessSerialNumber>,
                    UnsafeMutablePointer<UInt8>
                ) -> Int32).self
            )
        } else {
            self._postEventRecordTo = nil
        }

        if let h = aeHandle, let raw = dlsym(h, "GetProcessForPID") {
            self._getProcessForPID = unsafeBitCast(
                raw,
                to: (@convention(c) (
                    pid_t,
                    UnsafeMutablePointer<ProcessSerialNumber>
                ) -> Int32).self
            )
        } else {
            self._getProcessForPID = nil
        }

        BoundSpaceTrace.emit(
            "PerPidFocus.init envEnabled=\(envEnabled) " +
            "post=\(_postEventRecordTo != nil) " +
            "psn=\(_getProcessForPID != nil) " +
            "isAvailable=\(envEnabled && _postEventRecordTo != nil && _getProcessForPID != nil)"
        )
    }

    /// Make the target app key-focused without raising any of its
    /// windows. Returns `true` on success, `false` if the symbol
    /// wasn't available, the env opt-in wasn't set, or the PSN
    /// lookup failed (caller should fall back to `activate`).
    ///
    /// `windowID` is optional — when set, baked into the event record
    /// at offset 0x3c so the focus targets that specific window. When
    /// nil, the app's current key window is used (whatever was last
    /// key, possibly nothing — pass a windowID for predictability).
    public func makeKeyWithoutRaising(pid: pid_t, windowID: CGWindowID? = nil) -> Bool {
        guard isAvailable,
              let post = _postEventRecordTo,
              let getPSN = _getProcessForPID
        else {
            BoundSpaceTrace.emit(
                "PerPidFocus.skip pid=\(pid) reason=" +
                (envEnabled ? "symbol-missing" : "env-disabled")
            )
            return false
        }

        // Resolve PSN via dlsym'd GetProcessForPID. Apple deprecated
        // PSN-based APIs in 10.9 and marked the Swift binding
        // unavailable, but the C symbol is alive — `SLPSPostEventRecordTo`
        // still takes a PSN, we have no choice. yabai uses the same
        // path through its C wrapper.
        var psn = ProcessSerialNumber()
        let status = getPSN(pid, &psn)
        if status != 0 || (psn.highLongOfPSN == 0 && psn.lowLongOfPSN == 0) {
            BoundSpaceTrace.emit("PerPidFocus.skip pid=\(pid) reason=psn-resolve-failed status=\(status)")
            return false
        }

        // 0xf8 bytes, zero-initialised. Layout per yabai's
        // window_manager_make_key_window:
        //   byte 0x04 = 0xf8 (record length)
        //   byte 0x08 = 0x01 then 0x02 across the two calls
        //   bytes 0x20..0x30 = 0xff (sentinel; required, but specific
        //                            content untouched between calls)
        //   byte 0x3a = 0x10
        //   bytes 0x3c..0x40 = window_id (UInt32, little-endian)
        var buf = [UInt8](repeating: 0, count: 0xf8)
        buf[0x04] = 0xf8
        buf[0x3a] = 0x10
        if let wid = windowID {
            withUnsafeBytes(of: wid.littleEndian) { src in
                for (i, byte) in src.enumerated() {
                    buf[0x3c + i] = byte
                }
            }
        }
        for i in 0..<0x10 {
            buf[0x20 + i] = 0xff
        }

        // First call — activate-style.
        buf[0x08] = 0x01
        let r1 = buf.withUnsafeMutableBufferPointer { bp -> Int32 in
            post(&psn, bp.baseAddress!)
        }

        // Second call — commit-style. Both go to the SAME target PSN,
        // not "previously-frontmost then target" as the trycua blog
        // claims. Verified against yabai source.
        buf[0x08] = 0x02
        let r2 = buf.withUnsafeMutableBufferPointer { bp -> Int32 in
            post(&psn, bp.baseAddress!)
        }

        let ok = (r1 == 0 && r2 == 0)
        BoundSpaceTrace.emit(
            "PerPidFocus.makeKeyWithoutRaising pid=\(pid) " +
            "windowID=\(windowID.map(String.init) ?? "nil") " +
            "r1=\(r1) r2=\(r2) ok=\(ok)"
        )
        return ok
    }
}
