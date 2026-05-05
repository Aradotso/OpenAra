import CryptoKit
import Foundation

/// Per-tool whitelist of argument keys whose values are sensitive (typed text,
/// values written into form fields, etc.) and must not appear in plaintext logs.
///
/// The redactor replaces these values with a `<redacted len=N sha8=…>` token that
/// preserves enough signal for "did the same thing get sent twice" debugging
/// without leaking the underlying string. The SHA-8 is salted per-process so
/// hashes do not survive across runs and cannot be cross-referenced between
/// machines.
///
/// Tools not in the whitelist fail closed: every argument value is redacted.
/// This means a future tool with a sensitive field cannot accidentally leak its
/// payload because someone forgot to update the whitelist — the failure mode is
/// "logs are noisier than necessary," not "logs leak secrets."
public enum ArgumentRedactor {
    /// Argument keys whose VALUES are safe to log in plaintext, grouped by tool.
    /// Anything not listed gets redacted. Keep this list tight; default to
    /// redaction when in doubt.
    private static let plaintextAllowlist: [String: Set<String>] = [
        "list_apps":                Set(),
        "get_app_state":            ["app", "app_id", "include_screenshot", "screenshot_max_width"],
        "click":                    ["app", "app_id", "element_index", "x", "y", "click_count", "button"],
        "perform_secondary_action": ["app", "app_id", "element_index", "x", "y"],
        "scroll":                   ["app", "app_id", "element_index", "x", "y", "direction", "pages"],
        "drag":                     ["app", "app_id", "from_element_index", "to_element_index", "from_x", "from_y", "to_x", "to_y"],
        "press_key":                ["app", "app_id", "key"],
        "type_text":                ["app", "app_id", "element_index"],
        "set_value":                ["app", "app_id", "element_index"],
    ]

    /// Per-process random salt. Re-rolled at startup so log hashes from one run
    /// cannot be correlated with another run, even on the same machine.
    private static let salt: Data = {
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status != errSecSuccess {
            for index in 0..<bytes.count {
                bytes[index] = UInt8.random(in: 0...255)
            }
        }
        return Data(bytes)
    }()

    public static func redact(toolName: String, arguments: [String: Any]) -> [String: Any] {
        let allowedKeys = plaintextAllowlist[toolName] ?? Set()
        var result: [String: Any] = [:]
        for (key, value) in arguments {
            if allowedKeys.contains(key) {
                result[key] = value
            } else {
                result[key] = redactedToken(for: value)
            }
        }
        return result
    }

    static func redactedToken(for value: Any) -> String {
        let stringForm: String
        if let text = value as? String {
            stringForm = text
        } else {
            stringForm = String(describing: value)
        }

        let length = stringForm.utf8.count
        if length == 0 {
            return "<redacted len=0>"
        }

        var hasher = SHA256()
        hasher.update(data: salt)
        if let payload = stringForm.data(using: .utf8) {
            hasher.update(data: payload)
        }
        let digest = hasher.finalize()
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        let sha8 = String(hex.prefix(8))
        return "<redacted len=\(length) sha8=\(sha8)>"
    }
}

/// `OPENARA_LOG_RAW_ARGS=1` (or `true`/`yes`/`on`) opts out of redaction —
/// useful when debugging your own machine. Logged once at startup so the
/// choice is auditable.
public func argumentRedactionDisabled(environment: [String: String]) -> Bool {
    guard let rawValue = environment["OPENARA_LOG_RAW_ARGS"]?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .lowercased()
    else {
        return false
    }

    return ["1", "true", "yes", "on"].contains(rawValue)
}
