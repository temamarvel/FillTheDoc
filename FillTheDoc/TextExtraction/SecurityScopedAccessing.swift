//
//  SecurityScopedAccessing.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 10.02.2026.
//

import Foundation


/// Абстракция над доступом к security-scoped URL в sandbox-приложении macOS.
///
/// Нужна сервису extraction, чтобы безопасно открывать пользовательские файлы
/// и при этом оставаться тестопригодным без прямой зависимости от `URL.startAccessing...`.
protocol SecurityScopedAccessing {
    func withAccess<T>(_ url: URL, _ body: () throws -> T) throws -> T
}

/// Production-реализация security-scoped access для обычного runtime приложения.
struct DefaultSecurityScopedAccessor: SecurityScopedAccessing {
    init() {}
    
    func withAccess<T>(_ url: URL, _ body: () throws -> T) throws -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        return try body()
    }
}
