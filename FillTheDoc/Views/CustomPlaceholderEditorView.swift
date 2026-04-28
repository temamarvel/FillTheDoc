import SwiftUI

// MARK: - Draft models

nonisolated private struct ChoiceOptionDraft: Identifiable, Hashable {
    let id: String
    var title: String
    var replacementValue: String
    var description: String?
    
    nonisolated init(
        id: String = UUID().uuidString,
        title: String = "",
        replacementValue: String = "",
        description: String? = nil
    ) {
        self.id = id
        self.title = title
        self.replacementValue = replacementValue
        self.description = description
    }
    
    nonisolated init(option: PlaceholderOption) {
        self.id = option.id
        self.title = option.title
        self.replacementValue = option.replacementValue
        self.description = option.description
    }
    
    nonisolated var placeholderOption: PlaceholderOption {
        PlaceholderOption(
            id: id,
            title: title,
            replacementValue: replacementValue,
            description: description?.trimmedNilIfEmpty
        )
    }
}

private enum CustomPlaceholderEditorInputType: String, CaseIterable, Identifiable {
    case text
    case multilineText
    case choice
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
            case .text:
                return "Текст"
            case .multilineText:
                return "Многострочный"
            case .choice:
                return "Выбор"
        }
    }
    
    var settingsTitle: String {
        switch self {
            case .text:
                return "Текст"
            case .multilineText:
                return "Многострочный текст"
            case .choice:
                return "Выбор"
        }
    }
}

// MARK: - Inline validation model

private struct InlineValidationState {
    var keyError: String?
    var titleError: String?
    var descriptionError: String?
    var choiceGeneralError: String?
    var defaultOptionError: String?
    var choiceOptionErrors: [String: ChoiceOptionValidationError] = [:]
    
    var hasBlockingErrors: Bool {
        keyError != nil
        || titleError != nil
        || descriptionError != nil
        || choiceGeneralError != nil
        || defaultOptionError != nil
        || choiceOptionErrors.values.contains { $0.hasError }
    }
}

private struct ChoiceOptionValidationError {
    var titleError: String?
    var replacementValueError: String?
    
    var hasError: Bool {
        titleError != nil || replacementValueError != nil
    }
}

// MARK: - Main view

struct CustomPlaceholderEditorView: View {
    enum Mode {
        case create
        case edit(CustomPlaceholderDefinition)
        
        var title: String {
            switch self {
                case .create:
                    return "Добавить пользовательский плейсхолдер"
                case .edit:
                    return "Редактирование пользовательского плейсхолдера"
            }
        }
        
        var subtitle: String {
            "Вариант 1 — быстрое добавление"
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
        
        var saveButtonTitle: String {
            isEditing ? "Сохранить" : "Создать"
        }
    }
    
    let mode: Mode
    let existingKeys: Set<PlaceholderKey>
    let onSave: (CustomPlaceholderDefinition) async throws -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var keyText: String
    @State private var titleText: String
    @State private var descriptionText: String
    @State private var order: Int
    @State private var inputType: CustomPlaceholderEditorInputType
    @State private var textPlaceholder: String
    @State private var textRequired: Bool
    @State private var choiceOptions: [ChoiceOptionDraft]
    @State private var defaultOptionID: String?
    @State private var allowsEmptySelection: Bool
    @State private var emptyTitle: String
    @State private var presentationStyle: ChoicePresentationStyle
    @State private var isEnabled: Bool
    
    @State private var saveErrorText: String?
    @State private var isSaving = false
    
