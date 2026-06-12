//
//  LabeledTextField.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 11.06.2026.
//

import SwiftUI

struct LabeledTextFieldView: View {
    @Binding var text: String
    let prompt: String
    let label: String
    let error: String?
    
    private var hasError: Bool {
        guard let error else { return false }
        return !error.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.subheadline)
            
            
            VStack(alignment: .trailing) {
                TextField(prompt, text: $text)
                
                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.subheadline)
                        .padding(.trailing, 4)
                        .padding(.bottom, 2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .background(
                LinearGradient(
                    colors: [
                        .clear,
                        .red.opacity(0.1),
                        .red.opacity(0.3),
                        .clear
                    ],
                    startPoint: .bottom,
                    endPoint: .top
                )
                //.opacity(hasError ? 1 : 0)
                .cornerRadius(4)
            )
        }
        //.animation(.easeInOut(duration: 0.2), value: hasError)
    }
}

#Preview {
    Section{
        
        LabeledTextFieldView(text: .constant("Пример текста"), prompt: "prompt", label: "LAbel", error: "Error")
            .padding()
        
        
    }
    .frame(width: 300, height: 300)
}
