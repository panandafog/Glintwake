import SwiftUI

struct AboutView: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "sparkle")
                        .font(.system(size: 40))
                        .foregroundStyle(Palette.mint)
                        .accessibilityHidden(true)
                    Text("App.Name".localized)
                        .font(.largeTitle.weight(.semibold))
                    Text("About.Description".localized)
                        .foregroundStyle(Palette.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("About.Version".localized(version, build))
                        .monospacedDigit()
                        .accessibilityIdentifier("about-version")
                        .textSelection(.enabled)
                    Text("About.Developer".localized)
                        .foregroundStyle(Palette.secondary)
                }

                VStack(alignment: .leading, spacing: 16) {
                    Link(destination: AppLinks.support) {
                        Label("About.Support".localized, systemImage: "questionmark.circle")
                    }.accessibilityIdentifier("about-support-link")
                    Link(destination: AppLinks.privacy) {
                        Label("Privacy.FullPolicy".localized, systemImage: "hand.raised")
                    }.accessibilityIdentifier("about-privacy-link")
                }
                .tint(Palette.mint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .background(Palette.background)
        .navigationTitle("About.Title".localized)
    }
}
