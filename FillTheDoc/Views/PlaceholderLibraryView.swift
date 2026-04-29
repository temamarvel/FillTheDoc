import SwiftUI

// MARK: - PlaceholderLibraryItem

struct PlaceholderLibraryItem: Identifiable {
    var id: PlaceholderKey { descriptor.key }
    let descriptor: PlaceholderDescriptor
    let isUsedInTemplate: Bool
    let customDefinition: CustomPlaceholderDefinition?
}

private enum PlaceholderEditorSheet: Identifiable {
    case create
    case edit(CustomPlaceholderDefinition)
    
    var id: String {
        switch self {
            case .create:
                return "create"
            case .edit(let definition):
                return "edit-\(definition.key.rawValue)"
        }
    }
}

// MARK: - PlaceholderLibraryView

/// Справочник известных плейсхолдеров приложения.
///
/// Экран решает сразу несколько задач:
/// - показывает, какие ключи приложение знает в текущем runtime registry;
/// - объясняет, какие поля извлекаются из LLM, а какие заполняются вручную;
/// - документирует choice-поля и то, что именно попадёт в DOCX;
/// - даёт UI для управления persisted custom placeholders.
struct PlaceholderLibraryView: View {
    let placeholders: [PlaceholderDescriptor]
    let customDefinitions: [CustomPlaceholderDefinition]
    let usedKeys: Set<PlaceholderKey>
    let unknownKeys: Set<PlaceholderKey>
    let onCreateCustom: (CustomPlaceholderDefinition) async throws -> Void
    let onUpdateCustom: (CustomPlaceholderDefinition) async throws -> Void
    let onDeleteCustom: (PlaceholderKey) async throws -> Void
    
    @State private var searchText: String = ""
    @State private var showOnlyUsed: Bool = false
    @State private var editorSheet: PlaceholderEditorSheet?
    @State private var errorMessage: String?
    @State private var deleteCandidate: CustomPlaceholderDefinition?
    
    private var hasTemplate: Bool { !usedKeys.isEmpty || !unknownKeys.isEmpty }
    
    private var customDefinitionsByKey: [PlaceholderKey: CustomPlaceholderDefinition] {
        Dictionary(uniqueKeysWithValues: customDefinitions.map { ($0.key, $0) })
    }
    
    private var filteredItems: [PlaceholderLibraryItem] {
        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)
        
        return placeholders
            .filter { descriptor in
                if showOnlyUsed { return usedKeys.contains(descriptor.key) }
                return true
            }
            .filter { descriptor in
                guard !query.isEmpty else { return true }
                return descriptor.title.lowercased().contains(query)
                || descriptor.key.rawValue.lowercased().contains(query)
                || descriptor.description.lowercased().contains(query)
                || (descriptor.valueSourceLabel?.lowercased().contains(query) ?? false)
                || (descriptor.inputKindLabel?.lowercased().contains(query) ?? false)
                || (descriptor.textEditorStyleLabel?.lowercased().contains(query) ?? false)
            }
            .map {
                PlaceholderLibraryItem(
                    descriptor: $0,
                    isUsedInTemplate: usedKeys.contains($0.key),
                    customDefinition: customDefinitionsByKey[$0.key]
                )
            }
    }
    
    private var groupedItems: [(PlaceholderSection, [PlaceholderLibraryItem])] {
        let order: [PlaceholderSection] = [.company, .document, .computed, .custom]
        return order.compactMap { section in
            let items = filteredItems.filter { $0.descriptor.section == section }
            guard !items.isEmpty else { return nil }
            return (section, items)
        }
    }
    
    private var existingKeys: Set<PlaceholderKey> {
        Set(placeholders.map(\.key)).union(customDefinitions.map(\.key))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Поиск по названию, ключу или описанию…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 12)
                
                Button {
                    editorSheet = .create
                } label: {
                    Label("Добавить поле", systemImage: "plus")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.bar)
            
            Divider()
            
            if hasTemplate {
                HStack {
                    Toggle("Только используемые", isOn: $showOnlyUsed)
                        .toggleStyle(.checkbox)
                        .font(.subheadline)
                    Spacer()
                    if !unknownKeys.isEmpty {
                        Label("\(unknownKeys.count) неизвестных", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor))
                Divider()
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    if !unknownKeys.isEmpty && searchText.isEmpty {
                        Section {
                            ForEach(Array(unknownKeys), id: \.self) { key in
                                UnknownPlaceholderRowView(key: key)
                                Divider().padding(.leading, 20)
                            }
                        } header: {
                            SectionHeaderView(title: "Неизвестные плейсхолдеры в шаблоне")
                                .background(Color(nsColor: .windowBackgroundColor))
                        }
                    }
                    
                    ForEach(groupedItems, id: \.0) { section, items in
                        Section {
                            ForEach(items) { item in
                                PlaceholderLibraryRowView(
                                    item: item,
                                    onEdit: { definition in
                                        editorSheet = .edit(definition)
                                    },
                                    onDelete: { definition in
                                        deleteCandidate = definition
                                    }
                                )
                                Divider().padding(.leading, 20)
                            }
                        } header: {
                            SectionHeaderView(title: section.title)
                                .background(Color(nsColor: .windowBackgroundColor))
                        }
                    }
                    
                    if groupedItems.isEmpty && unknownKeys.isEmpty {
                        Text("Ничего не найдено")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    }
                }
            }
        }
        .frame(minWidth: 640, minHeight: 520)
        .sheet(item: $editorSheet) { sheet in
            switch sheet {
                case .create:
                    CustomPlaceholderEditorView(
                        mode: .create,
                        existingKeys: existingKeys,
                        onSave: onCreateCustom
                    )
                case .edit(let definition):
                    CustomPlaceholderEditorView(
                        mode: .edit(definition),
                        existingKeys: existingKeys,
                        onSave: onUpdateCustom
                    )
            }
        }
        .alert(
            "Ошибка",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) {}
            },
            message: {
                Text(errorMessage ?? "")
            }
        )
        .confirmationDialog(
            "Удалить пользовательский плейсхолдер?",
            isPresented: Binding(
                get: { deleteCandidate != nil },
                set: { if !$0 { deleteCandidate = nil } }
            ),
            titleVisibility: .visible,
            presenting: deleteCandidate
        ) { definition in
            Button("Удалить", role: .destructive) {
                Task {
                    do {
                        try await onDeleteCustom(definition.key)
                        await MainActor.run {
                            deleteCandidate = nil
                        }
                    } catch {
                        await MainActor.run {
                            errorMessage = error.localizedDescription
                            deleteCandidate = nil
                        }
                    }
                }
            }
            Button("Отмена", role: .cancel) {
                deleteCandidate = nil
            }
        } message: { definition in
            Text("Плейсхолдер <!\(definition.key.rawValue)!> будет удалён из runtime registry и из JSON-хранилища.")
        }
    }
}

