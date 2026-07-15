import Foundation

class YTDLP {
    nonisolated(unsafe) static let shared = YTDLP()
    private let fileManager = FileManager.default
    
    private var ytDlpPath: String {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("audio-cli")
        return dir.appendingPathComponent("yt-dlp").path
    }
    
    func ensureYtDlp() async throws -> String {
        if fileManager.fileExists(atPath: ytDlpPath) {
            return ytDlpPath
        }
        
        print("Downloading yt-dlp...")
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("audio-cli")
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        
        let url = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw NSError(domain: "YTDLP", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to download yt-dlp"])
        }
        
        try data.write(to: URL(fileURLWithPath: ytDlpPath))
        
        // Make executable
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/chmod")
        task.arguments = ["+x", ytDlpPath]
        try task.run()
        task.waitUntilExit()
        
        return ytDlpPath
    }
    
    struct YTSearchResult: Identifiable, Equatable {
        let id: String
        var title: String
        var url: String
        var uploader: String
    }
    
    func search(query: String) async throws -> [YTSearchResult] {
        let path = try await ensureYtDlp()
        var searchQuery = query
        if query.hasPrefix("yt: ") || query.hasPrefix("yt:") {
            searchQuery = "ytsearch5:" + query.replacingOccurrences(of: "yt: ", with: "").replacingOccurrences(of: "yt:", with: "").trimmingCharacters(in: .whitespaces)
        } else if !query.hasPrefix("http") && !query.hasPrefix("/") && !query.hasPrefix("./") && !query.hasPrefix("~/") {
            searchQuery = "ytsearch5:" + query
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = ["--extractor-args", "youtube:player_client=android", "--print", "%(title)s\t%(id)s\t%(url)s\t%(uploader)s", searchQuery]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Ignore stderr warnings
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            throw NSError(domain: "YTDLP", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Search failed"])
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "YTDLP", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to read output"])
        }
        
        let lines = output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines)
        if lines.isEmpty {
            throw NSError(domain: "YTDLP", code: 3, userInfo: [NSLocalizedDescriptionKey: "No output from yt-dlp"])
        }
        
        var results: [YTSearchResult] = []
        for line in lines {
            let parts = line.components(separatedBy: "\t")
            if parts.count >= 3 {
                var url = parts[2]
                let id = parts[1]
                if !url.hasPrefix("http") || url == "NA" {
                    if id != "NA" && !id.isEmpty {
                        url = "https://youtu.be/" + id
                    } else {
                        continue
                    }
                }
                results.append(YTSearchResult(id: id, title: parts[0], url: url, uploader: parts.count >= 4 ? parts[3] : ""))
            }
        }
        
        if results.isEmpty {
            throw NSError(domain: "YTDLP", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to parse result"])
        }
        return results
    }
    
    func getStreamURL(for url: String) async throws -> String {
        let path = try await ensureYtDlp()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        // -g gets the direct URL, -f bestaudio/best gets the best audio or falls back to best combined stream
        task.arguments = ["--extractor-args", "youtube:player_client=android", "-g", "-f", "bestaudio/best", url]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        try task.run()
        task.waitUntilExit()
        
        if task.terminationStatus != 0 {
            throw NSError(domain: "YTDLP", code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: "Failed to extract stream URL"])
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty else {
            throw NSError(domain: "YTDLP", code: 6, userInfo: [NSLocalizedDescriptionKey: "No stream URL found"])
        }
        return output
    }
}
