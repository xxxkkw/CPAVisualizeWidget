import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum DefaultsKey {
        static let baseURL = "usageKeeper.baseURL"
        static let authEnabled = "usageKeeper.authEnabled"
        static let lastSyncAt = "usageKeeper.lastSyncAt"
    }

    private enum KeychainKey {
        static let password = "usageKeeper.password"
        static let sessionToken = "usageKeeper.sessionToken"
    }

    private let autoSyncIntervalNanoseconds: UInt64 = 300_000_000_000

    let appGroupIdentifier = CPAVisualizeConfiguration.appGroupIdentifier

    @Published var baseURL: String
    @Published var authEnabled: Bool
    @Published var loginPassword: String
    @Published private(set) var lastSyncAt: Date?
    @Published private(set) var latestSnapshot: UsageSnapshot?
    @Published private(set) var hasStoredSession: Bool
    @Published private(set) var isSyncing = false
    @Published private(set) var syncStatusMessage: String?
    @Published private(set) var syncErrorMessage: String?

    private let defaults: UserDefaults
    private let keychain: KeychainStore
    private let snapshotStore: SharedSnapshotStore
    private var autoSyncTask: Task<Void, Never>?

    init(
        defaults: UserDefaults = .standard,
        keychain: KeychainStore = KeychainStore(service: CPAVisualizeConfiguration.keychainService),
        snapshotStore: SharedSnapshotStore = SharedSnapshotStore()
    ) {
        let storedBaseURL = defaults.string(forKey: DefaultsKey.baseURL) ?? ""
        let storedAuthEnabled = defaults.object(forKey: DefaultsKey.authEnabled) as? Bool ?? false
        let storedPassword = (try? keychain.loadString(for: KeychainKey.password)) ?? ""
        let storedSnapshot = try? snapshotStore.load()
        let storedSession = ((try? keychain.loadString(for: KeychainKey.sessionToken)) ?? "").isEmpty == false

        self.defaults = defaults
        self.keychain = keychain
        self.snapshotStore = snapshotStore
        self.baseURL = storedBaseURL
        self.authEnabled = storedAuthEnabled
        self.loginPassword = storedPassword
        self.latestSnapshot = storedSnapshot
        self.lastSyncAt = storedSnapshot?.lastUpdatedAt ?? (defaults.object(forKey: DefaultsKey.lastSyncAt) as? Date)
        self.hasStoredSession = storedSession
        self.syncStatusMessage = storedSnapshot == nil ? "已开启自动同步。" : "已载入共享快照，并已开启自动同步。"
        self.syncErrorMessage = nil

        startAutoSyncIfNeeded()
    }

    deinit {
        autoSyncTask?.cancel()
    }

    var normalizedBaseURL: URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let directURL = URL(string: trimmed), directURL.scheme != nil {
            return directURL
        }

        return URL(string: "http://\(trimmed)")
    }

    var sessionToken: String? {
        try? keychain.loadString(for: KeychainKey.sessionToken)
    }

    func saveSettings() {
        persist()
        Task { [weak self] in
            await self?.syncSnapshot()
        }
    }

    func syncSnapshot() async {
        guard !isSyncing else {
            return
        }

        guard let normalizedBaseURL else {
            syncStatusMessage = nil
            syncErrorMessage = "Usage Keeper 地址无效。"
            return
        }

        isSyncing = true
        syncStatusMessage = "正在同步 Usage Keeper…"
        syncErrorMessage = nil
        defer { isSyncing = false }

        let client = UsageKeeperClient(
            configuration: .init(
                baseURL: normalizedBaseURL,
                authEnabled: authEnabled,
                loginPassword: loginPassword.isEmpty ? nil : loginPassword,
                sessionToken: sessionToken
            )
        )

        do {
            let result = try await client.fetchSnapshot()
            storeSessionToken(result.sessionToken)
            updateSnapshot(result.snapshot)

            if syncErrorMessage == nil {
                syncStatusMessage = "同步完成：\(result.snapshot.lastUpdatedAt.formatted(date: .abbreviated, time: .shortened))"
            }
        } catch {
            syncStatusMessage = nil
            syncErrorMessage = error.localizedDescription
        }
    }

    func storeSessionToken(_ token: String?) {
        guard authEnabled else {
            hasStoredSession = false
            return
        }

        do {
            if let token, !token.isEmpty {
                try keychain.saveString(token, for: KeychainKey.sessionToken)
                hasStoredSession = true
            } else if hasStoredSession {
                try keychain.deleteValue(for: KeychainKey.sessionToken)
                hasStoredSession = false
            } else {
                hasStoredSession = false
            }
        } catch {
            syncStatusMessage = nil
            syncErrorMessage = "保存会话失败：\(error.localizedDescription)"
        }
    }

    func clearSession() {
        if hasStoredSession {
            storeSessionToken(nil)
        } else if syncErrorMessage == nil {
            syncStatusMessage = "当前没有可清除的本地会话。"
        }
    }

    func updateSnapshot(_ snapshot: UsageSnapshot) {
        do {
            try snapshotStore.save(snapshot)
            latestSnapshot = snapshot
            lastSyncAt = snapshot.lastUpdatedAt
            defaults.set(snapshot.lastUpdatedAt, forKey: DefaultsKey.lastSyncAt)
        } catch {
            syncStatusMessage = nil
            syncErrorMessage = "写入共享快照失败：\(error.localizedDescription)"
        }
    }

    func reloadSnapshot() {
        do {
            latestSnapshot = try snapshotStore.load()
            lastSyncAt = latestSnapshot?.lastUpdatedAt ?? (defaults.object(forKey: DefaultsKey.lastSyncAt) as? Date)
            syncStatusMessage = latestSnapshot == nil ? "当前还没有共享快照。" : "已重新读取本地共享快照。"
            syncErrorMessage = nil
        } catch {
            syncStatusMessage = nil
            syncErrorMessage = "读取共享快照失败：\(error.localizedDescription)"
        }
    }

    func clearSnapshot() {
        do {
            try snapshotStore.clear()
            latestSnapshot = nil
            lastSyncAt = nil
            defaults.removeObject(forKey: DefaultsKey.lastSyncAt)
            syncStatusMessage = "已清空共享快照。"
            syncErrorMessage = nil
        } catch {
            syncStatusMessage = nil
            syncErrorMessage = "清空共享快照失败：\(error.localizedDescription)"
        }
    }

    private func persist() {
        defaults.set(baseURL, forKey: DefaultsKey.baseURL)
        defaults.set(authEnabled, forKey: DefaultsKey.authEnabled)

        guard authEnabled else {
            syncStatusMessage = "设置已保存。"
            syncErrorMessage = nil
            return
        }

        do {
            if loginPassword.isEmpty {
                let hasStoredPassword = ((try? keychain.loadString(for: KeychainKey.password)) ?? "").isEmpty == false
                if hasStoredPassword {
                    try keychain.deleteValue(for: KeychainKey.password)
                }
            } else {
                try keychain.saveString(loginPassword, for: KeychainKey.password)
            }

            syncStatusMessage = "设置已保存。"
            syncErrorMessage = nil
        } catch {
            syncStatusMessage = nil
            syncErrorMessage = "保存本地凭据失败：\(error.localizedDescription)"
        }
    }

    private func startAutoSyncIfNeeded() {
        guard autoSyncTask == nil else {
            return
        }

        autoSyncTask = Task { [weak self] in
            guard let self else {
                return
            }

            await self.syncSnapshot()

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self.autoSyncIntervalNanoseconds)
                guard !Task.isCancelled else {
                    break
                }
                await self.syncSnapshot()
            }
        }
    }
}