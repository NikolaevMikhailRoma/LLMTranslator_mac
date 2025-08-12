import SwiftUI

struct TranslationBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 15))
            .multilineTextAlignment(.leading)          // сохраняем выравнивание
            .textSelection(.enabled)                   // Enable mouse text selection in the popover
            .padding(12)
            .background(.regularMaterial)              // «капля» macOS
            .cornerRadius(12)
            .fixedSize(horizontal: true, vertical: true) // bubble сам рассчитывает ширину/высоту
    }
}

