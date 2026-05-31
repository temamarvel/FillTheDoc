import Foundation

/// Валидирует draft пользовательского плейсхолдера до сохранения.
///
/// Это единственный источник правил валидации для custom placeholders.
/// UI-слой (inline validation) делегирует сюда, чтобы не дублировать логику.
struct CustomPlaceholderValidator: Sendable {
    
    /// Максимальное количество вариантов выбора для choice-плейсхолдера.
    static let maxChoiceOptions = 30
    
    /// Возвращает набор найденных проблем в definition draft.
    func validate(
        draft: PlaceholderDescriptor,
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
        
        if case .editable(source: .extracted, inputKind: .choice) = draft.kind {
            issues.append(.error("Плейсхолдер с выбором не может извлекаться моделью. Для него доступно только ручное заполнение."))
        }
        
        // Для extracted-плейсхолдера описание обязательно: оно попадает в LLM prompt
        // и без него модель не сможет корректно извлечь значение.
        if case .editable(source: .extracted, inputKind: .text) = draft.kind {
            let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if description.isEmpty {
                issues.append(.error("Для извлекаемого плейсхолдера описание обязательно — оно используется в промпте для модели."))
            }
        }
        
        issues.append(contentsOf: validateKind(draft.kind))
        return issues
    }
    
    // MARK: - Granular validation helpers (used by inline validation in editor)
    
    func validateKey(_ rawKey: String, existingKeys: Set<PlaceholderKey>) -> String? {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty {
            return "Ключ не может быть пустым."
        }
        if key.range(of: #"^[a-z][a-z0-9_]*$"#, options: .regularExpression) == nil {
            return "Только латинские буквы, цифры и _. Первый символ — буква."
        }
        if existingKeys.contains(key.placeholderKey) {
            return "Плейсхолдер с таким ключом уже существует."
        }
        return nil
    }
    
    func validateTitle(_ title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Название не может быть пустым." : nil
    }
    
    func validateDescription(
        _ description: String,
        valueSource: PlaceholderValueSource,
        inputType: CustomPlaceholderEditorInputType
    ) -> String? {
        guard inputType == .text, valueSource == .extracted else { return nil }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
        ? "Для извлекаемого плейсхолдера описание обязательно."
        : nil
    }
    
    func validateChoiceOptions(_ options: [String]) -> (general: String?, perOption: [Int: String]) {
        var generalError: String?
        var perOptionErrors: [Int: String] = [:]
        
        if options.isEmpty {
            generalError = "Добавьте хотя бы один вариант выбора."
            return (generalError, perOptionErrors)
        }
        
        if options.count > Self.maxChoiceOptions {
            generalError = "Максимум \(Self.maxChoiceOptions) вариантов выбора."
            return (generalError, perOptionErrors)
        }
        
        var normalizedValues: [String: Int] = [:]
        
        for (index, option) in options.enumerated() {
            let value = option.trimmingCharacters(in: .whitespacesAndNewlines)
            if value.isEmpty {
                perOptionErrors[index] = "Вариант выбора не может быть пустым."
                continue
            }
            normalizedValues[value, default: 0] += 1
        }
        
        if normalizedValues.contains(where: { $0.value > 1 }) {
            generalError = "Варианты выбора не должны повторяться."
        }
        
        return (generalError, perOptionErrors)
    }
    
    // MARK: - Private
    
    private func validateKind(_ kind: PlaceholderKind) -> [FieldIssue] {
        switch kind {
            case .editable(_, .text(let editorStyle)):
                return validateText(editorStyle)
            case .editable(_, .choice(let configuration)):
                return validateChoice(configuration)
            case .derived:
                return [.error("Пользовательский плейсхолдер должен поддерживать ввод значения.")]
        }
    }
    
    private func validateText(_ editorStyle: TextEditorStyle) -> [FieldIssue] {
        if case .multiline(let minLines, let maxLines) = editorStyle,
           minLines < 1 || maxLines < minLines {
            return [.error("Некорректная конфигурация многострочного текстового поля.")]
        }
        return []
    }
    
    private func validateChoice(_ configuration: ChoiceInputConfiguration) -> [FieldIssue] {
        var issues: [FieldIssue] = []
        
        if configuration.options.isEmpty {
            issues.append(.error("Добавьте хотя бы один вариант выбора."))
        }
        
        if configuration.options.count > Self.maxChoiceOptions {
            issues.append(.error("Максимум \(Self.maxChoiceOptions) вариантов выбора."))
        }
        
        let normalizedOptions = configuration.options.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        if normalizedOptions.contains(where: \.isEmpty) {
            issues.append(.error("Вариант выбора не может быть пустым."))
        }
        
        let nonEmptyOptions = normalizedOptions.filter { !$0.isEmpty }
        if Set(nonEmptyOptions).count != nonEmptyOptions.count {
            issues.append(.error("Варианты выбора не должны повторяться."))
        }
        
        return issues
    }
}

/// Вспомогательный enum для inline-валидации в EditorView.
/// Используется валидатором для определения контекста.
enum CustomPlaceholderEditorInputType: String, CaseIterable, Identifiable {
    case text
    case choice
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
            case .text: return "Текст"
            case .choice: return "Выбор"
        }
    }
    
    var systemImage: String {
        switch self {
            case .text: return "textformat"
            case .choice: return "list.bullet"
        }
    }
}
