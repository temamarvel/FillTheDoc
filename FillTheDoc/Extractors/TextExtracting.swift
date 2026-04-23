//
//  TextExtracting.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 10.02.2026.
//


import Foundation

/// Низкоуровневый адаптер извлечения текста из одного конкретного формата/механизма.
///
/// Контракт максимально простой: на вход даётся локальный URL временной копии файла,
/// на выходе — `RawExtractionOutput` без knowledge о UI, sandbox и диагностике верхнего уровня.
protocol TextExtracting {
    func extract(from url: URL) throws -> RawExtractionOutput
}
