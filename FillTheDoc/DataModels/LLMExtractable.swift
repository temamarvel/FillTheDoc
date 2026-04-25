//
//  LLMExtractable.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 20.02.2026.
//

import Foundation


/// Контракт для моделей, которые можно безопасно просить у LLM в виде JSON.
///
/// Тип, conforming к `LLMExtractable`, обязан явно перечислить schema-keys,
/// чтобы проект мог:
/// - генерировать prompt из реальной схемы данных;
/// - держать decoder и prompt синхронизированными;
/// - избегать «магических строк», размазанных по нескольким слоям.
protocol LLMExtractable: Codable {
    associatedtype SchemaKeys: CaseIterable & CodingKey
}

extension LLMExtractable {
    /// Полный список JSON-ключей, которые разрешены в ответе модели.
    static var llmSchemaKeys: [String] {
        SchemaKeys.allCases.map(\.stringValue)
    }
    
    /// Удобное строковое представление схемы для вставки в prompt.
    static var llmSchemaKeysLine: String {
        llmSchemaKeys.map { "\"\($0)\"" }.joined(separator: ", ")
    }
}

extension LLMExtractable {
    /// Отладочный helper: превращает модель в словарь для логов и инспекции.
    /// Не используется как бизнес-контракт приложения.
    func asDictionary() -> [String: Any] {
        let encoder = JSONEncoder()
        guard
            let data = try? encoder.encode(self),
            let object = try? JSONSerialization.jsonObject(with: data),
            let dict = object as? [String: Any]
        else {
            return [:]
        }
        
        return dict
    }
    
    /// Читабельное многострочное представление для debug-логов.
    /// Полезно, когда нужно быстро понять, что именно вернула модель после extraction.
    func toMultilineString() -> String {
        let dict = asDictionary()
        
        return dict
            .compactMap { key, value in
                guard !(value is NSNull) else { return nil }
                return "\(key): \(value)"
            }
            .sorted()
            .joined(separator: "\n")
    }
}
