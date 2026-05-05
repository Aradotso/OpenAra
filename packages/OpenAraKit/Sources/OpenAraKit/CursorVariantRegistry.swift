import Darwin
import Foundation

/// Snapshot of an OpenAra MCP session's claim on a cursor color. Stored in a
/// shared JSON file under `/tmp/openara-cursor-claims.json` so distinct
/// processes can negotiate non-overlapping cursor variants without blocking on
/// a daemon. Stale entries (whose PID no longer exists) are evicted lazily on
/// every read.
public struct CursorVariantClaim: Codable, Sendable, Equatable {
    public let color: String
    public let pid: Int32
    public let sessionID: String
    public let client: String
    public let startedAt: String

    public init(color: String, pid: Int32, sessionID: String, client: String, startedAt: String) {
        self.color = color
        self.pid = pid
        self.sessionID = sessionID
        self.client = client
        self.startedAt = startedAt
    }
}

public enum CursorVariantRegistry {
    public static let defaultClaimsPath = "/tmp/openara-cursor-claims.json"
    public static let defaultLockPath = "/tmp/openara-cursor-claims.lock"

    /// Pick a cursor variant for this session, preferring an unused color.
    /// `envOverride` wins if it is one of the supported variant names.
    /// Falls back to the deterministic FNV hash if every color is taken.
    public static func claim(
        client: String,
        sessionID: String,
        pid: Int32,
        envOverride: String? = nil,
        claimsPath: String = defaultClaimsPath,
        lockPath: String = defaultLockPath
    ) -> String {
        return withLock(path: lockPath) {
            var claims = readClaims(path: claimsPath).filter { isAlive(pid: $0.pid) && $0.sessionID != sessionID }

            let chosen: String
            if let envOverride, OpenAraCursorVariant.all.contains(envOverride) {
                chosen = envOverride
            } else if let free = firstUnclaimed(after: claims) {
                chosen = free
            } else {
                chosen = OpenAraCursorVariant.resolve(client: client, pid: pid)
            }

            claims.append(
                CursorVariantClaim(
                    color: chosen,
                    pid: pid,
                    sessionID: sessionID,
                    client: client,
                    startedAt: iso8601Now()
                )
            )
            writeClaims(claims, path: claimsPath)
            return chosen
        }
    }

    public static func release(
        sessionID: String,
        claimsPath: String = defaultClaimsPath,
        lockPath: String = defaultLockPath
    ) {
        withLock(path: lockPath) {
            let claims = readClaims(path: claimsPath)
                .filter { isAlive(pid: $0.pid) && $0.sessionID != sessionID }
            writeClaims(claims, path: claimsPath)
        }
    }

    public static func activeClaims(
        claimsPath: String = defaultClaimsPath,
        lockPath: String = defaultLockPath
    ) -> [CursorVariantClaim] {
        return withLock(path: lockPath) {
            let claims = readClaims(path: claimsPath).filter { isAlive(pid: $0.pid) }
            writeClaims(claims, path: claimsPath)
            return claims
        }
    }

    // MARK: - Private

    private static func firstUnclaimed(after claims: [CursorVariantClaim]) -> String? {
        let taken = Set(claims.map(\.color))
        return OpenAraCursorVariant.all.first { !taken.contains($0) }
    }

    private static func withLock<R>(path: String, _ body: () -> R) -> R {
        let fd = open(path, O_RDWR | O_CREAT, 0o644)
        guard fd >= 0 else {
            return body()
        }
        defer { close(fd) }
        _ = flock(fd, LOCK_EX)
        defer { _ = flock(fd, LOCK_UN) }
        return body()
    }

    private static func readClaims(path: String) -> [CursorVariantClaim] {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return []
        }
        return (try? JSONDecoder().decode([CursorVariantClaim].self, from: data)) ?? []
    }

    private static func writeClaims(_ claims: [CursorVariantClaim], path: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(claims) else {
            return
        }
        let tmp = path + ".tmp"
        do {
            try data.write(to: URL(fileURLWithPath: tmp))
            _ = rename(tmp, path)
        } catch {
            // Best-effort: registry is advisory, not authoritative.
        }
    }

    private static func isAlive(pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        let result = kill(pid, 0)
        if result == 0 {
            return true
        }
        return errno == EPERM
    }

    private static func iso8601Now() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }
}
