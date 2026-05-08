import Foundation

public enum CPAVisualizeConfiguration {
    public static let appGroupIdentifier = "group.com.xiongkaiwen.CPAVisualize"
    public static let keychainService = "com.xiongkaiwen.CPAVisualize"
    public static let snapshotFileName = "usage-snapshot.json"
    public static let widgetKind = "CPAUsageWidget"
}

public enum UsageRange: String, Codable, CaseIterable, Sendable {
    case today
    case sevenDays = "7d"
    case custom

    public var queryValue: String {
        rawValue
    }

    public var displayTitle: String {
        switch self {
        case .today:
            return "今日"
        case .sevenDays:
            return "近 7 天"
        case .custom:
            return "自定义"
        }
    }
}

public struct UsageSeriesPoint: Codable, Equatable, Sendable, Identifiable {
    public var id: String { date }
    public var date: String
    public var value: Double

    public init(date: String, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct UsageSummary: Codable, Equatable, Sendable {
    public var totalTokens: Int64
    public var totalCost: Double
    public var costAvailable: Bool
    public var cachedTokens: Int64
    public var reasoningTokens: Int64
    public var requestCount: Int64
    public var successRate: Double

    public init(
        totalTokens: Int64,
        totalCost: Double,
        costAvailable: Bool,
        cachedTokens: Int64,
        reasoningTokens: Int64,
        requestCount: Int64,
        successRate: Double
    ) {
        self.totalTokens = totalTokens
        self.totalCost = totalCost
        self.costAvailable = costAvailable
        self.cachedTokens = cachedTokens
        self.reasoningTokens = reasoningTokens
        self.requestCount = requestCount
        self.successRate = successRate
    }
}

public struct UsageSnapshot: Codable, Equatable, Sendable {
    public var generatedAt: Date
    public var lastUpdatedAt: Date
    public var today: UsageSummary
    public var sevenDay: UsageSummary
    public var dailyTokens: [UsageSeriesPoint]
    public var dailyCost: [UsageSeriesPoint]

    public init(
        generatedAt: Date = .now,
        lastUpdatedAt: Date = .now,
        today: UsageSummary,
        sevenDay: UsageSummary,
        dailyTokens: [UsageSeriesPoint],
        dailyCost: [UsageSeriesPoint]
    ) {
        self.generatedAt = generatedAt
        self.lastUpdatedAt = lastUpdatedAt
        self.today = today
        self.sevenDay = sevenDay
        self.dailyTokens = dailyTokens
        self.dailyCost = dailyCost
    }

    public static var preview: UsageSnapshot {
        UsageSnapshot(
            generatedAt: .now,
            lastUpdatedAt: .now,
            today: UsageSummary(
                totalTokens: 625_070_000,
                totalCost: 400.57,
                costAvailable: true,
                cachedTokens: 539_970_000,
                reasoningTokens: 1_570_000,
                requestCount: 612,
                successRate: 98.6
            ),
            sevenDay: UsageSummary(
                totalTokens: 2_194_800_000,
                totalCost: 1_140.69,
                costAvailable: true,
                cachedTokens: 1_761_700_000,
                reasoningTokens: 4_332_900,
                requestCount: 3_404,
                successRate: 97.8
            ),
            dailyTokens: [
                .init(date: "00:00", value: 0),
                .init(date: "02:00", value: 0),
                .init(date: "04:00", value: 0),
                .init(date: "06:00", value: 0),
                .init(date: "08:00", value: 0),
                .init(date: "10:00", value: 0),
                .init(date: "12:00", value: 2_500_000),
                .init(date: "13:00", value: 4_000_000),
                .init(date: "14:00", value: 29_000_000),
                .init(date: "15:00", value: 50_000_000),
                .init(date: "16:00", value: 27_000_000),
                .init(date: "17:00", value: 12_000_000),
                .init(date: "18:00", value: 0),
                .init(date: "20:00", value: 0),
                .init(date: "22:00", value: 0)
            ],
            dailyCost: [
                .init(date: "00:00", value: 0),
                .init(date: "02:00", value: 0),
                .init(date: "04:00", value: 0),
                .init(date: "06:00", value: 0),
                .init(date: "08:00", value: 0),
                .init(date: "10:00", value: 0),
                .init(date: "12:00", value: 4.31),
                .init(date: "13:00", value: 7.52),
                .init(date: "14:00", value: 61.48),
                .init(date: "15:00", value: 158.23),
                .init(date: "16:00", value: 106.77),
                .init(date: "17:00", value: 62.26),
                .init(date: "18:00", value: 0),
                .init(date: "20:00", value: 0),
                .init(date: "22:00", value: 0)
            ]
        )
    }
}
