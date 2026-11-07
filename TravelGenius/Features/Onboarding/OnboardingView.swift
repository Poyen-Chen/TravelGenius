import SwiftUI

/// New users choose concrete packing needs, not demographic proxies.
struct OnboardingView: View {
    var onComplete: () -> Void
    @Environment(\.packmonTheme) private var theme
    @State private var showingPreferences = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            MascotView(expression: .happy, size: 110)
            Text("先認識你的打包習慣")
                .font(.largeTitle.weight(.bold)).multilineTextAlignment(.center)
            Text("選平常會帶的東西，之後每趟都會帶上。")
                .foregroundStyle(theme.colors.secondaryText).multilineTextAlignment(.center)
            Spacer()
            Button("設定個人打包需求") { showingPreferences = true }
                .buttonStyle(PackmonPrimaryButtonStyle())
            Button("先略過") { UserPreferences.forNewTrips().save(); onComplete() }
                .frame(minHeight: 44)
        }
        .padding(24)
        .foregroundStyle(theme.colors.text)
        .background(theme.colors.canvas)
        .sheet(isPresented: $showingPreferences) {
            PreferenceSettingsView(onSaved: onComplete)
        }
    }
}
