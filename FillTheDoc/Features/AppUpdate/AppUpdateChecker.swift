import Foundation

enum AppUpdateCheckerError: LocalizedError {
    case missingCurrentVersion
    
    var errorDescription: String? {
        switch self {
            case .missingCurrentVersion:
                return "Не удалось получить текущую версию приложения."
        }
    }
}

/// Сервис проверки обновлений через GitHub Releases API.
///
/// Это прикладной network-layer, который:
/// - запрашивает последний release репозитория;
/// - сравнивает его с локальной версией;
/// - отдаёт UI уже готовую информацию для показа пользователю.
///
/// Сервис не хранит observable state и не знает, как именно UI покажет результат.
/// Его задача — выполнить запрос и вернуть нормализованный `UpdateAvailability`.
actor AppUpdateChecker {
    private let releaseClient: GitHubReleaseClient
    
    init(owner: String, repo: String, session: URLSession = .shared) {
        self.releaseClient = GitHubReleaseClient(owner: owner, repo: repo, session: session)
    }
    
    func checkForUpdate() async throws -> UpdateAvailability? {
        let currentVersion = try currentAppVersion()
        let release = try await releaseClient.fetchLatestRelease()
        
        let latestVersion = GitHubReleaseVersionParser.normalizedVersion(release.tagName)
        let normalizedCurrentVersion = GitHubReleaseVersionParser.normalizedVersion(currentVersion)
        
        guard GitHubReleaseVersionParser.isVersion(latestVersion, greaterThan: normalizedCurrentVersion) else {
            return nil
        }
        
        let preferredAsset = preferredDownloadAsset(from: release.assets)
        
        return UpdateAvailability(
            currentVersion: normalizedCurrentVersion,
            latestVersion: latestVersion,
            releasePageURL: release.htmlURL,
            downloadURL: preferredAsset?.browserDownloadURL,
            releaseTitle: release.name,
            releaseNotes: release.body
        )
    }
    
    private func currentAppVersion() throws -> String {
        guard
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AppUpdateCheckerError.missingCurrentVersion
        }
        
        return version
    }
    
    private func preferredDownloadAsset(from assets: [GitHubRelease.Asset]) -> GitHubRelease.Asset? {
        if let dmg = assets.first(where: { $0.name.localizedCaseInsensitiveContains(".dmg") }) {
            return dmg
        }
        
        if let zip = assets.first(where: { $0.name.localizedCaseInsensitiveContains(".zip") }) {
            return zip
        }
        
        return assets.first
    }
}
