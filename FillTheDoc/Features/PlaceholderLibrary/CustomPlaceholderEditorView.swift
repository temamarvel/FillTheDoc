import SwiftUI

// MARK: - CustomPlaceholderEditorView

/// Экран создания и редактирования пользовательских плейсхолдера.
///
/// View редактирует единый `CustomPlaceholderDraft`, валидирует его на UI-уровне
/// и по сохранению отдаёт готовый `PlaceholderDescriptor` во внешний persistence-flow.
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
    
    @State private var draft: CustomPlaceholderDraft
    @State private var lastTextValueSource: PlaceholderValueSource
    @State private var validationState: InlineValidationState
    @State private var saveErrorText: String?
    @State private var isSaving = false
    
    private let draftValidator = CustomPlaceholderDraftValidator()
    private let validator = CustomPlaceholderValidator()
    
    init(
        mode: Mode,
        existingKeys: Set<PlaceholderKey>,
        nextOrder: Int = 500,
        onSave: @escaping (PlaceholderDescriptor) async throws -> Void,
        onDismiss: (() -> Void)? = nil
    ) {
        self.mode = mode
        self.existingKeys = existingKeys
        self.onSave = onSave
        self.onDismiss = onDismiss
        
        let initialDraft: CustomPlaceholderDraft
        if let descriptor = mode.existingDefinition {
            initialDraft = CustomPlaceholderDraft(descriptor: descriptor)
        } else {
            initialDraft = .new(displayOrder: nextOrder)
        }
        
        var validationKeys = existingKeys
        if let existingDefinition = mode.existingDefinition {
            validationKeys.remove(existingDefinition.key)
        }
        
        _draft = State(initialValue: initialDraft)
        _lastTextValueSource = State(
            initialValue: {
                guard case .text(let valueSource) = initialDraft.inputKind else {
                    return .extracted
                }
                return valueSource
            }()
        )
        _validationState = State(
            initialValue: InlineValidationState(
                issues: CustomPlaceholderDraftValidator().validate(
                    initialDraft,
                    existingKeys: validationKeys
                )
            )
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            
            ScrollView {
                VStack {
                    baseSection
                    settingsSection
                }
            }
            
            //TODO: error?
//            if let saveErrorText {
//                Divider()
//                errorBanner(text: saveErrorText)
//                    .padding(.horizontal, 24)
//                    .padding(.vertical, 12)
//            }
//
            
            
            Divider()
            
            
            footerView
        }
        .background(.windowBackground)
        .onChange(of: draft) { _, _ in
            refreshValidation()
            saveErrorText = nil
        }
    }
}

// MARK: - Layout

private extension CustomPlaceholderEditorView {
    var existingKeysForValidation: Set<PlaceholderKey> {
        var keys = existingKeys
        if let existingDefinition = mode.existingDefinition {
            keys.remove(existingDefinition.key)
        }
        return keys
    }
    
    var tokenPreview: String {
        let key = draft.normalizedKey.isEmpty ? "placeholder_key" : draft.normalizedKey
        return "<!\(key)!>"
    }
    
    var canSave: Bool {
        !isSaving && !validationState.hasBlockingErrors
    }
    
    var inputKindSelection: InputKindSelection {
        switch draft.inputKind {
            case .text:
                return .text
            case .choice:
                return .choice
        }
    }
    
    var exampleValueTextBinding: Binding<String> {
        Binding(
            get: { draft.exampleValue ?? "" },
            set: { draft.exampleValue = $0 }
        )
    }
    
    var inputKindSelectionBinding: Binding<InputKindSelection> {
        Binding(
            get: { inputKindSelection },
            set: { selection in
                switch selection {
                    case .text:
                        draft.inputKind = .text(valueSource: lastTextValueSource)
                    case .choice:
                        if case .text(let valueSource) = draft.inputKind {
                            lastTextValueSource = valueSource
                        }
                        draft.inputKind = .choice(
                            options: [EditableChoiceOption(value: "")]
                        )
                        draft.isRequired = true
                }
            }
        )
    }
    
    var textValueSourceBinding: Binding<PlaceholderValueSource> {
        Binding(
            get: {
                guard case .text(let source) = draft.inputKind else {
                    return lastTextValueSource
                }
                return source
            },
            set: { newSource in
                lastTextValueSource = newSource
                guard case .text = draft.inputKind else { return }
                draft.inputKind = .text(valueSource: newSource)
            }
        )
    }
    
    var choiceOptions: [EditableChoiceOption] {
        guard case .choice(let options) = draft.inputKind else { return [] }
        return options
    }
    
