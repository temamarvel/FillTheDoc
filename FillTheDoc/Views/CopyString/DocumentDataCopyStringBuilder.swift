//
//  GoogleSheetsRowBuilding.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 19.03.2026.
//


import Foundation
import AppKit

/// Строит TSV-строку для внешнего сценария копирования в Google Sheets.
///
/// Это отдельный presentation/export helper: он не влияет на placeholder-resolution,
/// а только сериализует уже подтверждённые данные в нужный порядок колонок.
final class DocumentDataCopyStringBuilder {
    
    func makeRow(from resolvedValues: [PlaceholderKey: String]) -> String {
        let values: [String] = [
            resolvedValues.sanitizedValue(for: .fullCompanyName),   // Наименование
            resolvedValues.sanitizedValue(for: .ceoFullName),       // ФИО
            resolvedValues.sanitizedValue(for: .inn),               // ИНН
            resolvedValues.sanitizedValue(for: .phone),             // Телефон компании
            resolvedValues.sanitizedValue(for: .email),             // E-mail Компании
            resolvedValues.sanitizedValue(for: .documentNumber),    // Номер договора
            resolvedValues.sanitizedValue(for: .dateShort),         // Дата договора
            "",                                                     // Расч.счет
            resolvedValues.sanitizedValue(for: .fee),               // %
            resolvedValues.sanitizedValue(for: .minFee),            // Min
            "",                                                     // Прямые выплаты
            "",                                                     // МП. Карты
            ""                                                      // МП. СБП
        ]
        
        return values.joined(separator: "\t")
    }
    
    func copyToPasteboard(_ row: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(row, forType: .string)
    }
}

private extension Dictionary where Key == PlaceholderKey, Value == String {
    func sanitizedValue(for key: PlaceholderKey) -> String {
        (self[key] ?? "").sanitizedForCopiedString
    }
}
