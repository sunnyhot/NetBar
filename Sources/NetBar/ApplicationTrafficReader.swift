import AppKit
import Foundation

struct ApplicationTrafficReadResult {
    let stats: [ApplicationTrafficStats]
    let errorMessage: String?
}

protocol ApplicationTrafficReading: Sendable {
    func readApplications() -> ApplicationTrafficReadResult
}

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
            process.waitUntilExit()
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

    private static func parse(_ output: String) -> [ApplicationTrafficStats] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { parseLine(String($0)) }
    }

    private static func parseLine(_ line: String) -> ApplicationTrafficStats? {
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

    private static func parseProcessToken(_ token: String) -> (name: String, pid: Int32?) {
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

    private static func displayName(for pid: Int32?, fallback: String) -> String {
        guard
            let pid,
            let runningApplication = NSRunningApplication(processIdentifier: pid),
            let localizedName = runningApplication.localizedName,
            !localizedName.isEmpty
        else {
            return fallback
        }
        return localizedName
    }
}
