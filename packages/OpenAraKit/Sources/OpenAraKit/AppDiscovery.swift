import AppKit
import CoreServices
import Foundation

public struct RunningAppDescriptor {
    public let name: String
    public let bundleIdentifier: String?
    public let pid: pid_t
    public let runningApplication: NSRunningApplication
}

struct ListedAppDescriptor {
    let name: String
    let bundleIdentifier: String
    let isRunning: Bool
    let lastUsed: Date?
    let uses: Int?

    var renderedLine: String {
        var markers: [String] = []
        if isRunning {
            markers.append("running")
        }
        if let lastUsed {
            markers.append("last-used=\(AppDiscovery.usageDateFormatter.string(from: lastUsed))")
        }
        if let uses {
            markers.append("uses=\(uses)")
        }

        return "\(name) — \(bundleIdentifier) [\(markers.joined(separator: ", "))]"
    }
}

private struct SpotlightAppRecord {
    let name: String
    let bundleIdentifier: String
    let lastUsed: Date?
    let uses: Int?
}

private struct ResolvedAppInfo {
    let bundleIdentifier: String
    let name: String
}

enum AppDiscovery {
    private static let listAppsQuery = #"kMDItemContentType == "com.apple.application-bundle" && kMDItemFSName == "*.app""#
    private static let lastUsedDateRankingAttribute = "kMDItemLastUsedDate_Ranking"
    private static let useCountAttribute = "kMDItemUseCount"
    private static let maxRecentNonRunningApps = 10
    private static let fixtureListBundleIdentifier = "so.ara.openara.fixture"
    private static let standardApplicationSearchRoots: [URL] = [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        URL(fileURLWithPath: "/System/Applications", isDirectory: true),
        URL(fileURLWithPath: "/System/Library/CoreServices", isDirectory: true),
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true),
    ]

    static let usageDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func listCatalog() -> [ListedAppDescriptor] {
        let running = userFacingRunningApps()
        let runningByBundle = running.reduce(into: [String: RunningAppDescriptor]()) { result, descriptor in
            guard let bundleIdentifier = listedBundleIdentifier(for: descriptor) else {
                return
            }

            let key = bundleIdentifier.lowercased()
            if result[key] == nil {
                result[key] = descriptor
            }
        }

        var entriesByBundle: [String: ListedAppDescriptor] = [:]

        for record in SpotlightAppIndex.recentApps(cutoffDate: recentUsageCutoff()) {
            let key = record.bundleIdentifier.lowercased()
            let runningDescriptor = runningByBundle[key]
            entriesByBundle[key] = ListedAppDescriptor(
                name: runningDescriptor?.name ?? record.name,
                bundleIdentifier: record.bundleIdentifier,
                isRunning: runningDescriptor != nil,
                lastUsed: record.lastUsed,
                uses: record.uses
            )
        }

        for descriptor in running {
            guard let bundleIdentifier = listedBundleIdentifier(for: descriptor) else {
                continue
            }

            let key = bundleIdentifier.lowercased()
            let existing = entriesByBundle[key]
            entriesByBundle[key] = ListedAppDescriptor(
                name: descriptor.name,
                bundleIdentifier: bundleIdentifier,
                isRunning: true,
                lastUsed: existing?.lastUsed,
                uses: existing?.uses
            )
        }

        let sorted = entriesByBundle.values.sorted(by: compareListedApps)
        let runningEntries = sorted.filter(\.isRunning)
        let recentEntries = sorted.filter { !$0.isRunning }.prefix(maxRecentNonRunningApps)
        return runningEntries + recentEntries
    }

    static func runningApps() -> [RunningAppDescriptor] {
        NSWorkspace.shared.runningApplications
            .filter { !$0.isTerminated }
            .sorted { lhs, rhs in
                if lhs.isActive != rhs.isActive {
                    return lhs.isActive && !rhs.isActive
                }

                return appName(lhs).localizedCaseInsensitiveCompare(appName(rhs)) == .orderedAscending
            }
            .map { app in
                RunningAppDescriptor(
                    name: appName(app),
                    bundleIdentifier: app.bundleIdentifier,
                    pid: app.processIdentifier,
                    runningApplication: app
                )
            }
    }

    static func resolve(_ query: String) throws -> RunningAppDescriptor {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let running = runningApps()

        if let bundleIdentifier = blockedBundleIdentifier(forQuery: normalizedQuery) {
            throw AppSafetyPolicy.permissionDenied(bundleIdentifier: bundleIdentifier)
        }

        if let match = resolvedRunningApp(in: running, matching: normalizedQuery) {
            return match
        }

        try launchIfPossible(normalizedQuery)

        for _ in 0..<20 {
            if let launched = resolvedRunningApp(in: runningApps(), matching: normalizedQuery) {
                return launched
            }

            Thread.sleep(forTimeInterval: 0.25)
        }

        throw ComputerUseError.appNotFound(normalizedQuery)
    }

    private static func resolvedRunningApp(in descriptors: [RunningAppDescriptor], matching query: String) -> RunningAppDescriptor? {
        if isBundleIdentifierQuery(query) {
            return descriptors.first(where: { descriptor in
                descriptor.bundleIdentifier?.caseInsensitiveCompare(query) == .orderedSame
            })
        }

        return descriptors.first(where: { descriptor in
            guard !AppSafetyPolicy.isBlocked(bundleIdentifier: descriptor.bundleIdentifier) else {
                return false
            }

            return descriptor.name.caseInsensitiveCompare(query) == .orderedSame
                || descriptor.runningApplication.executableURL?.deletingPathExtension().lastPathComponent.caseInsensitiveCompare(query) == .orderedSame
        })
    }

    private static func userFacingRunningApps() -> [RunningAppDescriptor] {
        var seen: Set<String> = []
        var descriptors: [RunningAppDescriptor] = []

        for descriptor in runningApps() {
            guard isUserFacingListApp(descriptor.runningApplication) else {
                continue
            }

            guard let bundleIdentifier = listedBundleIdentifier(for: descriptor) else {
                continue
            }

            let key = bundleIdentifier.lowercased()
            guard seen.insert(key).inserted else {
                continue
            }

            descriptors.append(descriptor)
        }

        return descriptors
    }

    private static func listedBundleIdentifier(for descriptor: RunningAppDescriptor) -> String? {
        if let bundleIdentifier = descriptor.bundleIdentifier, !bundleIdentifier.isEmpty {
            return bundleIdentifier
        }

        guard descriptor.name == FixtureBridge.appName else {
            return nil
        }

        return fixtureListBundleIdentifier
    }

    private static func compareListedApps(_ lhs: ListedAppDescriptor, _ rhs: ListedAppDescriptor) -> Bool {
        if lhs.isRunning != rhs.isRunning {
            return lhs.isRunning && !rhs.isRunning
        }

        let lhsHasUsage = lhs.lastUsed != nil
        let rhsHasUsage = rhs.lastUsed != nil
        if lhsHasUsage != rhsHasUsage {
            return lhsHasUsage && !rhsHasUsage
        }

        let calendar = Calendar(identifier: .gregorian)
        if let lhsLast = lhs.lastUsed, let rhsLast = rhs.lastUsed {
            let lhsDay = calendar.startOfDay(for: lhsLast)
            let rhsDay = calendar.startOfDay(for: rhsLast)
            if lhsDay != rhsDay {
                return lhsDay > rhsDay
            }
        }

        if let lhsUses = lhs.uses, let rhsUses = rhs.uses, lhsUses != rhsUses {
            return lhsUses > rhsUses
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }

    private static func launchIfPossible(_ query: String) throws {
        if isBundleIdentifierQuery(query) {
            guard !AppSafetyPolicy.isBlocked(bundleIdentifier: query) else {
                return
            }

            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: query) {
                try openApplication(at: appURL)
            }
            return
        }

        guard let appURL = applicationURL(named: query) else {
            return
        }

        if AppSafetyPolicy.isBlocked(bundleIdentifier: Bundle(url: appURL)?.bundleIdentifier) {
            return
        }

        try openApplication(at: appURL)
    }

    private static func applicationURL(named query: String) -> URL? {
        let targetName = stripAppSuffix(from: query).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetName.isEmpty else {
            return nil
        }

        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.isApplicationKey, .isDirectoryKey, .nameKey]
        var visitedPaths: Set<String> = []

        for root in standardApplicationSearchRoots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let candidateURL as URL in enumerator {
                guard candidateURL.pathExtension.caseInsensitiveCompare("app") == .orderedSame else {
                    continue
                }

                let normalizedPath = candidateURL.standardizedFileURL.path.lowercased()
                guard visitedPaths.insert(normalizedPath).inserted else {
                    continue
                }

                let candidateName = stripAppSuffix(from: candidateURL.lastPathComponent)
                if candidateName.caseInsensitiveCompare(targetName) == .orderedSame {
                    return candidateURL
                }
            }
        }

        return nil
    }

    private static func openApplication(at appURL: URL) throws {
        let errorBox = LaunchErrorBox()
        let isBoundActive = BoundSpaceManager.shared.isActive
        let appName = appURL.lastPathComponent
        let bundleId = Bundle(url: appURL)?.bundleIdentifier ?? "<unknown>"
        let boundId = BoundSpaceManager.shared.boundSpaceId.map(String.init) ?? "nil"

        BoundSpaceTrace.emit(
            "openApplication.start app=\(appName) bundleId=\(bundleId) " +
            "isBoundActive=\(isBoundActive) boundSpaceId=\(boundId)"
        )

        // Reused-instance reconcile: if the bound-space mode is active
        // and there's already a running instance of this bundle whose
        // windows live somewhere other than the bound space, try to
        // move them in place. If the move no-ops (typical on full SIP
        // for windows we don't own) AND the bundle is on the relaunch
        // allow-list, terminate the existing instance so the upcoming
        // `withBoundSpace` launch creates a fresh one on the bound
        // space. Bundles NOT on the allow-list are left alone — we
        // accept that the agent will reuse the existing window on the
        // user's space (verify line will log match=false).
        if isBoundActive,
           let bid = Bundle(url: appURL)?.bundleIdentifier,
           let target = BoundSpaceManager.shared.boundSpaceId
        {
            do {
                try reconcileSpaceMembership(bundleId: bid, target: target, appName: appName)
            } catch ReconcileOutcome.alreadyPlaced {
                // Reconcile pinned the existing windows to the bound
                // space; no launch needed. Still emit a verify line
                // so trace diff between launches and reconciles is
                // easy to spot.
                let observed = BoundSpaceManager.shared.spaceIdsForApp(bundleIdentifier: bid)
                let observedStr = observed.map(String.init).joined(separator: ",")
                let matched = observed.contains(target)
                BoundSpaceTrace.emit(
                    "openApplication.verify (reconcile-only) " +
                    "app=\(appName) bundleId=\(bid) " +
                    "windowSpaces=\(observedStr) boundSpaceId=\(boundId) " +
                    "match=\(matched)"
                )
                return
            }
        }

        if isBoundActive {
            // Per-thread Mission Control space (host opt-in via
            // `OPENARA_BOUND_SPACE_ID`): wrap the launch in a silent
            // SLS-switch dance so the new window lands on the
            // host-specified desktop without the user's view
            // changing. The whole NSWorkspace.openApplication call
            // happens inside the Task so we can avoid capturing the
            // non-Sendable NSWorkspace.OpenConfiguration into the
            // outer Task closure.
            let outerSema = DispatchSemaphore(value: 0)
            Task {
                await BoundSpaceManager.shared.withBoundSpace {
                    let configuration = NSWorkspace.OpenConfiguration()
                    configuration.activates = false
                    // Force a new instance whenever the app supports
                    // it (Chrome, Safari, Finder, most editors). For
                    // multi-instance apps the new window lands on the
                    // bound space silently; the user's existing
                    // windows stay where they are. For single-instance
                    // apps like Calculator macOS silently ignores this
                    // flag and returns the existing instance — the
                    // host (Ara) handles those cases separately if it
                    // wants stronger isolation.
                    configuration.createsNewApplicationInstance = true
                    let innerSema = DispatchSemaphore(value: 0)
                    NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { runningApp, error in
                        errorBox.error = error
                        if let pid = runningApp?.processIdentifier {
                            BoundSpaceTrace.emit("openApplication.callback app=\(appName) pid=\(pid) error=\(error?.localizedDescription ?? "nil")")
                        } else {
                            BoundSpaceTrace.emit("openApplication.callback app=\(appName) pid=<none> error=\(error?.localizedDescription ?? "nil")")
                        }
                        innerSema.signal()
                    }
                    waitForSignal(innerSema)
                }
                outerSema.signal()
            }
            waitForSignal(outerSema)
        } else {
            // Vanilla path — preserved exactly as before for hosts
            // that don't use the per-thread-spaces feature.
            let configuration = NSWorkspace.OpenConfiguration()
            let semaphore = DispatchSemaphore(value: 0)
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { runningApp, error in
                errorBox.error = error
                if let pid = runningApp?.processIdentifier {
                    BoundSpaceTrace.emit("openApplication.callback (vanilla) app=\(appName) pid=\(pid) error=\(error?.localizedDescription ?? "nil")")
                } else {
                    BoundSpaceTrace.emit("openApplication.callback (vanilla) app=\(appName) pid=<none> error=\(error?.localizedDescription ?? "nil")")
                }
                semaphore.signal()
            }
            waitForSignal(semaphore)
        }

        if let launchError = errorBox.error {
            BoundSpaceTrace.emit("openApplication.error app=\(appName) error=\(launchError.localizedDescription)")
            throw launchError
        }

        // Best-effort verification: query SLS for where the launched
        // app's window(s) ended up. Lets the operator confirm "did
        // Calculator land on the Ara desktop or not" without manually
        // swiping through Mission Control.
        //
        // Poll-with-deadline pattern: live testing on Tahoe 26.4 found
        // that Calculator's first-launch can take >1.5s for the window
        // to register in `CGWindowListCopyWindowInfo`, even though the
        // process is spawned and reported back via openApplication's
        // callback at ~270ms. Without polling we'd consistently log
        // `windowSpaces= match=false` for cold launches even though
        // the window does appear (and on the correct space) shortly
        // after — false alarm. Poll up to 4s, exit early on first
        // non-empty list. Total cost is bounded; happy-path is fast.
        if let bid = Bundle(url: appURL)?.bundleIdentifier {
            var observed: [UInt64] = []
            let verifyDeadline = Date().addingTimeInterval(4.0)
            while Date() < verifyDeadline {
                observed = BoundSpaceManager.shared.spaceIdsForApp(bundleIdentifier: bid)
                if !observed.isEmpty { break }
                Thread.sleep(forTimeInterval: 0.1)
            }
            let observedStr = observed.map(String.init).joined(separator: ",")
            let bound = BoundSpaceManager.shared.boundSpaceId
            let matched: Bool = bound.map { observed.contains($0) } ?? false
            let parts = [
                "openApplication.verify",
                "app=\(appName)",
                "bundleId=\(bid)",
                "windowSpaces=\(observedStr)",
                "boundSpaceId=\(boundId)",
                "match=\(matched)",
            ]
            BoundSpaceTrace.emit(parts.joined(separator: " "))
        }
    }

    /// Pre-launch space reconciliation. Decides whether the existing
    /// running instance of `bundleId` (if any) needs to be moved or
    /// killed before the upcoming `withBoundSpace` launch.
    ///
    /// Decision tree:
    ///   * No running instance → no-op, fall through to launch.
    ///   * Running instance with at least one window on `target` →
    ///     no-op (already correct).
    ///   * Running instance entirely off `target`:
    ///     * try `BoundSpaceManager.relocateWindows`. If `allLanded`,
    ///       skip the launch entirely — the windows are now on the
    ///       bound space. Log `reconcile.pinned`.
    ///     * If relocate left windows stuck AND the bundle is on the
    ///       relaunch allow-list, `terminate()` every running
    ///       instance, wait up to 2s for `isTerminated`, then return
    ///       so the caller proceeds with launch-under-flip. Log
    ///       `reconcile.relaunched`.
    ///     * Otherwise, log `reconcile.locked` and return — the agent
    ///       will reuse the existing window on the user's space.
    ///       Acceptable for apps with unsaved-state risk (Mail,
    ///       Messages).
    private static func reconcileSpaceMembership(
        bundleId: String,
        target: UInt64,
        appName: String
    ) throws {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
        guard !running.isEmpty else {
            BoundSpaceTrace.emit("reconcile.skip bundleId=\(bundleId) reason=not-running")
            return
        }

        let currentSpaces = BoundSpaceManager.shared.spaceIdsForApp(bundleIdentifier: bundleId)
        if currentSpaces.contains(target) {
            BoundSpaceTrace.emit(
                "reconcile.already-correct bundleId=\(bundleId) " +
                "currentSpaces=\(currentSpaces.map(String.init).joined(separator: ","))"
            )
            return
        }

        // Try cheap, in-place move first.
        var anyLanded = false
        var anyStuck = false
        for app in running {
            let result = BoundSpaceManager.shared.relocateWindows(
                of: app.processIdentifier,
                to: target
            )
            if !result.landed.isEmpty { anyLanded = true }
            if !result.stuck.isEmpty { anyStuck = true }
        }

        if anyLanded && !anyStuck {
            BoundSpaceTrace.emit(
                "reconcile.pinned bundleId=\(bundleId) skipping launch"
            )
            // Throw a sentinel that the caller catches as "we're done,
            // no launch needed."
            throw ReconcileOutcome.alreadyPlaced
        }

        // Move was a partial or full no-op. Decide whether to kill +
        // relaunch based on the per-bundle policy.
        let policy = AppRelaunchPolicy.policy(for: bundleId)
        switch policy {
        case .allow:
            BoundSpaceTrace.emit(
                "reconcile.relaunching bundleId=\(bundleId) " +
                "policy=allow runningCount=\(running.count)"
            )
            for app in running {
                _ = app.terminate()
            }
            // Wait up to 2s for every instance to terminate before we
            // hand control back to the launch path. Avoids the new
            // launch racing the old instance and reusing it again.
            let deadline = Date().addingTimeInterval(2.0)
            while Date() < deadline,
                  !NSRunningApplication
                    .runningApplications(withBundleIdentifier: bundleId)
                    .isEmpty
            {
                Thread.sleep(forTimeInterval: 0.05)
            }
            let stillRunning = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleId)
                .count
            BoundSpaceTrace.emit(
                "reconcile.relaunched bundleId=\(bundleId) " +
                "stillRunning=\(stillRunning)"
            )

        case .deny:
            BoundSpaceTrace.emit(
                "reconcile.locked bundleId=\(bundleId) " +
                "policy=deny landed=\(anyLanded) stuck=\(anyStuck) " +
                "expect=verify-will-log-match=false"
            )
        }
    }

    private static func waitForSignal(_ semaphore: DispatchSemaphore) {
        if Thread.isMainThread {
            while semaphore.wait(timeout: .now()) == .timedOut {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.01))
            }
            return
        }

        semaphore.wait()
    }

    private final class LaunchErrorBox: @unchecked Sendable {
        var error: Error?
    }

    private static func recentUsageCutoff(referenceDate: Date = Date()) -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let startOfToday = calendar.startOfDay(for: referenceDate)
        return calendar.date(byAdding: .day, value: -13, to: startOfToday) ?? startOfToday
    }

    private static func blockedBundleIdentifier(forQuery query: String) -> String? {
        guard isBundleIdentifierQuery(query), AppSafetyPolicy.isBlocked(bundleIdentifier: query) else {
            return nil
        }

        return query
    }

    private static func isBundleIdentifierQuery(_ query: String) -> Bool {
        query.contains(".")
    }

    private static func isUserFacingListApp(_ app: NSRunningApplication) -> Bool {
        app.activationPolicy == .regular
    }

    private static func bundleDisplayName(_ bundle: Bundle?) -> String? {
        guard let bundle else {
            return nil
        }

        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle.object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
        return displayName ?? bundleName
    }

    private static func stripAppSuffix(from value: String) -> String {
        value.hasSuffix(".app") ? String(value.dropLast(4)) : value
    }

    static func appName(_ app: NSRunningApplication) -> String {
        app.localizedName
            ?? bundleDisplayName(Bundle(url: app.bundleURL ?? URL(fileURLWithPath: "/")))
            ?? app.bundleURL?.deletingPathExtension().lastPathComponent
            ?? app.executableURL?.lastPathComponent
            ?? "pid-\(app.processIdentifier)"
    }

    private enum SpotlightAppIndex {
        static func recentApps(cutoffDate: Date) -> [SpotlightAppRecord] {
            let sortingAttributes = [
                lastUsedDateRankingAttribute as CFString,
                useCountAttribute as CFString,
            ] as CFArray

            guard let query = MDQueryCreate(
                kCFAllocatorDefault,
                listAppsQuery as CFString,
                nil,
                sortingAttributes
            ) else {
                return []
            }

            MDQuerySetSearchScope(query, standardSearchScopes() as CFArray, 0)
            MDQuerySetSortOptionFlagsForAttribute(query, lastUsedDateRankingAttribute as CFString, kMDQueryReverseSortOrderFlag.rawValue)
            MDQuerySetSortOptionFlagsForAttribute(query, useCountAttribute as CFString, kMDQueryReverseSortOrderFlag.rawValue)

            guard MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue)) else {
                return []
            }

            var seen: Set<String> = []
            var records: [SpotlightAppRecord] = []

            for index in 0..<MDQueryGetResultCount(query) {
                guard let rawResult = MDQueryGetResultAtIndex(query, index) else {
                    continue
                }

                let item = unsafeBitCast(rawResult, to: MDItem.self)
                guard
                    let bundleIdentifier = stringAttribute(kMDItemCFBundleIdentifier, item: item),
                    !bundleIdentifier.isEmpty
                else {
                    continue
                }

                let key = bundleIdentifier.lowercased()
                guard seen.insert(key).inserted else {
                    continue
                }

                guard let path = stringAttribute(kMDItemPath, item: item) else {
                    continue
                }

                let appURL = URL(fileURLWithPath: path)
                let bundle = Bundle(url: appURL)
                if bundle?.object(forInfoDictionaryKey: "LSBackgroundOnly") as? Bool == true {
                    continue
                }
                if bundle?.object(forInfoDictionaryKey: "LSUIElement") as? Bool == true {
                    continue
                }

                let lastUsed = dateAttribute(lastUsedDateRankingAttribute as CFString, item: item)
                    ?? dateAttribute(kMDItemLastUsedDate, item: item)
                guard let lastUsed, lastUsed >= cutoffDate else {
                    continue
                }

                let uses = numberAttribute(useCountAttribute as CFString, item: item)?.intValue
                let displayName = bundleDisplayName(bundle)
                    ?? stringAttribute(kMDItemDisplayName, item: item).map(stripAppSuffix(from:))
                    ?? stripAppSuffix(from: appURL.lastPathComponent)

                records.append(
                    SpotlightAppRecord(
                        name: displayName,
                        bundleIdentifier: bundleIdentifier,
                        lastUsed: lastUsed,
                        uses: uses
                    )
                )
            }

            return records
        }

        private static func standardSearchScopes() -> [CFString] {
            var scopes: [String] = [
                "/Applications",
                "/System/Applications",
                "/System/Library/CoreServices",
            ]

            let homeApplications = NSString(string: "~/Applications").expandingTildeInPath
            if FileManager.default.fileExists(atPath: homeApplications) {
                scopes.append(homeApplications)
            }

            return scopes as [CFString]
        }

        private static func stringAttribute(_ name: CFString, item: MDItem) -> String? {
            MDItemCopyAttribute(item, name) as? String
        }

        private static func numberAttribute(_ name: CFString, item: MDItem) -> NSNumber? {
            MDItemCopyAttribute(item, name) as? NSNumber
        }

        private static func dateAttribute(_ name: CFString, item: MDItem) -> Date? {
            MDItemCopyAttribute(item, name) as? Date
        }
    }
}

