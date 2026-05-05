import Foundation

/// Locates resources packaged with `OpenAraKit`.
///
/// SwiftPM generates a `Bundle.module` accessor whose only candidates are
/// `Bundle.main.bundleURL/OpenAra_OpenAraKit.bundle` and a hardcoded absolute
/// path to the dev's local `.build/` directory. Neither exists when OpenAra
/// is shipped inside `OpenAra.app` (the actual bundle lives at
/// `Contents/Resources/OpenAra_OpenAraKit.bundle`), so `Bundle.module` traps
/// the process via `Swift.fatalError` the first time anything in the kit
/// touches it. We avoid `Bundle.module` entirely and walk our own candidate
/// list with the .app layout taken into account.
enum OpenAraKitResources {
    /// The directory inside which OpenAraKit's resource files live. Returns
    /// `Bundle.main.resourceURL` (which always exists for an `.app`) as a
    /// last-ditch fallback so callers don't have to handle nil.
    static let resourceContainerURL: URL = {
        let manager = FileManager.default
        for candidate in candidatePaths() {
            if manager.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        // Last resort: the .app's own Resources folder. Resources may not be
        // where we expect, but at least `url(forResource:withExtension:)` can
        // search there without crashing.
        return Bundle.main.resourceURL ?? Bundle.main.bundleURL
    }()

    private static func candidatePaths() -> [URL] {
        var paths: [URL] = []

        // 1. Shipped `.app` case — bundle sits in `Contents/Resources/`.
        if let resourceURL = Bundle.main.resourceURL {
            paths.append(resourceURL.appendingPathComponent("OpenAra_OpenAraKit.bundle"))
        }

        // 2. SwiftPM CLI build — bundle is a sibling of the executable.
        paths.append(Bundle.main.bundleURL.appendingPathComponent("OpenAra_OpenAraKit.bundle"))

        // 3. Test/dev environment — `xctest` is `Bundle.main` and the kit
        //    bundle lives in the local `.build/` directory next to the
        //    package. Walk up from this source file to find it.
        let sourceFile = URL(fileURLWithPath: #filePath)
        let packageRoot = sourceFile
            .deletingLastPathComponent() // OpenAraKit/
            .deletingLastPathComponent() // Sources/
            .deletingLastPathComponent() // OpenAraKit/
            .deletingLastPathComponent() // packages/
            .deletingLastPathComponent() // OpenAra/  (repo root)
        let buildRoot = packageRoot.appendingPathComponent(".build")
        let archs = ["arm64-apple-macosx", "x86_64-apple-macosx"]
        let configs = ["debug", "release"]
        for arch in archs {
            for config in configs {
                paths.append(buildRoot
                    .appendingPathComponent(arch)
                    .appendingPathComponent(config)
                    .appendingPathComponent("OpenAra_OpenAraKit.bundle"))
            }
        }
        for config in configs {
            paths.append(buildRoot
                .appendingPathComponent(config)
                .appendingPathComponent("OpenAra_OpenAraKit.bundle"))
        }
        return paths
    }

    /// Drop-in replacement for `Bundle.module.url(forResource:withExtension:)`
    /// that returns nil instead of crashing when a resource is missing.
    static func url(forResource name: String, withExtension ext: String) -> URL? {
        let candidate = resourceContainerURL.appendingPathComponent("\(name).\(ext)")
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        // Fall back to the main bundle in case resources were merged into the
        // app's Contents/Resources/ root rather than living inside a nested
        // OpenAra_OpenAraKit.bundle (e.g. a future build script that
        // flattens).
        return Bundle.main.url(forResource: name, withExtension: ext)
    }
}
