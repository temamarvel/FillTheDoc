//
//  TempFileStoring.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 10.02.2026.
//

import Foundation


/// Контракт для работы с временными копиями входных файлов.
///
/// Extraction pipeline использует temp-копии, чтобы внешние инструменты вроде `textutil`
/// не зависели от sandbox URL и не держали пользовательский ресурс дольше нужного.
protocol TempFileStoring {
    func copyToTemp(_ url: URL) throws -> URL
    func cleanup(forTempCopy tempURL: URL)
}

/// Стандартная файловая реализация временного хранилища для extraction pipeline.
struct DefaultTempFileStore: TempFileStoring {
    init() {}
    
    func copyToTemp(_ url: URL) throws -> URL {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory
            .appendingPathComponent("FillTheDoc-Extract-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        
        let dst = dir.appendingPathComponent(url.lastPathComponent, isDirectory: false)
        try fm.copyItem(at: url, to: dst)
        return dst
    }
    
    func cleanup(forTempCopy tempURL: URL) {
        let parent = tempURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: parent)
    }
}
