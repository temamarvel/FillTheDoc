//
//  ExtractedDTOFormView.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 21.02.2026.
//

import SwiftUI

/// Экран ручного подтверждения и редактирования placeholder-данных.
///
/// Это ключевая UX-граница проекта:
/// - LLM предлагает черновик `CompanyDetails`,
/// - пользователь проверяет и исправляет поля,
/// - после нажатия «Применить» приложение строит финальный словарь значений
///   для шаблона и помечает данные как подтверждённые.
struct DocumentDataFormView: View {
    @State private var formModel: PlaceholderFormModel
    private let registry: PlaceholderRegistryProtocol
    private let companyValidator: CompanyDetailsValidator
    
    @State private var errorText = ""
    @State private var validationTask: Task<Void, Never>?
    @State private var lastLookupKey: String?
    
    @FocusState private var focusedKey: PlaceholderKey?
    
    let onApply: ([PlaceholderKey: String], CompanyDetails) -> Void
    
    init(
        companyDetails: CompanyDetails,
        registry: PlaceholderRegistryProtocol,
        onApply: @escaping ([PlaceholderKey: String], CompanyDetails) -> Void
    ) {
        self.registry = registry
        let initialValues = CompanyDetailsAssembler.initialValues(from: companyDetails)
        
        _formModel = State(
            initialValue: PlaceholderFormModel(
                registry: registry,
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
                
                let customDefs = formModel.descriptors(in: .custom)
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
                        registry: registry
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
    private func sectionView(title: String, section: PlaceholderSection) -> some View {
        Section(title) {
            ForEach(formModel.descriptors(in: section)) { descriptor in
                let state = formModel.fieldStates[descriptor.key]
                let issue = state?.issue
                let color = issueColor(for: issue)
                
                DocumentDataFieldView(
                    title: descriptor.title,
                    placeholder: descriptor.placeholder,
                    text: binding(for: descriptor.key),
                    errorColor: color,
                    errorText: issue?.text,
                    focusedKey: $focusedKey,
                    key: descriptor.key
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
        // Справочная валидация не запускается на каждую клавишу:
        // она дебаунсится и работает только когда есть ИНН/ОГРН для lookup.
        let ogrn = formModel.value(for: .ogrn).trimmedNilIfEmpty
        let inn = formModel.value(for: .inn).trimmedNilIfEmpty
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
