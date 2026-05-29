//
//  ProcessRunning.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 10.02.2026.
//

import Foundation

/// Абстракция над запуском внешнего процесса.
///
/// Нужна в первую очередь для DI и тестирования extractor'ов, которые зависят
/// от системных утилит вроде `textutil`.
protocol ProcessRunning {
    func run(executable: URL, arguments: [String], timeout: TimeInterval) throws -> ProcessOutput
}

/// Результат выполнения внешнего процесса без дополнительных интерпретаций.
struct ProcessOutput {
    let stdout: Data
    let stderr: Data
    let exitCode: Int32
}

/// Ошибки уровня process-runner, не привязанные к конкретному extractor'у.
enum ProcessRunnerError: Error {
    case nonZeroExit(code: Int32, stderr: String)
    case timeout
}

/// Стандартная реализация запуска системного процесса с таймаутом.
///
/// Этот тип intentionally ничего не знает про office/pdf extraction.
/// Он решает только одну техническую задачу: безопасно запустить бинарь,
/// дождаться завершения и вернуть stdout/stderr.
final class DefaultProcessRunner: ProcessRunning {
    init() {}
    
    func run(executable: URL, arguments: [String], timeout: TimeInterval) throws -> ProcessOutput {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        
        try process.run()
        
        let group = DispatchGroup()
        group.enter()
        process.terminationHandler = { _ in group.leave() }
        
        if group.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            throw ProcessRunnerError.timeout
        }
        
        let stdout = outPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = errPipe.fileHandleForReading.readDataToEndOfFile()
        let code = process.terminationStatus
        
        if code != 0 {
            let errText = String(data: stderr, encoding: .utf8) ?? ""
            throw ProcessRunnerError.nonZeroExit(code: code, stderr: errText)
        }
        
        return ProcessOutput(stdout: stdout, stderr: stderr, exitCode: code)
    }
}
