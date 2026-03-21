import SwiftUI

struct ThemedTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.trTextTertiary))
            .padding(12)
            .foregroundStyle(.trTextPrimary)
            .background(.trBase)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.trSurfaceBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
