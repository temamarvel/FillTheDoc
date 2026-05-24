//
//  ChoiceInputConfiguration.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.05.2026.
//


nonisolated struct ChoiceInputConfiguration: Hashable, Codable, Sendable {
    var options: [PlaceholderOption]
    var defaultOptionID: String?
    var allowsEmptySelection: Bool
    var emptyTitle: String
    var presentationStyle: ChoicePresentationStyle
    
    init(
        options: [PlaceholderOption],
        defaultOptionID: String? = nil,
        allowsEmptySelection: Bool = true,
        emptyTitle: String = "Не выбрано",
        presentationStyle: ChoicePresentationStyle = .menu
    ) {
        self.options = options
        self.defaultOptionID = defaultOptionID
        self.allowsEmptySelection = allowsEmptySelection
        self.emptyTitle = emptyTitle
        self.presentationStyle = presentationStyle
    }
}
