import AppKit
import Foundation

struct SourceApplication: Codable, Equatable, Hashable {
    var name: String?
    var bundleIdentifier: String?
}

@MainActor
protocol SourceApplicationProviding {
    func frontmostApplication() -> SourceApplication?
}

struct NSWorkspaceSourceApplicationProvider: SourceApplicationProviding {
    func frontmostApplication() -> SourceApplication? {
        guard let application = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        return SourceApplication(
            name: application.localizedName,
            bundleIdentifier: application.bundleIdentifier
        )
    }
}
