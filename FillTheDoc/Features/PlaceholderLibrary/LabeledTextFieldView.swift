//
//  LabeledTextField.swift
//  FillTheDoc
//
//  Created by Артем Денисов on 11.06.2026.
//

import SwiftUI

struct VerticalLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading) {
            configuration.label
            configuration.content
        }
    }
}

extension LabeledContentStyle where Self == VerticalLabeledContentStyle {
    static var vertical: VerticalLabeledContentStyle { .init() }
}

struct LabeledTextFieldView: View {
    @Binding var text: String
    @State  var label: String
    
    var body: some View {
        
        LabeledContent{
            TextField("text", text: $text)
        }label: {
            Text(label)
                .font(.subheadline)
        }.labeledContentStyle(.vertical)
        
    }
}

#Preview {
    LabeledTextFieldView(text: .constant("Пример текста"), label: "LAbel")
        .padding()
        .frame(width: 320)
}
