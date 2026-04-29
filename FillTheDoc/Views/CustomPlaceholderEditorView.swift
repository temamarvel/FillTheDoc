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
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            replacementValue: replacementValue.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description?.trimmedNilIfEmpty
        )
    }
}

private enum CustomPlaceholderValueType: String, CaseIterable, Identifiable {
    case text
    case choice
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
            case .text:
                return "Текст"
            case .choice:
                return "Выбор"
        }
    }
    
    var settingsTitle: String {
        switch self {
            case .text:
                return "Текст"
            case .choice:
                return "Выбор"
        }
    }
}

private enum CustomPlaceholderTextEditorStyle: String, CaseIterable, Identifiable {
    case singleLine
    case multiline
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
            case .singleLine:
                return "Обычное поле"
            case .multiline:
                return "Многострочное поле"
        }
    }
    
    init(runtimeStyle: TextEditorStyle) {
        switch runtimeStyle {
            case .singleLine:
                self = .singleLine
            case .multiline:
                self = .multiline
        }
    }
    
    func runtimeStyle(minLines: Int, maxLines: Int) -> TextEditorStyle {
        switch self {
            case .singleLine:
                return .singleLine
            case .multiline:
                return .multiline(minLines: minLines, maxLines: maxLines)
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
    @State private var valueType: CustomPlaceholderValueType
    @State private var textEditorStyle: CustomPlaceholderTextEditorStyle
    @State private var multilineMinLines: Int
    @State private var multilineMaxLines: Int
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
    @State private var previewFieldValue: PlaceholderFieldValue = .empty
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
        
        _keyText = State(initialValue: definition?.key.rawValue ?? "")
        _titleText = State(initialValue: definition?.title ?? "")
        _descriptionText = State(initialValue: definition?.description ?? "")
        _order = State(initialValue: definition?.order ?? 500)
        _isEnabled = State(initialValue: definition?.isEnabled ?? true)
        
        switch definition?.inputKind {
            case .text(let configuration):
                _valueType = State(initialValue: .text)
                _textEditorStyle = State(initialValue: .init(runtimeStyle: configuration.editorStyle))
                switch configuration.editorStyle {
                    case .singleLine:
                        _multilineMinLines = State(initialValue: 1)
                        _multilineMaxLines = State(initialValue: 8)
                    case .multiline(let minLines, let maxLines):
                        _multilineMinLines = State(initialValue: minLines)
                        _multilineMaxLines = State(initialValue: maxLines)
                }
                _textPlaceholder = State(initialValue: configuration.placeholder)
                _textRequired = State(initialValue: configuration.isRequired)
                _choiceOptions = State(initialValue: Self.defaultChoiceOptions())
                _defaultOptionID = State(initialValue: nil)
                _allowsEmptySelection = State(initialValue: true)
                _emptyTitle = State(initialValue: "Не выбрано")
                _presentationStyle = State(initialValue: .menu)
                
            case .choice(let configuration):
                _valueType = State(initialValue: .choice)
                _textEditorStyle = State(initialValue: .singleLine)
                _multilineMinLines = State(initialValue: 1)
                _multilineMaxLines = State(initialValue: 8)
                _textPlaceholder = State(initialValue: "")
                _textRequired = State(initialValue: false)
                _choiceOptions = State(initialValue: configuration.options.map(ChoiceOptionDraft.init(option:)))
                _defaultOptionID = State(initialValue: configuration.defaultOptionID)
                _allowsEmptySelection = State(initialValue: configuration.allowsEmptySelection)
                _emptyTitle = State(initialValue: configuration.emptyTitle)
                _presentationStyle = State(initialValue: configuration.presentationStyle)
                
            case nil:
                _valueType = State(initialValue: .text)
                _textEditorStyle = State(initialValue: .singleLine)
                _multilineMinLines = State(initialValue: 1)
                _multilineMaxLines = State(initialValue: 8)
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
        previewDescriptor.token
    }
    
    private var previewDescriptor: PlaceholderDescriptor {
        makePreviewDefinition().makeRuntimeDefinition()
    }
    
    private var valueTypeDescription: String {
        switch valueType {
            case .text:
                return "Текстовый плейсхолдер — это строковое значение. Отдельно можно выбрать обычное или многострочное поле ввода."
            case .choice:
                return "Плейсхолдер с выбором — пользователь выбирает вариант, а в документ подставляется связанное значение."
        }
    }
    
    private var previewTextPlaceholder: String {
        let trimmed = textPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Введите значение" : trimmed
    }
    
    private var previewEmptyTitle: String {
        let trimmed = emptyTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Не выбрано" : trimmed
    }
    
    var body: some View {
        editorRoot
            .frame(minWidth: 920, minHeight: 640)
            .background(Color(nsColor: .windowBackgroundColor))
            .onAppear(perform: syncPreviewFieldValue)
            .onChange(of: previewDescriptor.signature) { _, _ in
                syncPreviewFieldValue()
            }
            .onChange(of: valueType, handleValueTypeChange)
            .onChange(of: keyText, clearSaveError)
            .onChange(of: titleText, clearSaveError)
            .onChange(of: descriptionText, clearSaveError)
            .onChange(of: textEditorStyle, clearSaveError)
            .onChange(of: multilineMinLines, clearSaveError)
            .onChange(of: multilineMaxLines, clearSaveError)
            .onChange(of: textPlaceholder, clearSaveError)
            .onChange(of: textRequired, clearSaveError)
            .onChange(of: choiceOptions, handleChoiceOptionsChange)
            .onChange(of: defaultOptionID, clearSaveError)
            .onChange(of: allowsEmptySelection, clearSaveError)
            .onChange(of: emptyTitle, clearSaveError)
            .onChange(of: presentationStyle, clearSaveError)
            .onChange(of: isEnabled, clearSaveError)
    }
}

private extension CustomPlaceholderEditorView {
    var editorRoot: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            editorContent
            saveErrorSection
            Divider()
            footerView
        }
    }
    
    var editorContent: some View {
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
    var saveErrorSection: some View {
        if let saveErrorText {
            Divider()
            errorBanner(text: saveErrorText)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
        }
    }
    
    func handleValueTypeChange(
        oldValue: CustomPlaceholderValueType,
        newValue: CustomPlaceholderValueType
    ) {
        saveErrorText = nil
        if newValue == .choice {
            normalizeDefaultOptionID(for: choiceOptions)
        }
    }
    
    func handleChoiceOptionsChange(
        oldValue: [ChoiceOptionDraft],
        newValue: [ChoiceOptionDraft]
    ) {
        saveErrorText = nil
        normalizeDefaultOptionID(for: newValue)
    }
    
    func clearSaveError<T>(oldValue: T, newValue: T) {
        saveErrorText = nil
    }
    
    func normalizeDefaultOptionID(for options: [ChoiceOptionDraft]) {
        guard let defaultOptionID else { return }
        guard options.contains(where: { $0.id == defaultOptionID }) else {
            self.defaultOptionID = nil
            return
        }
    }
}

