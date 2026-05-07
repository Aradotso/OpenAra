import Foundation
import OpenAraKit

// Tiny CLI that posts a remote-cursor distributed notification at a target
// openara child process. Existed because the host (Ara Desktop's acp-bridge)
// is Node and needs a fast (sub-50ms) way to drive the cursor — `xcrun swift
// -e <one-liner>` pays a ~200ms compiler startup per call, which is too slow
// for narrate-before-click animation budgets.
//
// Usage:
//   openara-cursor-narrator move  <pid> <x> <y>
//   openara-cursor-narrator pulse <pid> <x> <y> [clicks=1] [button=left|right]
//   openara-cursor-narrator reset <pid>
//
// All coordinates are AppKit global screen space (origin bottom-left, y-up).

let args = Array(CommandLine.arguments.dropFirst())

func usage() -> Never {
    FileHandle.standardError.write(Data("""
    usage: openara-cursor-narrator <op> <pid> [args...]
      move  <pid> <x> <y>
      pulse <pid> <x> <y> [clicks=1] [button=left|right]
      reset <pid>
    """.utf8))
    exit(64)
}

guard args.count >= 2 else { usage() }

let op = args[0].lowercased()
guard let pid = Int32(args[1]) else { usage() }

switch op {
case "move":
    guard args.count >= 4,
          let x = Double(args[2]),
          let y = Double(args[3])
    else { usage() }
    postOpenAraRemoteCursorMove(targetPID: pid, x: x, y: y)

case "pulse":
    guard args.count >= 4,
          let x = Double(args[2]),
          let y = Double(args[3])
    else { usage() }
    let clicks = args.count >= 5 ? (Int(args[4]) ?? 1) : 1
    let button = args.count >= 6 ? args[5] : "left"
    postOpenAraRemoteCursorPulse(targetPID: pid, x: x, y: y, clicks: clicks, button: button)

case "reset":
    postOpenAraRemoteCursorReset(targetPID: pid)

default:
    usage()
}

// Distributed notifications are async — give the system a moment to dispatch
// before exit so the post isn't dropped on the floor.
RunLoop.main.run(until: Date().addingTimeInterval(0.05))
