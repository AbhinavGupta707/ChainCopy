import Foundation

enum CaptureRejectionReason: Equatable {
    case captureDisabled
    case ownWrite
    case privacy(ClipboardPrivacyFilterReason)
    case unsupportedContent(PasteboardContentKind)
    case duplicateOfLatestItem
}

enum CaptureDecision: Equatable {
    case captured(ClipItem)
    case ignored(CaptureRejectionReason)
}

struct CaptureEngine {
    private let privacyFilter: ClipboardPrivacyFilter

    init(privacyFilter: ClipboardPrivacyFilter = ClipboardPrivacyFilter()) {
        self.privacyFilter = privacyFilter
    }

    func evaluate(
        snapshot: PasteboardCaptureSnapshot,
        method: CaptureMethod,
        existingItems: [ClipItem],
        settings: ClipboardSettings,
        ownWriteTracker: any OwnPasteboardWriteTracking
    ) -> CaptureDecision {
        guard settings.isCaptureEnabled else {
            return .ignored(.captureDisabled)
        }

        if ownWriteTracker.isOwnWrite(changeCount: snapshot.changeCount, types: snapshot.types) {
            return .ignored(.ownWrite)
        }

        let metadataDecision = privacyFilter.metadataDecision(for: snapshot.inspection, settings: settings)
        if let reason = metadataDecision.reason {
            return .ignored(.privacy(reason))
        }

        guard snapshot.content.capturableText != nil else {
            return .ignored(.unsupportedContent(snapshot.content.kind))
        }

        let privacyDecision = privacyFilter.decision(for: snapshot.inspection, settings: settings)
        if let reason = privacyDecision.reason {
            return .ignored(.privacy(reason))
        }

        guard let text = snapshot.content.capturableText else {
            return .ignored(.unsupportedContent(snapshot.content.kind))
        }

        let contentHash = ContentHasher.hash(text)
        if settings.suppressAdjacentDuplicates,
           existingItems.last?.contentHash == contentHash {
            return .ignored(.duplicateOfLatestItem)
        }

        let item = ClipItem(
            text: text,
            capturedAt: snapshot.capturedAt,
            sourceAppName: snapshot.sourceApplication?.name,
            sourceAppBundleIdentifier: snapshot.sourceApplication?.bundleIdentifier,
            captureMethod: method,
            contentHash: contentHash,
            contentKind: snapshot.content.kind,
            pasteboardChangeCount: snapshot.changeCount
        )

        return .captured(item)
    }
}
