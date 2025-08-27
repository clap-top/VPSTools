import SwiftUI
import Combine

// MARK: - SSH Connection Monitor View

/// SSH连接监控视图
/// 显示连接状态、统计信息和性能指标
struct SSHConnectionMonitorView: View {
    
    // MARK: - Environment Objects
    
    @EnvironmentObject var vpsManager: VPSManager
    @EnvironmentObject var sshConnectionManager: SSHConnectionManager
    
    // MARK: - State
    
    @State private var selectedTab: MonitorTab = .overview
    @State private var refreshTimer: Timer?
    @State private var isRefreshing: Bool = false
    
    // MARK: - Constants
    
    private let refreshInterval: TimeInterval = 5.0
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标签栏
                tabBar
                
                // 内容区域
                TabView(selection: $selectedTab) {
                    overviewTab
                        .tag(MonitorTab.overview)
                    
                    connectionsTab
                        .tag(MonitorTab.connections)
                    
                    metricsTab
                        .tag(MonitorTab.metrics)
                    
                    settingsTab
                        .tag(MonitorTab.settings)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("SSH连接监控")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
        }
        .onAppear {
            startRefreshTimer()
        }
        .onDisappear {
            stopRefreshTimer()
        }
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(MonitorTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    VStack(spacing: 4) {
                        Text(tab.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(selectedTab == tab ? .primary : .secondary)
                        
                        Rectangle()
                            .fill(selectedTab == tab ? Color.accentColor : Color.clear)
                            .frame(height: 2)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    // MARK: - Overview Tab
    
    private var overviewTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 连接统计卡片
                connectionStatsCard
                
                // 快速操作卡片
                quickActionsCard
                
                // 最近活动卡片
                recentActivityCard
                
                // 系统状态卡片
                systemStatusCard
            }
            .padding()
        }
    }
    
    // MARK: - Connections Tab
    
    private var connectionsTab: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(vpsManager.vpsInstances, id: \.id) { vps in
                    ConnectionStatusRow(vps: vps, connectionManager: sshConnectionManager)
                }
            }
            .padding()
        }
    }
    
    // MARK: - Metrics Tab
    
    private var metricsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 性能指标卡片
                performanceMetricsCard
                
                // 连接历史图表
                connectionHistoryChart
                
                // 错误统计卡片
                errorStatsCard
            }
            .padding()
        }
    }
    
    // MARK: - Settings Tab
    
    private var settingsTab: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 连接配置
                connectionConfigSection
                
                // 监控配置
                monitoringConfigSection
                
                // 高级设置
                advancedSettingsSection
            }
            .padding()
        }
    }
    
    // MARK: - Overview Components
    
    private var connectionStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.accentColor)
                Text("连接统计")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 20) {
                StatItem(
                    title: "总连接",
                    value: "\(sshConnectionManager.connectionStats.totalConnections)",
                    color: .blue
                )
                
                StatItem(
                    title: "活跃连接",
                    value: "\(sshConnectionManager.connectionStats.activeConnections)",
                    color: .green
                )
                
                StatItem(
                    title: "失败连接",
                    value: "\(sshConnectionManager.connectionStats.failedConnections)",
                    color: .red
                )
            }
            
            // 连接利用率进度条
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("连接利用率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.1f", sshConnectionManager.connectionStats.connectionUtilization))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: sshConnectionManager.connectionStats.connectionUtilization, total: 100)
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bolt")
                    .foregroundColor(.accentColor)
                Text("快速操作")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "连接全部",
                    icon: "network",
                    action: connectAllVPS
                )
                
                QuickActionButton(
                    title: "断开全部",
                    icon: "network.slash",
                    action: disconnectAllVPS
                )
                
                QuickActionButton(
                    title: "健康检查",
                    icon: "heart",
                    action: performHealthCheck
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var recentActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.accentColor)
                Text("最近活动")
                    .font(.headline)
                Spacer()
            }
            
            // 这里可以显示最近的活动日志
            Text("暂无最近活动")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var systemStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.accentColor)
                Text("系统状态")
                    .font(.headline)
                Spacer()
                
                Circle()
                    .fill(sshConnectionManager.isInitialized ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(title: "连接管理器", isActive: sshConnectionManager.isInitialized)
                StatusRow(title: "VPS管理器", isActive: true)
                StatusRow(title: "网络连接", isActive: true)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Metrics Components
    
    private var performanceMetricsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.accentColor)
                Text("性能指标")
                    .font(.headline)
                Spacer()
            }
            
            // 这里可以显示性能图表
            Text("性能图表开发中...")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var connectionHistoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.accentColor)
                Text("连接历史")
                    .font(.headline)
                Spacer()
            }
            
            // 这里可以显示连接历史图表
            Text("连接历史图表开发中...")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var errorStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                Text("错误统计")
                    .font(.headline)
                Spacer()
            }
            
            // 这里可以显示错误统计
            Text("暂无错误")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 20)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Settings Components
    
    private var connectionConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.accentColor)
                Text("连接配置")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ConfigRow(title: "最大并发连接数", value: "\(SSHConnectionConfig.Performance.maxConcurrentConnections)")
                ConfigRow(title: "连接超时时间", value: "\(Int(SSHConnectionConfig.Timeouts.connection))s")
                ConfigRow(title: "命令超时时间", value: "\(Int(SSHConnectionConfig.Timeouts.command))s")
                ConfigRow(title: "保活间隔", value: "\(Int(SSHConnectionConfig.KeepAlive.interval))s")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var monitoringConfigSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "eye")
                    .foregroundColor(.accentColor)
                Text("监控配置")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ConfigRow(title: "自动刷新", value: "启用")
                ConfigRow(title: "刷新间隔", value: "\(Int(refreshInterval))s")
                ConfigRow(title: "健康检查", value: "启用")
                ConfigRow(title: "负载均衡", value: "启用")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var advancedSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gearshape")
                    .foregroundColor(.accentColor)
                Text("高级设置")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 8) {
                ConfigRow(title: "连接池大小", value: "\(SSHConnectionConfig.ConnectionPool.maxSize)")
                ConfigRow(title: "最大重连次数", value: "\(SSHConnectionConfig.Reconnection.maxAttempts)")
                ConfigRow(title: "日志级别", value: SSHConnectionConfig.Logging.level.description)
                ConfigRow(title: "性能监控", value: SSHConnectionConfig.Logging.enablePerformanceLogging ? "启用" : "禁用")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Toolbar
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await refreshData()
            }
        }) {
            Image(systemName: isRefreshing ? "arrow.clockwise.circle.fill" : "arrow.clockwise")
                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                .animation(isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
        }
        .disabled(isRefreshing)
    }
    
    // MARK: - Actions
    
    private func connectAllVPS() {
        Task {
            for vps in vpsManager.vpsInstances {
                do {
                    try await sshConnectionManager.connect(to: vps)
                } catch {
                    print("Failed to connect to \(vps.name): \(error)")
                }
            }
        }
    }
    
    private func disconnectAllVPS() {
        Task {
            await sshConnectionManager.disconnectAll()
        }
    }
    
    private func performHealthCheck() {
        Task {
            await sshConnectionManager.performHealthCheck()
        }
    }
    
    private func refreshData() async {
        isRefreshing = true
        defer { isRefreshing = false }
        
        // 执行健康检查
        await sshConnectionManager.performHealthCheck()
        
        // 等待一小段时间让UI更新
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
    
    // MARK: - Timer Management
    
    private func startRefreshTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            Task {
                await refreshData()
            }
        }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Supporting Views

