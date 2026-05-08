import Foundation

struct UsageKeeperClient {
    struct Configuration {
        var baseURL: URL
        var authEnabled: Bool
        var loginPassword: String?
        var sessionToken: String?
        var timeout: TimeInterval = 30
    }

    struct SyncResult {
        let snapshot: UsageSnapshot
        let sessionToken: String?
    }

    enum ClientError: LocalizedError {
        case invalidBaseURL
        case authenticationRequired
        case missingPassword
        case missingSessionCookie
        case invalidResponse
        case invalidSession
        case unexpectedStatusCode(Int, String)

        var errorDescription: String? {
            switch self {
            case .invalidBaseURL:
                return "Usage Keeper 地址无效。"
            case .authenticationRequired:
                return "Usage Keeper 启用了登录保护，但当前没有可用会话。"
            case .missingPassword:
                return "需要提供 Usage Keeper 登录密码。"
            case .missingSessionCookie:
                return "登录成功，但没有收到会话 cookie。"
            case .invalidResponse:
                return "Usage Keeper 返回了无法解析的响应。"
            case .invalidSession:
                return "当前保存的 Usage Keeper 会话已失效，请重新登录。"
            case let .unexpectedStatusCode(code, body):
                return "Usage Keeper 返回状态码 \(code)：\(body)"
            }
        }
    }

    private let configuration: Configuration
    private let urlSession: URLSession
    private let sessionCookieName = "cpa_usage_keeper_session"

    init(configuration: Configuration, urlSession: URLSession = .shared) {
        self.configuration = configuration
        self.urlSession = urlSession
    }

    func fetchSnapshot() async throws -> SyncResult {
        let authenticatedSession = try await authenticateIfNeeded()
        let todayResult = try await requestOverview(range: .today, sessionToken: authenticatedSession)
        let sevenDayResult = try await requestOverview(range: .sevenDays, sessionToken: todayResult.sessionToken)
        let lastUpdatedAt = Date()

        let snapshot = UsageSnapshot(
            generatedAt: lastUpdatedAt,
            lastUpdatedAt: lastUpdatedAt,
            today: todayResult.response.makeSummary(),
            sevenDay: sevenDayResult.response.makeSummary(),
            dailyTokens: todayResult.response.hourlyTokenSeriesPoints(),
            dailyCost: todayResult.response.hourlyCostSeriesPoints()
        )

        return SyncResult(
            snapshot: snapshot,
            sessionToken: sevenDayResult.sessionToken
        )
    }

    func login() async throws -> String {
        guard configuration.authEnabled else {
            throw ClientError.authenticationRequired
        }
        guard let password = configuration.loginPassword, !password.isEmpty else {
            throw ClientError.missingPassword
        }

        var request = try buildRequest(path: "/api/v1/auth/login", queryItems: [], sessionToken: nil)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(LoginRequest(password: password))

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<empty body>"
            throw ClientError.unexpectedStatusCode(httpResponse.statusCode, body)
        }

        guard let requestURL = request.url,
              let cookieValue = extractSessionCookie(from: httpResponse, requestURL: requestURL)
        else {
            throw ClientError.missingSessionCookie
        }

        return cookieValue
    }

    private func authenticateIfNeeded() async throws -> String? {
        guard configuration.authEnabled else {
            return nil
        }

        if let sessionToken = configuration.sessionToken, !sessionToken.isEmpty {
            if try await isSessionValid(sessionToken) {
                return sessionToken
            }

            if configuration.loginPassword == nil {
                throw ClientError.invalidSession
            }
        }

        guard configuration.loginPassword != nil else {
            throw ClientError.authenticationRequired
        }

        return try await login()
    }

    private func isSessionValid(_ sessionToken: String) async throws -> Bool {
        let response: SessionResponse = try await request(
            path: "/api/v1/auth/session",
            queryItems: [],
            sessionToken: sessionToken
        )
        return response.authenticated
    }

    private func requestOverview(range: UsageRange, sessionToken: String?) async throws -> (response: OverviewResponse, sessionToken: String?) {
        do {
            let response: OverviewResponse = try await request(
                path: "/api/v1/usage/overview",
                queryItems: [URLQueryItem(name: "range", value: range.queryValue)],
                sessionToken: sessionToken
            )
            return (response, sessionToken)
        } catch ClientError.unexpectedStatusCode(let code, _) where code == 401 && configuration.authEnabled && configuration.loginPassword != nil {
            let refreshedSession = try await login()
            let response: OverviewResponse = try await request(
                path: "/api/v1/usage/overview",
                queryItems: [URLQueryItem(name: "range", value: range.queryValue)],
                sessionToken: refreshedSession
            )
            return (response, refreshedSession)
        }
    }

    private func request<Response: Decodable>(
        path: String,
        queryItems: [URLQueryItem],
        sessionToken: String?
    ) async throws -> Response {
        let request = try buildRequest(path: path, queryItems: queryItems, sessionToken: sessionToken)
        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<empty body>"
            throw ClientError.unexpectedStatusCode(httpResponse.statusCode, body)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "decode failure"
            throw ClientError.unexpectedStatusCode(httpResponse.statusCode, body)
        }
    }

    private func buildRequest(path: String, queryItems: [URLQueryItem], sessionToken: String?) throws -> URLRequest {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            throw ClientError.invalidBaseURL
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        components.path = basePath.isEmpty ? normalizedPath : "/\(basePath)\(normalizedPath)"
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw ClientError.invalidBaseURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = configuration.timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let sessionToken, !sessionToken.isEmpty {
            request.setValue("\(sessionCookieName)=\(sessionToken)", forHTTPHeaderField: "Cookie")
        }

        return request
    }

    private func extractSessionCookie(from response: HTTPURLResponse, requestURL: URL) -> String? {
        let headers = response.allHeaderFields.reduce(into: [String: String]()) { partialResult, item in
            partialResult[String(describing: item.key)] = String(describing: item.value)
        }

        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: requestURL)
        return cookies.first(where: { $0.name == sessionCookieName })?.value
    }
}

