//
//  DocumentDataRowView.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.03.2026.
//

import SwiftUI

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
        switch descriptor.inputKind {
            case .some(.text):
                fieldRow(alignment: .center) {
                    textField(axis: .horizontal, multiline: false)
                }
            case .some(.multilineText):
                fieldRow(alignment: .top) {
                    textField(axis: .vertical, multiline: true)
                }
            case .some(.choice(let configuration)):
                fieldRow(alignment: .center) {
                    choiceField(configuration: configuration)
                }
            case .none:
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
    
    func textField(axis: Axis, multiline: Bool) -> some View {
        Group {
            if multiline {
                TextField(
                    "",
                    text: textBinding,
                    prompt: Text(descriptor.placeholder),
                    axis: axis
                )
                .lineLimit(1...8)
            } else {
                TextField(
                    "",
                    text: textBinding,
                    prompt: Text(descriptor.placeholder),
                    axis: axis
                )
                .lineLimit(1)
            }
        }
        .focused($focusedKey, equals: descriptor.key)
    }
    
    @ViewBuilder
    func choiceField(configuration: ChoiceInputConfiguration) -> some View {
        switch configuration.presentationStyle {
            case .menu:
                Picker(
                    "",
                    selection: optionalChoiceSelectionBinding(for: configuration)
                ) {
                    if configuration.allowsEmptySelection {
                        Text(configuration.emptyTitle)
                            .tag(String?.none)
                    }
                    ForEach(configuration.options) { option in
                        Text(option.title)
                            .tag(String?.some(option.id))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            case .segmented:
                if configuration.allowsEmptySelection || configuration.defaultOptionID == nil {
                    Picker(
                        "",
                        selection: optionalChoiceSelectionBinding(for: configuration)
                    ) {
                        Text(configuration.emptyTitle)
                            .tag(String?.none)
                        ForEach(configuration.options) { option in
                            Text(option.title)
                                .tag(String?.some(option.id))
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                } else {
                    Picker(
                        "",
                        selection: requiredChoiceSelectionBinding(for: configuration)
                    ) {
                        ForEach(configuration.options) { option in
                            Text(option.title)
                                .tag(option.id)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
        }
    }
    
    var textBinding: Binding<String> {
        Binding(
            get: {
                switch value {
                    case .text(let text):
                        return text
                    case .choice, .empty:
                        return ""
                }
            },
            set: { newValue in
                value = .text(newValue)
            }
        )
    }
    
    func optionalChoiceSelectionBinding(
        for configuration: ChoiceInputConfiguration
    ) -> Binding<String?> {
        Binding(
            get: {
                effectiveChoiceSelection(for: configuration)
            },
            set: { newValue in
                if let newValue {
                    value = .choice(optionID: newValue)
                } else {
                    value = .empty
                }
            }
        )
    }
    
    func requiredChoiceSelectionBinding(
        for configuration: ChoiceInputConfiguration
    ) -> Binding<String> {
        Binding(
            get: {
                effectiveChoiceSelection(for: configuration)
                ?? configuration.options.first?.id
                ?? ""
            },
            set: { newValue in
                value = .choice(optionID: newValue)
            }
        )
    }
    
    func effectiveChoiceSelection(
        for configuration: ChoiceInputConfiguration
    ) -> String? {
        if case .choice(let optionID) = value,
           configuration.options.contains(where: { $0.id == optionID }) {
            return optionID
        }
        if let defaultOptionID = configuration.defaultOptionID,
           configuration.options.contains(where: { $0.id == defaultOptionID }) {
            return defaultOptionID
        }
        if !configuration.allowsEmptySelection {
            return configuration.options.first?.id
        }
        return nil
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
        initialValue: .text(""),
        issue: .error("Поле обязательно для заполнения.")
    )
    .frame(width: 560)
}

#Preview("Многострочное поле") {
    DocumentDataFieldPreviewContainer(
        key: .address,
        initialValue: .text("г. Москва, ул. Ленина, д. 1, офис 25")
    )
    .frame(width: 560)
}

#Preview("Поле выбора") {
    DocumentDataFieldPreviewContainer(
        key: .paymentMethod,
        initialValue: .choice(optionID: "invoice")
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
        let registry = DefaultPlaceholderRegistry()
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
