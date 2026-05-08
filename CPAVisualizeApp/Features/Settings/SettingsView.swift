import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore

    private var previewSnapshot: UsageSnapshot {
        store.latestSnapshot ?? .preview
    }

    var body: some View {
        ZStack {
            LiquidGlassAppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    syncStatusCard
                    previewCard(snapshot: previewSnapshot)
                    configurationCard
                }
                .padding(24)
                .frame(maxWidth: 760, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
        }
    }

    private struct LiquidGlassAppBackground: View {
        var body: some View {
            Rectangle()
                .fill(.clear)
                .glassEffect(.regular, in: Rectangle())
                .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CPA Visualize")
                .font(.system(size: 28, weight: .semibold))
            Text("宿主 App 负责保存 Usage Keeper 地址、登录信息、拉取 today / 7d 概览，并把共享快照写给桌面 widget。")
                .foregroundStyle(.secondary)
        }
    }

    private var syncStatusCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                if store.isSyncing {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text("正在从 Usage Keeper 拉取 today 和 7d 概览。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                infoRow(title: "上次同步", value: store.lastSyncAt?.formatted(date: .abbreviated, time: .shortened) ?? "尚未同步")
                infoRow(title: "本地 Session", value: store.hasStoredSession ? "已缓存" : "未缓存")

                if let status = store.syncStatusMessage {
                    infoRow(title: "状态", value: status, valueColor: .secondary)
                }

                if let error = store.syncErrorMessage {
                    infoRow(title: "错误", value: error, valueColor: .red)
                }
            }
            .padding(.top, 8)
        } label: {
            Label("同步状态", systemImage: "arrow.trianglehead.2.clockwise")
        }
    }

    private var configurationCard: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Usage Keeper URL", text: $store.baseURL)
                    .textFieldStyle(.roundedBorder)

                Text("支持 `http://` 和 `https://` 地址。保存后会立即同步，此后每 5 分钟自动同步一次。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Usage Keeper 启用了密码登录", isOn: $store.authEnabled)

                SecureField("登录密码（可选保存到 Keychain）", text: $store.loginPassword)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!store.authEnabled)

                HStack(spacing: 12) {
                    Button("保存设置") {
                        store.saveSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.isSyncing)

                    Button("重新读取快照") {
                        store.reloadSnapshot()
                    }
                    .buttonStyle(.bordered)
                }

                HStack(spacing: 12) {
                    Button("清空共享快照") {
                        store.clearSnapshot()
                    }
                    .buttonStyle(.bordered)

                    Button("清除本地会话") {
                        store.clearSession()
                    }
                    .buttonStyle(.bordered)
                }

                if let normalizedBaseURL = store.normalizedBaseURL {
                    infoRow(title: "后端地址", value: normalizedBaseURL.absoluteString)
                }
                infoRow(title: "App Group", value: store.appGroupIdentifier)
            }
            .padding(.top, 8)
        } label: {
            Label("连接设置", systemImage: "gearshape")
        }
    }

    private func previewCard(snapshot: UsageSnapshot) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    metric(title: "今日 Token", value: snapshot.today.totalTokens.formatted(.number.notation(.compactName)))
                    Spacer()
                    metric(title: "今日 Cost", value: formattedCost(snapshot.today))
                }

                HStack {
                    metric(title: "今日 Cached", value: snapshot.today.cachedTokens.formatted(.number.notation(.compactName)))
                    Spacer()
                    metric(title: "今日 Reasoning", value: snapshot.today.reasoningTokens.formatted(.number.notation(.compactName)))
                }

                HStack {
                    metric(title: "7D Token", value: snapshot.sevenDay.totalTokens.formatted(.number.notation(.compactName)))
                    Spacer()
                    metric(title: "7D Req", value: snapshot.sevenDay.requestCount.formatted(.number.notation(.compactName)))
                }

                Text("最近一次快照：\(snapshot.lastUpdatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        } label: {
            Label("Widget 预览数据", systemImage: "chart.line.uptrend.xyaxis")
        }
    }

    private func infoRow(title: String, value: String, valueColor: Color = .secondary) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 84, alignment: .leading)

            Text(value)
                .font(.footnote)
                .foregroundStyle(valueColor)
                .textSelection(.enabled)
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
        }
    }

    private func formattedCost(_ summary: UsageSummary) -> String {
        guard summary.totalCost.isFinite else {
            return "--"
        }
        return summary.totalCost.formatted(.currency(code: "USD"))
    }
}

#Preview {
    SettingsView(store: SettingsStore())
}