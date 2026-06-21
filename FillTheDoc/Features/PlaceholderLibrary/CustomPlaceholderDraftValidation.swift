import Foundation

enum CustomPlaceholderDraftIssue: Equatable, Sendable {
    case title(String)
    case key(String)
    case description(String)
    case exampleValue(String)
    case choiceGeneral(String)
    case choiceOption(id: UUID, message: String)
}

struct InlineValidationState: Equatable, Sendable {
    var titleError: String?
    var keyError: String?
    var descriptionError: String?
    var exampleValueError: String?
    var choiceGeneralError: String?
    var choiceOptionErrors: [UUID: String] = [:]
    
    init(issues: [CustomPlaceholderDraftIssue] = []) {
        for issue in issues {
            switch issue {
                case .title(let message):
                    titleError = message
                case .key(let message):
                    keyError = message
                case .description(let message):
                    descriptionError = message
                case .exampleValue(let message):
                    exampleValueError = message
                case .choiceGeneral(let message):
                    choiceGeneralError = message
                case .choiceOption(let id, let message):
                    choiceOptionErrors[id] = message
            }
        }
    }
    
    var hasBlockingErrors: Bool {
        titleError != nil
        || keyError != nil
        || descriptionError != nil
        || exampleValueError != nil
        || choiceGeneralError != nil
        || !choiceOptionErrors.isEmpty
    }
}

struct CustomPlaceholderDraftValidator: Sendable {
    static let maxChoiceOptions = CustomPlaceholderValidator.maxChoiceOptions
    static let minimumChoiceOptions = CustomPlaceholderValidator.minimumChoiceOptions
    static let maxDescriptionLength = 500
    
    func validate(
        _ draft: CustomPlaceholderDraft,
        existingKeys: Set<PlaceholderKey>
    ) -> [CustomPlaceholderDraftIssue] {
        var issues: [CustomPlaceholderDraftIssue] = []
        
        if draft.normalizedTitle.isEmpty {
            issues.append(.title("Название не может быть пустым."))
        }
        
        if draft.normalizedKey.isEmpty {
            issues.append(.key("Ключ не может быть пустым."))
        } else {
            if draft.normalizedKey.range(of: #"^[a-z][a-z0-9_]*$"#, options: .regularExpression) == nil {
                issues.append(.key("Только латинские буквы, цифры и _. Первый символ — буква."))
            }
            
            if existingKeys.contains(PlaceholderKey(rawValue: draft.normalizedKey)) {
                issues.append(.key("Плейсхолдер с таким ключом уже существует."))
            }
        }
        
        if case .text(let valueSource) = draft.inputKind,
           valueSource == .extracted,
           draft.normalizedDescription == nil {
            issues.append(.description("Для извлекаемого плейсхолдера описание обязательно."))
        }
        
        if draft.description.count > Self.maxDescriptionLength {
            issues.append(.description("Описание не должно превышать \(Self.maxDescriptionLength) символов."))
        }
        
        switch draft.inputKind {
            case .text:
                break
            case .choice(let options):
                issues.append(contentsOf: validateChoice(options))
        }
        
        issues.append(contentsOf: validateExampleValue(draft))
        
        return issues
    }
}

private extension CustomPlaceholderDraftValidator {
    func validateExampleValue(_ draft: CustomPlaceholderDraft) -> [CustomPlaceholderDraftIssue] {
        guard let exampleValue = draft.normalizedExampleValue else { return [] }
        
        switch draft.inputKind {
            case .text:
                return []
            case .choice(let options):
                let normalizedOptions = options
                    .map(\.value)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                guard normalizedOptions.contains(exampleValue) else {
                    return [
                        .exampleValue("Пример значения должен совпадать с одним из вариантов выбора.")
                    ]
                }
                
                return []
        }
    }
    
    func validateChoice(_ options: [EditableChoiceOption]) -> [CustomPlaceholderDraftIssue] {
        var issues: [CustomPlaceholderDraftIssue] = []
        
        if options.isEmpty {
            return [.choiceGeneral("Добавьте минимум два варианта выбора.")]
        }
        
        if options.count > Self.maxChoiceOptions {
            issues.append(.choiceGeneral("Максимум \(Self.maxChoiceOptions) вариантов выбора."))
        }
        
        var nonEmptyCount = 0
        var seenValues: [String: UUID] = [:]
        
        for option in options {
            let normalizedValue = option.value.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if normalizedValue.isEmpty {
                issues.append(.choiceOption(id: option.id, message: "Вариант выбора не может быть пустым."))
                continue
            }
            
            nonEmptyCount += 1
            
            if let existingID = seenValues[normalizedValue] {
                issues.append(.choiceGeneral("Варианты выбора не должны повторяться."))
                issues.append(.choiceOption(id: existingID, message: "Вариант повторяется."))
                issues.append(.choiceOption(id: option.id, message: "Вариант повторяется."))
            } else {
                seenValues[normalizedValue] = option.id
            }
        }
        
        if nonEmptyCount < Self.minimumChoiceOptions {
            issues.append(.choiceGeneral("Добавьте минимум \(Self.minimumChoiceOptions) непустых варианта выбора."))
        }
        
        return issues.removingDuplicateGeneralChoiceErrors()
    }
}

private extension Array where Element == CustomPlaceholderDraftIssue {
    func removingDuplicateGeneralChoiceErrors() -> [CustomPlaceholderDraftIssue] {
        var seenMessages = Set<String>()
        
        return filter { issue in
            guard case .choiceGeneral(let message) = issue else { return true }
            return seenMessages.insert(message).inserted
        }
    }
}
