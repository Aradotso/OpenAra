import Foundation

/// File-append logger for OpenAra. Mirrors the queue-backed pattern used in
/// AraDesktop so the broader Ara product line shares a single observability shape.
///
/// Writes go to `~/Library/Logs/OpenAra/openara.log` (release) or
/// `openara-dev.log` (dev), chosen by bundle identifier suffix. Files are
/// created with mode 0600 so other local users cannot read them, and rotate
/// when they exceed `logRotationByteLimit` (5 MB) — the previous file is kept
/// as `.1` and a fresh empty file takes over. Set `OPENARA_LOG_DIR` to
/// override the directory (used by tests and embedders). Embedders can also
/// subscribe in-process via ``OpenAraLogger/subscribe(_:)`` to receive
/// structured records as they happen — useful for AraDesktop, smoke
/// harnesses, and tests.
public enum OpenAraLogger {
    public enum Level: String, Sendable {
        case debug
        case info
        case warn
        case error
    }

    public struct Record: Sendable {
        public let timestamp: Date
        public let level: Level
        public let category: String
        public let message: String
    }

    public typealias Subscriber = @Sendable (Record) -> Void

    // MARK: - Public surface

    /// Write a debug-level record. Use for verbose tracing.
    public static func debug(_ message: @autoclosure () -> String, category: String = "openara") {
        emit(.debug, category: category, message: message())
    }

    /// Write an info-level record. Default for routine lifecycle events.
    public static func info(_ message: @autoclosure () -> String, category: String = "openara") {
        emit(.info, category: category, message: message())
    }

    /// Write a warn-level record. Use for recoverable problems.
    public static func warn(_ message: @autoclosure () -> String, category: String = "openara") {
        emit(.warn, category: category, message: message())
    }

    /// Write an error-level record. Use for unrecoverable problems and surface
    /// them on `stderr` so the parent process sees them immediately.
    public static func error(_ message: @autoclosure () -> String, category: String = "openara") {
        let resolved = message()
        emit(.error, category: category, message: resolved)
        let line = "openara error: \(resolved)\n"
        if let data = line.data(using: .utf8) {
            FileHandle.standardError.write(data)
        }
    }

    /// Subscribe to log records in-process. Returns a cancellation token; call it
    /// to unsubscribe. Subscriptions never receive historical records.
    @discardableResult
    public static func subscribe(_ subscriber: @escaping Subscriber) -> () -> Void {
        let token = state.withLock { $0.addSubscriber(subscriber) }
        return { state.withLock { $0.removeSubscriber(token) } }
    }

    /// Force-flush the in-flight write queue. Tests use this; production code
    /// generally does not.
    public static func flush() {
        writeQueue.sync(flags: .barrier) {}
    }

    // MARK: - Internals

    private static let writeQueue = DispatchQueue(
        label: "com.ara.openara.logger",
        qos: .utility,
        attributes: .concurrent
    )

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    /// Default rotation threshold. The previous file is kept as `<basename>.1`.
    static let logRotationByteLimit: UInt64 = 5 * 1024 * 1024

    private static let logFilePath: String = resolveLogPath()

    private static func resolveLogPath() -> String {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let basename = bundleID.hasSuffix(".dev") ? "openara-dev.log" : "openara.log"
        let directory = resolveLogDirectory()
        return (directory as NSString).appendingPathComponent(basename)
    }

    private static func resolveLogDirectory() -> String {
        let environment = ProcessInfo.processInfo.environment
        if let override = environment["OPENARA_LOG_DIR"], !override.isEmpty {
            return (override as NSString).expandingTildeInPath
        }
        let home = NSHomeDirectory() as NSString
        return home.appendingPathComponent("Library/Logs/OpenAra")
    }

    private struct State {
        var nextSubscriberID: UInt64 = 0
        var subscribers: [UInt64: Subscriber] = [:]

        mutating func addSubscriber(_ subscriber: @escaping Subscriber) -> UInt64 {
            nextSubscriberID += 1
            let token = nextSubscriberID
            subscribers[token] = subscriber
            return token
        }

        mutating func removeSubscriber(_ token: UInt64) {
            subscribers.removeValue(forKey: token)
        }
    }

    private static let state = MutexBox(State())

    private static func emit(_ level: Level, category: String, message: String) {
        let record = Record(timestamp: Date(), level: level, category: category, message: message)
        notifySubscribers(record)
        appendToFile(record)
    }

    private static func notifySubscribers(_ record: Record) {
        let snapshot = state.withLock { Array($0.subscribers.values) }
        for subscriber in snapshot {
            subscriber(record)
        }
    }

    private static func appendToFile(_ record: Record) {
        let line = format(record)
        guard let data = line.data(using: .utf8) else { return }
        writeQueue.async(flags: .barrier) {
            writeData(data)
        }
    }

    private static func format(_ record: Record) -> String {
        let stamp = timestampFormatter.string(from: record.timestamp)
        return "[\(stamp)] [\(record.level.rawValue)] [\(record.category)] \(record.message)\n"
    }

    private static func writeData(_ data: Data) {
        let path = logFilePath
        ensureLogDirectory(for: path)
        rotateIfNeeded(path: path, additionalBytes: data.count)

        let manager = FileManager.default
        if manager.fileExists(atPath: path) {
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
            return
        }

        let attributes: [FileAttributeKey: Any] = [.posixPermissions: NSNumber(value: Int16(0o600))]
        manager.createFile(atPath: path, contents: data, attributes: attributes)
    }

    private static func ensureLogDirectory(for path: String) {
        let directory = (path as NSString).deletingLastPathComponent
        if directory.isEmpty { return }
        let manager = FileManager.default
        var isDir: ObjCBool = false
        if manager.fileExists(atPath: directory, isDirectory: &isDir), isDir.boolValue {
            return
        }
        try? manager.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: NSNumber(value: Int16(0o700))]
        )
    }

    private static func rotateIfNeeded(path: String, additionalBytes: Int) {
        let manager = FileManager.default
        guard manager.fileExists(atPath: path) else { return }
        guard let attrs = try? manager.attributesOfItem(atPath: path),
              let size = attrs[.size] as? UInt64 else { return }
        if size + UInt64(additionalBytes) <= logRotationByteLimit { return }

        let rotatedPath = path + ".1"
        if manager.fileExists(atPath: rotatedPath) {
            try? manager.removeItem(atPath: rotatedPath)
        }
        try? manager.moveItem(atPath: path, toPath: rotatedPath)
    }
}

// MARK: - MutexBox

/// Tiny lock-protected container; avoids pulling in Swift Concurrency to keep
/// OpenAraKit usable from synchronous CLI entry points.
private final class MutexBox<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()

    init(_ value: T) {
        self.value = value
    }

    func withLock<R>(_ body: (inout T) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}