    func choiceOptionBinding(at index: Int) -> Binding<EditableChoiceOption> {
        Binding(
            get: {
                let options = choiceOptions
                guard options.indices.contains(index) else {
                    return EditableChoiceOption()
                }
                return options[index]
            },
            set: { newValue in
                guard case .choice(var options) = draft.inputKind,
                      options.indices.contains(index) else { return }
                options[index] = newValue
                draft.inputKind = .choice(options: options)
            }
        )
    }
    
    func closeEditor() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
    
    var headerView: some View {
        HStack {
            Text(mode.title)
                .font(.title3.weight(.semibold))
        }
    }
    
    var baseSection: some View {
        editorCard {
            sectionHeader("1. Основные параметры")
            
            labeledTextField(
                title: "Название плейсхолдера",
                text: $draft.title,
                prompt: "Например: Номер договора",
                helper: .plain("Отображаемое имя в интерфейсе"),
                errorText: validationState.titleError
            )
            
            labeledTextField(
                title: "Ключ плейсхолдера",
                text: $draft.key,
                prompt: "Например: contract_number",
                helper: .token(prefix: "Используется в шаблоне документа как", token: tokenPreview),
                errorText: validationState.keyError,
                isDisabled: mode.isEditing
            )
        }
    }
    
    var settingsSection: some View {
        editorCard {
            sectionHeader("2. Настройки плейсхолдера")
            
            VStack {
                Text("Тип значения")
                    .font(.subheadline.weight(.medium))
                
                Picker("", selection: inputKindSelectionBinding) {
                    ForEach(InputKindSelection.allCases) { type in
                        Label(type.title, systemImage: type.systemImage)
                            .tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            switch draft.inputKind {
                case .text:
                    textSettingsSection
                case .choice:
                    choiceSettingsSection
            }
            
            exampleValueSection
        }
    }
    
    var textSettingsSection: some View {
        VStack {
            VStack {
                Text("Источник значения")
                    .font(.subheadline.weight(.medium))
                
                Picker("", selection: textValueSourceBinding) {
                    ForEach(PlaceholderValueSource.allCases) { source in
                        Text(source.editorTitle)
                            .tag(source)
                    }
                }
                .pickerStyle(.segmented)
                
                Text(textValueSourceBinding.wrappedValue.editorHelperText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            VStack {
                HStack {
                    Text(textValueSourceBinding.wrappedValue == .extracted ? "Описание для экстракции (для LLM)" : "Описание поля")
                        .font(.subheadline.weight(.medium))
                    
                    Image(systemName: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help(
                            textValueSourceBinding.wrappedValue == .extracted
                            ? "Опишите, какое значение нужно найти в исходных документах. Это описание попадёт в промпт извлечения."
                            : "Краткое описание поля для интерфейса и библиотеки плейсхолдеров."
                        )
                }
                
                multilineTextEditor(
                    text: $draft.description,
                    prompt: "Например: Номер договора. Обычно содержит цифры и может включать дополнительные символы, например, слеши или дефисы."
                )
                
                if let descriptionError = validationState.descriptionError {
                    validationMessage(descriptionError, style: .error)
                } else {
                    HStack {
                        Text(
                            textValueSourceBinding.wrappedValue == .extracted
                            ? "Описание помогает модели понять, какие данные искать."
                            : "Описание используется в интерфейсе и справочнике плейсхолдеров."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Text("\(draft.description.count)/500")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Toggle("Поле обязательно для заполнения", isOn: $draft.isRequired)
        }
    }
    
    var exampleValueSection: some View {
        VStack {
            labeledTextField(
                title: "Пример значения (необязательно)",
                text: exampleValueTextBinding,
                prompt: draft.isTextInput
                ? "Например: 123/2024-ОД или Д-45 от 12.03.2024"
                : "Например: счет",
                helper: .plain(exampleValueHelperText),
                errorText: validationState.exampleValueError
            )
        }
    }
    
    var choiceSettingsSection: some View {
        VStack {
            VStack {
                Text("Источник значения")
                    .font(.subheadline.weight(.medium))
                Text("Плейсхолдер с выбором всегда заполняется пользователем вручную.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                   
            }
            
            HStack {
                HStack {
                    Text("Варианты выбора")
                        .font(.subheadline.weight(.medium))
                    
                    Image(systemName: "questionmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("Введите варианты, которые пользователь увидит в меню. Выбранная строка и будет подставлена в документ.")
                }
                
                Spacer()
                
                Text("\(choiceOptions.count)/\(CustomPlaceholderDraftValidator.maxChoiceOptions) \(choiceOptions.count.optionCountWord)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let choiceGeneralError = validationState.choiceGeneralError {
                validationMessage(choiceGeneralError, style: .error)
            }
            
            VStack {
                ForEach(Array(choiceOptions.enumerated()), id: \.element.id) { index, option in
                    ChoiceOptionRowView(
                        option: choiceOptionBinding(at: index),
                        errorText: validationState.choiceOptionErrors[option.id],
                        canDelete: choiceOptions.count > 1,
                        onDelete: {
                            removeOption(id: option.id)
                        }
                    )
                }
            }
            
            Button {
                addOption()
            } label: {
                Label("Добавить вариант", systemImage: "plus")
            }
            .disabled(choiceOptions.count >= CustomPlaceholderDraftValidator.maxChoiceOptions)
            
            Toggle("Поле обязательно для выбора", isOn: $draft.isRequired)
        }
    }
    
    var footerView: some View {
        HStack {
            if validationState.hasBlockingErrors {
                Label("Исправьте ошибки перед сохранением", systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Отмена") {
                closeEditor()
            }
            //.buttonStyle(.bordered)
            
            Button(mode.saveButtonTitle) {
                save()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
    }
    
    var exampleValueHelperText: String {
        switch draft.inputKind {
            case .text:
                return "Используется как пример итогового значения и отображается серым текстом в поле ввода."
            case .choice:
                return "Используется в библиотеке плейсхолдеров как пример возможного выбранного значения."
        }
    }
}

// MARK: - Validation / Save

private extension CustomPlaceholderEditorView {
    func refreshValidation() {
        validationState = InlineValidationState(
            issues: draftValidator.validate(
                draft,
                existingKeys: existingKeysForValidation
            )
        )
    }
    
    func save() {
        saveErrorText = nil
        refreshValidation()
        
        guard !validationState.hasBlockingErrors else {
            return
        }
        
        isSaving = true
        
        let descriptor = draft.makeDescriptor()
        let issues = validator.validate(
            descriptor: descriptor,
            existingKeys: existingKeysForValidation
        )
        
        guard issues.isEmpty else {
            saveErrorText = issues.map(\.text).joined(separator: "\n")
            isSaving = false
            return
        }
        
        Task {
            do {
                try await onSave(descriptor)
                
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
    
    func addOption() {
        guard case .choice(var options) = draft.inputKind else { return }
        options.append(.init())
        draft.inputKind = .choice(options: options)
    }
    
    func removeOption(id: UUID) {
        guard case .choice(var options) = draft.inputKind else { return }
        options.removeAll { $0.id == id }
        if options.isEmpty {
            options = [.init()]
        }
        draft.inputKind = .choice(options: options)
    }
    
    func editorCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack {
            content()
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12) //TODO: check radius
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - ChoiceOptionRowView

private struct ChoiceOptionRowView: View {
    @Binding var option: EditableChoiceOption
    let errorText: String?
    let canDelete: Bool
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack {
                TextField("Например: СБП", text: $option.value)
                    
                    
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                errorText == nil ? Color.primary.opacity(0.12) : Color.red.opacity(0.65),
                                lineWidth: 1
                            )
                    )
                
                if let errorText {
                    validationMessage(errorText, style: .error)
                }
            }
            
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            
            }
//            .buttonStyle(.borderless)
            .disabled(!canDelete)
            .help(canDelete ? "Удалить вариант" : "Минимум два варианта")
            
        }
    }
    
    private func validationMessage(
        _ text: String,
        style: ValidationMessageStyle
    ) -> some View {
        HStack {
            Image(systemName: style.systemImage)
                .font(.caption)
                .foregroundStyle(style.color)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(style.color)
               
        }
    }
}

// MARK: - Small UI helpers

private enum InputKindSelection: String, CaseIterable, Identifiable {
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

private extension PlaceholderValueSource {
    var editorTitle: String {
        switch self {
            case .manual:
                return "Пользователь вводит вручную"
            case .extracted:
                return "Извлекать из документа с помощью ИИ"
        }
    }
    
    var editorHelperText: String {
        switch self {
            case .manual:
                return "Поле не будет заполняться моделью."
            case .extracted:
                return "Поле будет извлекаться из документа с помощью ИИ."
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
        VStack {
            Text(title)
                .font(.subheadline.weight(.medium))
            
            TextField(prompt, text: text)
                .disabled(isDisabled)
            
//            if let errorText {
//                validationMessage(errorText, style: .error)
//            } else if let helper {
//                helperView(helper)
//            }
        }
    }
    
    func multilineTextEditor(
        text: Binding<String>,
        prompt: String
    ) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                //.fill(Color(nsColor: .textBackgroundColor))
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
        HStack {
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
        HStack {
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
