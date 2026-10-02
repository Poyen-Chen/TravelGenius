import SwiftUI

/// A themed, modal confirmation. Opening or dismissing this sheet never mutates data.
struct PackmonRemovalSheet: View {
    let title: String
    let name: String
    let message: String
    let actionTitle: String
    let remove: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.packmonTheme) private var theme
    @State private var submitted = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "trash")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.colors.danger)
                    .padding(16)
                    .background(theme.colors.danger.opacity(0.1), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityHidden(true)
                Text(title).font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
                Text(name).font(.headline).fixedSize(horizontal: false, vertical: true)
                Text(message).font(.body).foregroundStyle(theme.colors.secondaryText)
                VStack(spacing: 12) {
                    Button("取消", role: .cancel) { dismiss() }
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(theme.colors.surface, in: RoundedRectangle(cornerRadius: 16))
                    Button(actionTitle, role: .destructive) {
                        guard !submitted else { return }
                        submitted = true
                        remove()
                        dismiss()
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(theme.colors.danger)
                    .background(theme.colors.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
                    .disabled(submitted)
                }.font(.headline).buttonStyle(.plain)
            }.padding(24)
        }
        .foregroundStyle(theme.colors.text)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(theme.colors.canvas)
    }
}
