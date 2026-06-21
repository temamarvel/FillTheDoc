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
    @State private var viewModel: DocumentDataFormViewModel
    @State private var referenceValidationCoordinator: CompanyValidationService
    
    @FocusState private var focusedKey: PlaceholderKey?
    
    private let descriptors: [PlaceholderDescriptor]
    private let initialValues: [PlaceholderKey: String]
    private let placeholderRegistry: PlaceholderRegistryProtocol
    
    private let onApprove: ([PlaceholderKey: String]) -> Void
    private let onChange: () -> Void
    
    init(
        descriptors: [PlaceholderDescriptor],
        initialValues: [PlaceholderKey: String],
        placeholderRegistry: PlaceholderRegistryProtocol,
        companyValidator: CompanyReferenceValidator = CompanyReferenceValidator(),
        onApprove: @escaping ([PlaceholderKey: String]) -> Void,
        onChange: @escaping () -> Void
    ) {
        self.descriptors = descriptors
        self.initialValues = initialValues
        self.placeholderRegistry = placeholderRegistry
        self.onApprove = onApprove
        self.onChange = onChange
        _viewModel = State(
            initialValue: DocumentDataFormViewModel(
                descriptors: descriptors,
                extractedDescriptorValues: initialValues,
                placeholderRegistry: placeholderRegistry
            )
        )
        _referenceValidationCoordinator = State(
            initialValue: CompanyValidationService(validator: companyValidator)
        )
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
                Button("Заменить на данные из ФНС") {
                    replaceWithReferenceValues()
                }
                Spacer()
                Button("Применить") {
                    onApprove(viewModel.makeApprovedValues())
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
        .onChange(of: descriptorsSyncToken) { _, _ in
            viewModel.syncDescriptors(
                descriptors: descriptors,
                extractedValues: initialValues,
                placeholderRegistry: placeholderRegistry
            )
        }
        .onDisappear {
            referenceValidationCoordinator.cancel()
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
    
    var descriptorsSyncToken: String {
        descriptors.map(\.signature).joined(separator: "||")
    }
    
    func companyValuesForReferenceValidation() -> [PlaceholderKey: String] {
        viewModel.makeApprovedValues(in: .company)
    }
    
    // MARK: - Reference validation scheduling
    
    private func scheduleReferenceValidation() {
        referenceValidationCoordinator.scheduleValidation(
            valuesProvider: { companyValuesForReferenceValidation() },
            applyIssues: { viewModel.applyExternalIssues($0) }
        )
    }
    
    private func runReferenceValidation() {
        referenceValidationCoordinator.runValidationNow(
            valuesProvider: { companyValuesForReferenceValidation() },
            applyIssues: { viewModel.applyExternalIssues($0) }
        )
    }
    
    private func replaceWithReferenceValues() {
        referenceValidationCoordinator.runReplacementNow(
            valuesProvider: { companyValuesForReferenceValidation() },
            applyResult: { issues, referenceValues in
                let replacedKeys = viewModel.applyReferenceValues(referenceValues)
                let filteredIssues = issues.filter { !replacedKeys.contains($0.key) }
                viewModel.applyExternalIssues(filteredIssues)
                
                if !replacedKeys.isEmpty {
                    onChange()
                }
            }
        )
    }
}
