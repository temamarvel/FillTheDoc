import SwiftUI
import UniformTypeIdentifiers

/// Generic DropZone карточка с опциональным "нижним" контентом (bottom).
/// - Поддерживает drag&drop файлов (UTType.fileURL)
/// - Показывает path (как текст) и валидность (иконка/цвет)
/// - Может "расти по контенту" (heightToContent) или быть фиксированной по высоте
struct DropZoneView: View {
    let title: String
    let subtitle: String?
    let isValid: Bool
    let path: String
    let onDropURLs: ([URL]) -> Void
    
    @State private var isTargeted: Bool = false
    
    init(
        title: String,
        subtitle: String? = nil,
        isValid: Bool,
        path: String,
        onDropURLs: @escaping ([URL]) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.isValid = isValid
        self.path = path
        self.onDropURLs = onDropURLs
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            
            dropArea
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isTargeted)
    }
    
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: isValid ? "checkmark.circle" : "circle")
                .foregroundStyle(isValid ? .green : .red)
                .imageScale(.large)
                .accessibilityLabel(isValid ? "Valid" : "Not selected")
        }
    }
    
    private var dropArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName:"doc")
                    .imageScale(.large)
                    .foregroundStyle(isValid ? .green : .red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isValid ? "Файл выбран" : "Перетащи файл сюда")
                        .font(.subheadline.weight(.semibold))
                    Text(pathPreview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                
                Spacer()
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isTargeted ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03))
            )
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted, perform: handleDrop(providers:))
    }
    
    // MARK: - Helpers
    
    private var borderColor: Color {
        if isTargeted { return .yellow.opacity(0.7) }
        if isValid { return .green.opacity(0.5) }
        return .red.opacity(0.5)
    }
    
    private var pathPreview: String {
        let trimmed = path.trimmed
        return trimmed.isEmpty ? "Путь не выбран" : trimmed
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else {
            return false
        }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            
            DispatchQueue.main.async {
                onDropURLs([url])
            }
        }
        return true
    }
}

private struct DropZoneCardPreviewContainer: View {
    @State private var emptyPath: String = ""
    @State private var validPath: String = "/Users/artem/Documents/template.docx"
    @State private var loadingPath: String = "/Users/artem/Documents/details.pdf"
    
    var body: some View {
        VStack(spacing: 24) {
            
            // 1. Пустое состояние
            DropZoneView(
                title: "Шаблон (DOCX)",
                subtitle: "Перетащи сюда файл шаблона",
                isValid: false,
                path: emptyPath,
                onDropURLs: { _ in }
            )
            
            // 2. Валидное состояние
            DropZoneView(
                title: "Реквизиты",
                subtitle: "Файл с данными клиента",
                isValid: true,
                path: validPath,
                onDropURLs: { _ in }
            )
        }
    }
}

#Preview {
    DropZoneCardPreviewContainer()
        .frame(width: 520)
        .padding()
}
