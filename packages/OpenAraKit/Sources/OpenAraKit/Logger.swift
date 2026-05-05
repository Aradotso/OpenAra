import Foundation

/// File-append logger for OpenAra. Mirrors the queue-backed pattern used in
/// AraDesktop so the broader Ara product line shares a single observability shape.
///
/// Writes go to `/tmp/openara.log` (release) or `/tmp/openara-dev.log` (dev),
/// chosen by bundle identifier suffix. Embedders can also subscribe in-process
/// via ``OpenAraLogger/subscribe(_:)`` to receive structured records as they
/// happen — useful for AraDesktop, smoke harnesses, and tests.
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

    private static let logFilePath: String = {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        return bundleID.hasSuffix(".dev") ? "/tmp/openara-dev.log" : "/tmp/openara.log"
    }()

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
        if FileManager.default.fileExists(atPath: path) {
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: path, contents: data)
        }
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
