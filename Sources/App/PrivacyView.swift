import SwiftUI

struct PrivacyView: View {
    private let privacyURL = URL(string: "https://github.com/panandafog/Glintwake/blob/master/AppStore/privacy-policy.md")!
    private let supportURL = URL(string: "https://github.com/panandafog/Glintwake/blob/master/AppStore/support.md")!

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy.Summary".localized)
                Text("Privacy.Local".localized)
                Text("Privacy.Support".localized)
                Link("Privacy.FullPolicy".localized, destination: privacyURL).accessibilityIdentifier("privacy-policy-link")
                Link("Privacy.SupportPage".localized, destination: supportURL).accessibilityIdentifier("support-link")
                Link("panandafog@icloud.com", destination: URL(string: "mailto:panandafog@icloud.com")!)
            }.padding(24)
        }
        .navigationTitle("Privacy.Title".localized)
    }
}
