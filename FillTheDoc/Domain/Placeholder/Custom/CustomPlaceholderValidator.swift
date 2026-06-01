import Foundation

/// Валидирует draft пользовательского плейсхолдера до сохранения.
///
/// Это единственный источник правил валидации для custom placeholders.
/// UI-слой (inline validation) делегирует сюда, чтобы не дублировать логику.
struct CustomPlaceholderValidator: Sendable {
    
    /// Максимальное количество вариантов выбора для choice-плейсхолдера.
    static let maxChoiceOptions = 30
    static let minimumChoiceOptions = 2
    
    /// Возвращает набор найденных проблем в definition draft.
    func validate(
        descriptor: PlaceholderDescriptor,
        existingKeys: Set<PlaceholderKey>
    ) -> [FieldIssue] {
        var issues: [FieldIssue] = []
        let rawKey = descriptor.key.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = descriptor.title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if rawKey.isEmpty {
            issues.append(.error("Ключ плейсхолдера не может быть пустым."))
        }
        
        if !rawKey.isEmpty,
           rawKey.range(of: #"^[a-z][a-z0-9_]*$"#, options: .regularExpression) == nil {
            issues.append(.error("Ключ должен содержать только латинские буквы, цифры и _. Первый символ — буква."))
        }
        
        if existingKeys.contains(descriptor.key) {
            issues.append(.error("Плейсхолдер с таким ключом уже существует."))
        }
        
        if title.isEmpty {
            issues.append(.error("Название плейсхолдера не может быть пустым."))
        }
        
        if case .editable(source: .extracted, inputKind: .choice) = descriptor.kind {
            issues.append(.error("Плейсхолдер с выбором не может извлекаться моделью. Для него доступно только ручное заполнение."))
        }
        
        // Для extracted-плейсхолдера описание обязательно: оно попадает в LLM prompt
        // и без него модель не сможет корректно извлечь значение.
        if case .editable(source: .extracted, inputKind: .text) = descriptor.kind {
            let description = descriptor.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if description.isEmpty {
                issues.append(.error("Для извлекаемого плейсхолдера описание обязательно — оно используется в промпте для модели."))
            }
        }
        
        issues.append(contentsOf: validateKind(descriptor.kind))
        return issues
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
        switch editorStyle {
            case .singleLine, .multiline:
                return []
        }
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
        if nonEmptyOptions.count < Self.minimumChoiceOptions {
            issues.append(.error("Добавьте минимум \(Self.minimumChoiceOptions) непустых варианта выбора."))
        }
        if Set(nonEmptyOptions).count != nonEmptyOptions.count {
            issues.append(.error("Варианты выбора не должны повторяться."))
        }
        
        return issues
    }
}