// MARK: - Header / Layout

private extension CustomPlaceholderEditorView {
    var headerView: some View {
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
    
    var leftPane: some View {
        VStack(alignment: .leading, spacing: 24) {
            EditorSectionView(title: "1. Основное") {
                basicSection
            }
            
            EditorSectionView(title: "2. Тип значения") {
                valueTypeSection
            }
            
            EditorSectionView(title: "3. Настройки (\(valueType.settingsTitle))") {
                inputSettingsSection
            }
        }
    }
    
    var basicSection: some View {
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
    
    var descriptionEditor: some View {
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
    
    var valueTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $valueType) {
                ForEach(CustomPlaceholderValueType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            
            Text(valueTypeDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    @ViewBuilder
    var inputSettingsSection: some View {
        switch valueType {
            case .text:
                textSettingsSection
            case .choice:
                choiceSettingsSection
        }
    }
    
    var textSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            labeledTextField(
                title: "Плейсхолдер",
                text: $textPlaceholder,
                prompt: textEditorStyle == .multiline
                ? "Например: Введите дополнительные условия"
                : "Например: Введите номер договора",
                helperText: "Это подсказка внутри поля ввода, а не DOCX-токен."
            )
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Вид текстового редактора")
                    .font(.subheadline.weight(.medium))
                
                Picker("", selection: $textEditorStyle) {
                    ForEach(CustomPlaceholderTextEditorStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                
                Text("Определяет только способ ввода в UI. Тип значения остаётся текстовым.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
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
    
    var choiceSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            choiceOptionsSection
            Divider()
            choiceDefaultSection
        }
    }
    
    var choiceOptionsSection: some View {
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
    
    var choiceDefaultSection: some View {
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
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Стиль выбора")
                    .font(.subheadline.weight(.medium))
                
                Picker("", selection: $presentationStyle) {
                    Text("Меню").tag(ChoicePresentationStyle.menu)
                    Text("Сегменты").tag(ChoicePresentationStyle.segmented)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
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
    
    private func removeOption(id: String) {
        choiceOptions.removeAll { $0.id == id }
        if defaultOptionID == id {
            defaultOptionID = nil
        }
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
                
                Form {
                    DocumentDataFieldView(
                        descriptor: previewDescriptor,
                        value: $previewFieldValue,
                        issue: nil,
                        focusedKey: $previewFocusedKey
                    )
                }
                .formStyle(.grouped)
            }
            
            previewHintCard
            
            Spacer()
        }
        .padding(24)
    }
    
    func makePreviewDefinition() -> CustomPlaceholderDefinition {
        let previewKey = PlaceholderKey(rawValue: normalizedKeyText.isEmpty ? "placeholder_key" : normalizedKeyText)
        let previewTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = previewTitle.isEmpty ? "Название поля" : previewTitle
        let previewDescription = descriptionText.trimmedNilIfEmpty
        let persistedInputKind: PersistedPlaceholderInputKind
        
        switch valueType {
            case .text:
                persistedInputKind = .text(
                    PersistedTextInputConfiguration(
                        placeholder: previewTextPlaceholder,
                        isRequired: textRequired,
                        editorStyle: textEditorStyle.runtimeStyle(
                            minLines: multilineMinLines,
                            maxLines: multilineMaxLines
                        )
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
    
    var previewChoiceOptions: [PlaceholderOption] {
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
    
    func syncPreviewFieldValue() {
        previewFieldValue = normalizedPreviewFieldValue(
            previewFieldValue,
            for: previewDescriptor
        )
    }
    
    func normalizedPreviewFieldValue(
        _ currentValue: PlaceholderFieldValue,
        for descriptor: PlaceholderDescriptor
    ) -> PlaceholderFieldValue {
        switch descriptor.inputKind {
            case .some(.text):
                if case .text(let text) = currentValue {
                    return .text(text)
                }
                return .text("")
            case .some(.choice(let configuration)):
                if case .choice(let optionID) = currentValue,
                   configuration.options.contains(where: { $0.id == optionID }) {
                    return .choice(optionID: optionID)
                }
                if let defaultOptionID = configuration.defaultOptionID,
                   configuration.options.contains(where: { $0.id == defaultOptionID }) {
                    return .choice(optionID: defaultOptionID)
                }
                if !configuration.allowsEmptySelection,
                   let firstOptionID = configuration.options.first?.id {
                    return .choice(optionID: firstOptionID)
                }
                return .empty
            case .none:
                return .empty
        }
    }
    
    var previewHintCard: some View {
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
}

// MARK: - Validation / Save

private extension CustomPlaceholderEditorView {
    func validateInline() -> InlineValidationState {
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
    
    func makeDefinition() -> CustomPlaceholderDefinition {
        let trimmedKey = PlaceholderKey(rawValue: normalizedKeyText)
        let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = descriptionText.trimmedNilIfEmpty
        let persistedInputKind: PersistedPlaceholderInputKind
        
        switch valueType {
            case .text:
                persistedInputKind = .text(
                    PersistedTextInputConfiguration(
                        placeholder: textPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines),
                        isRequired: textRequired,
                        editorStyle: textEditorStyle.runtimeStyle(
                            minLines: multilineMinLines,
                            maxLines: multilineMaxLines
                        )
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

private struct EditorSectionView<Content: View>: View {
    let title: String
    let content: Content
    
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
