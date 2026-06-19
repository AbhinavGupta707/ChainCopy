import Foundation

protocol OwnPasteboardWriteTracking {
    func isOwnWrite(changeCount: Int, types: Set<String>) -> Bool
}

final class OwnPasteboardWriteTracker: OwnPasteboardWriteTracking {
    private let markerType: String
    private let maxTrackedWrites: Int
    private var trackedChangeCounts: [Int] = []

    init(
        markerType: String = PasteboardTypeNames.chainCopyOwnedWrite,
        maxTrackedWrites: Int = 20
    ) {
        self.markerType = markerType
        self.maxTrackedWrites = maxTrackedWrites
    }

    func record(changeCount: Int) {
        guard changeCount >= 0, !trackedChangeCounts.contains(changeCount) else {
            return
        }

        trackedChangeCounts.append(changeCount)

        if trackedChangeCounts.count > maxTrackedWrites {
            trackedChangeCounts.removeFirst(trackedChangeCounts.count - maxTrackedWrites)
        }
    }

    func isOwnWrite(changeCount: Int, types: Set<String>) -> Bool {
        types.contains(markerType) || trackedChangeCounts.contains(changeCount)
    }
}
