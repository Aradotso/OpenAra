import AppKit
import Testing
@testable import OpenAraKit

@Suite final class PermissionTests {
    @Test func permissionDiagnosticsListsMissingPermissionsInCanonicalOrder() {
        let diagnostics = PermissionDiagnostics(
            accessibilityTrusted: false,
            screenCaptureGranted: true
        )

                #expect(diagnostics.missingPermissions == [.accessibility])
    }

    @Test func permissionDiagnosticsHasNoMissingPermissionsWhenAllGranted() {
        let diagnostics = PermissionDiagnostics(
            accessibilityTrusted: true,
            screenCaptureGranted: true
        )

                #expect(diagnostics.missingPermissions.isEmpty)
    }

    @Test func preferredPermissionAppBundleURLPrefersInstalledCopyOverTransientRunningCopy() {
        let installed = URL(fileURLWithPath: "/opt/homebrew/lib/node_modules/openara/dist/Open Computer Use.app")
        let running = URL(fileURLWithPath: "/Users/example/projects/openara/dist/Open Computer Use.app")
        let fallback = URL(fileURLWithPath: "/Users/example/projects/openara-debug/dist/Open Computer Use.app")

        let resolved = PermissionSupport.preferredPermissionAppBundleURL(
            preferredInstalledBundleURL: installed,
            runningBundleURL: running,
            fallbackDevelopmentBundleURL: fallback
        )

                #expect(resolved == installed)
    }

    @Test func preferredPermissionAppBundleURLPrefersRunningDevelopmentCopy() {
        let installed = URL(fileURLWithPath: "/Applications/Open Computer Use.app")
        let running = URL(fileURLWithPath: "/Users/example/projects/openara/dist/Open Computer Use (Dev).app")
        let fallback = URL(fileURLWithPath: "/Users/example/projects/openara-debug/dist/Open Computer Use (Dev).app")

        let resolved = PermissionSupport.preferredPermissionAppBundleURL(
            preferredInstalledBundleURL: installed,
            runningBundleURL: running,
            fallbackDevelopmentBundleURL: fallback,
            preferRunningBundle: true
        )

                #expect(resolved == running)
    }

    @Test func preferredInstalledAppBundleURLUsesFirstDiscoveredInstalledCopy() {
        let applications = URL(fileURLWithPath: "/Applications/Open Computer Use.app")
        let npm = URL(fileURLWithPath: "/opt/homebrew/lib/node_modules/openara/dist/Open Computer Use.app")
        let duplicateApplications = URL(fileURLWithPath: "/Applications/Open Computer Use.app")

        let resolved = PermissionSupport.preferredInstalledAppBundleURL(
            candidates: [applications, npm, duplicateApplications]
        )

                #expect(resolved == applications)
    }

    @Test func permissionClientsKeepStableBundleIdentityAheadOfTransientAppPath() {
        let installed = URL(fileURLWithPath: "/opt/homebrew/lib/node_modules/openara/dist/Open Computer Use.app")
        let running = URL(fileURLWithPath: "/Users/example/projects/openara/dist/Open Computer Use.app")

        let clients = PermissionSupport.permissionClients(
            primaryBundleURL: installed,
            runningBundleURL: running,
            mainBundleIdentifier: PermissionSupport.bundleIdentifier
        )

                #expect(clients == [ PermissionClientRecord(identifier: PermissionSupport.bundleIdentifier, type: 0), PermissionClientRecord(identifier: installed.path, type: 1), PermissionClientRecord(identifier: running.path, type: 1), ])
    }

    @Test func permissionClientsKeepDevelopmentBundleIdentitySeparateFromRelease() {
        let running = URL(fileURLWithPath: "/Users/example/projects/openara/dist/Open Computer Use (Dev).app")

        let clients = PermissionSupport.permissionClients(
            primaryBundleURL: running,
            runningBundleURL: running,
            mainBundleIdentifier: PermissionSupport.developmentBundleIdentifier,
            includeCanonicalBundleIdentifier: false
        )

                #expect(clients == [ PermissionClientRecord(identifier: PermissionSupport.developmentBundleIdentifier, type: 0), PermissionClientRecord(identifier: running.path, type: 1), ])
    }

    @Test func tCCAuthorizationGrantedTreatsAnyGrantedCandidateAsGranted() {
                #expect(tccAuthorizationGranted(authValues: [0, 2]))
                #expect(!(tccAuthorizationGranted(authValues: [0, nil])))
                #expect(!(tccAuthorizationGranted(authValues: [])))
    }
}
