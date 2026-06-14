//
//  LabeledTextField.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 11.06.2026.
//

import SwiftUI

private struct HeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    func measureHeight(_ height: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear
                    .preference(key: HeightPreferenceKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { newValue in
            height.wrappedValue = newValue
        }
    }
}

struct LabeledContainerView<Label: View, Content: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    @State private var contentHeight: CGFloat = 0
    @State private var errorTextHeight: CGFloat = 0
    
    private let smallErrorTopPadding: CGFloat = 8
    private let largeErrorTopPadding: CGFloat = 12
    private let errorBottomPadding: CGFloat = 2
    private let smallErrorOffset: CGFloat = -6
    private let largeErrorOffset: CGFloat = -10
    
    private let labelContent: Label
    private let fieldContent: Content
    let error: String?
    
    init(
        error: String? = nil,
        @ViewBuilder label: () -> Label,
        @ViewBuilder content: () -> Content
    ) {
        self.labelContent = label()
        self.fieldContent = content()
        self.error = error
    }
    
    private var showError: Bool {
        guard isEnabled, let error, !error.isEmpty else {
            return false
        }
        
        return true
    }
    
    private var compactErrorHeight: CGFloat {
        errorTextHeight + smallErrorTopPadding + errorBottomPadding
    }
    
    private var usesLargeErrorSpacing: Bool {
        contentHeight > compactErrorHeight
    }
    
    private var errorTopPadding: CGFloat {
        usesLargeErrorSpacing ? largeErrorTopPadding : smallErrorTopPadding
    }
    
    private var errorOffset: CGFloat {
        usesLargeErrorSpacing ? largeErrorOffset : smallErrorOffset
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            labelContent
            
            VStack(spacing: 0) {
                fieldContent
                    .measureHeight($contentHeight)
                
                if showError, let error = error {
                    HStack{
                        Spacer()
                        
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.subheadline)
                            .padding(.trailing, 4)
                            .measureHeight($errorTextHeight)
                            .padding(.top, errorTopPadding)
                            .padding(.bottom, errorBottomPadding)
                    }
                    .zIndex(-1)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .background(
                        LinearGradient(
                            colors: [
                                .red.opacity(0.3),
                                .red.opacity(0.1),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .cornerRadius(4)
                        .opacity(showError ? 1 : 0)
                        .animation(.easeInOut(duration: 0.2), value: showError)
                    )
                    
                    .offset(y: errorOffset)
                }
            }
            
        }
    }
}

extension LabeledContainerView where Label == Text {
    init(
        label: String,
        error: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            error: error,
            label: {
                Text(label)
                    .font(.subheadline)
            },
            content: content
        )
    }
}

struct LabeledTextFieldView<Label: View>: View {
    @Binding var text: String
    let prompt: String
    private let labelContent: Label
    let error: String?
    let minLines: Int
    
    init(
        text: Binding<String>,
        prompt: String,
        error: String? = nil,
        minLines: Int = 1,
        @ViewBuilder label: () -> Label
    ) {
        self._text = text
        self.prompt = prompt
        self.labelContent = label()
        self.error = error
        self.minLines = minLines
    }
    
    var body: some View {
        LabeledContainerView(
            error: error,
            label: {
                labelContent
            },
            content: {
                TextField(prompt, text: $text, axis: .vertical)
                    .lineLimit(minLines...)
            }
        )
    }
}

extension LabeledTextFieldView where Label == Text {
    init(
        text: Binding<String>,
        prompt: String,
        label: String,
        error: String? = nil,
        minLines: Int = 1
    ) {
        self.init(
            text: text,
            prompt: prompt,
            error: error,
            minLines: minLines
        ) {
            Text(label)
                .font(.subheadline)
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
        
        LabeledTextFieldView(text: .constant("Пример текста Пример текста Пример текста Пример текстаПример текстаПример текстаПример текстаПример текстаПример текстаПример текстаПример текстаПример текстаПример текстаПример текстаПример текстаПример текстаПример текстаПример текстаПример текстаПример текстаПример текстаПример текста"), prompt: "prompt", label: "LAbel", error: "Error", minLines: 3)
            .padding()
        
        Spacer()
    }
    .frame(width: 300, height: 500)
}
