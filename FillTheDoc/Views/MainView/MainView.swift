import SwiftUI
import UniformTypeIdentifiers

/// Главный экран приложения.
///
/// Экран намеренно остаётся «тонким»: он не принимает бизнес-решения сам,
/// а только связывает визуальные состояния с `MainViewModel`.
/// Основной пользовательский сценарий здесь такой:
/// 1. Пользователь перетаскивает шаблон DOCX и файл с реквизитами.
/// 2. `MainViewModel` сканирует плейсхолдеры шаблона и извлекает данные из документа.
/// 3. Пользователь подтверждает/редактирует значения в форме.
/// 4. После подтверждения запускается заполнение шаблона и экспорт результата.
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
                        //                        let keys = viewModel.templatePlaceholders.compactMap {
                        //                            CompanyDetails.CodingKeys(rawValue: $0)
                        //                        }
                        
                        DocumentDataFormView(
                            companyDetails: details,
                            registry: viewModel.placeholderRegistry
                        ) { resolvedDict, company in
                            viewModel.applyFormData(resolvedDict: resolvedDict, company: company)
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
                usedKeys: viewModel.templatePlaceholderKeys,
                unknownKeys: viewModel.unknownTemplatePlaceholderKeys
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
