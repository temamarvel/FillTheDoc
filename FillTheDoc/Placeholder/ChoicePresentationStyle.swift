//
//  ChoicePresentationStyle.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


/// Предпочтительный способ отображения choice-поля в SwiftUI-форме.
nonisolated enum ChoicePresentationStyle: String, Codable, Hashable, Sendable {
    case menu
    case segmented
}
