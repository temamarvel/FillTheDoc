import Foundation

/// Централизованные пути для пользовательских данных приложения в sandbox-less desktop режиме.
///
/// Пока здесь хранится только JSON с пользовательскими плейсхолдерами, но версия с
/// отдельным helper'ом удобнее, чем размазывать логику Application Support по разным store'ам.
enum AppStorageLocations {
    static func applicationSupportDirectory(appName: String = "FillTheDoc") throws -> URL {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appURL = baseURL.appendingPathComponent(appName, isDirectory: true)
        try FileManager.default.createDirectory(
            at: appURL,
            withIntermediateDirectories: true
        )
        return appURL
    }
    
    static func customPlaceholdersFileURL() throws -> URL {
        try applicationSupportDirectory()
            .appendingPathComponent("custom_placeholders.json")
    }
}