    init(
        mode: Mode,
        existingKeys: Set<PlaceholderKey>,
        onSave: @escaping (CustomPlaceholderDefinition) async throws -> Void
    ) {
        self.mode = mode
        self.existingKeys = existingKeys
        self.onSave = onSave
        
        let definition = mode.existingDefinition
        
        _keyText = State(initialValue: definition?.key.rawValue ?? "")
        _titleText = State(initialValue: definition?.title ?? "")
        _descriptionText = State(initialValue: definition?.description ?? "")
        _order = State(initialValue: definition?.order ?? 500)
        _isEnabled = State(initialValue: definition?.isEnabled ?? true)
        
        switch definition?.inputKind {
            case .text(let configuration):
                _inputType = State(initialValue: .text)
                _textPlaceholder = State(initialValue: configuration.placeholder)
                _textRequired = State(initialValue: configuration.isRequired)
                _choiceOptions = State(initialValue: Self.defaultChoiceOptions())
                _defaultOptionID = State(initialValue: nil)
                _allowsEmptySelection = State(initialValue: true)
                _emptyTitle = State(initialValue: "Не выбрано")
                _presentationStyle = State(initialValue: .menu)
                
            case .multilineText(let configuration):
                _inputType = State(initialValue: .multilineText)
                _textPlaceholder = State(initialValue: configuration.placeholder)
                _textRequired = State(initialValue: configuration.isRequired)
                _choiceOptions = State(initialValue: Self.defaultChoiceOptions())
                _defaultOptionID = State(initialValue: nil)
                _allowsEmptySelection = State(initialValue: true)
                _emptyTitle = State(initialValue: "Не выбрано")
                _presentationStyle = State(initialValue: .menu)
                
            case .choice(let configuration):
                _inputType = State(initialValue: .choice)
                _textPlaceholder = State(initialValue: "")
                _textRequired = State(initialValue: false)
                _choiceOptions = State(initialValue: configuration.options.map(ChoiceOptionDraft.init(option:)))
                _defaultOptionID = State(initialValue: configuration.defaultOptionID)
                _allowsEmptySelection = State(initialValue: configuration.allowsEmptySelection)
                _emptyTitle = State(initialValue: configuration.emptyTitle)
                _presentationStyle = State(initialValue: configuration.presentationStyle)
                
            case nil:
                _inputType = State(initialValue: .text)
                _textPlaceholder = State(initialValue: "")
                _textRequired = State(initialValue: false)
                _choiceOptions = State(initialValue: Self.defaultChoiceOptions())
                _defaultOptionID = State(initialValue: nil)
                _allowsEmptySelection = State(initialValue: true)
                _emptyTitle = State(initialValue: "Не выбрано")
                _presentationStyle = State(initialValue: .menu)
        }
    }
    
    // MARK: - Derived state
    
    private var normalizedKeyText: String {
        keyText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
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
    
    private var tokenPreview: String {
        let key = normalizedKeyText.isEmpty ? "placeholder_key" : normalizedKeyText
        return "<!\(key)!>"
    }
    
    private var previewDescriptor: PlaceholderDescriptor {
        makePreviewDefinition().makeRuntimeDefinition()
    }
    
    var body: some View {
        editorRoot
            .frame(minWidth: 920, minHeight: 640)
            .background(Color(nsColor: .windowBackgroundColor))
            .onChange(of: inputType, handleInputTypeChange)
            .onChange(of: keyText, clearSaveError)
            .onChange(of: titleText, clearSaveError)
            .onChange(of: descriptionText, clearSaveError)
            .onChange(of: choiceOptions, handleChoiceOptionsChange)
    }
    
    private var editorRoot: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            editorContent
            saveErrorSection
            Divider()
            footerView
        }
    }
    
