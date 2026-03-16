//
//  FillTheDocApp.swift
//  FillTheDoc
//
//  Created by Artem Denisov on 09.02.2026.
//

import SwiftUI

@main
struct FillTheDocApp: App {
    @StateObject private var apiKeyStore = APIKeyStore()
    @StateObject private var replacer = DocxPlaceholderReplacer()
    @StateObject private var scaner = DocxTemplatePlaceholderScanner()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(apiKeyStore)
                .environmentObject(replacer)
                .environmentObject(scaner)
                .onAppear {
                    apiKeyStore.load()
                }
        }
    }
}
