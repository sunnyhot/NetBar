import AppKit
import Darwin
import Foundation

struct ApplicationTrafficReadResult {
    let stats: [ApplicationTrafficStats]
    let errorMessage: String?
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
    private var isRunning = false
    private var restartAttempts = 0
    private let maxRestartAttempts = 3

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
    }

    func readApplications() -> ApplicationTrafficReadResult {
        lock.lock()
        let stats = Array(latestStats.values)
        let hasProcess = process != nil
        lock.unlock()

        if hasProcess && !stats.isEmpty {
            return ApplicationTrafficReadResult(stats: stats, errorMessage: nil)
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
            restartAttempts = 0
            startOutputReader(outputPipe)
        } catch {
            try? outputPipe.fileHandleForReading.close()
            self.process = nil
            self.outputPipe = nil
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
            if let stat = NettopApplicationTrafficReader.parseLinePublic(String(line)) {
                latestStats[stat.id] = stat
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
        latestStats.removeAll(keepingCapacity: true)
        partialLine.removeAll(keepingCapacity: true)
        lock.unlock()

        if restartAttempts < maxRestartAttempts {
            restartAttempts += 1
            lock.lock()
            launchProcess()
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

// MARK: - One-shot nettop reader (fallback)

final class NettopApplicationTrafficReader: ApplicationTrafficReading, @unchecked Sendable {
    static let arguments = [
        "-P",
        "-L", "1",
        "-x",
        "-t", "external",
        "-J", "bytes_in,bytes_out"
    ]

    private let executableURL = URL(fileURLWithPath: "/usr/bin/nettop")

    func readApplications() -> ApplicationTrafficReadResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = executableURL
        process.arguments = Self.arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            // Add a 10-second timeout to prevent waitUntilExit() from hanging
            // indefinitely on some macOS versions, which would leave
            // isReadingApplicationTraffic stuck at true forever.
            let semaphore = DispatchSemaphore(value: 0)
            DispatchQueue.global().async {
                process.waitUntilExit()
                semaphore.signal()
            }
            let timeoutResult = semaphore.wait(timeout: .now() + 10.0)
            if timeoutResult == .timedOut {
                process.terminate()
                return ApplicationTrafficReadResult(
                    stats: [],
                    errorMessage: "nettop 读取超时（10秒）"
                )
            }
        } catch {
            return ApplicationTrafficReadResult(
                stats: [],
                errorMessage: "无法启动 nettop：\(error.localizedDescription)"
            )
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return ApplicationTrafficReadResult(
                stats: [],
                errorMessage: message?.isEmpty == false ? message : "nettop 退出码：\(process.terminationStatus)"
            )
        }

        let output = String(data: outputData, encoding: .utf8) ?? ""
        return ApplicationTrafficReadResult(
            stats: Self.parse(output),
            errorMessage: nil
        )
    }

    fileprivate static func parse(_ output: String) -> [ApplicationTrafficStats] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { parseLinePublic(String($0)) }
    }

    fileprivate static func parseLinePublic(_ line: String) -> ApplicationTrafficStats? {
        let line = stripControlCharacters(from: line)
        guard !line.hasPrefix(",") else { return nil }

        let columns = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard columns.count >= 3 else { return nil }

        let processToken = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !processToken.isEmpty else { return nil }

        let receivedBytes = UInt64(columns[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let sentBytes = UInt64(columns[2].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        let parsedProcess = parseProcessToken(processToken)
        let displayName = displayNamePublic(for: parsedProcess.pid, fallback: parsedProcess.name)
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

    fileprivate static func parseProcessToken(_ token: String) -> (name: String, pid: Int32?) {
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

    private static let displayNameCache = NSCache<NSNumber, NSString>()

    fileprivate static func displayNamePublic(for pid: Int32?, fallback: String) -> String {
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
