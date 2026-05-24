import SwiftUI

// MARK: - Draft models

nonisolated private struct ChoiceOptionDraft: Identifiable, Hashable {
    let id: String
    var title: String
    
    nonisolated init(
        id: String = UUID().uuidString,
        title: String = ""
    ) {
        self.id = id
        self.title = title
    }
    
    nonisolated init(option: PlaceholderOption) {
        self.id = option.id
        self.title = option.title
    }
    
    nonisolated var generatedReplacementValue: String {
        title.generatedLatinIdentifier
    }
    
    nonisolated var placeholderOption: PlaceholderOption {
        PlaceholderOption(
            id: id,
            title: title.trimmed,
            replacementValue: generatedReplacementValue
        )
    }
}

private enum CustomPlaceholderEditorInputType: String, CaseIterable, Identifiable {
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

private enum CustomPlaceholderEditorValueSource: String, CaseIterable, Identifiable {
    case manual
    case extracted
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
            case .manual:
                return "Пользователь вводит вручную"
            case .extracted:
                return "Извлекать из документа с помощью ИИ"
        }
    }
    
    var helperText: String {
        switch self {
            case .manual:
                return "Поле не будет заполняться моделью и всегда редактируется пользователем."
            case .extracted:
                return "Поле войдёт в LLM schema и будет пытаться извлекаться из исходного документа."
        }
    }
    
    var placeholderValueSource: PlaceholderValueSource {
        switch self {
            case .manual:
                return .manual
            case .extracted:
                return .extracted
        }
    }
    
    init(valueSource: PlaceholderValueSource) {
        switch valueSource {
            case .manual:
                self = .manual
            case .extracted:
                self = .extracted
        }
    }
}

// MARK: - Validation

private struct InlineValidationState {
    var titleError: String?
    var keyError: String?
    var choiceGeneralError: String?
    var choiceOptionErrors: [String: String] = [:]
    
    var hasBlockingErrors: Bool {
        titleError != nil
        || keyError != nil
        || choiceGeneralError != nil
        || !choiceOptionErrors.isEmpty
    }
}

// MARK: - CustomPlaceholderEditorView

struct CustomPlaceholderEditorView: View {
    enum Mode {
        case create
        case edit(PlaceholderDescriptor)
        
        var title: String {
            switch self {
                case .create:
                    return "Новый пользовательский плейсхолдер"
                case .edit:
                    return "Редактирование пользовательского плейсхолдера"
            }
        }
        
        var saveButtonTitle: String {
            switch self {
                case .create:
                    return "Создать"
                case .edit:
                    return "Сохранить"
            }
        }
        
        var existingDefinition: PlaceholderDescriptor? {
            switch self {
                case .create:
                    return nil
                case .edit(let definition):
                    return definition
            }
        }
        
        var isEditing: Bool {
            if case .edit = self { return true }
            return false
        }
    }
    
    let mode: Mode
    let existingKeys: Set<PlaceholderKey>
    let onSave: (PlaceholderDescriptor) async throws -> Void
    let onDismiss: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var titleText: String
    @State private var keyText: String
    @State private var descriptionText: String
    @State private var valueType: CustomPlaceholderEditorInputType
    
    @State private var textPlaceholder: String
    @State private var textRequired: Bool
    @State private var textValueSource: CustomPlaceholderEditorValueSource
    
    @State private var choiceOptions: [ChoiceOptionDraft]
    
    @State private var order: Int
    
    @State private var saveErrorText: String?
    @State private var isSaving = false
    
    init(
        mode: Mode,
        existingKeys: Set<PlaceholderKey>,
        onSave: @escaping (PlaceholderDescriptor) async throws -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.existingKeys = existingKeys
        self.onSave = onSave
        self.onDismiss = onDismiss
        
        let definition = mode.existingDefinition
        
        _titleText = State(initialValue: definition?.title ?? "")
        _keyText = State(initialValue: definition?.key.rawValue ?? "")
        _descriptionText = State(initialValue: definition?.description ?? "")
        _order = State(initialValue: definition?.order ?? 500)
        
        switch definition?.kind {
            case .editable(let source, .text(let configuration)):
                _valueType = State(initialValue: .text)
                _textPlaceholder = State(initialValue: configuration.placeholder)
                _textRequired = State(initialValue: configuration.isRequired)
                _textValueSource = State(initialValue: .init(valueSource: source))
                _choiceOptions = State(initialValue: Self.defaultChoiceOptions())
                
            case .editable(_, .choice(let configuration)):
                _valueType = State(initialValue: .choice)
                _textPlaceholder = State(initialValue: "")
                _textRequired = State(initialValue: false)
                _textValueSource = State(initialValue: .manual)
                _choiceOptions = State(initialValue: configuration.options.map(ChoiceOptionDraft.init(option:)))
                
            case .derived, nil:
                _valueType = State(initialValue: .text)
                _textPlaceholder = State(initialValue: "")
                _textRequired = State(initialValue: false)
                _textValueSource = State(initialValue: .manual)
                _choiceOptions = State(initialValue: Self.defaultChoiceOptions())
        }
    }
    
