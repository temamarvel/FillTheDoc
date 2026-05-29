import Foundation

nonisolated enum GitHubReleaseVersionParser {
    nonisolated static func normalizedVersion(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "v", with: "", options: [.anchored, .caseInsensitive])
    }
    
    nonisolated static func isVersion(_ lhs: String, greaterThan rhs: String) -> Bool {
        compareVersions(lhs, rhs) == .orderedDescending
    }
    
    nonisolated static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        guard let left = Version(lhs), let right = Version(rhs) else {
            return .orderedSame
        }
        
        if left < right { return .orderedAscending }
        if left > right { return .orderedDescending }
        return .orderedSame
    }
}
