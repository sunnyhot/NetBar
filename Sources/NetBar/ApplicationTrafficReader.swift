import AppKit
import Darwin
import Foundation

struct ApplicationTrafficReadResult {
    let stats: [ApplicationTrafficStats]
    let errorMessage: String?
}

/// Streaming reader 失败原因的稳定标识。reader 层无法访问语言偏好,
/// 通过 rawValue 透传到 UI 层再映射为双语文案。
enum ApplicationTrafficReaderFailure: String {
    case spawnFailed = "spawn_failed"
    case restartsExhausted = "restarts_exhausted"
}

protocol ApplicationTrafficReading: Sendable {
    func readApplications() -> ApplicationTrafficReadResult
}

// MARK: - Streaming nettop reader (persistent process)

final class StreamingNettopReader: ApplicationTrafficReading, @unchecked Sendable {
    private let executableURL: URL
    private let arguments: [String]

    private var process: Process?
    private var outputPipe: Pipe?
    private var latestStats: [String: ApplicationTrafficStats] = [:]
    private var partialLine: String = ""
    private let lock = NSLock()
    private(set) var isRunning = false
    private var restartAttempts = 0
    private let maxRestartAttempts = 3
    private var lastErrorMessage: String?

    private static let nettopArguments = [
        "-P",
        "-L", "0",
        "-x",
        "-t", "external",
        "-J", "bytes_in,bytes_out"
    ]

    private static let defaultArguments = [
        "-q",
        "/dev/null",
        "/usr/bin/nettop"
    ] + StreamingNettopReader.nettopArguments

    init(
        executableURL: URL = URL(fileURLWithPath: "/usr/bin/script"),
        arguments: [String] = StreamingNettopReader.defaultArguments
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
    }

    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !isRunning else { return }
        launchProcess()
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        isRunning = false
        process?.terminate()
        process = nil
        closeOutputHandleLocked()
        latestStats.removeAll(keepingCapacity: true)
        partialLine.removeAll(keepingCapacity: true)
        // 主动停止不是错误,清除历史错误避免下次 start() 前误报
        lastErrorMessage = nil
    }

    func readApplications() -> ApplicationTrafficReadResult {
        lock.lock()
        let stats = Array(latestStats.values)
        let errorMessage = lastErrorMessage
        lock.unlock()

        if !stats.isEmpty {
            return ApplicationTrafficReadResult(stats: stats, errorMessage: nil)
        }
        if let errorMessage {
            return ApplicationTrafficReadResult(stats: [], errorMessage: errorMessage)
        }
        return ApplicationTrafficReadResult(stats: [], errorMessage: nil)
    }

    private func launchProcess() {
        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        // nettop buffers CSV output heavily when stdout is a regular Pipe.
        // macOS' script command allocates a pseudo-terminal for nettop, making
        // it flush lines immediately like common realtime traffic monitors.
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        process.terminationHandler = { [weak self] _ in
            self?.handleProcessTermination()
        }

        do {
            try process.run()
            self.process = process
            self.outputPipe = outputPipe
            self.isRunning = true
            // 注意:此处不重置 restartAttempts——spawn 成功不代表健康,
            // 只有解析到真实数据(appendOutput)才重置,否则瞬死循环无法耗尽
            lastErrorMessage = nil
            startOutputReader(outputPipe)
        } catch {
            try? outputPipe.fileHandleForReading.close()
            self.process = nil
            self.outputPipe = nil
            lastErrorMessage = ApplicationTrafficReaderFailure.spawnFailed.rawValue
        }
    }

    private func startOutputReader(_ outputPipe: Pipe) {
        DispatchQueue.global(qos: .utility).async { [weak self, outputPipe] in
            let handle = outputPipe.fileHandleForReading
            let fileDescriptor = handle.fileDescriptor
            var buffer = [UInt8](repeating: 0, count: 64 * 1024)
            while true {
                let bytesRead = Darwin.read(fileDescriptor, &buffer, buffer.count)
                guard bytesRead > 0 else { break }
                let data = Data(buffer.prefix(bytesRead))
                let text = String(data: data, encoding: .utf8) ?? ""
                self?.appendOutput(text)
            }
        }
    }

    private func appendOutput(_ text: String) {
        lock.lock()
        defer { lock.unlock() }
        guard isRunning else { return }

        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let combined = partialLine + normalizedText
        let lines = combined.split(separator: "\n", omittingEmptySubsequences: false)

        // If text doesn't end with newline, last element is incomplete
        let hasTrailingNewline = normalizedText.last == "\n"
        let completeLineCount = hasTrailingNewline ? lines.count : lines.count - 1

        for i in 0..<completeLineCount {
            let line = lines[i]
            guard !line.isEmpty else { continue }
            if let stat = NettopLineParser.parseLine(String(line)) {
                latestStats[stat.id] = stat
                // 解析到真实数据 = 进程健康,重置重启预算
                restartAttempts = 0
            }
        }

        if hasTrailingNewline {
            partialLine = ""
        } else {
            partialLine = String(lines.last ?? "")
        }

        // Safety cap: partialLine should stay small (a few KB)
        if partialLine.count > 64_000 {
            partialLine = ""
        }
    }

    private func handleProcessTermination() {
        lock.lock()
        guard isRunning else {
            lock.unlock()
            return
        }
        closeOutputHandleLocked()

        if restartAttempts < maxRestartAttempts {
            // 重启尝试期间保留 latestStats:进程瞬间重启成功是常态,
            // 清空会让 UI 在重启窗口期闪空态
            restartAttempts += 1
            launchProcess()
            lock.unlock()
        } else {
            // 放弃重启:复位 isRunning/process,让 start() 可以再次拉起
            // (此前 isRunning 卡 true 导致耗尽后永远无法自愈)
            isRunning = false
            process = nil
            latestStats.removeAll(keepingCapacity: true)
            partialLine.removeAll(keepingCapacity: true)
            lastErrorMessage = ApplicationTrafficReaderFailure.restartsExhausted.rawValue
            lock.unlock()
        }
    }

    private func closeOutputHandleLocked() {
        outputPipe = nil
    }

    deinit {
        process?.terminate()
    }
}

