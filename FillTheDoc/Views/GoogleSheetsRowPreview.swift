import SwiftUI

struct GoogleSheetsRowPreview: View {
    let fields: [GoogleSheetsField]
    let status: String?
    let onCopy: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Строка для Google Sheets")
                .font(.title3.weight(.semibold))
            
            VStack(spacing: 0) {
                ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        Text(field.title)
                            .foregroundStyle(.secondary)
                            .frame(width: 180, alignment: .leading)
                        
                        Text(field.value.isEmpty ? "—" : field.value)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(index.isMultiple(of: 2) ? Color.white.opacity(0.02) : Color.clear)
                    
                    if index < fields.count - 1 {
                        Divider()
                            .opacity(0.35)
                    }
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            }
            
            HStack(spacing: 12) {
                Button("Скопировать еще раз") {
                    onCopy()
                }
                
                if let status {
                    Text(status)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
