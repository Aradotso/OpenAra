import AppKit
import Foundation

/// ReverseFlipScheduler — closes the self-activation race that breaks
/// the dedicated-Ara-workspace promise for ~95% of GUI apps.
///
/// **The problem.** When `withBoundSpace { … }` launches an app like
/// Calculator or brings Finder forward, the app calls
/// `NSApp.activate(ignoringOtherApps:true)` ~50-200ms after spawn (this
/// is the macOS default — see SwiftLint #2643 — Calculator, Notes,
/// Mail, every Electron app does it). That `activate()` makes the app
/// "frontmost" and WindowServer follows by swapping the user's
/// rendered space to wherever the app's window lives. Even if the
/// silent-flip placed the new window on the bound space, the user's
/// view gets dragged along — they wanted to stay on Desktop 2 but
/// macOS jerks them to Desktop 4.
///
/// **The fix.** Listen for `NSWorkspace.didActivateApplicationNotification`
/// filtered to the just-launched bundle id. When it fires (the
/// expected race window is 50-2000ms post-launch), immediately:
///   1. `SLSManagedDisplaySetCurrentSpace(prevSpace)` — bookkeeping
///      back to where the user was. Their screen returns home with
///      no animation since this is just a bookkeeping flip on a
///      non-frontmost daemon.
///   2. `PerPidFocus.makeKeyWithoutRaising(prevFrontPid)` —
///      restore keyboard focus to whatever the user had key-focused
///      before. Without this, their next keystroke would land in the
///      newly-launched app's text field, not their original work.
///
/// **Why this works where launch-time fixes don't.** We can't
/// suppress the activate from outside the app (its NSApplication.main
/// loop owns that decision). But we CAN react to the activate
/// notification within the same runloop tick and undo it before the
/// user perceives any change. WindowServer's "current space" is a
/// piece of bookkeeping state, not animation state — slamming it
/// back is invisible.
///
/// **Lifetime.** Each scheduled reverse-flip is a one-shot:
/// auto-removes the observer on first matching notification OR after
/// `deadline` seconds, whichever is first. Multiple concurrent
/// schedules (rare but possible) are tracked independently keyed by
/// bundleId.
public final class ReverseFlipScheduler: @unchecked Sendable {
    public static let shared = ReverseFlipScheduler()

    /// Active observers keyed by bundle id so we don't leak across
    /// rapid back-to-back launches of the same app. The dictionary is
    /// only ever mutated on the main queue (where notifications fire).
    private var pending: [String: PendingFlip] = [:]

    private final class PendingFlip {
        let observer: NSObjectProtocol
        var deadlineTimer: DispatchSourceTimer?
        init(observer: NSObjectProtocol) {
            self.observer = observer
        }
    }

    private init() {}

    /// Arm a one-shot reverse-flip. Call BEFORE invoking
    /// `withBoundSpace { … }` so the observer is registered before
    /// the launched app has a chance to activate itself. Idempotent
    /// for the same bundleId — re-arming replaces the previous
    /// pending observer.
    ///
    /// `prevSpace` and `prevFrontPid` should be captured immediately
    /// before this call from `BoundSpaceManager.currentSpace()` and
    /// `NSWorkspace.shared.frontmostApplication?.processIdentifier`.
    public func schedule(
        launchedBundleId: String,
        prevSpace: UInt64,
        prevFrontPid: pid_t?,
        deadline: TimeInterval = 3.0
    ) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // Cancel any previously-pending reverse-flip for this
            // bundle id — the new launch supersedes it.
            self.cancelLocked(launchedBundleId)

            let center = NSWorkspace.shared.notificationCenter
            let observerBox = ObserverBox()
            let observer = center.addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard let self else { return }
                guard
                    let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                    app.bundleIdentifier == launchedBundleId
                else { return }
                self.fire(
                    launchedBundleId: launchedBundleId,
                    activatedApp: app,
                    prevSpace: prevSpace,
                    prevFrontPid: prevFrontPid,
                    observerBox: observerBox
                )
            }
            observerBox.observer = observer

            let pending = PendingFlip(observer: observer)

            // Hard deadline — if the launched app doesn't activate
            // within `deadline`, the silent-flip held cleanly and we
            // don't need to bounce. Just remove the observer and log.
            let timer = DispatchSource.makeTimerSource(queue: .main)
            timer.schedule(deadline: .now() + deadline)
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                if self.pending[launchedBundleId] != nil {
                    BoundSpaceTrace.emit(
                        "reverse-flip.deadline-expired bundleId=\(launchedBundleId) " +
                        "deadlineSec=\(deadline)"
                    )
                    self.cancelLocked(launchedBundleId)
                }
            }
            timer.resume()
            pending.deadlineTimer = timer

            self.pending[launchedBundleId] = pending
            BoundSpaceTrace.emit(
                "reverse-flip.scheduled bundleId=\(launchedBundleId) " +
                "prevSpace=\(prevSpace) prevFrontPid=\(prevFrontPid?.description ?? "nil") " +
                "deadlineSec=\(deadline)"
            )
        }
    }

    private func fire(
        launchedBundleId: String,
        activatedApp: NSRunningApplication,
        prevSpace: UInt64,
        prevFrontPid: pid_t?,
        observerBox: ObserverBox
    ) {
        // Bookkeeping back home. WindowServer renders the change
        // invisibly because we're not the frontmost app and this is
        // just a state mutation, not a Mission Control gesture.
        let setOK = BoundSpaceManager.shared.setCurrentSpace(prevSpace)

        // Restore keyboard focus to the user's previous frontmost
        // app, if we have a pid for it AND it still exists. Without
        // this, the user's next keystroke lands in the just-launched
        // app's first responder.
        var focusOK: Bool? = nil
        if let prevPid = prevFrontPid,
           NSRunningApplication(processIdentifier: prevPid) != nil
        {
            focusOK = PerPidFocus.shared.makeKeyWithoutRaising(pid: prevPid)
        }

        BoundSpaceTrace.emit(
            "reverse-flip.fired bundleId=\(launchedBundleId) " +
            "activatedPid=\(activatedApp.processIdentifier) " +
            "prevSpace=\(prevSpace) setSpaceOK=\(setOK) " +
            "prevFrontPid=\(prevFrontPid?.description ?? "nil") " +
            "focusOK=\(focusOK.map(String.init) ?? "n/a")"
        )

        cancelLocked(launchedBundleId)
    }

    /// Remove a pending reverse-flip. Always called on the main
    /// queue — either from the deadline timer or from `fire` after a
    /// successful match.
    private func cancelLocked(_ bundleId: String) {
        guard let pending = pending.removeValue(forKey: bundleId) else { return }
        NSWorkspace.shared.notificationCenter.removeObserver(pending.observer)
        pending.deadlineTimer?.cancel()
    }

    /// Boxes the observer reference so the closure can capture it
    /// before assignment (Cocoa addObserver returns the observer; we
    /// need the closure to be able to reference it for self-removal).
    private final class ObserverBox: @unchecked Sendable {
        var observer: NSObjectProtocol?
    }
}
