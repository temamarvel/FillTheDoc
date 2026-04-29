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

private struct CustomPlaceholderEditorValidation {
    var titleError: String?
    var keyError: String?
    var textPlaceholderError: String?
    var choiceGeneralError: String?
    var choiceOptionErrors: [String: ChoiceOptionError] = [:]
    
    var hasErrors: Bool {
        titleError != nil
        || keyError != nil
        || textPlaceholderError != nil
        || choiceGeneralError != nil
        || choiceOptionErrors.values.contains(where: \.hasErrors)
    }
}

private struct ChoiceOptionError {
    var titleError: String?
    var replacementValueError: String?
    
    var hasErrors: Bool {
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
            "Настройте поле, которое пользователь будет заполнять вручную"
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
    @State private var inputType: CustomPlaceholderEditorInputType
    
    @State private var textPlaceholder: String
    @State private var textRequired: Bool
    
    @State private var choiceOptions: [ChoiceOptionDraft]
    @State private var defaultOptionID: String?
    
    @State private var order: Int
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
        
        _titleText = State(initialValue: definition?.title ?? "")
        _keyText = State(initialValue: definition?.key.rawValue ?? "")
        _descriptionText = State(initialValue: definition?.description ?? "")
        _order = State(initialValue: definition?.order ?? 500)
        _isEnabled = State(initialValue: definition?.isEnabled ?? true)
        
        switch definition?.inputKind {
            case .text(let configuration), .multilineText(let configuration):
                _inputType = State(initialValue: .text)
                _textPlaceholder = State(initialValue: configuration.placeholder)
                _textRequired = State(initialValue: configuration.isRequired)
                _choiceOptions = State(initialValue: Self.defaultChoiceOptions())
                _defaultOptionID = State(initialValue: nil)
                
            case .choice(let configuration):
                _inputType = State(initialValue: .choice)
                _textPlaceholder = State(initialValue: "")
                _textRequired = State(initialValue: false)
                _choiceOptions = State(initialValue: configuration.options.map(ChoiceOptionDraft.init(option:)))
                _defaultOptionID = State(initialValue: configuration.defaultOptionID)
                
            case nil:
                _inputType = State(initialValue: .text)
                _textPlaceholder = State(initialValue: "")
                _textRequired = State(initialValue: false)
                _choiceOptions = State(initialValue: Self.defaultChoiceOptions())
                _defaultOptionID = State(initialValue: nil)
        }
    }
    
    // MARK: - Derived state
    
    private var normalizedKey: String {
        keyText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
    
    private var tokenPreview: String {
        let key = normalizedKey.isEmpty ? "placeholder_key" : normalizedKey
        return "<!\(key)!>"
    }
    
    private var existingKeysForValidation: Set<PlaceholderKey> {
        var keys = existingKeys
        if let existingDefinition = mode.existingDefinition {
            keys.remove(existingDefinition.key)
        }
        return keys
    }
    
    private var validation: CustomPlaceholderEditorValidation {
        validate()
    }
    
    private var canSave: Bool {
        !isSaving && !validation.hasErrors
    }
    
    private var previewTitle: String {
        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Название поля" : title
    }
    
    private var previewTextPlaceholder: String {
        let placeholder = textPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines)
        return placeholder.isEmpty ? "Введите значение" : placeholder
    }
    
    private var previewChoiceTitle: String {
        if let defaultOptionID,
           let option = choiceOptions.first(where: { $0.id == defaultOptionID }),
           !option.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return option.title
        }
        
