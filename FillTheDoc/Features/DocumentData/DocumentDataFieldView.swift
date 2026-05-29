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
            case .editable(_, .text(let editorStyle)):
                fieldRow(alignment: verticalAlignment(for: editorStyle)) {
                    textInput(editorStyle: editorStyle)
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
    
    func verticalAlignment(for editorStyle: TextEditorStyle) -> VerticalAlignment {
        switch editorStyle {
            case .singleLine:
                return .center
            case .multiline:
                return .top
        }
    }
    
    @ViewBuilder
    func textInput(editorStyle: TextEditorStyle) -> some View {
        switch editorStyle {
            case .singleLine:
                TextField(
                    "",
                    text: textBinding,
                    prompt: Text(inputExampleValue),
                    axis: .horizontal
                )
                .lineLimit(1)
                .focused($focusedKey, equals: descriptor.key)
            case .multiline(let minLines, let maxLines):
                TextField(
                    "",
                    text: textBinding,
                    prompt: Text(inputExampleValue),
                    axis: .vertical
                )
                .lineLimit(minLines...max(maxLines, minLines))
                .focused($focusedKey, equals: descriptor.key)
        }
    }
    
    var inputExampleValue: String {
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
    
    var errorText: String? {
        issue?.text
    }
    
    var errorColor: Color {
        guard let issue else { return .clear }
        switch issue.severity {
            case .error:
                return .red
            case .warning:
                return .orange
        }
    }
    
    @ViewBuilder
    var validationText: some View {
        if let errorText {
            Text(errorText)
                .font(.caption)
                .foregroundStyle(errorColor)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
    
    @ViewBuilder
    var validationBackground: some View {
        if errorText != nil {
            LinearGradient(
                colors: [
                    .clear,
                    errorColor.opacity(0.10),
                    errorColor.opacity(0.22)
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

#Preview("Многострочное поле") {
    DocumentDataFieldPreviewContainer(
        key: .address,
        initialValue: .value("г. Москва, ул. Ленина, д. 1, офис 25")
    )
    .frame(width: 560)
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
