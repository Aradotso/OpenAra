import AppKit
import CoreText
import Foundation

public enum AppFonts {
    public static let serifFamily = "EB Garamond"
    public static let sansFamily = "Inter"

    private static let bundledFonts: [(resource: String, ext: String)] = [
        ("EBGaramond-Variable", "ttf"),
        ("Inter-Variable", "ttf"),
    ]

    private static let registrationLock = NSLock()
    nonisolated(unsafe) private static var didRegister = false

    public static func registerBundledFonts() {
        registrationLock.lock()
        defer { registrationLock.unlock() }
        guard !didRegister else { return }
        didRegister = true

        for (resource, ext) in bundledFonts {
            guard let url = OpenAraKitResources.url(forResource: resource, withExtension: ext) else {
                continue
            }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }

    public static func serif(size: CGFloat) -> NSFont {
        registerBundledFonts()
        return NSFont(name: serifFamily, size: size)
            ?? NSFont(name: "New York", size: size)
            ?? NSFont.systemFont(ofSize: size)
    }

    public static func sans(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        registerBundledFonts()
        if let interFamilyMatch = NSFont(name: weightedInterName(for: weight), size: size) {
            return interFamilyMatch
        }
        return NSFont.systemFont(ofSize: size, weight: weight)
    }

    private static func weightedInterName(for weight: NSFont.Weight) -> String {
        switch weight {
        case .ultraLight, .thin, .light:
            return "Inter-Light"
        case .medium:
            return "Inter-Medium"
        case .semibold:
            return "Inter-SemiBold"
        case .bold:
            return "Inter-Bold"
        case .heavy, .black:
            return "Inter-Black"
        default:
            return "Inter-Regular"
        }
    }
}
