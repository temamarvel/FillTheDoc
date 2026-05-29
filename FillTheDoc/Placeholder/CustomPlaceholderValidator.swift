import Foundation

/// Валидирует draft пользовательского плейсхолдера до сохранения.
///
/// Это отдельный слой правил для редактора: он проверяет не runtime-значение поля,
/// а корректность самой definition-модели — ключ, заголовок, тип ввода и конфигурацию опций.
struct CustomPlaceholderValidator: Sendable {
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
        
        issues.append(contentsOf: validateKind(draft.kind))
        return issues
    }
    
    private func validateKind(_ kind: PlaceholderKind) -> [FieldIssue] {
        switch kind {
            case .editable(_, .text(let configuration)):
                return validateText(configuration)
            case .editable(_, .choice(let configuration)):
                return validateChoice(configuration)
            case .derived:
                return [.error("Пользовательский плейсхолдер должен поддерживать ввод значения.")]
        }
    }
    
    private func validateText(_ configuration: TextInputConfiguration) -> [FieldIssue] {
        if case .multiline(let minLines, let maxLines) = configuration.editorStyle,
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
