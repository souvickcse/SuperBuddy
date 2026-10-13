import Foundation

/// Tiny opt-in trace used while developing the overlay.
/// Enabled only when `/tmp/spiderbuddy.debug` exists, so a normal build never logs
/// anything and there is no cost beyond one `fileExists` check at launch.
enum BuddyDebug {
    static let enabled = FileManager.default.fileExists(atPath: "/tmp/spiderbuddy.debug")
    private static let path = "/tmp/spiderbuddy.log"

    static func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        let line = String(format: "%.3f ", Date().timeIntervalSince1970) + message() + "\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