    private var editorContent: some View {
        HStack(spacing: 0) {
            ScrollView {
                leftPane
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            
            Divider()
            
            rightPreviewPane
                .frame(maxHeight: .infinity, alignment: .top)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.35))
        }
    }
    
    @ViewBuilder
    private var saveErrorSection: some View {
        if let saveErrorText {
            Divider()
            errorBanner(text: saveErrorText)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
    }
    
    private func handleInputTypeChange(
        oldValue: CustomPlaceholderEditorInputType,
        newValue: CustomPlaceholderEditorInputType
    ) {
        saveErrorText = nil
        
        if newValue != .choice {
            defaultOptionID = nil
        } else {
            normalizeDefaultOptionID(for: choiceOptions)
        }
    }
    
    private func handleChoiceOptionsChange(
        oldValue: [ChoiceOptionDraft],
        newValue: [ChoiceOptionDraft]
    ) {
        saveErrorText = nil
        normalizeDefaultOptionID(for: newValue)
    }
    
    private func clearSaveError<T>(oldValue: T, newValue: T) {
        saveErrorText = nil
    }
    
    private func normalizeDefaultOptionID(for options: [ChoiceOptionDraft]) {
        guard let defaultOptionID else { return }
        guard !options.contains(where: { $0.id == defaultOptionID }) else { return }
        self.defaultOptionID = nil
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
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
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
    
    // MARK: - Left pane
    
    private var leftPane: some View {
        VStack(alignment: .leading, spacing: 24) {
            EditorSectionView(title: "1. Основное") {
                basicSection
            }
            
            EditorSectionView(title: "2. Тип поля") {
                inputTypePicker
            }
            
            EditorSectionView(title: "3. Настройки (\(inputType.settingsTitle))") {
                inputSettingsSection
            }
        }
    }
    
    private var basicSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeledTextField(
                title: "Название",
                text: $titleText,
                prompt: "Например: Условия доставки",
                errorText: validation.titleError
            )
            
            labeledTextField(
                title: "Ключ",
                text: $keyText,
                prompt: "Например: delivery_terms",
                helperText: "Ключ используется в шаблоне DOCX. Формат токена: \(tokenPreview)",
                errorText: validation.keyError,
                isDisabled: mode.isEditing
            )
            
            descriptionEditor
        }
    }
    
    private var descriptionEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Описание")
                .font(.subheadline.weight(.medium))
            
            multilineInput(
                text: $descriptionText,
                hasError: validation.descriptionError != nil
            )
            .frame(height: 88)
            
            HStack(alignment: .firstTextBaseline) {
                if let descriptionError = validation.descriptionError {
                    validationMessage(descriptionError, color: .red)
                }
                
                Spacer()
                
                Text("\(descriptionText.count)/255")
                    .font(.caption2)
                    .foregroundStyle(validation.descriptionError == nil ? .gray : .red)
            }
        }
    }
    
    private var inputTypePicker: some View {
        Picker("", selection: $inputType) {
            ForEach(CustomPlaceholderEditorInputType.allCases) { type in
                Text(type.title).tag(type)
            }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }
    
    @ViewBuilder
    private var inputSettingsSection: some View {
        switch inputType {
            case .text, .multilineText:
                textSettingsSection
            case .choice:
                choiceSettingsSection
        }
    }
    
    private var textSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeledTextField(
                title: "Плейсхолдер",
                text: $textPlaceholder,
                prompt: "Введите подсказку для поля",
                helperText: "Это подсказка внутри поля ввода, а не DOCX-токен."
            )
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Обязательное поле")
                        .font(.subheadline.weight(.medium))
                    
                    Text("Если включено, пользователь не сможет применить форму с пустым значением.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $textRequired)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
        }
    }
    
    private var choiceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            choiceOptionsSection
            
            Divider()
            
            choiceDefaultSection
        }
    }
    
    private var choiceOptionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Варианты выбора")
                    .font(.subheadline.weight(.medium))
                
                Spacer()
                
                Text("\(choiceOptions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            if let choiceGeneralError = validation.choiceGeneralError {
                validationMessage(choiceGeneralError, color: .red)
            }
            
            ForEach(Array(choiceOptions.enumerated()), id: \.element.id) { index, option in
                choiceOptionRow(option: option, index: index)
            }
            
            Button {
                choiceOptions.append(.init())
            } label: {
                Label("Добавить вариант", systemImage: "plus")
            }
            .buttonStyle(.link)
        }
    }
    
    private var choiceDefaultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Настройки выбора")
                .font(.subheadline.weight(.medium))
            
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
            
            if let defaultOptionError = validation.defaultOptionError {
                validationMessage(defaultOptionError, color: .red)
            }
            
            Toggle("Разрешить пустой выбор", isOn: $allowsEmptySelection)
            
            if allowsEmptySelection {
                labeledTextField(
                    title: "Заголовок пустого выбора",
                    text: $emptyTitle,
                    prompt: "Например: Не выбрано"
                )
            }
        }
    }
    
    private func choiceOptionRow(
        option: ChoiceOptionDraft,
        index: Int
    ) -> some View {
        let optionError = validation.choiceOptionErrors[option.id]
        
        return ChoiceOptionRowView(
            index: index,
            option: bindingForChoiceOption(id: option.id),
            titleError: optionError?.titleError,
            replacementValueError: optionError?.replacementValueError,
            onDelete: {
                removeOption(id: option.id)
            }
        )
    }
    
    private func bindingForChoiceOption(id: String) -> Binding<ChoiceOptionDraft> {
        Binding(
            get: {
                choiceOptions.first(where: { $0.id == id }) ?? ChoiceOptionDraft(id: id)
            },
            set: { newValue in
                guard let index = choiceOptions.firstIndex(where: { $0.id == id }) else {
                    return
                }
                choiceOptions[index] = newValue
            }
        )
    }
    
    // MARK: - Right pane
    
    private var rightPreviewPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Предпросмотр")
                .font(.title3.weight(.semibold))
            
            Text("Так плейсхолдер будет выглядеть в форме")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            previewCard {
                tokenChip(tokenPreview)
                
                Divider()
                    .padding(.vertical, 2)
                
                Form{
                    CustomPlaceholderDocumentDataFieldPreview(descriptor: previewDescriptor)
                }
                .formStyle(.grouped)
            }
            
            previewHintCard
            
            Spacer()
        }
        .padding(24)
    }
    
    private func makePreviewDefinition() -> CustomPlaceholderDefinition {
        let previewKey = PlaceholderKey(rawValue: normalizedKeyText.isEmpty ? "placeholder_key" : normalizedKeyText)
        let previewTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = previewTitle.isEmpty ? "Название поля" : previewTitle
        let previewDescription = descriptionText.trimmedNilIfEmpty
        let persistedInputKind: PersistedPlaceholderInputKind
        
        switch inputType {
            case .text:
                persistedInputKind = .text(
                    PersistedTextInputConfiguration(
                        placeholder: previewTextPlaceholder,
                        isRequired: textRequired
                    )
                )
                
            case .multilineText:
                persistedInputKind = .multilineText(
                    PersistedTextInputConfiguration(
                        placeholder: previewTextPlaceholder,
                        isRequired: textRequired
                    )
                )
                
            case .choice:
                persistedInputKind = .choice(
                    PersistedChoiceInputConfiguration(
                        options: previewChoiceOptions,
                        defaultOptionID: defaultOptionID,
                        allowsEmptySelection: allowsEmptySelection,
                        emptyTitle: previewEmptyTitle,
                        presentationStyle: presentationStyle
                    )
                )
        }
        
        return CustomPlaceholderDefinition(
            key: previewKey,
            title: resolvedTitle,
            description: previewDescription,
            inputKind: persistedInputKind,
            order: order,
            isEnabled: isEnabled,
            createdAt: mode.existingDefinition?.createdAt ?? .distantPast,
            updatedAt: mode.existingDefinition?.updatedAt ?? .distantPast
        )
    }
    
    private var previewTextPlaceholder: String {
        let trimmed = textPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Введите значение" : trimmed
    }
    
    private var previewEmptyTitle: String {
        let trimmed = emptyTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Не выбрано" : trimmed
    }
    
    private var previewChoiceOptions: [PlaceholderOption] {
        let options = choiceOptions.enumerated().map { index, option in
            let title = option.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedTitle = title.isEmpty ? "Вариант \(index + 1)" : title
            let replacementValue = option.replacementValue.trimmingCharacters(in: .whitespacesAndNewlines)
            
            return PlaceholderOption(
                id: option.id,
                title: resolvedTitle,
                replacementValue: replacementValue.isEmpty ? resolvedTitle : replacementValue,
                description: option.description?.trimmedNilIfEmpty
            )
        }
        
        if options.isEmpty {
            return [
                PlaceholderOption(id: "preview_option_1", title: "Вариант 1", replacementValue: "Вариант 1"),
                PlaceholderOption(id: "preview_option_2", title: "Вариант 2", replacementValue: "Вариант 2")
            ]
        }
        
        return options
    }
    
    private var previewHintCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("DOCX-токен", systemImage: "doc.text")
                .font(.caption.weight(.semibold))
            
            Text("В шаблоне документа нужно использовать именно \(tokenPreview).")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.accentColor.opacity(0.08))
        )
    }
    
    // MARK: - Footer
    
    private var footerView: some View {
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
    
    // MARK: - Validation
    
    private func validateInline() -> InlineValidationState {
        var state = InlineValidationState()
        
        let rawKey = normalizedKeyText
        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if rawKey.isEmpty {
            state.keyError = "Ключ не может быть пустым."
        } else if rawKey.range(of: #"^[a-z][a-z0-9_]*$"#, options: .regularExpression) == nil {
            state.keyError = "Только латинские буквы, цифры и _. Первый символ — буква."
        } else if existingKeysForValidation.contains(PlaceholderKey(rawValue: rawKey)) {
            state.keyError = "Плейсхолдер с таким ключом уже существует."
        }
        
        if title.isEmpty {
            state.titleError = "Название не может быть пустым."
        }
        
        if descriptionText.count > 255 {
            state.descriptionError = "Описание слишком длинное."
        }
        
        if inputType == .choice {
            validateChoiceInline(into: &state)
        }
        
        return state
    }
    
    private func validateChoiceInline(into state: inout InlineValidationState) {
        if choiceOptions.count < 2 {
            state.choiceGeneralError = "Для поля выбора нужно минимум два варианта."
        }
        
        for option in choiceOptions {
            var optionError = ChoiceOptionValidationError()
            
            if option.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                optionError.titleError = "Название варианта не может быть пустым."
            }
            
            if option.replacementValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                optionError.replacementValueError = "Значение для документа не может быть пустым."
            }
            
            if optionError.hasError {
                state.choiceOptionErrors[option.id] = optionError
            }
        }
        
        if let defaultOptionID,
           !choiceOptions.contains(where: { $0.id == defaultOptionID }) {
            state.defaultOptionError = "Значение по умолчанию должно существовать в списке вариантов."
        }
    }
    
    // MARK: - Save
    
    private func save() {
        saveErrorText = nil
        
        guard !validation.hasBlockingErrors else {
            return
        }
        
        isSaving = true
        
        let definition = makeDefinition()
        let validator = CustomPlaceholderValidator()
        let issues = validator.validate(
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
    
    private func makeDefinition() -> CustomPlaceholderDefinition {
        let trimmedKey = PlaceholderKey(rawValue: normalizedKeyText)
        let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = descriptionText.trimmedNilIfEmpty
        
        let persistedInputKind: PersistedPlaceholderInputKind
        
        switch inputType {
            case .text:
                persistedInputKind = .text(
                    PersistedTextInputConfiguration(
                        placeholder: textPlaceholder,
                        isRequired: textRequired
                    )
                )
                
            case .multilineText:
                persistedInputKind = .multilineText(
                    PersistedTextInputConfiguration(
                        placeholder: textPlaceholder,
                        isRequired: textRequired
                    )
                )
                
            case .choice:
                persistedInputKind = .choice(
                    PersistedChoiceInputConfiguration(
                        options: choiceOptions.map(\.placeholderOption),
                        defaultOptionID: defaultOptionID,
                        allowsEmptySelection: allowsEmptySelection,
                        emptyTitle: emptyTitle,
                        presentationStyle: presentationStyle
                    )
                )
        }
        
        return CustomPlaceholderDefinition(
            key: trimmedKey,
            title: trimmedTitle,
            description: trimmedDescription,
            inputKind: persistedInputKind,
            order: order,
            isEnabled: isEnabled,
            createdAt: mode.existingDefinition?.createdAt ?? Date(),
            updatedAt: Date()
        )
    }
    
    private func removeOption(id: String) {
        choiceOptions.removeAll { $0.id == id }
        if defaultOptionID == id {
            defaultOptionID = nil
        }
    }
    
    private static func defaultChoiceOptions() -> [ChoiceOptionDraft] {
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
    let onDelete: () -> Void
    
    private var hasError: Bool {
        titleError != nil || replacementValueError != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                numberBadge
                
                VStack(alignment: .leading, spacing: 8) {
                    validatedTextField(
                        "Название варианта",
                        text: $option.title,
                        hasError: titleError != nil
                    )
                    
                    if let titleError {
                        validationMessage(titleError, color: .red)
                    }
                    
                    validatedTextField(
                        "Значение для документа",
                        text: $option.replacementValue,
                        hasError: replacementValueError != nil
                    )
                    
                    if let replacementValueError {
                        validationMessage(replacementValueError, color: .red)
                    }
                }
                
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .help("Удалить вариант")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    hasError ? Color.red.opacity(0.35) : Color.primary.opacity(0.08),
                    lineWidth: 1
                )
        )
    }
    
    private var numberBadge: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
            
            Text("\(index + 1)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
        }
        .frame(width: 22, height: 22)
        .padding(.top, 6)
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

// MARK: - EditorSectionView

@MainActor
private struct CustomPlaceholderDocumentDataFieldPreview: View {
    let descriptor: PlaceholderDescriptor
    
    @State private var formModel: PlaceholderFormModel
    @FocusState private var focusedKey: PlaceholderKey?
    
    init(descriptor: PlaceholderDescriptor) {
        self.descriptor = descriptor
        _formModel = State(
            initialValue: PlaceholderFormModel(
                registry: SinglePlaceholderPreviewRegistry(descriptor: descriptor)
            )
        )
    }
    
    var body: some View {
        DocumentDataFieldView(
            descriptor: descriptor,
            formModel: formModel,
            errorColor: .clear,
            errorText: nil,
            focusedKey: $focusedKey
        )
        .onChange(of: descriptor.signature) { _, _ in
            formModel.syncDefinitions(
                with: SinglePlaceholderPreviewRegistry(descriptor: descriptor)
            )
        }
    }
}

private struct SinglePlaceholderPreviewRegistry: PlaceholderRegistryProtocol {
    let descriptor: PlaceholderDescriptor
    
    private static let defaultNormalizer: FieldNormalizer = { $0 }
    private static let defaultValidator: FieldValidator = { _ in nil }
    
    var allDescriptors: [PlaceholderDescriptor] { [descriptor] }
    var inputDescriptors: [PlaceholderDescriptor] { descriptor.acceptsUserInput ? [descriptor] : [] }
    var extractedDescriptors: [PlaceholderDescriptor] { inputDescriptors.filter { $0.valueSource == .extracted } }
    var manualDescriptors: [PlaceholderDescriptor] { inputDescriptors.filter { $0.valueSource == .manual } }
    var customDescriptors: [PlaceholderDescriptor] { inputDescriptors.filter(\.isUserDefined) }
    var llmSchemaKeys: [PlaceholderKey] { extractedDescriptors.map(\.key) }
    
    func descriptor(for key: PlaceholderKey) -> PlaceholderDescriptor? {
        descriptor.key == key ? descriptor : nil
    }
    
    func contains(_ key: PlaceholderKey) -> Bool {
        descriptor.key == key
    }
    
    func descriptors(in section: PlaceholderSection) -> [PlaceholderDescriptor] {
        descriptor.section == section ? [descriptor] : []
    }
    
    func normalizer(for key: PlaceholderKey) -> FieldNormalizer {
        if key == descriptor.key {
            return descriptor.normalizer
        }
        return Self.defaultNormalizer
    }
    
    func validator(for key: PlaceholderKey) -> FieldValidator {
        if key == descriptor.key {
            return descriptor.validator
        }
        return Self.defaultValidator
    }
    
    func resolve(_ key: PlaceholderKey, context: PlaceholderResolutionContext) -> String? {
        guard key == descriptor.key else { return nil }
        return context.editableValues[key] ?? context.customValues[key]
    }
    
    func resolveAll(context: PlaceholderResolutionContext) -> [PlaceholderKey: String] {
        guard let value = resolve(descriptor.key, context: context) else {
            return [:]
        }
        return [descriptor.key: value]
    }
}

private struct EditorSectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            content
        }
    }
}

// MARK: - Small UI helpers

private extension CustomPlaceholderEditorView {
    
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
            }
        }
    }
    
    func validatedTextField(
        _ prompt: String,
        text: Binding<String>,
        hasError: Bool,
        isDisabled: Bool = false
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
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.65 : 1)
    }
    
    func multilineInput(
        text: Binding<String>,
        hasError: Bool
    ) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            hasError ? Color.red.opacity(0.65) : Color.primary.opacity(0.08),
                            lineWidth: 1
                        )
                )
            
            if text.wrappedValue.isEmpty {
                Text("Кратко опишите, для чего используется это поле")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
            
            TextEditor(text: text)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
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
    
    func previewCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
    
    func tokenChip(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.10))
            )
    }
    
    func errorBanner(text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            
            Text(text)
                .font(.callout)
                .foregroundStyle(.red)
                .multilineTextAlignment(.leading)
            
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
