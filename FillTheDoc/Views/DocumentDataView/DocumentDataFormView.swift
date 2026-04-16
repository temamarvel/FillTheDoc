//
//  ExtractedDTOFormView.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 21.02.2026.
//

import SwiftUI
import DaDataAPIClient

struct DocumentDataFormView: View {
    @State private var companyDetailsModel: CompanyDetailsModel
    @State private var documentDetailsModel: DocumentDetailsModel
    
    @State private var errorText = ""
    
    @FocusState private var focusedKey: FormFocusKey?
    
    let onApply: (DocumentDetails) -> Void
    
    init(
        companyDetails: CompanyDetails,
        metadata: DocumentMetadata,
        onApply: @escaping (DocumentDetails) -> Void
    ) {
        _companyDetailsModel = State(
            initialValue: CompanyDetailsModel(
                companyDetails: companyDetails,
                metadata: metadata.companyDetails,
                keys: CompanyDetails.CompanyDetailsKeys.allCases
            )
        )
    
        _documentDetailsModel = State(
            initialValue: DocumentDetailsModel(
                metadata: metadata.documentDetails,
                keys: DocumentDetails.DocumentDetailsKeys.allCases
            )
        )
        self.onApply = onApply
    }
    
    var body: some View {
        VStack{
            Form {
                Section("Документ"){
                    ForEach(documentDetailsModel.keysInOrder(), id: \.self) { key in
                        if let state = documentDetailsModel.fields[key] {
                            fieldRow(key: key, state: state)
                        }
                    }
                }
                
                Section("Реквизиты компании") {
                    
                    ForEach(companyDetailsModel.keysInOrder(), id: \.self) { key in
                        if let state = companyDetailsModel.fields[key] {
                            fieldRow(key: key, state: state)
                        }
                    }
                }
            }
            
            Divider()
            
            HStack {
                Button("Валидация с ФНС") {
                    Task{
                        await companyDetailsModel.validateFieldsWithReference()
                    }
                }
                Spacer()
                Button("Применить") {
                    do {
                        let validatedCompanyDatails = try companyDetailsModel.buildResult()
                        let validatedDocumentDatails = try documentDetailsModel.buildResult(companyDetails: validatedCompanyDatails)
                        
                        onApply(validatedDocumentDatails)
                    } catch {
                        errorText = error.localizedDescription
                    }
                }
                .disabled(companyDetailsModel.hasErrors || documentDetailsModel.hasErrors)
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .onChange(of: focusedKey) { old, new in
            guard let lost = old, lost != new else { return }
            companyDetailsModel.scheduleReferenceValidation()
        }
        .animation(.easeInOut(duration: 0.15), value: companyDetailsModel.fields)
        .animation(.easeInOut(duration: 0.15), value: documentDetailsModel.fields)
    }
    
    @ViewBuilder
    private func fieldRow(key: CompanyDetails.CompanyDetailsKeys, state: FieldState) -> some View {
        let issue = state.issue
        let color = issueColor(for: issue)
        
                DocumentDataFieldView(
                    title: companyDetailsModel.title(for: key),
                    placeholder: companyDetailsModel.placeholder(for: key),
                    text: companyDetailsBinding(for: key),
                    errorColor: color,
                    errorText: issue?.text,
                    focusedKey: $focusedKey,
                    key: key
                )
            
        
    }
    
    @ViewBuilder
    private func fieldRow(key: DocumentDetails.DocumentDetailsKeys, state: FieldState) -> some View {
        let issue = state.issue
        let color = issueColor(for: issue)
        
        
                DocumentDataFieldView(
                    title: documentDetailsModel.title(for: key),
                    placeholder: documentDetailsModel.placeholder(for: key),
                    text: documentDetailsBinding(for: key),
                    errorColor: color,
                    errorText: issue?.text,
                    focusedKey: $focusedKey,
                    key: key
                )
        
    }
    
    // MARK: - Binding
    
    private func companyDetailsBinding(for key: CompanyDetails.CompanyDetailsKeys) -> Binding<String> {
        Binding(
            get: { companyDetailsModel.value(for: key) },
            set: { companyDetailsModel.setValue($0, for: key) }
        )
    }
    
    private func documentDetailsBinding(for key: DocumentDetails.DocumentDetailsKeys) -> Binding<String> {
        Binding(
            get: { documentDetailsModel.value(for: key) },
            set: { documentDetailsModel.setValue($0, for: key) }
        )
    }
    
    private func issueColor(for issue: FieldIssue?) -> Color {
        guard let issue else { return .clear }
        
        switch issue.severity {
            case .error: return .red
            case .warning: return .orange
        }
    }
}

//#Preview {
//    PreviewWrapper()
//}
//
//private struct PreviewWrapper: View {
//    @State private var result: DocumentDetails? = nil
//    @State private var requisites = CompanyDetails(
//        companyName: "ООО «Ромашка»",
//        legalForm: LegalForm.parse("OOO"),
//        ceoFullName: "Иванов Иван Иванович",
//        ceoFullGenitiveName: "Иванова Ивана Ивановича",
//        ceoShortenName: "Иванов И.И.",
//        ogrn: "1234567890123",
//        inn: "7701234567",
//        kpp: "770101001",
//        email: "info@romashka.ru",
//        address: "ТЕСТ Адрес",
//        phone: "+79991234567"
//    )
//    
//    var body: some View {
//        DocumentDataFormView(
//            companyDetails: requisites,
//            metadata: CompanyDetails.fieldMetadata,
//            keys: [.company(.companyName), .company(.legalForm), .company(.ceoFullName), .company(.ceoShortenName), .company(.ogrn), .company(.inn), .company(.kpp), .company(.email)]
//        ) { updated in
//            result = updated
//        }
//        .frame(width: 600, height: 700)
//        .padding()
//    }
//}


