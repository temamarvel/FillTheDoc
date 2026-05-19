import SwiftUI

// MARK: - Draft models

nonisolated private struct ChoiceOptionDraft: Identifiable, Hashable {
    let id: String
    var title: String
    var replacementValue: String
    
    nonisolated init(
        id: String = UUID().uuidString,
        title: String = "",
        replacementValue: String = ""
    ) {
        self.id = id
        self.title = title
        self.replacementValue = replacementValue
    }
    
    nonisolated init(option: PlaceholderOption) {
        self.id = option.id
        self.title = option.title
        self.replacementValue = option.replacementValue
    }
    
    nonisolated var placeholderOption: PlaceholderOption {
        PlaceholderOption(
            id: id,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            replacementValue: replacementValue.trimmingCharacters(in: .whitespacesAndNewlines)
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
}

// MARK: - Validation

private struct InlineValidationState {
    var titleError: String?
    var keyError: String?
    var choiceGeneralError: String?
    var choiceOptionErrors: [String: ChoiceOptionValidationError] = [:]
    
    var hasBlockingErrors: Bool {
        titleError != nil
        || keyError != nil
        || choiceGeneralError != nil
        || choiceOptionErrors.values.contains(where: \.hasError)
    }
}

private struct ChoiceOptionValidationError {
    var titleError: String?
    var replacementValueError: String?
    
    var hasError: Bool {
        titleError != nil || replacementValueError != nil
    }
}

// MARK: - CustomPlaceholderEditorView

struct CustomPlaceholderEditorView: View {
    enum Mode {
        case create
        case edit(CustomPlaceholderDefinition)
        
        var title: String {
            switch self {
                case .create:
                    return "Новый плейсхолдер"
                case .edit:
                    return "Редактирование плейсхолдера"
            }
        }
        
        var subtitle: String {
            "Основные поля сверху, настройки и предпросмотр ниже"
        }
        
        var saveButtonTitle: String {
            switch self {
                case .create:
                    return "Создать"
                case .edit:
                    return "Сохранить"
            }
        }
        
        var existingDefinition: CustomPlaceholderDefinition? {
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
    let onSave: (CustomPlaceholderDefinition) async throws -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var titleText: String
    @State private var keyText: String
    @State private var descriptionText: String
    @State private var valueType: CustomPlaceholderEditorInputType
    
    @State private var textPlaceholder: String
    @State private var textRequired: Bool
    
    @State private var choiceOptions: [ChoiceOptionDraft]
    @State private var defaultOptionID: String?
    
    @State private var order: Int
    @State private var isEnabled: Bool
    @State private var previewValue: PlaceholderFieldValue
    
    @State private var saveErrorText: String?
    @State private var isSaving = false
    @FocusState private var previewFocusedKey: PlaceholderKey?
    
    init(
        mode: Mode,
        existingKeys: Set<PlaceholderKey>,
        onSave: @escaping (CustomPlaceholderDefinition) async throws -> Void
    ) {
        self.mode = mode
        self.existingKeys = existingKeys
        self.onSave = onSave
        
        let definition = mode.existingDefinition
        
        _titleText = State(initialValue: definition?.title ?? "")
        _keyText = State(initialValue: definition?.key.rawValue ?? "")
        _descriptionText = State(initialValue: definition?.description ?? "")
        _order = State(initialValue: definition?.order ?? 500)
        _isEnabled = State(initialValue: definition?.isEnabled ?? true)
        _previewValue = State(initialValue: .empty)
        
        switch definition?.inputKind {
            case .text(let configuration):
                _valueType = State(initialValue: .text)
                _textPlaceholder = State(initialValue: configuration.placeholder)
                _textRequired = State(initialValue: configuration.isRequired)
                _choiceOptions = State(initialValue: Self.defaultChoiceOptions())
                _defaultOptionID = State(initialValue: nil)
                
            case .choice(let configuration):
                _valueType = State(initialValue: .choice)
                _textPlaceholder = State(initialValue: "")
                _textRequired = State(initialValue: false)
                _choiceOptions = State(initialValue: configuration.options.map(ChoiceOptionDraft.init(option:)))
                _defaultOptionID = State(initialValue: configuration.defaultOptionID)
                
            case nil:
                _valueType = State(initialValue: .text)
                _textPlaceholder = State(initialValue: "")
                _textRequired = State(initialValue: false)
                _choiceOptions = State(initialValue: Self.defaultChoiceOptions())
                _defaultOptionID = State(initialValue: nil)
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
    
    private var previewTitle: String {
        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Название поля" : title
    }
    
    private var previewKey: PlaceholderKey {
        PlaceholderKey(rawValue: normalizedKeyText.isEmpty ? "placeholder_key" : normalizedKeyText)
    }
    
    private var previewDescriptor: PlaceholderDescriptor {
        makeDefinition(
            key: previewKey,
            title: previewTitle
        )
        .makeRuntimeDefinition()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    baseSection
                    settingsSection
                    previewSection
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
        .frame(minWidth: 760, minHeight: 640)
        //.background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: valueType) { _, newValue in
            saveErrorText = nil
            
            if newValue == .choice {
                normalizeDefaultOptionID()
            } else {
                defaultOptionID = nil
            }
        }
        .onChange(of: choiceOptions) { _, _ in
            saveErrorText = nil
            normalizeDefaultOptionID()
        }
        .onChange(of: titleText) { _, _ in saveErrorText = nil }
        .onChange(of: keyText) { _, _ in saveErrorText = nil }
        .onChange(of: textPlaceholder) { _, _ in saveErrorText = nil }
    }
}

// MARK: - Layout

private extension CustomPlaceholderEditorView {
    var headerView: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(mode.title)
                    .font(.title2.weight(.semibold))
                
                Text(mode.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Закрыть")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    var baseSection: some View {
        editorCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 18) {
                    labeledTextField(
                        title: "Название",
                        text: $titleText,
                        prompt: "Например: Способ оплаты",
                        helperText: "Отображаемое название плейсхолдера.",
                        errorText: validation.titleError
                    )
                    
                    labeledTextField(
                        title: "Ключ",
                        text: $keyText,
                        prompt: "Например: payment_method",
                        helperText: "Используется в шаблонах как \(tokenPreview)",
                        errorText: validation.keyError,
                        isDisabled: mode.isEditing
                    )
                }
                
                Picker("", selection: $valueType) {
                    ForEach(CustomPlaceholderEditorInputType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                
                Text(valueType == .text
                     ? "Текст — пользователь вводит значение вручную."
                     : "Выбор — пользователь выбирает вариант, а в документ подставляется связанное значение.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    var settingsSection: some View {
        switch valueType {
            case .text:
                textSettingsSection
            case .choice:
                choiceSettingsSection
        }
    }
    
    var textSettingsSection: some View {
        editorCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(
                    title: "Настройки текстового поля",
                    subtitle: "Настройте подсказку внутри поля и обязательность заполнения."
                )
                
                labeledTextField(
                    title: "Плейсхолдер",
                    text: $textPlaceholder,
                    prompt: "Например: Введите номер договора",
                    helperText: "Текст-подсказка, который пользователь увидит внутри поля."
                )
                
                Divider()
                
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Обязательное поле")
                            .font(.subheadline.weight(.medium))
                        
                        Text("Пользователь должен будет заполнить это поле.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $textRequired)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }
        }
    }
    
    var choiceSettingsSection: some View {
        editorCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader(
                    title: "Варианты выбора",
                    subtitle: "Слева — что видит пользователь. Справа — что попадёт в DOCX."
                )
                
                if let choiceGeneralError = validation.choiceGeneralError {
                    validationMessage(choiceGeneralError, color: .red)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("")
                            .frame(width: 26)
                        
                        Text("Отображаемое название")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Значение для подстановки")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("")
                            .frame(width: 28)
                    }
                    
                    ForEach(choiceOptions.indices, id: \.self) { index in
                        let optionID = choiceOptions[index].id
                        let optionError = validation.choiceOptionErrors[optionID]
                        
                        ChoiceOptionRowView(
                            index: index,
                            option: $choiceOptions[index],
                            titleError: optionError?.titleError,
                            replacementValueError: optionError?.replacementValueError,
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
                }
                .buttonStyle(.link)
                
                Divider()
                
                Picker(
                    "Значение по умолчанию",
                    selection: Binding<String?>(
                        get: { defaultOptionID },
                        set: { defaultOptionID = $0 }
                    )
                ) {
                    Text("Без значения по умолчанию")
                        .tag(String?.none)
                    
                    ForEach(choiceOptions) { option in
                        Text(option.title.isEmpty ? "Без названия" : option.title)
                            .tag(String?.some(option.id))
                    }
                }
            }
        }
    }
    
    var previewSection: some View {
        editorCard {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader(
                    title: "Предпросмотр",
                    subtitle: "Так плейсхолдер будет выглядеть в шаблоне и в форме."
                )
                
                HStack(alignment: .top, spacing: 28) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Токен в документе")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            Text(tokenPreview)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(.tint)
                                .lineLimit(1)
                            
                            Spacer(minLength: 8)
                            
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
                        )
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("В форме для пользователя")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        
                        Form{
                                DocumentDataFieldView(
                                    descriptor: previewDescriptor,
                                    value: $previewValue,
                                    focusedKey: $previewFocusedKey
                                )
                                .id(previewDescriptor.signature)
                        }.formStyle(.grouped)
                            
                    }
                    
                    .frame(maxWidth: .infinity)
                    
                }
                
                Divider()
                
                Label(
                    "Значение из формы будет автоматически подставлено в документ при заполнении.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
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
                dismiss()
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
        } else if existingKeysForValidation.contains(PlaceholderKey(rawValue: rawKey)) {
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
        
        for option in choiceOptions {
            var optionError = ChoiceOptionValidationError()
            
            if option.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                optionError.titleError = "Введите название."
            }
            
            if option.replacementValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                optionError.replacementValueError = "Введите значение."
            }
            
            if optionError.hasError {
                state.choiceOptionErrors[option.id] = optionError
            }
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
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    saveErrorText = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
    
    func makeDefinition(
        key: PlaceholderKey? = nil,
        title: String? = nil
    ) -> CustomPlaceholderDefinition {
        let key = key ?? PlaceholderKey(rawValue: normalizedKeyText)
        let title = title ?? titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = descriptionText.trimmedNilIfEmpty
        
        let inputKind: PersistedPlaceholderInputKind
        
        switch valueType {
            case .text:
                inputKind = .text(
                    PersistedTextInputConfiguration(
                        placeholder: textPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines),
                        isRequired: textRequired,
                        editorStyle: .singleLine
                    )
                )
                
            case .choice:
                inputKind = .choice(
                    PersistedChoiceInputConfiguration(
                        options: choiceOptions.map(\.placeholderOption),
                        defaultOptionID: defaultOptionID,
                        allowsEmptySelection: true,
                        emptyTitle: "Не выбрано",
                        presentationStyle: .menu
                    )
                )
        }
        
        return CustomPlaceholderDefinition(
            key: key,
            title: title,
            description: description,
            inputKind: inputKind,
            order: order,
            isEnabled: isEnabled,
            createdAt: mode.existingDefinition?.createdAt ?? Date(),
            updatedAt: Date()
        )
    }
    
    func removeOption(id: String) {
        choiceOptions.removeAll { $0.id == id }
        
        if defaultOptionID == id {
            defaultOptionID = nil
        }
    }
    
    func normalizeDefaultOptionID() {
        guard let defaultOptionID else { return }
        guard !choiceOptions.contains(where: { $0.id == defaultOptionID }) else { return }
        self.defaultOptionID = nil
    }
    
    static func defaultChoiceOptions() -> [ChoiceOptionDraft] {
        [
            .init(title: "Вариант 1", replacementValue: "Вариант 1"),
            .init(title: "Вариант 2", replacementValue: "Вариант 2")
        ]
    }
}

// MARK: - ChoiceOptionRowView

private struct ChoiceOptionRowView: View {
    let index: Int
    @Binding var option: ChoiceOptionDraft
    let titleError: String?
    let replacementValueError: String?
    let canDelete: Bool
    let onDelete: () -> Void
    
    private var hasError: Bool {
        titleError != nil || replacementValueError != nil
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                validatedTextField(
                    "Например: Безналичный расчёт",
                    text: $option.title,
                    hasError: titleError != nil
                )
                
                if let titleError {
                    validationMessage(titleError, color: .red)
                }
            }
            .frame(maxWidth: .infinity)
            
            VStack(alignment: .leading, spacing: 4) {
                validatedTextField(
                    "Например: beznalichnyy_raschet",
                    text: $option.replacementValue,
                    hasError: replacementValueError != nil
                )
                
                if let replacementValueError {
                    validationMessage(replacementValueError, color: .red)
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
        }
        .padding(.vertical, 2)
        .overlay(alignment: .leading) {
            if hasError {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.red.opacity(0.12))
                    .frame(width: 3)
                    .offset(x: -6)
            }
        }
    }
    
    private func validatedTextField(
        _ prompt: String,
        text: Binding<String>,
        hasError: Bool
    ) -> some View {
        TextField(prompt, text: text)
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        hasError ? Color.red.opacity(0.65) : Color.primary.opacity(0.12),
                        lineWidth: 1
                    )
            )
    }
    
    private func validationMessage(
        _ text: String,
        color: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: color == .red ? "exclamationmark.circle.fill" : "info.circle.fill")
                .font(.caption)
                .foregroundStyle(color)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Small UI helpers

private extension CustomPlaceholderEditorView {
    func editorCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
//        .background(
//            RoundedRectangle(cornerRadius: 12)
//                .fill(Color(nsColor: .windowBackgroundColor))
//        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }
    
    func sectionHeader(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    func labeledTextField(
        title: String,
        text: Binding<String>,
        prompt: String,
        helperText: String? = nil,
        errorText: String? = nil,
        isDisabled: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
            
            validatedTextField(
                prompt,
                text: text,
                hasError: errorText != nil,
                isDisabled: isDisabled
            )
            
            if let errorText {
                validationMessage(errorText, color: .red)
            } else if let helperText {
                Text(helperText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    func validatedTextField(
        _ prompt: String,
        text: Binding<String>,
        hasError: Bool,
        isDisabled: Bool = false
    ) -> some View {
        TextField(prompt, text: text)
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
                        hasError ? Color.red.opacity(0.65) : Color.primary.opacity(0.12),
                        lineWidth: 1
                    )
            )
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.65 : 1)
    }
    
    func validationMessage(
        _ text: String,
        color: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: color == .red ? "exclamationmark.circle.fill" : "info.circle.fill")
                .font(.caption)
                .foregroundStyle(color)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(color)
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

// MARK: - Preview

#Preview("Create / Text") {
    CustomPlaceholderEditorPreviewContainer(
        mode: .create
    )
}

#Preview("Create / Choice") {
    CustomPlaceholderEditorPreviewContainer(
        mode: .create,
        initialDefinition: CustomPlaceholderDefinition(
            key: PlaceholderKey(rawValue: "payment_method"),
            title: "Способ оплаты",
            description: "Выберите способ оплаты договора.",
            inputKind: .choice(
                PersistedChoiceInputConfiguration(
                    options: [
                        PlaceholderOption(
                            id: "cash",
                            title: "Наличные",
                            replacementValue: "Наличные"
                        ),
                        PlaceholderOption(
                            id: "invoice",
                            title: "Безналичный расчёт",
                            replacementValue: "Безналичный расчёт"
                        )
                    ],
                    defaultOptionID: "invoice",
                    allowsEmptySelection: true,
                    emptyTitle: "Не выбрано",
                    presentationStyle: .menu
                )
            ),
            order: 100
        )
    )
}

#Preview("Edit") {
    CustomPlaceholderEditorPreviewContainer(
        mode: .edit(
            CustomPlaceholderDefinition(
                key: PlaceholderKey(rawValue: "delivery_address"),
                title: "Адрес доставки",
                description: "Адрес, который будет подставлен в договор.",
                inputKind: .text(
                    PersistedTextInputConfiguration(
                        placeholder: "Введите адрес доставки",
                        isRequired: true,
                        editorStyle: .singleLine
                    )
                ),
                order: 200
            )
        )
    )
}

@MainActor
private struct CustomPlaceholderEditorPreviewContainer: View {
    let mode: CustomPlaceholderEditorView.Mode
    let initialDefinition: CustomPlaceholderDefinition?
    
    init(
        mode: CustomPlaceholderEditorView.Mode,
        initialDefinition: CustomPlaceholderDefinition? = nil
    ) {
        self.mode = mode
        self.initialDefinition = initialDefinition
    }
    
    var body: some View {
        CustomPlaceholderEditorView(
            mode: resolvedMode,
            existingKeys: existingKeys
        ) { _ in
            try await Task.sleep(for: .milliseconds(300))
        }
        .frame(width: 820, height: 720)
    }
    
    private var resolvedMode: CustomPlaceholderEditorView.Mode {
        if let initialDefinition {
            return .edit(initialDefinition)
        }
        
        return mode
    }
    
    private var existingKeys: Set<PlaceholderKey> {
        [
            .companyName,
            .address,
            .email,
            .phone,
            .paymentMethod,
            PlaceholderKey(rawValue: "delivery_address")
        ]
    }
}
