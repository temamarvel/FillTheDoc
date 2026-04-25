//
//  APIKeyStore.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 13.02.2026.
//


import Foundation
import SwiftUI

/// UI-facing store для API-ключа OpenAI.
///
/// Хранит минимум состояния, нужный интерфейсу:
/// - текущее значение ключа;
/// - необходимость показать prompt;
/// - текст ошибки для пользователя.
///
/// Важно: этот тип не хранит секрет «сам по себе» как полноценное secure storage.
/// Он управляет UI-состоянием вокруг секрета, а низкоуровневое чтение/сохранение
/// делегирует `KeychainService`.
@MainActor
@Observable
final class APIKeyStore {
    private(set) var apiKey: String?
    var isPromptPresented: Bool = false
    var errorText: String?
    
    private let keychain: KeychainService
    private let account: String
    
    init(
        keychain: KeychainService = KeychainService(),
        account: String = "openai_api_key"
    ) {
        self.keychain = keychain
        self.account = account
    }
    
    func load() async {
        // Загрузка вызывается на старте экрана, чтобы сразу понять:
        // можно ли выполнять OpenAI-сценарий или нужно запросить ключ у пользователя.
        do {
            let loaded = try await keychain.loadString(account: account)?
                .trimmed
            
            if let loaded, !loaded.isEmpty {
                apiKey = loaded
                isPromptPresented = false
                errorText = nil
            } else {
                apiKey = nil
                isPromptPresented = true
            }
        } catch {
            apiKey = nil
            errorText = "Не удалось прочитать ключ из Keychain: \(error.localizedDescription)"
            isPromptPresented = true
        }
        
    }
    
    func save(_ enteredKey: String) async {
        let trimmed = enteredKey.trimmed
        guard !trimmed.isEmpty else {
            apiKey = nil
            isPromptPresented = true
            errorText = "Ключ не может быть пустым."
            return
        }
        // После успешного сохранения этот store становится источником UI-state,
        // но canonical место хранения секрета по-прежнему Keychain.
        do {
            try await keychain.saveString(trimmed, account: account)
            apiKey = trimmed
            errorText = nil
            isPromptPresented = false
        } catch {
            apiKey = nil
            errorText = "Не удалось сохранить ключ в Keychain: \(error.localizedDescription)"
            isPromptPresented = true
        }
        
    }
    
    func clear() async {
        Task {
            do {
                try await keychain.delete(account: account)
                apiKey = nil
                errorText = nil
                isPromptPresented = true
            } catch {
                errorText = "Не удалось удалить ключ из Keychain: \(error.localizedDescription)"
            }
        }
    }
    
    /// Удобно для guard’ов в действиях.
    /// Не проверяет валидность ключа на стороне OpenAI, только факт наличия непустого значения.
    var hasKey: Bool {
        let k = apiKey?.trimmed ?? ""
        return !k.isEmpty
    }
}
