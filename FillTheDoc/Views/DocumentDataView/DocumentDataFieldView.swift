//
//  DocumentDataRowView.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 24.03.2026.
//

import SwiftUI

struct DocumentDataFieldView: View {
    let descriptor: PlaceholderDescriptor
    let formModel: PlaceholderFormModel
    let errorColor: Color
    let errorText: String?
    @FocusState.Binding var focusedKey: PlaceholderKey?
    
    var body: some View {
        switch descriptor.inputKind {
            case .some(.text):
                textFieldRow(multiline: false)
            case .some(.multilineText):
                textFieldRow(multiline: true)
            case .some(.choice(let configuration)):
                choiceFieldRow(configuration: configuration)
            case .none:
                EmptyView()
        }
    }
    
    @ViewBuilder
    private func textFieldRow(multiline: Bool) -> some View {
        HStack(alignment: multiline ? .top : .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(descriptor.title)
            }
            
            VStack(alignment: .trailing, spacing: 4) {
                //TODO: fix multiline layout
                if multiline {
                    TextField(
                        "",
                        text: Binding(
                            get: { formModel.value(for: descriptor.key) },
                            set: { formModel.setValue($0, for: descriptor.key) }
                        ),
                        prompt: Text(descriptor.placeholder),
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .focused($focusedKey, equals: descriptor.key)
                } else {
                    TextField(
                        "",
                        text: Binding(
                            get: { formModel.value(for: descriptor.key) },
                            set: { formModel.setValue($0, for: descriptor.key) }
                        ),
                        prompt: Text(descriptor.placeholder),
                        axis: .horizontal
                    )
                    .focused($focusedKey, equals: descriptor.key)
                }
                
                validationText
            }
            .background(validationBackground)
        }
    }
    
    @ViewBuilder
    private func choiceFieldRow(configuration: ChoiceInputConfiguration) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(descriptor.title)
                
            }
            
            HStack{
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    switch configuration.presentationStyle {
                        case .menu:
                            Picker(
                                "",
                                selection: Binding<String?>(
                                    get: { formModel.choiceSelection(for: descriptor.key) },
                                    set: { formModel.setChoiceSelection($0, for: descriptor.key) }
                                )
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
                                Picker("", selection: Binding<String?>(
                                    get: { formModel.choiceSelection(for: descriptor.key) },
                                    set: { formModel.setChoiceSelection($0, for: descriptor.key) }
                                )) {
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
                                Picker("", selection: Binding<String>(
                                    get: {
                                        formModel.choiceSelection(for: descriptor.key)
                                        ?? configuration.defaultOptionID
                                        ?? configuration.options.first?.id
                                        ?? ""
                                    },
                                    set: { formModel.setChoiceSelection($0, for: descriptor.key) }
                                )) {
                                    ForEach(configuration.options) { option in
                                        Text(option.title).tag(option.id)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                            }
                    }
                    
                    validationText
                }
            }
            .background(validationBackground)
        }
    }
    
    @ViewBuilder
    private var validationText: some View {
        if let errorText {
            Text(errorText)
                .font(.caption)
                .foregroundStyle(errorColor)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
    
    @ViewBuilder
    private var validationBackground: some View {
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
        }
    }
}


#Preview("Текстовое поле с ошибкой") {
    DocumentDataFieldPreviewContainer(key: .fee)
        .frame(width: 560)
}

#Preview("Многострочное поле") {
    DocumentDataFieldPreviewContainer(
        key: .address,
        initialValues: [
            .address: "г. Москва, ул. Ленина, д. 1, офис 25"
        ]
    )
    .frame(width: 560)
}

#Preview("Поле выбора") {
    DocumentDataFieldPreviewContainer(key: .paymentMethod) { formModel in
        formModel.setChoiceSelection("invoice", for: .paymentMethod)
    }
    .frame(width: 560)
}

@MainActor
private struct DocumentDataFieldPreviewContainer: View {
    private let descriptor: PlaceholderDescriptor
    @State private var formModel: PlaceholderFormModel
    @FocusState private var focusedKey: PlaceholderKey?
    
    init(
        key: PlaceholderKey,
        initialValues: [PlaceholderKey: String] = [:],
        configure: (PlaceholderFormModel) -> Void = { _ in }
    ) {
        let registry = DefaultPlaceholderRegistry()
        guard let descriptor = registry.descriptor(for: key) else {
            preconditionFailure("Не найден descriptor для preview key: \(key.rawValue)")
        }
        
        self.descriptor = descriptor
        let model = PlaceholderFormModel(registry: registry, initialValues: initialValues)
        configure(model)
        _formModel = State(initialValue: model)
    }
    
    var body: some View {
        Form {
            DocumentDataFieldView(
                descriptor: descriptor,
                formModel: formModel,
                errorColor: issueColor,
                errorText: issue?.text,
                focusedKey: $focusedKey
            )
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var issue: FieldIssue? {
        formModel.issue(for: descriptor.key)
    }
    
    private var issueColor: Color {
        guard let issue else { return .clear }
        switch issue.severity {
            case .error:
                return .red
            case .warning:
                return .orange
        }
    }
}
