//
//  AppUpdateStore.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 01.04.2026.
//


import Foundation
import Observation

/// UI-facing store для проверки обновлений.
///
/// Хранит только observable state для интерфейса, а networking и сравнение версий
/// делегирует `AppUpdateService`.
///
/// Это стандартный для проекта split ответственности:
/// - service выполняет побочную работу и возвращает данные;
/// - store хранит состояние, удобное для SwiftUI.
@MainActor
@Observable
final class AppUpdateStore {
    private let service: AppUpdateService
    
    var updateInfo: AppUpdateInfo?
    var isChecking = false
    var errorText: String?
    
    init() {
        self.service = AppUpdateService(owner: "temamarvel", repo: "FillTheDoc")
    }
    
    var currentVersionText: String {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !version.isEmpty {
            return version
        }
        
        return "—"
    }
    
    var hasUpdate: Bool {
        updateInfo != nil
    }
    
    func checkForUpdates() async {
        // Ошибка проверки обновлений не должна ломать основной сценарий приложения,
        // поэтому store просто сохраняет её в `errorText` и обнуляет `updateInfo`.
        isChecking = true
        defer { isChecking = false }
        
        do {
            updateInfo = try await service.checkForUpdate()
            errorText = nil
        } catch {
            updateInfo = nil
            errorText = error.localizedDescription
        }
    }
}
