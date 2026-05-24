//
//  PlaceholderOption.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


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