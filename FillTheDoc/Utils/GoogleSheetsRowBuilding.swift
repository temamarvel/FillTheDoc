import Foundation
import AppKit

struct GoogleSheetsField: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

final class GoogleSheetsRowBuilder {
    
    func makeFields(from data: DocumentData) -> [GoogleSheetsField] {
        [
            .init(title: "Наименование", value: sanitize("\(data.companyDetails?.legalForm) \(data.companyDetails?.companyName)")),
            .init(title: "ФИО", value: sanitize(data.companyDetails?.ceoFullName)),
            .init(title: "ИНН", value: sanitize(data.companyDetails?.inn)),
            .init(title: "Телефон компании", value: ""),
            .init(title: "E-mail Компании", value: sanitize(data.companyDetails?.email)),
            .init(title: "Номер договора", value: ""),
            .init(title: "Дата договора", value: ""),
            .init(title: "Расч.счет", value: ""),
            .init(title: "%", value: sanitize(data.discount)),
            .init(title: "Min", value: sanitize(data.minDiscount)),
            .init(title: "Прямые выплаты", value: ""),
            .init(title: "МП. Карты", value: ""),
            .init(title: "МП. СБП", value: "")
        ]
    }
    
    func makeRow(from data: DocumentData) -> String {
        makeFields(from: data)
            .map(\.value)
            .joined(separator: "\t")
    }
    
    func copyToPasteboard(_ row: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(row, forType: .string)
    }
    
    private func sanitize(_ value: String?) -> String {
        guard let value else { return "" }
        
        return value
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
