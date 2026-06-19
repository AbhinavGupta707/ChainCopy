import Foundation

struct PasteboardInspection: Equatable {
    var types: Set<String>
    var sourceAppName: String?
    var sourceAppBundleIdentifier: String?
    var text: String?

    var textByteCount: Int {
        text?.utf8.count ?? 0
    }
}

enum ClipboardPrivacyFilterReason: Equatable {
    case ignoredPasteboardType(String)
    case ignoredSourceApp
    case emptyText
    case oversizedText(maxBytes: Int, actualBytes: Int)
    case sensitiveContentPattern
}

struct ClipboardPrivacyFilterDecision: Equatable {
    var isAllowed: Bool
    var reason: ClipboardPrivacyFilterReason?

    static let allowed = ClipboardPrivacyFilterDecision(isAllowed: true, reason: nil)

    static func blocked(_ reason: ClipboardPrivacyFilterReason) -> ClipboardPrivacyFilterDecision {
        ClipboardPrivacyFilterDecision(isAllowed: false, reason: reason)
    }
}

struct ClipboardPrivacyFilter {
    func decision(
        for inspection: PasteboardInspection,
        settings: ClipboardSettings
    ) -> ClipboardPrivacyFilterDecision {
        if let ignoredType = firstIgnoredType(in: inspection.types, settings: settings) {
            return .blocked(.ignoredPasteboardType(ignoredType))
        }

        if isIgnoredSourceApp(inspection, settings: settings) {
            return .blocked(.ignoredSourceApp)
        }

        guard let text = inspection.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return .blocked(.emptyText)
        }

        let byteCount = text.utf8.count
        if byteCount > settings.maxItemSizeBytes {
            return .blocked(.oversizedText(maxBytes: settings.maxItemSizeBytes, actualBytes: byteCount))
        }

        if matchesSensitivePattern(in: text, settings: settings) {
            return .blocked(.sensitiveContentPattern)
        }

        return .allowed
    }

    func metadataDecision(
        for inspection: PasteboardInspection,
        settings: ClipboardSettings
    ) -> ClipboardPrivacyFilterDecision {
        if let ignoredType = firstIgnoredType(in: inspection.types, settings: settings) {
            return .blocked(.ignoredPasteboardType(ignoredType))
        }

        if isIgnoredSourceApp(inspection, settings: settings) {
            return .blocked(.ignoredSourceApp)
        }

        return .allowed
    }

    private func firstIgnoredType(
        in types: Set<String>,
        settings: ClipboardSettings
    ) -> String? {
        let ignoredTypes = Set(settings.ignoredPasteboardTypes)
        return types.first { ignoredTypes.contains($0) }
    }

    private func isIgnoredSourceApp(
        _ inspection: PasteboardInspection,
        settings: ClipboardSettings
    ) -> Bool {
        if let bundleIdentifier = inspection.sourceAppBundleIdentifier?.lowercased() {
            let ignoredBundleIdentifiers = Set(settings.ignoredAppBundleIdentifiers.map { $0.lowercased() })
            if ignoredBundleIdentifiers.contains(bundleIdentifier) {
                return true
            }
        }

        guard let appName = inspection.sourceAppName?.lowercased() else {
            return false
        }

        return settings.ignoredAppNames.contains { appName.contains($0.lowercased()) }
    }

    private func matchesSensitivePattern(
        in text: String,
        settings: ClipboardSettings
    ) -> Bool {
        let searchRange = NSRange(text.startIndex..<text.endIndex, in: text)

        return settings.sensitiveContentPatterns.contains { pattern in
            guard let expression = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive]
            ) else {
                return false
            }

            return expression.firstMatch(in: text, range: searchRange) != nil
        }
    }
}