        if let first = choiceOptions.first,
           !first.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return first.title
        }
        
        return "Выберите значение"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    basicCard
                    settingsCard
                    previewCard
                }
                .padding(24)
            }
            
            if let saveErrorText {
                Divider()
                errorBanner(saveErrorText)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            
            Divider()
            
            footerView
        }
        .frame(minWidth: 760, minHeight: 660)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: inputType) { _, newValue in
            saveErrorText = nil
            if newValue == .choice {
                normalizeDefaultOptionID()
            } else {
                defaultOptionID = nil
            }
        }
        .onChange(of: titleText) { _, _ in saveErrorText = nil }
        .onChange(of: keyText) { _, _ in saveErrorText = nil }
        .onChange(of: textPlaceholder) { _, _ in saveErrorText = nil }
        .onChange(of: choiceOptions) { _, _ in
            saveErrorText = nil
            normalizeDefaultOptionID()
        }
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
    
    var basicCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 18) {
                    validatedField(
                        title: "Название",
                        prompt: "Например: Способ оплаты",
                        text: $titleText,
                        helper: "Отображаемое название поля.",
                        error: validation.titleError
                    )
                    
                    validatedField(
                        title: "Ключ",
                        prompt: "Например: payment_method",
                        text: $keyText,
                        helper: "Используется в DOCX как \(tokenPreview)",
                        error: validation.keyError,
                        isDisabled: mode.isEditing
                    )
                }
                
                Picker("", selection: $inputType) {
                    ForEach(CustomPlaceholderEditorInputType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                
                Text(inputType == .text
                     ? "Текстовый плейсхолдер — обычное поле ввода."
                     : "Плейсхолдер с выбором — пользователь выбирает один вариант, а в документ подставляется связанное значение.")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    var settingsCard: some View {
        switch inputType {
            case .text:
                textSettingsCard
            case .choice:
                choiceSettingsCard
        }
    }
    
    var textSettingsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                cardHeader(
                    title: "Настройки текстового поля",
                    subtitle: "Настройте подсказку и обязательность заполнения."
                )
                
                validatedField(
                    title: "Плейсхолдер",
                    prompt: "Например: Введите номер договора",
                    text: $textPlaceholder,
                    helper: "Текст-подсказка внутри поля ввода.",
                    error: validation.textPlaceholderError
                )
                
                Divider()
                
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Обязательное поле")
                            .font(.subheadline.weight(.medium))
                        
                        Text("Пользователь должен будет заполнить это поле перед применением формы.")
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
    }
    
    var choiceSettingsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                cardHeader(
                    title: "Варианты выбора",
                    subtitle: "Пользователь видит название варианта, а в документ попадает значение для подстановки."
                )
                
                if let choiceGeneralError = validation.choiceGeneralError {
                    validationMessage(choiceGeneralError, color: .red)
                }
                
                VStack(spacing: 8) {
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
                    
                    ForEach(Array(choiceOptions.enumerated()), id: \.element.id) { index, option in
                        choiceOptionRow(
                            option: option,
                            index: index
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
    
    var previewCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                cardHeader(
                    title: "Предпросмотр",
                    subtitle: "Так плейсхолдер будет выглядеть в форме и как токен в документе."
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
                        
                        VStack(alignment: .leading, spacing: 7) {
                            Text(previewTitle)
                                .font(.subheadline.weight(.medium))
                            
                            previewControl
                        }
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
    
    @ViewBuilder
    var previewControl: some View {
        switch inputType {
            case .text:
                Text(previewTextPlaceholder)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                
            case .choice:
                HStack {
                    Text(previewChoiceTitle)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
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
    }
    
    var footerView: some View {
        HStack {
            if validation.hasErrors {
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

// MARK: - Choice rows

private extension CustomPlaceholderEditorView {
    func choiceOptionRow(
        option: ChoiceOptionDraft,
        index: Int
    ) -> some View {
        let optionError = validation.choiceOptionErrors[option.id]
        
        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                compactTextField(
                    "Например: Безналичный расчёт",
                    text: bindingForChoiceOption(id: option.id).title,
                    hasError: optionError?.titleError != nil
                )
                
                if let titleError = optionError?.titleError {
                    validationMessage(titleError, color: .red)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                compactTextField(
                    "Например: beznalichnyy_raschet",
                    text: bindingForChoiceOption(id: option.id).replacementValue,
                    hasError: optionError?.replacementValueError != nil
                )
                
                if let replacementValueError = optionError?.replacementValueError {
                    validationMessage(replacementValueError, color: .red)
                }
            }
            
            Button(role: .destructive) {
                removeOption(id: option.id)
            } label: {
                Image(systemName: "trash")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .disabled(choiceOptions.count <= 2)
            .help(choiceOptions.count <= 2 ? "Минимум два варианта" : "Удалить вариант")
        }
    }
    
    func bindingForChoiceOption(id: String) -> Binding<ChoiceOptionDraft> {
        Binding(
            get: {
                choiceOptions.first(where: { $0.id == id }) ?? ChoiceOptionDraft(id: id)
            },
            set: { newValue in
                guard let index = choiceOptions.firstIndex(where: { $0.id == id }) else { return }
                choiceOptions[index] = newValue
            }
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
}

// MARK: - Save / validation

private extension CustomPlaceholderEditorView {
    func validate() -> CustomPlaceholderEditorValidation {
        var result = CustomPlaceholderEditorValidation()
        
        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = normalizedKey
        
        if title.isEmpty {
            result.titleError = "Название не может быть пустым."
        }
        
        if key.isEmpty {
            result.keyError = "Ключ не может быть пустым."
        } else if key.range(of: #"^[a-z][a-z0-9_]*$"#, options: .regularExpression) == nil {
            result.keyError = "Только латинские буквы, цифры и _. Первый символ — буква."
        } else if existingKeysForValidation.contains(PlaceholderKey(rawValue: key)) {
            result.keyError = "Плейсхолдер с таким ключом уже существует."
        }
        
        switch inputType {
            case .text:
                break
                
            case .choice:
                if choiceOptions.count < 2 {
                    result.choiceGeneralError = "Для выбора нужно минимум два варианта."
                }
                
                for option in choiceOptions {
                    var optionError = ChoiceOptionError()
                    
                    if option.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        optionError.titleError = "Введите название."
                    }
                    
                    if option.replacementValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        optionError.replacementValueError = "Введите значение."
                    }
                    
                    if optionError.hasErrors {
                        result.choiceOptionErrors[option.id] = optionError
                    }
                }
        }
        
        return result
    }
    
    func save() {
        saveErrorText = nil
        
        guard !validation.hasErrors else {
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
        let key = PlaceholderKey(rawValue: normalizedKey)
        let title = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = descriptionText.trimmedNilIfEmpty
        
        let inputKind: PersistedPlaceholderInputKind
        
        switch inputType {
            case .text:
                inputKind = .text(
                    PersistedTextInputConfiguration(
                        placeholder: textPlaceholder.trimmingCharacters(in: .whitespacesAndNewlines),
                        isRequired: textRequired
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
    
    static func defaultChoiceOptions() -> [ChoiceOptionDraft] {
        [
            ChoiceOptionDraft(title: "Вариант 1", replacementValue: "Вариант 1"),
            ChoiceOptionDraft(title: "Вариант 2", replacementValue: "Вариант 2")
        ]
    }
}

// MARK: - Small UI helpers

private extension CustomPlaceholderEditorView {
    func card<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }
    
    func cardHeader(
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
    
    func validatedField(
        title: String,
        prompt: String,
        text: Binding<String>,
        helper: String? = nil,
        error: String? = nil,
        isDisabled: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.medium))
            
            compactTextField(
                prompt,
                text: text,
                hasError: error != nil,
                isDisabled: isDisabled
            )
            
            if let error {
                validationMessage(error, color: .red)
            } else if let helper {
                Text(helper)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    func compactTextField(
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
    
    func errorBanner(_ text: String) -> some View {
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