    private var normalizedKeyText: String {
        keyText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    private var tokenPreview: String {
        let key = normalizedKeyText.isEmpty ? "placeholder_key" : normalizedKeyText
        return "<!\(key)!>"
    }
    
    private var existingKeysForValidation: Set<PlaceholderKey> {
        var keys = existingKeys
        if let existingDefinition = mode.existingDefinition {
            keys.remove(existingDefinition.key)
        }
        return keys
    }
    
    private var validation: InlineValidationState {
        validateInline()
    }
    
    private var canSave: Bool {
        !isSaving && !validation.hasBlockingErrors
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    baseSection
                    settingsSection
                }
                .padding(24)
            }
            
            if let saveErrorText {
                Divider()
                errorBanner(text: saveErrorText)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            
            Divider()
            footerView
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: valueType) { _, _ in
            if valueType == .choice {
                textValueSource = .manual
            }
            saveErrorText = nil
        }
        .onChange(of: titleText) { _, _ in saveErrorText = nil }
        .onChange(of: keyText) { _, _ in saveErrorText = nil }
        .onChange(of: descriptionText) { _, _ in saveErrorText = nil }
        .onChange(of: textPlaceholder) { _, _ in saveErrorText = nil }
        .onChange(of: choiceOptions) { _, _ in saveErrorText = nil }
    }
}

// MARK: - Layout

private extension CustomPlaceholderEditorView {
    func closeEditor() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
    
