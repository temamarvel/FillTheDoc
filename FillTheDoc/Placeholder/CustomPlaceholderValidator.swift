import Foundation

struct CustomPlaceholderValidator: Sendable {
    func validate(
        draft: CustomPlaceholderDefinition,
        existingKeys: Set<PlaceholderKey>
    ) -> [FieldIssue] {
        var issues: [FieldIssue] = []
        let rawKey = draft.key.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if rawKey.isEmpty {
            issues.append(.error("Ключ плейсхолдера не может быть пустым."))
        }
        
        if !rawKey.isEmpty,
           rawKey.range(of: #"^[a-z][a-z0-9_]*$"#, options: .regularExpression) == nil {
            issues.append(.error("Ключ должен содержать только латинские буквы, цифры и _. Первый символ — буква."))
        }
        
        if existingKeys.contains(draft.key) {
            issues.append(.error("Плейсхолдер с таким ключом уже существует."))
        }
        
        if title.isEmpty {
            issues.append(.error("Название плейсхолдера не может быть пустым."))
        }
        
        issues.append(contentsOf: validateInputKind(draft.inputKind))
        return issues
    }
    
    private func validateInputKind(_ inputKind: PersistedPlaceholderInputKind) -> [FieldIssue] {
        switch inputKind {
            case .text, .multilineText:
                return []
            case .choice(let configuration):
                return validateChoice(configuration)
        }
    }
    
    private func validateChoice(_ configuration: PersistedChoiceInputConfiguration) -> [FieldIssue] {
        var issues: [FieldIssue] = []
        
        if configuration.options.count < 2 {
            issues.append(.error("Для поля выбора нужно минимум два варианта."))
        }
        
        let optionIDs = configuration.options.map(\.id)
        if Set(optionIDs).count != optionIDs.count {
            issues.append(.error("ID вариантов выбора должны быть уникальными."))
        }
        
        for option in configuration.options {
            if option.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.error("Название варианта выбора не может быть пустым."))
            }
            if option.replacementValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.error("Значение для подстановки не может быть пустым."))
            }
        }
        
        if let defaultOptionID = configuration.defaultOptionID {
            let hasDefaultOption = configuration.options.contains { $0.id == defaultOptionID }
            if !hasDefaultOption {
                issues.append(.error("Default-вариант должен существовать в списке вариантов."))
            }
        }
        
        return issues
    }
}
