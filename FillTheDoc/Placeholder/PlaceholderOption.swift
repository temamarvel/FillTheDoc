//
//  PlaceholderOption.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


/// Один вариант выбора для `choice`-плейсхолдера.
///
/// Важно, что `id` и `replacementValue` разделены:
/// UI и persistence работают со стабильным идентификатором,
/// а в итоговый DOCX попадает именно replacement-строка.
nonisolated struct PlaceholderOption: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var title: String
    var replacementValue: String
    var description: String?
    
    init(
        id: String,
        title: String,
        replacementValue: String,
        description: String? = nil
    ) {
        self.id = id
        self.title = title
        self.replacementValue = replacementValue
        self.description = description
    }
}
