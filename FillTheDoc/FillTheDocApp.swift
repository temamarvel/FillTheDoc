//
//  FillTheDocApp.swift
//  FillTheDoc
//
//  Created by Artem Denisov on 09.02.2026.
//

import SwiftUI

/// Точка входа в macOS-приложение.
///
/// Вся реальная orchestration-логика находится ниже по стеку:
/// - `MainView` описывает верхнеуровневый экран и привязки UI,
/// - `MainViewModel` координирует извлечение текста, вызов LLM,
///   подтверждение данных пользователем и экспорт итогового DOCX.
@main
struct FillTheDocApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()                
        }
    }
}
