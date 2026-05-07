import AppKit
import Foundation
import OpenAraKit

final class MCPAppRuntime: NSObject, NSApplicationDelegate {
    private let server: StdioMCPServer
    private var runtimeError: Error?
    private var turnEndedObserver: NSObjectProtocol?
    private var remoteCursorObservers: [NSObjectProtocol] = []

    private init(server: StdioMCPServer) {
        self.server = server
    }

    @MainActor
    static func run(server: StdioMCPServer) throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)

        let delegate = MCPAppRuntime(server: server)
        application.delegate = delegate
        application.run()

        if let runtimeError = delegate.runtimeError {
            throw runtimeError
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let selfObject = openAraTurnEndedNotificationObject(pid: getpid())
        turnEndedObserver = DistributedNotificationCenter.default().addObserver(
            forName: openAraTurnEndedNotificationName,
            object: selfObject,
            queue: .main
        ) { _ in
            Task { @MainActor in
                resetOpenAraVisualCursor()
            }
        }

        // Remote-cursor channel: when the host (Ara Desktop's acp-bridge) sets
        // OPENARA_REMOTE_CURSOR=1, register a second set of observers that let
        // any external mechanism — primarily the Playwright/CDP browser path —
        // animate this overlay to a screen point and pulse a click. The cursor
        // becomes a single coherent narrator for every agent action regardless
        // of which mechanism fired underneath.
        if openAraRemoteCursorEnabled() {
            MainActor.assumeIsolated {
                remoteCursorObservers = startOpenAraRemoteCursorChannel(pid: getpid())
            }
        }

        Thread.detachNewThreadSelector(#selector(processStandardIO), toTarget: self, with: nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let turnEndedObserver {
            DistributedNotificationCenter.default().removeObserver(turnEndedObserver)
        }
        if !remoteCursorObservers.isEmpty {
            stopOpenAraRemoteCursorChannel(remoteCursorObservers)
            remoteCursorObservers.removeAll()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    @objc
    private func processStandardIO() {
        do {
            try server.run()
        } catch {
            runtimeError = error
        }

        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }
}
