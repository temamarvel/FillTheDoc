//
//  ExtractedDTOFormView.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 21.02.2026.
//

import SwiftUI

/// Экран ручного подтверждения и редактирования placeholder-данных.
///
/// Это ключевая UX-граница проекта и самое важное место для понимания философии приложения:
/// - LLM предлагает только черновик `CompanyDetails`;
/// - пользователь остаётся финальным владельцем данных;
/// - только после нажатия «Применить» значения считаются подтверждёнными
///   и могут попасть в шаблон/экспорт.
///
/// Иначе говоря, здесь проект делает переход от "AI suggestion" к
/// "approved business data".
struct DocumentDataFormView: View {
    @State private var formModel: PlaceholderFormModel
    private let registry: PlaceholderRegistryProtocol
    private let companyValidator: CompanyDetailsValidator
    
    @State private var errorText = ""
    @State private var validationTask: Task<Void, Never>?
    /// Последний ключ lookup'а нужен, чтобы не дёргать справочную сверку повторно
    /// для тех же самых реквизитов без фактического изменения идентификатора компании.
    @State private var lastLookupKey: String?
    
    @FocusState private var focusedKey: PlaceholderKey?
    
    let onApply: ([PlaceholderKey: String], CompanyDetails) -> Void
    
    private var extractedValuesSnapshot: [PlaceholderKey: String] {
        CompanyDetailsAssembler.initialValues(from: companyDetails)
    }
    
    private var registrySignature: [String] {
        registry.inputDescriptors.map(\.signature)
    }
    
    init(
        companyDetails: CompanyDetails,
        registry: PlaceholderRegistryProtocol,
        onApply: @escaping ([PlaceholderKey: String], CompanyDetails) -> Void
    ) {
        self.companyDetails = companyDetails
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
    
    private let companyDetails: CompanyDetails
    
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
                    // На этом шаге строим уже не только DTO компании, но и полный placeholder-map,
                    // включая derived/system значения, чтобы дальнейший export pipeline
                    // больше не зависел от промежуточного состояния формы.
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
        .onChange(of: registrySignature) { _, _ in
            formModel.syncDefinitions(with: registry, extractedValues: extractedValuesSnapshot)
        }
        .onChange(of: extractedValuesSnapshot) { _, newValue in
            formModel.applyExtractedValues(newValue)
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
                    descriptor: descriptor,
                    formModel: formModel,
                    errorColor: color,
                    errorText: issue?.text,
                    focusedKey: $focusedKey
                )
            }
        }
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
        // Это снижает шум в UI и лишние сетевые запросы во время обычного ввода.
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
        // Ручной запуск нужен как явное действие пользователя на случай,
        // если авто-проверка не сработала или хочется повторно свериться после серии правок.
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
//    @State private var isApplied = false
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
//        ) { _, _ in
//            isApplied = true
//        }
//        .frame(width: 600, height: 700)
//        .padding()
//    }
//}
