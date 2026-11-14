import SwiftUI

enum AppLinks {
    static let privacy = URL(string: "https://github.com/panandafog/Glintwake/blob/master/AppStore/privacy-policy.md")!
    static let support = URL(string: "https://github.com/panandafog/Glintwake/blob/master/AppStore/support.md")!
}

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy.Summary".localized)
                Text("Privacy.Local".localized)
                Text("Privacy.Support".localized)
                Link("Privacy.FullPolicy".localized, destination: AppLinks.privacy).accessibilityIdentifier("privacy-policy-link")
                Link("Privacy.SupportPage".localized, destination: AppLinks.support).accessibilityIdentifier("support-link")
                Link("panandafog@icloud.com", destination: URL(string: "mailto:panandafog@icloud.com")!)
            }.padding(24)
        }
        .navigationTitle("Privacy.Title".localized)
    }
}
