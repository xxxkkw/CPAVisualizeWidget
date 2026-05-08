import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

struct SharedSnapshotStore {
    let appGroupIdentifier: String
    let fileName: String

    init(
        appGroupIdentifier: String = CPAVisualizeConfiguration.appGroupIdentifier,
        fileName: String = CPAVisualizeConfiguration.snapshotFileName
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.fileName = fileName
    }

    func load() throws -> UsageSnapshot? {
        let url = try snapshotURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(UsageSnapshot.self, from: data)
    }

    func save(_ snapshot: UsageSnapshot) throws {
        let url = try snapshotURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(snapshot)
        try data.write(to: url, options: [.atomic])

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    func clear() throws {
        let url = try snapshotURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }
        try FileManager.default.removeItem(at: url)

        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func snapshotURL() throws -> URL {
        let directory = try containerDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(fileName)
    }

    private func containerDirectory() throws -> URL {
        if let groupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
            return groupURL.appendingPathComponent("SharedCache", isDirectory: true)
        }

        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return applicationSupport.appendingPathComponent("CPAVisualize", isDirectory: true)
    }
}