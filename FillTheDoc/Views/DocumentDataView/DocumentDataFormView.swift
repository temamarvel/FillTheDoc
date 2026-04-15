//
//  ExtractedDTOFormView.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 21.02.2026.
//

import SwiftUI
import DaDataAPIClient

struct DocumentDataFormView: View {
    
    //typealias Key = CompanyDetails.CompanyDetailsKeys
    
    @State private var companyDetailsModel: CompanyDetailsModel
    @State private var documentDetailsModel: DocumentDetailsModel
    
    @State private var errorText = ""
    @State private var fee = ""
    @State private var minFee = ""
    @State private var docNumber = ""
    
    @FocusState private var focusedKey: FormFocusKey?
    
    let onApply: (DocumentDetails) -> Void
    
    init(
        companyDetails: CompanyDetails,
        metadata: [Key: FieldMetadata],
        keys: [FormFocusKey],
        onApply: @escaping (DocumentDetails) -> Void
    ) {
        
        let validator = CompanyDetailsValidator(metadata: metadata)
        
        _companyDetailsModel = State(
            initialValue: CompanyDetailsModel(
                companyDetails: companyDetails,
                metadata: metadata,
                keys: keys,
                validator: validator
            )
        )
        
        let documentDetails = DocumentDetails(documentNumber: "", fee: "", minFee: "", companyDetails: companyDetails)
        
        _documentDetailsModel = State(
            initialValue: DocumentDetailsModel(
                documentDetails: documentDetails,
                metadata: metadata,
                keys: keys,
                validator: validator
            )
        )
        self.onApply = onApply
    }
    
//    private var docNumberError: String? {
//        docNumber.isEmpty ? "Номер договора не может быть пустым" : nil
//    }
    
//    private var feeError: String? {
//        Validators.percentage(fee)
//    }
//    
//    private var minFeeError: String? {
//        Validators.percentage(minFee)
//    }
    
    var body: some View {
        VStack{
            Form {
                Section("Документ"){
//                    DocumentDataFieldView(title: "Номер договора", placeholder: "yyyy-mm-#", text: $docNumber, errorColor: .red, errorText: docNumberError, focusedKey: $focusedKey, key: .document(.documentNumber))
                    
                    ForEach(documentDetailsModel.keysInOrder(), id: \.self) { key in
                        if let state = documentDetailsModel.fields[key] {
                            let formFocusedKey = FormFocusKey(stringValue: key.stringValue)
                            fieldRow(key: key, state: state, formFocusedKey: formFocusedKey)
                        }
                    }
                }
                
//                Section("Комиссия"){
//                    DocumentDataFieldView(title: "Комиссия, %", placeholder: "10", text: $fee, errorColor: .red, errorText: feeError, focusedKey: $focusedKey, key: .document(.fee))
//                    
//                    DocumentDataFieldView(title: "Мин. комиссия, руб", placeholder: "10", text: $minFee, errorColor: .red, errorText: minFeeError, focusedKey: $focusedKey, key: .document(.minFee))
//                }
                
                Section("Реквизиты компании") {
                    
                    ForEach(companyDetailsModel.keysInOrder(), id: \.self) { key in
                        if let state = companyDetailsModel.fields[key] {
                            let formFocusedKey = FormFocusKey(stringValue: key.stringValue)
                            fieldRow(key: key, state: state, formFocusedKey: formFocusedKey)
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
                        let result = DocumentDetails(documentNumber: docNumber, fee: fee.trimmed, minFee: minFee.trimmed, companyDetails: validatedCompanyDatails)
                        onApply(result)
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
    private func fieldRow(key: CompanyDetails.CompanyDetailsKeys, state: FieldState, formFocusedKey: FormFocusKey?) -> some View {
        let issue = state.issue
        let color = issueColor(for: issue)
        
                DocumentDataFieldView(
                    title: companyDetailsModel.title(for: key),
                    placeholder: companyDetailsModel.placeholder(for: key),
                    text: companyDetailsBinding(for: key),
                    errorColor: color,
                    errorText: issue?.text,
                    focusedKey: $focusedKey,
                    key: formFocusedKey
                )
            
        
    }
    
    @ViewBuilder
    private func fieldRow(key: DocumentDetails.DocumentDetailsKeys, state: FieldState, formFocusedKey: FormFocusKey?) -> some View {
        let issue = state.issue
        let color = issueColor(for: issue)
        
        
                DocumentDataFieldView(
                    title: documentDetailsModel.title(for: key),
                    placeholder: documentDetailsModel.placeholder(for: key),
                    text: documentDetailsBinding(for: key),
                    errorColor: color,
                    errorText: issue?.text,
                    focusedKey: $focusedKey,
                    key: formFocusedKey
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


