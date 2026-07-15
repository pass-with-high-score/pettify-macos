import Foundation
import CryptoKit

// MARK: - TrackInfo

struct TrackInfo {
    let title: String
    let videoId: String
    let url: String
    let artist: String
    var localThumbnailURL: String? = nil

    var thumbnailURL: String {
        if let local = localThumbnailURL { return local }
        if videoId.isEmpty { return "" }
        return "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg"
    }
}

// MARK: - YtDlpService

@MainActor
final class YtDlpService: ObservableObject {

    // MARK: Published State

    @Published var setupStatus: String = ""

    // MARK: Paths

    private let appSupportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("audio-cli", isDirectory: true)
    }()

    private var binaryPath: URL {
        appSupportDir.appendingPathComponent("yt-dlp")
    }

    private let cacheDir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("audio-cli-yt", isDirectory: true)
    }()

    private static let downloadURL = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!

    // MARK: - Setup

    /// Ensures the yt-dlp binary is available, downloading it if necessary.
    func ensureBinary() async {
        let fm = FileManager.default

        // Create directories if needed
        try? fm.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        try? fm.createDirectory(at: cacheDir, withIntermediateDirectories: true)

        if fm.fileExists(atPath: binaryPath.path) {
            setupStatus = "yt-dlp ready"
            return
        }

        setupStatus = "Downloading yt-dlp…"
        do {
            let (tempURL, _) = try await URLSession.shared.download(from: Self.downloadURL)
            try? fm.removeItem(at: binaryPath)
            try fm.moveItem(at: tempURL, to: binaryPath)

            // chmod 755
            try fm.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: binaryPath.path
            )
            setupStatus = "yt-dlp ready"
        } catch {
            setupStatus = "Failed to download yt-dlp: \(error.localizedDescription)"
        }
    }

    // MARK: - Search

    /// Searches YouTube for the given query string and returns track metadata.
    /// If the query starts with "http", it is treated as a direct URL.
    func search(query: String) async throws -> [TrackInfo] {
        await ensureBinary()
        let effectiveQuery = query.lowercased().hasPrefix("http") ? query : "ytsearch1:\(query)"

        let output = try await runYtDlp(arguments: [
            "--no-warnings",
            "--playlist-end", "10",
            "--extractor-args", "youtube:player_client=android",
            "--print", "%(title)s\t%(id)s\t%(webpage_url)s\t%(uploader)s",
            effectiveQuery
        ])

        let lines = output.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var tracks: [TrackInfo] = []
        for line in lines {
            let parts = line.components(separatedBy: "\t")
            if parts.count >= 4 {
                tracks.append(TrackInfo(
                    title: parts[0],
                    videoId: parts[1],
                    url: parts[2],
                    artist: parts[3]
                ))
            }
        }
        
        if tracks.isEmpty {
            throw YtDlpError.parseError("Unexpected output format or no results")
        }

        return tracks
    }

    // MARK: - Download Audio

    /// Downloads audio for the given YouTube URL and returns a local file URL.
    /// Results are cached using an MD5 hash of the URL as the filename.
    func downloadAudio(from youtubeURL: String, quality: String = "bestaudio") async throws -> URL {
        await ensureBinary()
        let hash = md5(youtubeURL)
        let outputPath = cacheDir.appendingPathComponent("\(hash).mp3")

        if FileManager.default.fileExists(atPath: outputPath.path) {
            return outputPath
        }
        
        let audioFormat: String
        if quality == "128k" {
            audioFormat = "bestaudio[abr<=128]/bestaudio/best"
        } else if quality == "256k" {
            audioFormat = "bestaudio[abr<=256]/bestaudio/best"
        } else {
            audioFormat = "bestaudio/best"
        }

        _ = try await runYtDlp(arguments: [
            "--no-warnings",
            "--no-playlist",
            "--extractor-args", "youtube:player_client=android",
            "-x",
            "--audio-format", "mp3",
            "--audio-quality", quality == "bestaudio" ? "0" : "5",
            "-f", audioFormat,
            "-o", outputPath.path,
            youtubeURL
        ])

        guard FileManager.default.fileExists(atPath: outputPath.path) else {
            throw YtDlpError.downloadFailed("Output file not found after download")
        }

        return outputPath
    }

    // MARK: - Thumbnail

    /// Extracts the YouTube video ID from a URL and returns a thumbnail URL.
    func thumbnailURL(from youtubeURL: String) -> String? {
        guard let videoId = extractVideoId(from: youtubeURL) else { return nil }
        return "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg"
    }

    // MARK: - Private Helpers

    /// Runs the yt-dlp binary with the given arguments on a background thread.
    private func runYtDlp(arguments: [String]) async throws -> String {
        let binary = binaryPath.path

        guard FileManager.default.fileExists(atPath: binary) else {
            throw YtDlpError.binaryNotFound
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binary)
            process.arguments = arguments

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            let group = DispatchGroup()
            var outputData = Data()
            var errData = Data()

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            // Read stdout concurrently to prevent deadlocks
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                outputData = stdout.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            // Read stderr concurrently
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                errData = stderr.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }

            // Wait for reading to complete and process to exit
            DispatchQueue.global(qos: .utility).async {
                group.wait()
                process.waitUntilExit()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                if process.terminationStatus == 0 {
                    continuation.resume(returning: output)
                } else {
                    let errOutput = String(data: errData, encoding: .utf8) ?? ""
                    continuation.resume(throwing: YtDlpError.processError(
                        code: process.terminationStatus,
                        message: errOutput.isEmpty ? output : errOutput
                    ))
                }
            }
        }
    }

    /// Extracts a YouTube video ID from common URL formats.
    private func extractVideoId(from urlString: String) -> String? {
        guard let url = URL(string: urlString) else { return nil }

        // youtu.be/<id>
        if url.host?.contains("youtu.be") == true {
            let id = url.pathComponents.dropFirst().first
            return id
        }

        // youtube.com/watch?v=<id>
        if url.host?.contains("youtube.com") == true {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            return components?.queryItems?.first(where: { $0.name == "v" })?.value
        }

        return nil
    }

    /// Computes the MD5 hex digest of a string.
    private func md5(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Errors

enum YtDlpError: LocalizedError {
    case binaryNotFound
    case parseError(String)
    case downloadFailed(String)
    case processError(code: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case .binaryNotFound:
            return "yt-dlp binary not found. Please restart the app to download it."
        case .parseError(let detail):
            return "Failed to parse yt-dlp output: \(detail)"
        case .downloadFailed(let detail):
            return "Audio download failed: \(detail)"
        case .processError(let code, let message):
            return "yt-dlp exited with code \(code): \(message)"
        }
    }
}