// MARK: - Nettop CSV line parser

/// Parses a single line of nettop CSV output into an `ApplicationTrafficStats`.
///
/// This is a shared helper for the streaming reader (`StreamingNettopReader`);
/// the legacy one-shot reader that previously hosted these statics has been removed.
enum NettopLineParser {
    /// nettop arguments scoped to a single sample (`-L 1`).
    static let arguments = [
        "-P",
        "-L", "1",
        "-x",
        "-t", "external",
        "-J", "bytes_in,bytes_out"
    ]

    static func parseLine(_ line: String) -> ApplicationTrafficStats? {
        let line = stripControlCharacters(from: line)
        guard !line.hasPrefix(",") else { return nil }

        let columns = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard columns.count >= 3 else { return nil }

        let processToken = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !processToken.isEmpty else { return nil }

        let receivedBytes = UInt64(columns[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let sentBytes = UInt64(columns[2].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        let parsedProcess = parseProcessToken(processToken)
        let displayName = displayName(for: parsedProcess.pid, fallback: parsedProcess.name)
        let id = parsedProcess.pid.map { "\(parsedProcess.name).\($0)" } ?? parsedProcess.name

        return ApplicationTrafficStats(
            id: id,
            processName: parsedProcess.name,
            displayName: displayName,
            pid: parsedProcess.pid,
            receivedBytes: receivedBytes,
            sentBytes: sentBytes
        )
    }

    static func parseProcessToken(_ token: String) -> (name: String, pid: Int32?) {
        guard
            let dotIndex = token.lastIndex(of: "."),
            dotIndex < token.index(before: token.endIndex)
        else {
            return (token, nil)
        }

        let name = String(token[..<dotIndex])
        let pidText = String(token[token.index(after: dotIndex)...])
        return (name, Int32(pidText))
    }

    private static func stripControlCharacters(from line: String) -> String {
        var scalars: [UnicodeScalar] = []
        for scalar in line.unicodeScalars {
            switch scalar.value {
            case 8:
                if !scalars.isEmpty {
                    scalars.removeLast()
                }
            case 0..<32:
                continue
            default:
                scalars.append(scalar)
            }
        }
        return String(String.UnicodeScalarView(scalars))
    }

    private static let displayNameCache = LockedObjectCache<NSNumber, NSString>()

    static func displayName(for pid: Int32?, fallback: String) -> String {
        guard let pid else { return fallback }

        let key = NSNumber(value: pid)
        if let cached = displayNameCache.object(forKey: key) {
            return cached as String
        }

        guard
            let runningApplication = NSRunningApplication(processIdentifier: pid),
            let localizedName = runningApplication.localizedName,
            !localizedName.isEmpty
        else {
            return fallback
        }

        displayNameCache.setObject(localizedName as NSString, forKey: key)
        return localizedName
    }
}