    var headerView: some View {
        HStack(spacing: 12) {
            Button {
                closeEditor()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Закрыть")
            
            Spacer()
            
            Text(mode.title)
                .font(.title3.weight(.semibold))
            
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }
    
    var baseSection: some View {
        editorCard{
            sectionHeader("1. Основные параметры")
            
            labeledTextField(
                title: "Название плейсхолдера",
                text: $titleText,
                prompt: "Например: Номер договора",
                helper: .plain("Отображаемое имя в интерфейсе"),
                errorText: validation.titleError
            )
            
            labeledTextField(
                title: "Ключ плейсхолдера",
                text: $keyText,
                prompt: "Например: contract_number",
                helper: .token(prefix: "Используется в шаблоне документа как", token: tokenPreview),
                errorText: validation.keyError,
                isDisabled: mode.isEditing
            )
        }
    }
    
    var settingsSection: some View {
        editorCard {
            sectionHeader("2. Настройки плейсхолдера")
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Тип плейсхолдера")
                    .font(.subheadline.weight(.medium))
                
                Picker("", selection: $valueType) {
                    ForEach(CustomPlaceholderEditorInputType.allCases) { type in
                        Label(type.title, systemImage: type.systemImage)
                            .tag(type)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }
            
            switch valueType {
                case .text:
                    textSettingsSection
                case .choice:
                    choiceSettingsSection
            }
        }
    }
    
    var textSettingsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Источник значения")
                    .font(.subheadline.weight(.medium))
                
                Picker("", selection: $textValueSource) {
                    ForEach(CustomPlaceholderEditorValueSource.allCases) { source in
                        Text(source.title)
                            .tag(source)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                
                Text(textValueSource.helperText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(textValueSource == .extracted ? "Описание для экстракции (для LLM)" : "Описание поля")
                        .font(.subheadline.weight(.medium))
                    
                    Image(systemName: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help(textValueSource == .extracted
                              ? "Опишите, какое значение нужно найти в исходных документах. Это описание попадёт в промпт извлечения."
                              : "Краткое описание поля для интерфейса и библиотеки плейсхолдеров.")
                }
                
                multilineTextEditor(
                    text: $descriptionText,
                    prompt: "Например: Номер договора. Обычно содержит цифры и может включать дополнительные символы, например, слеши или дефисы."
                )
                .frame(height: 118)
                
                HStack {
                    Text(textValueSource == .extracted
                         ? "Описание помогает модели понять, какие данные искать."
                         : "Описание используется в интерфейсе и справочнике плейсхолдеров.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(descriptionText.count)/500")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                labeledTextField(
                    title: "Подсказка для ввода (необязательно)",
                    text: $textPlaceholder,
                    prompt: "Например: 123/2024-ОД или Д-45 от 12.03.2024",
                    helper: .plain("Подсказка отображается пользователю в поле ввода")
                )
            }
        }
    }
    
    var choiceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Источник значения")
                    .font(.subheadline.weight(.medium))
                Text("Плейсхолдер с выбором всегда заполняется пользователем вручную.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Text("Варианты выбора")
                        .font(.subheadline.weight(.medium))
                    
                    Image(systemName: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("Введите только варианты, которые пользователь увидит в UI. Значение на латинице будет создано автоматически.")
                }
                
                Spacer()
                
                Text("\(choiceOptions.count) \(choiceOptions.count.optionCountWord)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let choiceGeneralError = validation.choiceGeneralError {
                validationMessage(choiceGeneralError, style: .error)
            }
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(choiceOptions.indices, id: \.self) { index in
                    let optionID = choiceOptions[index].id
                    ChoiceOptionRowView(
                        index: index,
                        option: $choiceOptions[index],
                        errorText: validation.choiceOptionErrors[optionID],
                        canDelete: choiceOptions.count > 2,
                        onDelete: {
                            removeOption(id: optionID)
                        }
                    )
                }
            }
            
            Button {
                choiceOptions.append(.init())
            } label: {
                Label("Добавить вариант", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
    
    var footerView: some View {
        HStack {
            if validation.hasBlockingErrors {
                Label("Исправьте ошибки перед сохранением", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Отмена") {
                closeEditor()
            }
            .buttonStyle(.bordered)
            
            Button(mode.saveButtonTitle) {
                save()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

// MARK: - Validation / Save

private extension CustomPlaceholderEditorView {
    func validateInline() -> InlineValidationState {
        var state = InlineValidationState()
        
        let rawKey = normalizedKeyText
        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if title.isEmpty {
            state.titleError = "Название не может быть пустым."
        }
        
        if rawKey.isEmpty {
            state.keyError = "Ключ не может быть пустым."
        } else if rawKey.range(of: #"^[a-z][a-z0-9_]*$"#, options: .regularExpression) == nil {
            state.keyError = "Только латинские буквы, цифры и _. Первый символ — буква."
        } else if existingKeysForValidation.contains(rawKey.placeholderKey) {
            state.keyError = "Плейсхолдер с таким ключом уже существует."
        }
        
        if valueType == .choice {
            validateChoiceInline(into: &state)
        }
        
        return state
    }
    
    func validateChoiceInline(into state: inout InlineValidationState) {
        if choiceOptions.count < 2 {
            state.choiceGeneralError = "Для поля выбора нужно минимум два варианта."
        }
        
        var generatedValues: [String: Int] = [:]
        
        for option in choiceOptions {
            let title = option.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let generatedValue = option.generatedReplacementValue
            
            if title.isEmpty {
                state.choiceOptionErrors[option.id] = "Введите название варианта."
                continue
            }
            
            if generatedValue.isEmpty {
                state.choiceOptionErrors[option.id] = "Не удалось автоматически создать значение на латинице. Измените название."
                continue
            }
            
            generatedValues[generatedValue, default: 0] += 1
        }
        
        let duplicatedGeneratedValues = generatedValues.filter { $0.value > 1 }.map(\.key)
        if !duplicatedGeneratedValues.isEmpty {
            state.choiceGeneralError = "Некоторые варианты дают одинаковое значение на латинице. Измените названия вариантов."
        }
    }
    
    func save() {
        saveErrorText = nil
        
        guard !validation.hasBlockingErrors else {
            return
        }
        
        isSaving = true
        
        let definition = makeDefinition()
        let issues = CustomPlaceholderValidator().validate(
            draft: definition,
            existingKeys: existingKeysForValidation
        )
        
        guard issues.isEmpty else {
            saveErrorText = issues.map(\.text).joined(separator: "\n")
            isSaving = false
            return
        }
        
        Task {
            do {
                try await onSave(definition)
                
                await MainActor.run {
                    isSaving = false
                    closeEditor()
                }
            } catch {
                await MainActor.run {
                    saveErrorText = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
    
    func editorCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }
    
    func makeDefinition() -> PlaceholderDescriptor {
        let inputKind: PlaceholderInputKind
        let valueSource: PlaceholderValueSource
        
        switch valueType {
            case .text:
                valueSource = textValueSource.placeholderValueSource
                inputKind = .text(
                    TextInputConfiguration(
                        placeholder: textPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines),
                        isRequired: textRequired,
                        trimOnCommit: true,
                        editorStyle: .singleLine
                    )
                )
                
            case .choice:
                valueSource = .manual
                inputKind = .choice(
                    ChoiceInputConfiguration(
                        options: choiceOptions.map(\.placeholderOption),
                        defaultOptionID: nil,
                        allowsEmptySelection: true,
                        emptyTitle: "Не выбрано",
                        presentationStyle: .menu
                    )
                )
        }
        
        return PlaceholderDescriptor(
            key: normalizedKeyText.placeholderKey,
            title: titleText.trimmingCharacters(in: .whitespacesAndNewlines),
            description: descriptionText.trimmed,
            section: .custom,
            order: order,
            kind: .editable(source: valueSource, inputKind: inputKind),
            isUserDefined: true,
            exampleValue: nil,
            isRequired: inputKind.isRequired
        )
    }
    
    func removeOption(id: String) {
        choiceOptions.removeAll { $0.id == id }
    }
    
    static func defaultChoiceOptions() -> [ChoiceOptionDraft] {
        [
            .init(title: "Вариант 1"),
            .init(title: "Вариант 2")
        ]
    }
}

// MARK: - ChoiceOptionRowView

private struct ChoiceOptionRowView: View {
    let index: Int
    @Binding var option: ChoiceOptionDraft
    let errorText: String?
    let canDelete: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 34)
            
            VStack(alignment: .leading, spacing: 5) {
                TextField("Например: Договор поставки", text: $option.title)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                errorText == nil ? Color.primary.opacity(0.12) : Color.red.opacity(0.65),
                                lineWidth: 1
                            )
                    )
                
                if let errorText {
                    validationMessage(errorText, style: .error)
                } else {
                    HStack(spacing: 4) {
                        Text("Будет сохранено как:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(option.generatedReplacementValue.isEmpty ? "—" : option.generatedReplacementValue)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .disabled(!canDelete)
            .help(canDelete ? "Удалить вариант" : "Минимум два варианта")
            .padding(.top, 2)
        }
    }
    
    private func validationMessage(
        _ text: String,
        style: ValidationMessageStyle
    ) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: style.systemImage)
                .font(.caption)
                .foregroundStyle(style.color)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(style.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Small UI helpers

private enum FieldHelper {
    case plain(String)
    case token(prefix: String, token: String)
}

private enum ValidationMessageStyle {
    case error
    case info
    
    var color: Color {
        switch self {
            case .error: return .red
            case .info: return .secondary
        }
    }
    
    var systemImage: String {
        switch self {
            case .error: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
        }
    }
}

private extension CustomPlaceholderEditorView {
    func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
    }
    
    func labeledTextField(
        title: String,
        text: Binding<String>,
        prompt: String,
        helper: FieldHelper? = nil,
        errorText: String? = nil,
        isDisabled: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
            
            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            errorText == nil ? Color.primary.opacity(0.12) : Color.red.opacity(0.65),
                            lineWidth: 1
                        )
                )
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.65 : 1)
            
            if let errorText {
                validationMessage(errorText, style: .error)
            } else if let helper {
                helperView(helper)
            }
        }
    }
    
    func multilineTextEditor(
        text: Binding<String>,
        prompt: String
    ) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                )
            
            if text.wrappedValue.isEmpty {
                Text(prompt)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .allowsHitTesting(false)
            }
            
            TextEditor(text: text)
                .font(.body)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.clear)
        }
    }
    
    @ViewBuilder
    func helperView(_ helper: FieldHelper) -> some View {
        switch helper {
            case .plain(let text):
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
            case .token(let prefix, let token):
                HStack(spacing: 6) {
                    Text(prefix)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(token)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.accentColor.opacity(0.10))
                        )
                }
        }
    }
    
    func validationMessage(
        _ text: String,
        style: ValidationMessageStyle
    ) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: style.systemImage)
                .font(.caption)
                .foregroundStyle(style.color)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(style.color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    func errorBanner(text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.red.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.red.opacity(0.20), lineWidth: 1)
        )
    }
}

// MARK: - Local generation helpers

private extension String {
    nonisolated var generatedLatinIdentifier: String {
        let source = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return "" }
        
        let latin = source.applyingTransform(.toLatin, reverse: false) ?? source
        let withoutDiacritics = latin.applyingTransform(.stripDiacritics, reverse: false) ?? latin
        let lowercased = withoutDiacritics.lowercased()
        
        var result = ""
        var previousWasSeparator = false
        
        for scalar in lowercased.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
                previousWasSeparator = false
            } else if !previousWasSeparator {
                result.append("_")
                previousWasSeparator = true
            }
        }
        
        result = result.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        
        if let first = result.unicodeScalars.first,
           CharacterSet.decimalDigits.contains(first) {
            result = "option_" + result
        }
        
        return result
    }
}

private extension Int {
    var optionCountWord: String {
        let mod10 = self % 10
        let mod100 = self % 100
        
        if mod10 == 1 && mod100 != 11 {
            return "вариант"
        }
        
        if (2...4).contains(mod10) && !(12...14).contains(mod100) {
            return "варианта"
        }
        
        return "вариантов"
    }
}
