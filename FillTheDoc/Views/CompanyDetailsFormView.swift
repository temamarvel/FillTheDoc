//
//  ExtractedDTOFormView.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 21.02.2026.
//

import SwiftUI
import DaDataAPIClient

import SwiftUI
import DaDataAPIClient

struct CompanyDetailsFormView: View {
    
    typealias Key = CompanyDetails.CodingKeys
    
    @StateObject private var model: CompanyDetailsModel
    let onApply: (CompanyDetails) -> Void
    
    @State private var showErrorAlert = false
    @State private var errorText = ""
    
    // типизированный фокус
    @FocusState private var focusedKey: Key?
    
    init(
        companyDetails: CompanyDetails,
        metadata: [Key: FieldMetadata],
        onApply: @escaping (CompanyDetails) -> Void
    ) {
        let token = Bundle.main.infoDictionary?["DADATA_TOKEN"] as? String ?? "N_T"
        let client = DaDataClient(configuration: .init(token: token))
        let validator = CompanyDetailsValidator(dadataClient: client)
        
        _model = StateObject(
            wrappedValue: CompanyDetailsModel(
                companyDetails: companyDetails,
                metadata: metadata,
                validator: validator,
                dadata: client
            )
        )
        self.onApply = onApply
    }
    
    var columns: [GridItem] = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        Form {
            ForEach(model.keysInOrder(), id: \.self) { key in
                if let state = model.fields[key] {
                    fieldRow(key: key, state: state)
                }
            }
            
            HStack {
                Spacer()
                Button("Применить") {
                    do {
                        let dto = try model.buildResult()
                        onApply(dto)
                    } catch {
                        errorText = error.localizedDescription
                        showErrorAlert = true
                    }
                }
                .disabled(model.hasErrors)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 8)
        }
        .formStyle(.grouped)
        .onChange(of: focusedKey) { old, new in
            guard let lost = old, lost != new else { return }
            Task { await model.validateFieldsWithReference() }
        }
        .alert("Ошибка", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorText)
        }
        .animation(.easeInOut(duration: 0.15), value: model.fields)
    }
    
    @ViewBuilder
    private func fieldRow(key: CompanyDetailsModel.Key, state: FieldState) -> some View {
        //VStack(alignment: .leading, spacing: 6) {
        VStack() {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(model.title(for: key))
                    .frame(width: 160, alignment: .leading)
                
                TextField(model.placeholder(for: key), text: binding(for: key), prompt: Text(model.placeholder(for: key)))
                    .focused($focusedKey, equals: key)
                    .background(.red.opacity(0.3))
            }
            
            
            if let message = model.message(for: key)?.text {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
                    
        }
        //.padding(.vertical, 4)
        //.padding(.vertical, 4)
    }
    
    // MARK: - Binding
    
    private func binding(for key: Key) -> Binding<String> {
        Binding(
            get: { model.value(for: key) },
            set: { model.setValue($0, for: key) } // local внутри
        )
    }
    
    // MARK: - Styles
    
    private func borderColor(for message: CompanyDetailsValidator.FieldMessage?) -> Color {
        guard let message, let severity = message.severity else {
            return .clear
        }
        
        switch severity {
            case .error:
                return .red.opacity(0.85)
            case .warning:
                return .orange.opacity(0.75)
        }
    }
    
    private func borderWidth(for message: CompanyDetailsValidator.FieldMessage?) -> CGFloat {
        guard let message else {
            return 0
        }
        
        return message.severity == nil ? 0 : 1
    }
    
    private func messageColor(for message: CompanyDetailsValidator.FieldMessage?) -> Color {
        guard let message, let severity = message.severity else {
            return .clear
        }
        
        switch severity {
            case .error: return .red
            case .warning: return .orange
        }
    }
}

#Preview("Interactive") {
    PreviewWrapper()
}

private struct PreviewWrapper: View {
    @State private var requisites = CompanyDetails(
        companyName: "ООО «Ромашка»",
        legalForm: "ООО",
        ceoFullName: "Иванов Иван Иванович",
        ceoShortenName: "Иванов И.И.",
        ogrn: "1234567890123",
        inn: "7701234567",
        kpp: "770101001",
        email: "info@romashka.ru"
    )
    
    var body: some View {
        CompanyDetailsFormView(
            companyDetails: requisites,
            metadata: CompanyDetails.fieldMetadata
        ) { updated in
            requisites = updated
        }
        .frame(width: 600, height: 700)
        .padding()
    }
}