/// Sentinel thrown by `reconcileSpaceMembership` when the relocate
/// path succeeded and the launch should be skipped entirely. Caught by
/// `openApplication` so the user sees the same `verify` log line as if
/// the launch had succeeded — just without spawning a new process.
private enum ReconcileOutcome: Error {
    case alreadyPlaced
}

/// Per-bundle policy gate for the "kill + relaunch" branch of the
/// reused-instance reconciler. Default is `.deny` — we only relaunch
/// the apps where unsaved-state risk is essentially zero AND macOS
/// silently coerces `createsNewApplicationInstance` to false.
///
/// Allow-list rationale (see plan in PR description):
///   * Calculator, Notes, Stickies, Preview, TextEdit — single-instance
///     by macOS contract, document state is auto-saved or trivial.
/// Deliberately NOT on the allow-list:
///   * Mail / Messages — in-progress compose, draft loss is bad.
///   * iWork (Pages/Numbers/Keynote) — unsaved document risk.
///   * Anything not enumerated — opt-in policy. New entries go through
///     code review.
private enum AppRelaunchPolicy {
    case allow
    case deny

    private static let allowed: Set<String> = [
        "com.apple.calculator",
        "com.apple.Notes",
        "com.apple.Stickies",
        "com.apple.Preview",
        "com.apple.TextEdit",
    ]

