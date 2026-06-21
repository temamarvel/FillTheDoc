//
//  DocumentDataFieldView.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.03.2026.
//

import SwiftUI

/// Универсальная строка одного editable-поля в форме подтверждения данных.
///
/// View не принимает архитектурных решений о нормализации или валидации,
/// а только отображает `PlaceholderDescriptor`, текущее typed-значение и возможный issue.
struct DocumentDataFieldView: View {
    let descriptor: PlaceholderDescriptor
    let issue: FieldIssue?
    @Binding private var value: PlaceholderFieldValue
    @FocusState.Binding var focusedKey: PlaceholderKey?
    
    init(
        descriptor: PlaceholderDescriptor,
        value: Binding<PlaceholderFieldValue>,
        issue: FieldIssue? = nil,
        focusedKey: FocusState<PlaceholderKey?>.Binding
    ) {
        self.descriptor = descriptor
        self.issue = issue
        self._value = value
        self._focusedKey = focusedKey
    }
    
    var body: some View {
        switch descriptor.kind {
            case .editable(_, .text):
                fieldRow(alignment: .top) {
                    adaptiveTextInput
                }
            case .editable(_, .choice(let configuration)):
                fieldRow(alignment: .center) {
                    choiceField(configuration: configuration)
                }
            case .derived:
                EmptyView()
        }
    }
}

private extension DocumentDataFieldView {
    @ViewBuilder
    func fieldRow<Control: View>(
        alignment: VerticalAlignment,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: alignment) {
            VStack(alignment: .leading, spacing: 4) {
                Text(descriptor.title)
            }
            
            Spacer(minLength: 16)
            
            VStack(alignment: .trailing, spacing: 4) {
                control()
                validationText
            }
            .background(validationBackground)
        }
    }
    
    var adaptiveTextInput: some View {
        TextField(
            "",
            text: textBinding,
            prompt: Text(inputPrompt),
            axis: .vertical
        )
        .lineLimit(1...4)
        .focused($focusedKey, equals: descriptor.key)
    }
    
    var inputPrompt: String {
        descriptor.exampleValue ?? ""
    }
    
    @ViewBuilder
    func choiceField(configuration: ChoiceInputConfiguration) -> some View {
        Picker(
            "",
            selection: choiceSelectionBinding(configuration)
        ) {
            if configuration.allowsEmptyValue {
                Text(configuration.emptyTitle)
                    .tag("")
            }
            ForEach(configuration.options, id: \.self) { option in
                Text(option)
                    .tag(option)
            }
        }
        .labelsHidden()
        .pickerStyle(.menu)
    }
    
    var textBinding: Binding<String> {
        Binding(
            get: {
                switch value {
                    case .value(let text):
                        return text
                    case .empty:
                        return ""
                }
            },
            set: { newValue in
                if newValue.isEmpty {
                    value = .empty
                } else {
                    value = .value(newValue)
                }
            }
        )
    }
    
    func choiceSelectionBinding(
        _ configuration: ChoiceInputConfiguration
    ) -> Binding<String> {
        Binding(
            get: {
                switch configuration.normalizedFieldValue(for: value.stringValue) {
                    case .value(let selectedValue):
                        return selectedValue
                    case .empty:
                        return ""
                }
            },
            set: { newValue in
                if newValue.isEmpty {
                    value = configuration.allowsEmptyValue ? .empty : configuration.normalizedFieldValue(for: nil)
                } else {
                    value = .value(newValue)
                }
            }
        )
    }
    
    var issueText: String? {
        issue?.text
    }
    
    var issueColor: Color {
        guard let issue else { return .clear }
        switch issue.severity {
            case .info:
                return .blue
            case .error:
                return .red
            case .warning:
                return .orange
        }
    }
    
    @ViewBuilder
    var validationText: some View {
        if let issueText {
            Text(issueText)
                .font(.caption)
                .foregroundStyle(issueColor)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
    
    @ViewBuilder
    var validationBackground: some View {
        if issueText != nil {
            LinearGradient(
                colors: [
                    .clear,
                    issueColor.opacity(0.10),
                    issueColor.opacity(0.22)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .cornerRadius(2)
        }
    }
}

#Preview("Текстовое поле с ошибкой") {
    DocumentDataFieldPreviewContainer(
        key: .fee,
        initialValue: .value(""),
        issue: .error("Поле обязательно для заполнения.")
    )
    .frame(width: 560)
}

#Preview("Адаптивное поле — короткое значение") {
    DocumentDataFieldPreviewContainer(
        key: .address,
        initialValue: .value("г. Москва")
    )
    .frame(width: 420)
}

#Preview("Адаптивное поле — длинное значение") {
    DocumentDataFieldPreviewContainer(
        key: .address,
        initialValue: .value("Российская Федерация, 123112, г. Москва, Пресненская набережная, д. 12, башня Федерация, офис 508, помещение 14")
    )
    .frame(width: 420)
}

#Preview("Поле выбора") {
    DocumentDataFieldPreviewContainer(
        key: .paymentMethod,
        initialValue: .value("счет")
    )
    .frame(width: 560)
}

@MainActor
private struct DocumentDataFieldPreviewContainer: View {
    private let descriptor: PlaceholderDescriptor
    private let issue: FieldIssue?
    @State private var value: PlaceholderFieldValue
    @FocusState private var focusedKey: PlaceholderKey?
    
    init(
        key: PlaceholderKey,
        initialValue: PlaceholderFieldValue = .empty,
        issue: FieldIssue? = nil
    ) {
        let registry = PlaceholderRegistry()
        guard let descriptor = registry.descriptor(for: key) else {
            preconditionFailure("Не найден descriptor для preview key: \(key.rawValue)")
        }
        
        self.descriptor = descriptor
        self.issue = issue
        _value = State(initialValue: initialValue)
    }
    
    var body: some View {
        Form {
            DocumentDataFieldView(
                descriptor: descriptor,
                value: $value,
                issue: issue,
                focusedKey: $focusedKey
            )
        }
        .formStyle(.grouped)
        .padding()
    }
}