// MARK: - SectionHeaderView

private struct SectionHeaderView: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - PlaceholderLibraryRowView

struct PlaceholderLibraryRowView: View {
    let item: PlaceholderLibraryItem
    let onEdit: (CustomPlaceholderDefinition) -> Void
    let onDelete: (CustomPlaceholderDefinition) -> Void
    
    @State private var copied = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(item.descriptor.title)
                        .font(.subheadline.weight(.medium))
                    
                    if let sourceLabel = item.descriptor.valueSourceLabel {
                        MetadataBadgeView(text: sourceLabel, color: .blue)
                    } else {
                        MetadataBadgeView(text: "Вычисляется", color: .purple)
                    }
                    
                    if let inputKindLabel = item.descriptor.inputKindLabel {
                        MetadataBadgeView(text: inputKindLabel, color: .teal)
                    }
                    
                    if let textEditorStyleLabel = item.descriptor.textEditorStyleLabel {
                        MetadataBadgeView(text: textEditorStyleLabel, color: .mint)
                    }
                    
                    if item.descriptor.isUserDefined {
                        MetadataBadgeView(text: "Пользовательский", color: .green)
                    }
                    
                    if item.isUsedInTemplate {
                        UsedBadgeView()
                    }
                }
                
                Text(item.descriptor.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack(spacing: 8) {
                    Text(item.descriptor.token)
                        .font(.caption.monospaced())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    if let example = item.descriptor.exampleValue {
                        Text("Пример: \(example)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if case .some(.choice(let configuration)) = item.descriptor.inputKind {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Варианты выбора")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        ForEach(configuration.options) { option in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("• \(option.title) → \(option.replacementValue)")
                                    .font(.caption)
                                if let description = option.description, !description.isEmpty {
                                    Text(description)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let defaultOptionID = configuration.defaultOptionID,
                           let option = configuration.options.first(where: { $0.id == defaultOptionID }) {
                            Text("Default: \(option.title)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if let definition = item.customDefinition {
                    Button {
                        onEdit(definition)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    .help("Редактировать")
                    
                    Button(role: .destructive) {
                        onDelete(definition)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    .help("Удалить")
                }
                
                Button {
                    copyToken()
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .frame(width: 20, height: 20)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.borderless)
                .help("Скопировать токен")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private func copyToken() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.descriptor.token, forType: .string)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copied = false }
        }
    }
}

// MARK: - UnknownPlaceholderRowView

private struct UnknownPlaceholderRowView: View {
    let key: PlaceholderKey
    
    @State private var copied = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(key.token)
                    .font(.subheadline.monospaced().weight(.medium))
                Text("Ключ не распознан приложением. Значение не будет подставлено автоматически.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(key.token, forType: .string)
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { copied = false }
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .frame(width: 20, height: 20)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// MARK: - Badges

private struct MetadataBadgeView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

private struct UsedBadgeView: View {
    var body: some View {
        Text("В шаблоне")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.12))
            .foregroundStyle(.green)
            .clipShape(Capsule())
    }
}

// MARK: - PlaceholderKey token helper

private extension PlaceholderKey {
    var token: String { "<!\(rawValue)!>" }
}
