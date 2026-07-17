import SwiftUI

struct WhatsNewView: View {
    @Environment(SettingsManager.self) private var settings
    @Binding var isPresented: Bool
    @AppStorage("lastLaunchedVersion") private var lastLaunchedVersion: Int = 0
    
    let currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    let currentBuild: Int = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.appAccent)
                    .padding(.bottom, 8)
                
                Text("What's New in Drovio")
                    .font(.system(size: 22, weight: .bold))
                
                Text("Version \(currentVersion)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 32)
            
            // Features List
            VStack(alignment: .leading, spacing: 20) {

                FeatureRow(
                    icon: "sparkles.rectangle.stack",
                    color: .purple,
                    title: "Better Updates",
                    description: "Under-the-hood improvements to the update engine for a smoother experience."
                )
                
                FeatureRow(
                    icon: "textformat",
                    color: .orange,
                    title: "Quality Options Updated",
                    description: "The quality selection labels have been simplified."
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            
            Spacer()
            
            // Continue Button
            Button {
                lastLaunchedVersion = currentBuild
                withAnimation {
                    isPresented = false
                }
            } label: {
                Text("Continue")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.appAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(width: 360, height: 480)
        .preferredColorScheme(settings.theme.colorScheme)
        .background(VisualEffectBackground(material: .popover, blendingMode: .withinWindow))
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
