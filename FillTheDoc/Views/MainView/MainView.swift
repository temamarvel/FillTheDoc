import SwiftUI
import UniformTypeIdentifiers

/// Главный экран приложения.
///
/// Этот view — композиционный корневой контейнер, а не место для business logic.
/// Его задача — собрать на одном экране все крупные этапы сценария:
/// - загрузку шаблона и файла с реквизитами;
/// - ручное подтверждение данных;
/// - запуск финального fill/export;
/// - показ служебных элементов вроде prompt'а для API key и бейджа обновлений.
///
/// Почему экран intentionally «тонкий»:
/// - бизнес-решения и порядок шагов принадлежат `MainViewModel`;
/// - специализированные view'шки ниже отвечают только за свои маленькие куски UI;
/// - благодаря этому корневой экран остаётся читаемым и не размазывает архитектуру по layout-коду.
///
/// Базовый flow для чтения кода:
/// 1. Drop зоны передают URL'ы в `MainViewModel`.
/// 2. После LLM-извлечения появляется `DocumentDataFormView`.
/// 3. После «Применить» форма отдаёт подтверждённые значения обратно в view model.
/// 4. Кнопка `Заполнить шаблон` запускает export пайплайн.
struct MainView: View {
    @State private var viewModel: MainViewModel
    @State private var showLibrary: Bool = false
    
    init() {
        //let apiKeyStore = APIKeyStore()
        let viewModel = MainViewModel()
        
        //_apiKeyStore = State(initialValue: apiKeyStore)
        _viewModel = State(initialValue: viewModel)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Заполнение документа")
                .font(.title2.weight(.semibold))
            
            HStack(spacing: 16) {
                DropZoneView(
                    title: "Шаблон (DOCX)",
                    isValid: viewModel.isTemplateValid,
                    path: viewModel.templatePath,
                    onDropURLs: { viewModel.handleTemplateDrop($0) }
                )
                
                DropZoneView(
                    title: "Реквизиты (DOC, DOCX, PDF, XLS, XLSX)",
                    isValid: viewModel.isDetailsValid,
                    path: viewModel.detailsPath,
                    onDropURLs: { viewModel.handleDetailsDrop($0) }
                )
            }
            
            Group {
                if let googleSheetsRow = viewModel.googleSheetsRow, !googleSheetsRow.isEmpty {
                    DocumentDataCopyStringPresenterView(content: googleSheetsRow)
                } else {
                    if let details = viewModel.details {
                        DocumentDataFormView(
                            companyDetails: details,
                            registry: viewModel.placeholderRegistry
                        ) { resolvedValues, company in
                            viewModel.applyFormData(resolvedValues: resolvedValues, company: company)
                        }
                    } else {
                        EmptyCompanyDetailsView()
                    }
                }
            }
            
            Divider()
            
            HStack {
                Spacer()
                
                Button {
                    Task { await viewModel.runFill() }
                } label: {
                    Text("Заполнить шаблон")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!viewModel.canRun || viewModel.isLoading)
                
                Spacer()
            }
            
            HStack{
                Spacer()
                
                Button {
                    showLibrary = true
                } label: {
                    Image(systemName: "list.bullet.rectangle")
                }
                .buttonStyle(.borderless)
                .help("Справочник плейсхолдеров")
                
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    Text("v\(version) (\(build))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                if let updateInfo = viewModel.updateStore.updateInfo {
                    AppUpdateBadgeView(updateInfo: updateInfo)
                }
            }
        }
        .task {
            await viewModel.updateStore.checkForUpdates()
        }
        .task {
            await viewModel.apiKeyStore.load()
        }
        .task {
            await viewModel.loadCustomPlaceholders()
        }
        .padding(20)
        .fileExporter(
            isPresented: $viewModel.showExporter,
            document: viewModel.exportDocument,
            contentType: UTType(filenameExtension: "docx") ?? .data,
            defaultFilename: viewModel.exportDefaultFilename
        ) { result in
            viewModel.handleExportResult(result)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.apiKeyStore.isPromptPresented },
            set: { viewModel.apiKeyStore.isPromptPresented = $0 }
        )) {
            APIKeyPromptView { enteredKey in
                Task {
                    await viewModel.apiKeyStore.save(enteredKey)
                }
            }
            .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showLibrary) {
            PlaceholderLibraryView(
                placeholders: viewModel.availablePlaceholders,
                customDefinitions: viewModel.customPlaceholderDefinitions,
                usedKeys: viewModel.templatePlaceholderKeys,
                unknownKeys: viewModel.unknownTemplatePlaceholderKeys,
                onCreateCustom: { definition in
                    try await viewModel.addCustomPlaceholder(definition)
                },
                onUpdateCustom: { definition in
                    try await viewModel.updateCustomPlaceholder(definition)
                },
                onDeleteCustom: { key in
                    try await viewModel.deleteCustomPlaceholder(key: key)
                }
            )
        }
        .overlay {
            if viewModel.isLoading {
                AIWaitingIndicatorView()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
    }
}

#Preview {
    MainView()
}
