//
//  DocumentData.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 18.03.2026.
//

import Foundation

/// Read-model для операций после подтверждения данных пользователем.
///
/// В отличие от `CompanyDetails`, эта структура не приходит из LLM напрямую.
/// Она собирается уже внутри приложения как компактный DTO с данными документа,
/// а placeholder-резолв выполняется отдельно через `PlaceholderRegistry`.
struct DocumentDetails: Codable, Sendable {
    let documentNumber: String?
    let fee: String?
    let minFee: String?
    let companyDetails: CompanyDetails?
}
