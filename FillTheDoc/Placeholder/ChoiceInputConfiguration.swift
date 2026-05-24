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
nonisolated extension ChoiceInputConfiguration {
    func option(withID id: String) -> PlaceholderOption? {
        options.first { $0.id == id }
    }
    
    var fallbackOption: PlaceholderOption? {
        if let defaultOptionID,
           let option = option(withID: defaultOptionID) {
            return option
        }
        if !allowsEmptySelection {
            return options.first
        }
        return nil
    }
    
    func effectiveOptionID(for optionID: String?) -> String? {
        if let optionID,
           let option = option(withID: optionID) {
            return option.id
        }
        return fallbackOption?.id
    }
    
    func normalizedFieldValue(for optionID: String?) -> PlaceholderFieldValue {
        if let optionID = effectiveOptionID(for: optionID) {
            return .choice(optionID: optionID)
        }
        return .empty
    }
    
    func replacementValue(for optionID: String?) -> String {
        if let optionID,
           let option = option(withID: optionID) {
            return option.replacementValue
        }
        if optionID == nil {
            return fallbackOption?.replacementValue ?? ""
        }
        return ""
    }
}
