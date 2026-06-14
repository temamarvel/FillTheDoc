//
//  LabeledTextField.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 11.06.2026.
//

import SwiftUI

struct LabeledTextFieldView: View {
    @Environment(\.isEnabled) private var isEnabled
    
    @Binding var text: String
    let prompt: String
    let label: String
    let error: String?
    
    private var showError: Bool {
        guard isEnabled, let error, !error.isEmpty else {
            return false
        }
        
        return true
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
                .font(.subheadline)
            
            
            VStack(alignment: .trailing) {
                TextField(prompt, text: $text, axis: .vertical)
                
                if showError, let error = error {
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
                
                .cornerRadius(4)
                .opacity(showError ? 1 : 0)
                .animation(.easeInOut(duration: 0.2), value: showError)
            )
        }
    }
}

#Preview {
    VStack{
        
        LabeledTextFieldView(text: .constant("Пример текста"), prompt: "prompt", label: "LAbel", error: "Error")
            .padding()
        
        LabeledTextFieldView(text: .constant("Пример текста"), prompt: "prompt", label: "LAbel", error: "Error")
            .padding()
            .disabled(true)
        
        
    }
    .frame(width: 300, height: 300)
}