    static func policy(for bundleId: String) -> AppRelaunchPolicy {
        allowed.contains(bundleId) ? .allow : .deny
    }
}

private enum AppSafetyPolicy {
    private static let blockedBundleIdentifiers: Set<String> = [
        "com.apple.ScreenContinuity",
        "com.1password.1password",
        "com.1password.safari",
        "com.bitwarden.desktop",
        "com.dashlane.dashlanephonefinal",
        "com.lastpass.LastPass",
        "com.nordsec.nordpass",
        "me.proton.pass.electron",
        "me.proton.pass.catalyst",
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "com.mitchellh.ghostty",
        "com.raphaelamorim.rio",
        "dev.commandline.waveterm",
        "com.google.Chrome",
        "com.openai.atlas.alpha",
        "com.openai.atlas.beta",
        "com.apple.UserNotificationCenter",
        "com.apple.LocalAuthenticationRemoteService",
        "com.apple.SecurityAgent",
    ]

    static func isBlocked(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else {
            return false
        }

        return blockedBundleIdentifiers.contains(bundleIdentifier)
    }

    static func permissionDenied(bundleIdentifier: String) -> ComputerUseError {
        .permissionDenied("Computer Use is not allowed to use the app '\(bundleIdentifier)' for safety reasons.")
    }
}