private struct LoginRequest: Encodable {
    let password: String
}

private struct SessionResponse: Decodable {
    let authenticated: Bool
}

private struct OverviewResponse: Decodable {
    let usage: OverviewUsage
    let summary: OverviewSummary
    let dailySeries: OverviewSeries
    let hourlySeries: OverviewSeries?
    let series: OverviewSeries?
    let timezone: String?

    enum CodingKeys: String, CodingKey {
        case usage
        case summary
        case dailySeries = "daily_series"
        case hourlySeries = "hourly_series"
        case series
        case timezone
    }

    func makeSummary() -> UsageSummary {
        let successRate = usage.totalRequests == 0 ? 0 : (Double(usage.successCount) / Double(usage.totalRequests)) * 100
        return UsageSummary(
            totalTokens: summary.tokenCount,
            totalCost: summary.totalCost,
            costAvailable: summary.costAvailable,
            cachedTokens: summary.cachedTokens,
            reasoningTokens: summary.reasoningTokens,
            requestCount: summary.requestCount,
            successRate: successRate
        )
    }

    func hourlyTokenSeriesPoints() -> [UsageSeriesPoint] {
        (hourlySeries?.tokens ?? series?.tokens ?? dailySeries.tokens)
            .hourlySeriesPoints(timeZoneIdentifier: timezone)
    }

    func hourlyCostSeriesPoints() -> [UsageSeriesPoint] {
        (hourlySeries?.cost ?? series?.cost ?? dailySeries.cost)
            .hourlySeriesPoints(timeZoneIdentifier: timezone)
    }
}

private struct OverviewUsage: Decodable {
    let totalRequests: Int64
    let successCount: Int64

    enum CodingKeys: String, CodingKey {
        case totalRequests = "total_requests"
        case successCount = "success_count"
    }
}

private struct OverviewSummary: Decodable {
    let requestCount: Int64
    let tokenCount: Int64
    let totalCost: Double
    let costAvailable: Bool
    let cachedTokens: Int64
    let reasoningTokens: Int64

    enum CodingKeys: String, CodingKey {
        case requestCount = "request_count"
        case tokenCount = "token_count"
        case totalCost = "total_cost"
        case costAvailable = "cost_available"
        case cachedTokens = "cached_tokens"
        case reasoningTokens = "reasoning_tokens"
    }
}

private struct OverviewSeries: Decodable {
    let tokens: [String: Int64]
    let cost: [String: Double]
}

private func parseISO8601Date(_ value: String) -> Date? {
    let formatterWithFractionalSeconds = ISO8601DateFormatter()
    formatterWithFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = formatterWithFractionalSeconds.date(from: value) {
        return date
    }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter.date(from: value)
}

private extension Dictionary where Key == String, Value == Int64 {
    func sortedSeriesPoints() -> [UsageSeriesPoint] {
        keys.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }).map { key in
            UsageSeriesPoint(date: key, value: Double(self[key] ?? 0))
        }
    }

    func hourlySeriesPoints(timeZoneIdentifier: String?) -> [UsageSeriesPoint] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier ?? "") ?? .current

        let valuesByHour = reduce(into: [Int: Int64]()) { result, item in
            guard let date = parseISO8601Date(item.key) else {
                return
            }
            let hour = calendar.component(.hour, from: date)
            result[hour, default: 0] += item.value
        }

        guard !valuesByHour.isEmpty else {
            return sortedSeriesPoints()
        }

        return (0 ..< 24).map { hour in
            UsageSeriesPoint(date: String(format: "%02d:00", hour), value: Double(valuesByHour[hour] ?? 0))
        }
    }
}

private extension Dictionary where Key == String, Value == Double {
    func sortedSeriesPoints() -> [UsageSeriesPoint] {
        keys.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }).map { key in
            UsageSeriesPoint(date: key, value: self[key] ?? 0)
        }
    }

    func hourlySeriesPoints(timeZoneIdentifier: String?) -> [UsageSeriesPoint] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier ?? "") ?? .current

        let valuesByHour = reduce(into: [Int: Double]()) { result, item in
            guard let date = parseISO8601Date(item.key) else {
                return
            }
            let hour = calendar.component(.hour, from: date)
            result[hour, default: 0] += item.value
        }

        guard !valuesByHour.isEmpty else {
            return sortedSeriesPoints()
        }

        return (0 ..< 24).map { hour in
            UsageSeriesPoint(date: String(format: "%02d:00", hour), value: valuesByHour[hour] ?? 0)
        }
    }
}