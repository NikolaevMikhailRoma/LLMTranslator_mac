import SwiftUI

struct TranslationBubble: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .padding(12)
            .background(.regularMaterial)     // полупрозрачная «капля» macOS 12+
            .cornerRadius(12)
            .frame(maxWidth: 320, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

