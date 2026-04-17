//
//  ExtractedDTOFormView.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 21.02.2026.
//

import SwiftUI

struct DocumentDataFormView: View {
    @State private var formModel: PlaceholderFormModel
    private let companyValidator: CompanyDetailsValidator
    
    @State private var errorText = ""
    @State private var validationTask: Task<Void, Never>?
    @State private var lastLookupKey: String?
    
    @FocusState private var focusedKey: PlaceholderKey?
    
    let onApply: ([String: String], CompanyDetails) -> Void
    
    init(
        companyDetails: CompanyDetails,
        onApply: @escaping ([String: String], CompanyDetails) -> Void
    ) {
        let allDefinitions = DocumentPlaceholderCatalog.editableDefinitions
        + CompanyPlaceholderCatalog.editableDefinitions
        
        let initialValues = CompanyPlaceholderCatalog.initialValues(from: companyDetails)
        
        _formModel = State(
            initialValue: PlaceholderFormModel(
                editableDefinitions: allDefinitions,
                initialValues: initialValues
            )
        )
        
        self.companyValidator = CompanyDetailsValidator()
        self.onApply = onApply
    }
    
    var body: some View {
        VStack {
            Form {
                sectionView(title: "Документ", section: .document)
                sectionView(title: "Реквизиты компании", section: .company)
                
                let customDefs = formModel.definitions(in: .custom)
                if !customDefs.isEmpty {
                    sectionView(title: "Пользовательские поля", section: .custom)
                }
            }
            
            Divider()
            
            HStack {
                Button("Валидация с ФНС") {
                    runReferenceValidation()
                }
                Spacer()
                Button("Применить") {
                    let companyValues = formModel.editableValues(in: .company)
                    let company = CompanyDetailsAssembler.makeCompanyDetails(from: companyValues)
                    let resolved = TemplatePlaceholderResolver.resolve(
                        formModel: formModel,
                        company: company
                    )
                    onApply(resolved, company)
                }
                .disabled(formModel.hasErrors)
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .onChange(of: focusedKey) { old, new in
            guard let _ = old, old != new else { return }
            scheduleReferenceValidation()
        }
        .animation(.easeInOut(duration: 0.15), value: formModel.fieldStates)
    }
    
    @ViewBuilder
    private func sectionView(title: String, section: EditablePlaceholderDefinition.Section) -> some View {
        Section(title) {
            ForEach(formModel.definitions(in: section)) { definition in
                let state = formModel.fieldStates[definition.key]
                let issue = state?.issue
                let color = issueColor(for: issue)
                
                DocumentDataFieldView(
                    title: definition.title,
                    placeholder: definition.placeholder,
                    text: binding(for: definition.key),
                    errorColor: color,
                    errorText: issue?.text,
                    focusedKey: $focusedKey,
                    key: definition.key
                )
            }
        }
    }
    
    private func binding(for key: PlaceholderKey) -> Binding<String> {
        Binding(
            get: { formModel.value(for: key) },
            set: { formModel.setValue($0, for: key) }
        )
    }
    
    private func issueColor(for issue: FieldIssue?) -> Color {
        guard let issue else { return .clear }
        switch issue.severity {
            case .error: return .red
            case .warning: return .orange
        }
    }
    
    // MARK: - Reference validation scheduling
    
    private func scheduleReferenceValidation() {
        let ogrn = formModel.value(for: "ogrn").trimmedNilIfEmpty
        let inn = formModel.value(for: "inn").trimmedNilIfEmpty
        let lookupKey = ogrn ?? inn
        guard let lookupKey, !lookupKey.isEmpty else { return }
        if lookupKey == lastLookupKey { return }
        
        validationTask?.cancel()
        validationTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(300))
                try Task.checkCancellation()
                let companyValues = formModel.editableValues(in: .company)
                let issues = await companyValidator.validateWithReference(values: companyValues)
                try Task.checkCancellation()
                formModel.applyExternalIssues(issues)
                lastLookupKey = lookupKey
            } catch {}
        }
    }
    
    private func runReferenceValidation() {
        validationTask?.cancel()
        validationTask = Task {
            let companyValues = formModel.editableValues(in: .company)
            let issues = await companyValidator.validateWithReference(values: companyValues)
            formModel.applyExternalIssues(issues)
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
