import SwiftUI

// MARK: - PlaceholderLibraryItem

struct PlaceholderLibraryItem: Identifiable {
    var id: PlaceholderKey { descriptor.key }
    let descriptor: PlaceholderDescriptor
    let isUsedInTemplate: Bool
}

// MARK: - PlaceholderLibraryView

struct PlaceholderLibraryView: View {
    let placeholders: [PlaceholderDescriptor]
    let usedKeys: Set<PlaceholderKey>
    let unknownKeys: Set<PlaceholderKey>
    
    @State private var searchText: String = ""
    @State private var showOnlyUsed: Bool = false
    
    private var hasTemplate: Bool { !usedKeys.isEmpty || !unknownKeys.isEmpty }
    
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
            }
            .map { PlaceholderLibraryItem(descriptor: $0, isUsedInTemplate: usedKeys.contains($0.key)) }
    }
    
    private var groupedItems: [(PlaceholderSection, [PlaceholderLibraryItem])] {
        let order: [PlaceholderSection] = [.company, .document, .computed, .custom]
        return order.compactMap { section in
            let items = filteredItems.filter { $0.descriptor.section == section }
            guard !items.isEmpty else { return nil }
            return (section, items)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
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
                    // Unknown keys section
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
                    
                    // Known placeholders grouped by section
                    ForEach(groupedItems, id: \.0) { section, items in
                        Section {
                            ForEach(items) { item in
                                PlaceholderLibraryRowView(item: item)
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
        .frame(minWidth: 560, minHeight: 500)
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
    
    @State private var copied = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.descriptor.title)
                        .font(.subheadline.weight(.medium))
                    
                    KindBadgeView(kind: item.descriptor.kind)
                    
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
            }
            
            Spacer()
            
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

private struct KindBadgeView: View {
    let kind: PlaceholderKind
    
    var color: Color {
        switch kind {
            case .editable: return .blue
            case .derived: return .purple
            case .custom: return .green
        }
    }
    
    var body: some View {
        Text(kind.label)
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
