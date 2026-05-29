import Foundation

nonisolated struct UpdateAvailability: Sendable {
    let currentVersion: String
    let latestVersion: String
    let releasePageURL: URL
    let downloadURL: URL?
    let releaseTitle: String?
    let releaseNotes: String?
}
