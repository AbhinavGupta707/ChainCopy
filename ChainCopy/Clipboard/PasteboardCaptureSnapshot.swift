import Foundation

struct PasteboardCaptureSnapshot: Equatable {
    var changeCount: Int
    var types: Set<String>
    var content: PasteboardContent
    var sourceApplication: SourceApplication?
    var capturedAt: Date

    init(
        changeCount: Int,
        types: Set<String>? = nil,
        content: PasteboardContent,
        sourceApplication: SourceApplication? = nil,
        capturedAt: Date = Date()
    ) {
        self.changeCount = changeCount
        self.types = types ?? content.typeNames
        self.content = content
        self.sourceApplication = sourceApplication
        self.capturedAt = capturedAt
    }

    var inspection: PasteboardInspection {
        PasteboardInspection(
            types: types,
            sourceAppName: sourceApplication?.name,
            sourceAppBundleIdentifier: sourceApplication?.bundleIdentifier,
            text: content.capturableText
        )
    }
}
