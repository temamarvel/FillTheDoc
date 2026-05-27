//
//  DocumentDataFormView.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 21.02.2026.
//

import SwiftUI

/// Экран ручного подтверждения и редактирования placeholder-данных.
///
/// Это ключевая UX-граница проекта:
/// - LLM предлагает черновик placeholder values;
/// - пользователь редактирует и подтверждает данные;
/// - по нажатию «Применить» view только сообщает о готовности сохранить snapshot;
/// - вычисление итоговых значений для шаблона происходит вне UI.
struct DocumentDataFormView: View {
    let viewModel: DocumentDataFormViewModel
    private let registry: PlaceholderRegistryProtocol
    private let companyValidator: CompanyReferenceValidator
    private let extractedValues: [PlaceholderKey: String]
    
    @State private var errorText = ""
    @State private var validationTask: Task<Void, Never>?
    /// Последний ключ lookup'а нужен, чтобы не дёргать справочную сверку повторно
    /// для тех же самых реквизитов без фактического изменения идентификатора компании.
    @State private var lastLookupKey: String?
    
    @FocusState private var focusedKey: PlaceholderKey?
    
    let onApply: () -> Void
    let onChange: () -> Void
    
    private var registrySignature: [String] {
        registry.inputDescriptors.map(\.signature)
    }
    
    init(
        viewModel: DocumentDataFormViewModel,
        extractedValues: [PlaceholderKey: String],
        registry: PlaceholderRegistryProtocol,
        onApply: @escaping () -> Void,
        onChange: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.registry = registry
        self.extractedValues = extractedValues
        self.companyValidator = CompanyReferenceValidator()
        self.onApply = onApply
        self.onChange = onChange
    }
    
    var body: some View {
        VStack {
            Form {
                sectionView(title: "Документ", section: .document)
                sectionView(title: "Реквизиты компании", section: .company)
                
                let customDescriptors = viewModel.descriptors(in: .custom)
                if !customDescriptors.isEmpty {
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
                    onApply()
                }
                .disabled(viewModel.hasErrors)
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .onChange(of: focusedKey) { old, new in
            guard let _ = old, old != new else { return }
            scheduleReferenceValidation()
        }
        .onChange(of: registrySignature) { _, _ in
            viewModel.syncDefinitions(with: registry, extractedValues: extractedValues)
        }
        .animation(.easeInOut(duration: 0.15), value: viewModel.fieldStates)
    }
    
    @ViewBuilder
    private func sectionView(title: String, section: PlaceholderSection) -> some View {
        Section(title) {
            ForEach(viewModel.descriptors(in: section)) { descriptor in
                DocumentDataFieldView(
                    descriptor: descriptor,
                    value: fieldBinding(for: descriptor.key),
                    issue: viewModel.issue(for: descriptor.key),
                    focusedKey: $focusedKey
                )
            }
        }
    }
    
    private func fieldBinding(for key: PlaceholderKey) -> Binding<PlaceholderFieldValue> {
        Binding(
            get: { viewModel.fieldValue(for: key) },
            set: {
                viewModel.setFieldValue($0, for: key)
                onChange()
            }
        )
    }
    
    // MARK: - Reference validation scheduling
    
    private func scheduleReferenceValidation() {
        // Справочная валидация не запускается на каждую клавишу:
        // она дебаунсится и работает только когда есть ИНН/ОГРН для lookup.
        // Это снижает шум в UI и лишние сетевые запросы во время обычного ввода.
        let ogrn = viewModel.value(for: .ogrn).trimmedNilIfEmpty
        let inn = viewModel.value(for: .inn).trimmedNilIfEmpty
        let lookupKey = ogrn ?? inn
        guard let lookupKey, !lookupKey.isEmpty else { return }
        if lookupKey == lastLookupKey { return }
        
        validationTask?.cancel()
        validationTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(300))
                try Task.checkCancellation()
                let companyValues = viewModel.sourceValues(in: .company)
                let issues = await companyValidator.validate(values: companyValues)
                try Task.checkCancellation()
                viewModel.applyExternalIssues(issues)
                lastLookupKey = lookupKey
            } catch {}
        }
    }
    
    private func runReferenceValidation() {
        // Ручной запуск нужен как явное действие пользователя на случай,
        // если авто-проверка не сработала или хочется повторно свериться после серии правок.
        validationTask?.cancel()
        validationTask = Task {
            let companyValues = viewModel.sourceValues(in: .company)
            let issues = await companyValidator.validate(values: companyValues)
            viewModel.applyExternalIssues(issues)
        }
    }
}
