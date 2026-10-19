#if os(macOS)
import Darwin
import Dispatch
import Foundation

/// A test-owned child with finite execution/cleanup waits and no unread output pipe.
enum OwnedTestSubprocess {
    static let maximumLogBytes = 64 * 1_024

    struct Result {
        let processID: pid_t
        let terminationStatus: Int32
        let terminationReason: Process.TerminationReason
        let timedOut: Bool
        let output: String
    }

    enum Failure: Error {
        case cannotCreateLog
        case cleanupDeadlineExceeded(processID: pid_t, output: String)
    }

    static func run(executable: URL, arguments: [String], environment: [String: String]? = nil,
                    timeout: TimeInterval = 30, terminationGrace: TimeInterval = 1) throws -> Result {
        precondition(timeout > 0 && timeout.isFinite && terminationGrace > 0 && terminationGrace.isFinite)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let logURL = directory.appendingPathComponent("child.log")
        guard FileManager.default.createFile(atPath: logURL.path, contents: nil) else {
            throw Failure.cannotCreateLog
        }
        let log = try FileHandle(forWritingTo: logURL)
        defer { try? log.close() }

        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = environment
        process.standardOutput = log
        process.standardError = log
        let exited = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in exited.signal() }
        try process.run()
        let pid = process.processIdentifier
        var reaped = exited.wait(timeout: .now() + timeout) == .success
        let timedOut = !reaped
        if !reaped {
            if process.isRunning { process.terminate() }
            reaped = exited.wait(timeout: .now() + terminationGrace) == .success
        }
        if !reaped {
            // Signal only this still-running child, never a process name or process group.
            if process.isRunning { _ = Darwin.kill(pid, SIGKILL) }
            reaped = exited.wait(timeout: .now() + terminationGrace) == .success
        }
        let output = try boundedLog(at: logURL)
        guard reaped else { throw Failure.cleanupDeadlineExceeded(processID: pid, output: output) }
        return Result(processID: pid, terminationStatus: process.terminationStatus,
                      terminationReason: process.terminationReason, timedOut: timedOut, output: output)
    }

    private static func boundedLog(at url: URL) throws -> String {
        let file = try FileHandle(forReadingFrom: url)
        defer { try? file.close() }
        let count = try file.seekToEnd()
        try file.seek(toOffset: 0)
        if count <= UInt64(maximumLogBytes) {
            return String(decoding: try file.read(upToCount: maximumLogBytes) ?? Data(), as: UTF8.self)
        }
        let half = maximumLogBytes / 2
        let prefix = try file.read(upToCount: half) ?? Data()
        try file.seek(toOffset: count - UInt64(half))
        let suffix = try file.read(upToCount: half) ?? Data()
        return String(decoding: prefix, as: UTF8.self) +
            "\n[\(count - UInt64(maximumLogBytes)) output bytes omitted]\n" +
            String(decoding: suffix, as: UTF8.self)
    }
}
#endif
