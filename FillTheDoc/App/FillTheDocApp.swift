//
//  FillTheDocApp.swift
//  FillTheDoc
//
//  Created by Artem Denisov on 09.02.2026.
//

import SwiftUI

/// Точка входа в macOS-приложение.
///
/// Здесь почти нет прикладной логики специально.
/// Этот файл отвечает только за старт `SwiftUI`-сцены, а вся предметная работа
/// начинается ниже по стеку:
/// - `MainView` собирает корневой экран и связывает крупные UI-блоки;
/// - `MainViewModel` координирует основной сценарий приложения;
/// - специализированные сервисы ниже занимаются extraction, LLM, validation,
///   placeholder-resolution, export и инфраструктурой.
///
/// Если вы впервые знакомитесь с проектом, после этого файла почти всегда имеет
/// смысл сразу переходить в `MainView`, а затем в `MainViewModel`.
@main
struct FillTheDocApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
