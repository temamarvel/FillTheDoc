
//
//  FileInfo.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 10.02.2026.
//


import Foundation

/// Маленький helper для чтения базовых метаданных файла без разрастания extraction-сервиса.
enum FileInfo {
    /// Возвращает размер файла в байтах, если его удалось получить через `FileManager`.
    static func fileSizeBytes(_ url: URL) -> Int64? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
    }
}
