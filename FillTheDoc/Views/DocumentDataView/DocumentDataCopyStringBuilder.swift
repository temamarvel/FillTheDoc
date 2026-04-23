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
    
    func makeRow(from data: DocumentDetails) -> String {
        let values: [String] = [
            data.companyDetails?.fullCompanyName.sanitizedForTSV ?? "",   // Наименование
            data.companyDetails?.ceoFullName?.sanitizedForTSV ?? "",      // ФИО
            data.companyDetails?.inn?.sanitizedForTSV ?? "",              // ИНН
            data.companyDetails?.phone?.sanitizedForTSV ?? "",            // Телефон компании
            data.companyDetails?.email?.sanitizedForTSV ?? "",            // E-mail Компании
            data.documentNumber?.sanitizedForTSV ?? "",                        // Номер договора
            data.dateShort.sanitizedForTSV,                               // Дата договора
            "",                                                           // Расч.счет
            data.fee?.sanitizedForTSV ?? "",                              // %
            data.minFee?.sanitizedForTSV ?? "",                           // Min
            "",                                                           // Прямые выплаты
            "",                                                           // МП. Карты
            ""                                                            // МП. СБП
        ]
        
        return values.joined(separator: "\t")
    }
    
    func copyToPasteboard(_ row: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(row, forType: .string)
    }
}