/// 监控标签页
enum MonitorTab: CaseIterable {
    case overview
    case connections
    case metrics
    case settings
    
    var title: String {
        switch self {
        case .overview: return "概览"
        case .connections: return "连接"
        case .metrics: return "指标"
        case .settings: return "设置"
        }
    }
}

/// 统计项组件
struct StatItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 快速操作按钮
struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
}

/// 状态行组件
struct StatusRow: View {
    let title: String
    let isActive: Bool
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
            
            Spacer()
            
            Circle()
                .fill(isActive ? Color.green : Color.red)
                .frame(width: 8, height: 8)
        }
    }
}

/// 配置行组件
struct ConfigRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

/// 连接状态行组件
struct ConnectionStatusRow: View {
    let vps: VPSInstance
    let connectionManager: SSHConnectionManager
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vps.name)
                    .font(.headline)
                
                Text("\(vps.host):\(vps.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                ConnectionStatusBadge(state: connectionManager.getConnectionState(for: vps))
                
                if let metrics = connectionManager.getConnectionMetrics(for: vps) {
                    Text("\(String(format: "%.1f", metrics.averageResponseTime))ms")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

/// 连接状态徽章
struct ConnectionStatusBadge: View {
    let state: SSHConnectionState
    
    var body: some View {
        Text(state.displayText)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(state.color.opacity(0.2))
            .foregroundColor(state.color)
            .cornerRadius(4)
    }
}

// MARK: - Extensions

extension SSHConnectionState {
    var displayText: String {
        switch self {
        case .disconnected: return "断开"
        case .connecting: return "连接中"
        case .connected: return "已连接"
        case .failed: return "失败"
        case .timeout: return "超时"
        }
    }
    
    var color: Color {
        switch self {
        case .disconnected: return .gray
        case .connecting: return .orange
        case .connected: return .green
        case .failed: return .red
        case .timeout: return .red
        }
    }
}

// MARK: - Preview

struct SSHConnectionMonitorView_Previews: PreviewProvider {
    static var previews: some View {
        SSHConnectionMonitorView()
            .environmentObject(VPSManager())
            .environmentObject(SSHConnectionManager())
    }
}
