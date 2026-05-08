import Foundation
import WidgetKit

enum UsageWidgetDisplayMode {
    case live
    case empty
    case preview
}

struct UsageWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: UsageSnapshot?
    let displayMode: UsageWidgetDisplayMode
    let isStale: Bool
}

struct UsageTimelineProvider: TimelineProvider {
    private let store = SharedSnapshotStore()

    func placeholder(in context: Context) -> UsageWidgetEntry {
        UsageWidgetEntry(
            date: .now,
            snapshot: .preview,
            displayMode: .preview,
            isStale: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageWidgetEntry) -> Void) {
        completion(makeEntry(previewIfMissing: context.isPreview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageWidgetEntry>) -> Void) {
        let entry = makeEntry(previewIfMissing: context.isPreview)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func makeEntry(previewIfMissing: Bool) -> UsageWidgetEntry {
        do {
            if let snapshot = try store.load() {
                let isStale = Date().timeIntervalSince(snapshot.lastUpdatedAt) > 7200
                return UsageWidgetEntry(
                    date: .now,
                    snapshot: snapshot,
                    displayMode: .live,
                    isStale: isStale
                )
            }
        } catch {
        }

        if previewIfMissing {
            return UsageWidgetEntry(
                date: .now,
                snapshot: .preview,
                displayMode: .preview,
                isStale: false
            )
        }

        return UsageWidgetEntry(
            date: .now,
            snapshot: nil,
            displayMode: .empty,
            isStale: false
        )
    }
}
