import SwiftUI

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
            case .text: return "Текст"
            case .multilineText: return "Многострочный текст"
            case .choice: return "Выбор"
        }
    }
}

struct CustomPlaceholderEditorView: View {
    enum Mode {
        case create
        case edit(CustomPlaceholderDefinition)
        
        var title: String {
            switch self {
                case .create:
                    return "Новый пользовательский плейсхолдер"
                case .edit:
                    return "Редактирование плейсхолдера"
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
    @State private var errorText: String?
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
    
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Общее") {
                    TextField("Ключ", text: $keyText)
                        .disabled(mode.isEditing)
                    TextField("Название", text: $titleText)
                    TextField("Описание", text: $descriptionText, axis: .vertical)
                        .lineLimit(2...4)
                    Stepper("Порядок: \(order)", value: $order, in: 0...10_000)
                    Toggle("Плейсхолдер включён", isOn: $isEnabled)
                }
                
                Section("Тип поля") {
                    Picker("Тип", selection: $inputType) {
                        ForEach(CustomPlaceholderEditorInputType.allCases) { inputType in
                            Text(inputType.title).tag(inputType)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                switch inputType {
                    case .text, .multilineText:
                        Section("Настройки текста") {
                            TextField("Подсказка в поле", text: $textPlaceholder)
                            Toggle("Поле обязательно для заполнения", isOn: $textRequired)
                        }
                    case .choice:
                        choiceConfigurationSection
                }
                
                if let errorText {
                    Section {
                        Text(errorText)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            
            Divider()
            
            HStack {
                Button("Отмена") {
                    dismiss()
                }
                Spacer()
                Button(mode.isEditing ? "Сохранить" : "Создать") {
                    save()
                }
                .disabled(isSaving)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(minWidth: 620, minHeight: 560)
    }
    
    @ViewBuilder
    private var choiceConfigurationSection: some View {
        Section("Варианты выбора") {
            ForEach($choiceOptions) { $option in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Название варианта", text: $option.title)
                        Button(role: .destructive) {
                            removeOption(id: option.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    TextField("Значение для документа", text: $option.replacementValue)
                    TextField("Описание варианта", text: Binding(
                        get: { option.description ?? "" },
                        set: { option.description = $0.isEmpty ? nil : $0 }
                    ))
                }
                .padding(.vertical, 4)
            }
            
            Button {
                choiceOptions.append(.init())
            } label: {
                Label("Добавить вариант", systemImage: "plus")
            }
            
            Picker("Default-вариант", selection: Binding<String?>(
                get: { defaultOptionID },
                set: { defaultOptionID = $0 }
            )) {
                Text("Без default")
                    .tag(String?.none)
                ForEach(choiceOptions) { option in
                    Text(option.title.isEmpty ? "Без названия" : option.title)
                        .tag(String?.some(option.id))
                }
            }
            
            Toggle("Разрешить пустой выбор", isOn: $allowsEmptySelection)
            TextField("Заголовок пустого выбора", text: $emptyTitle)
            Picker("Стиль отображения", selection: $presentationStyle) {
                Text("Меню").tag(ChoicePresentationStyle.menu)
                Text("Segmented").tag(ChoicePresentationStyle.segmented)
            }
        }
    }
    
    private func save() {
        errorText = nil
        isSaving = true
        
        let definition = makeDefinition()
        let validator = CustomPlaceholderValidator()
        var validationKeys = existingKeys
        if let existingDefinition = mode.existingDefinition {
            validationKeys.remove(existingDefinition.key)
        }
        let issues = validator.validate(draft: definition, existingKeys: validationKeys)
        
        guard issues.isEmpty else {
            errorText = issues.map(\.text).joined(separator: "\n")
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
                    errorText = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
    
    private func makeDefinition() -> CustomPlaceholderDefinition {
        let trimmedKey = PlaceholderKey(rawValue: keyText.trimmed.lowercased())
        let trimmedTitle = titleText.trimmed
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
