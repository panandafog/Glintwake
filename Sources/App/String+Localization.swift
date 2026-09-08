import Foundation

extension String {
    var localized: String {
        NSLocalizedString(self, comment: self)
    }

    func localized(_ arguments: CVarArg...) -> String {
        String(format: localized, locale: Locale.current, arguments: arguments)
    }
}
