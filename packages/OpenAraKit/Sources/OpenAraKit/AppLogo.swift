import AppKit
import Foundation

public enum AppLogo {
    private static let resourceName = "openara-logo-512"

    public static func load() -> NSImage? {
        if let url = OpenAraKitResources.url(forResource: resourceName, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        if let url = Bundle.main.url(forResource: resourceName, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }

        if let mainBundleIcon = Bundle.main.url(forResource: "OpenAra", withExtension: "icns"),
           let image = NSImage(contentsOf: mainBundleIcon) {
            return image
        }

        return nil
    }
}
