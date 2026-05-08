import AppKit
import Foundation

/// AppNewWindowForcer — handles the case where the agent says
/// "open Finder" but Finder is already running and `NSWorkspace.openApplication`
/// just brings its existing window forward instead of creating a new one.
///
/// **Why this exists.** For the dedicated-Ara-workspace promise to
/// hold, the agent's working window needs to *be on the bound space*,
/// not on whatever space the existing instance was last seen. For
/// not-running-yet apps the silent-flip handles this — WindowServer
/// places newly-created windows on the bookkeeping current space,
/// which we've flipped to bound. But for already-running
/// single-instance apps (Finder, Mail, Notes, Messages, Stickies),
/// macOS silently ignores `createsNewApplicationInstance=true` AND
/// reuses the existing process, so no new window is born — there's
/// nothing for the silent-flip to "place".
///
/// **The fix.** Inside the `withBoundSpace { … }` closure (so
/// bookkeeping current = bound space), explicitly tell the running
/// app to create a new window. Two strategies:
///   1. AppleScript "make new …" — clean, reliable, app-specific
///      vocabulary. Works for Finder, Safari, TextEdit.
///   2. Synthetic Cmd+N keystroke via `CGEvent.postToPid` — fallback
///      for apps without a clean AppleScript verb. Doesn't require
///      key focus because we deliver per-pid.
///
/// The new window is born with bookkeeping current = bound, so
/// WindowServer assigns it to the bound space. The user's view stays
/// home (the silent-flip restore handles that), and any post-launch
/// reverse-flip (`ReverseFlipScheduler`) handles the inevitable
/// self-activation.
public enum AppNewWindowForcer {
    /// Decide if the just-launched pid is a reuse of an existing
    /// instance — i.e. the same pid was running BEFORE we called
    /// `NSWorkspace.openApplication`. Caller passes the pre-launch
    /// snapshot of pids for this bundle.
    public static func wasReused(callbackPid: pid_t, preLaunchPids: Set<pid_t>) -> Bool {
        callbackPid != 0 && preLaunchPids.contains(callbackPid)
    }

    /// Force the running app to create a new window. Logs every
    /// decision via `BoundSpaceTrace` so the trace tells the full
    /// story of why a launch did or didn't get a new window in the
    /// bound space.
    ///
    /// Should be called INSIDE `withBoundSpace { … }` so the new
    /// window is born during the flipped-bookkeeping window.
    @discardableResult
    public static func force(bundleId: String, pid: pid_t) -> Bool {
        if let scriptText = appleScript(for: bundleId) {
            let ok = runAppleScript(scriptText, label: bundleId)
            BoundSpaceTrace.emit(
                "force-new-window.applescript bundleId=\(bundleId) " +
                "pid=\(pid) ok=\(ok)"
            )
            return ok
        }

        // Fallback: synthesize Cmd+N to the pid. Most macOS apps
        // bind Cmd+N to "New Document" or "New Window".
        // CGEvent.postToPid delivers regardless of focus, so this
        // works even if the app's window isn't key. The keystroke
        // may NOT register if the app gates Cmd+N on key window
        // state — that's a known limitation; AppleScript path is
        // strictly preferred where available.
        let ok = sendCmdN(toPid: pid)
        BoundSpaceTrace.emit(
            "force-new-window.cmdn bundleId=\(bundleId) pid=\(pid) ok=\(ok)"
        )
        return ok
    }

    // MARK: - AppleScript dispatch

    /// Per-app AppleScript verb for "make new window/document".
    /// Returns nil for apps without a published vocabulary; caller
    /// falls back to Cmd+N.
    ///
    /// Sources for individual app dictionaries: `osascript -e
    /// 'tell app "X" to open dictionary'` exposes them. Verified
    /// against Tahoe 26.4 stock installs.
    private static func appleScript(for bundleId: String) -> String? {
        switch bundleId {
        case "com.apple.finder":
            // Finder's `make new Finder window` is the canonical
            // path. Default location is "computer" — we let it
            // default since the agent's task can navigate after.
            return """
            tell application "Finder"
                make new Finder window
                activate
            end tell
            """

        case "com.apple.Safari":
            return """
            tell application "Safari"
                make new document
                activate
            end tell
            """

        case "com.apple.TextEdit":
            return """
            tell application "TextEdit"
                make new document
                activate
            end tell
            """

        case "com.apple.Preview":
            // Preview without a file argument creates an open dialog,
            // not a new document — we skip the AppleScript path and
            // fall through to Cmd+N which also opens the dialog.
            return nil

        default:
            // Unknown bundle: rely on Cmd+N fallback. We don't try
            // a generic `make new document` because not every app
            // implements it — the AppleScript would error out.
            return nil
        }
    }

    @discardableResult
    private static func runAppleScript(_ source: String, label: String) -> Bool {
        var errorDict: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&errorDict)
        if let errorDict {
            BoundSpaceTrace.emit(
                "force-new-window.applescript.error label=\(label) " +
                "error=\(errorDict.description.prefix(200))"
            )
            return false
        }
        return result != nil
    }

    // MARK: - Cmd+N fallback via CGEvent

    private static let kVK_ANSI_N: CGKeyCode = 0x2D

    @discardableResult
    private static func sendCmdN(toPid pid: pid_t) -> Bool {
        guard
            let down = CGEvent(keyboardEventSource: nil, virtualKey: kVK_ANSI_N, keyDown: true),
            let up = CGEvent(keyboardEventSource: nil, virtualKey: kVK_ANSI_N, keyDown: false)
        else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.postToPid(pid)
        up.postToPid(pid)
        return true
    }
}
