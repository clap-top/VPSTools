import SwiftUI
import Combine

// MARK: - Connection Monitor View

/// 连接监控视图
struct ConnectionMonitorView: View {
    @ObservedObject var vpsManager: VPSManager
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部统计卡片
                ConnectionStatsCard(vpsManager: vpsManager)
                    .padding()
                
                // 标签页选择器
                Picker("监控类型", selection: $selectedTab) {
                    Text("连接池").tag(0)
                    Text("健康状态").tag(1)
                    Text("性能指标").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // 标签页内容
                TabView(selection: $selectedTab) {
                    ConnectionPoolView(vpsManager: vpsManager)
                        .tag(0)
                    
                    HealthStatusView(vpsManager: vpsManager)
                        .tag(1)
                    
                    PerformanceMetricsView(vpsManager: vpsManager)
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("连接监控")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Connection Stats Card

struct ConnectionStatsCard: View {
    @ObservedObject var vpsManager: VPSManager
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("连接统计")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button("刷新") {
                    // 刷新统计数据
                }
                .buttonStyle(BorderedButtonStyle())
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ConnectionStatCard(
                    title: "总连接",
                    value: "\(vpsManager.getConnectionPoolStats().totalConnections)",
                    color: .blue
                )
                
                ConnectionStatCard(
                    title: "健康连接",
                    value: "\(vpsManager.getConnectionPoolStats().healthyConnections)",
                    color: .green
                )
                
                ConnectionStatCard(
                    title: "使用中",
                    value: "\(vpsManager.getConnectionPoolStats().inUseConnections)",
                    color: .orange
                )
            }
            
            // 连接池利用率
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("连接池利用率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.1f", vpsManager.getConnectionPoolStats().utilizationRate))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: vpsManager.getConnectionPoolStats().utilizationRate / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - Connection Stat Card

struct ConnectionStatCard: View {
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
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Connection Pool View

struct ConnectionPoolView: View {
    @ObservedObject var vpsManager: VPSManager
    
    var body: some View {
        List {
            ForEach(vpsManager.vpsInstances) { vps in
                ConnectionPoolItemView(
                    vps: vps,
                    status: vpsManager.connectionPool.getConnectionStatus(for: vps.id),
                    health: vpsManager.getConnectionHealth(for: vps.id)
                )
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Connection Pool Item View

struct ConnectionPoolItemView: View {
    let vps: VPSInstance
    let status: ConnectionStatus?
    let health: ConnectionHealth?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(vps.name)
                        .font(.headline)
                    
                    Text(vps.host)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 状态指示器
                ConnectionStatusIndicator(status: status, health: health)
            }
            
            if let status = status {
                HStack(spacing: 16) {
                    StatusInfo(label: "连接状态", value: status.isConnected ? "已连接" : "未连接")
                    StatusInfo(label: "健康状态", value: status.isHealthy ? "健康" : "不健康")
                    StatusInfo(label: "使用次数", value: "\(status.useCount)")
                }
                .font(.caption)
                
                if let lastUsed = status.lastUsed {
                    Text("最后使用: \(lastUsed, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Connection Status Indicator

struct ConnectionStatusIndicator: View {
    let status: ConnectionStatus?
    let health: ConnectionHealth?
    
    var statusColor: Color {
        guard let status = status else { return .gray }
        
        if !status.isConnected {
            return .red
        }
        
        if !status.isHealthy {
            return .orange
        }
        
        return .green
    }
    
    var statusText: String {
        guard let status = status else { return "未知" }
        
        if !status.isConnected {
            return "断开"
        }
        
        if !status.isHealthy {
            return "异常"
        }
        
        return "正常"
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(statusColor)
        }
    }
}

// MARK: - Status Info

struct StatusInfo: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Health Status View

struct HealthStatusView: View {
    @ObservedObject var vpsManager: VPSManager
    
    var body: some View {
        List {
            ForEach(vpsManager.vpsInstances) { vps in
                HealthStatusItemView(
                    vps: vps,
                    health: vpsManager.getConnectionHealth(for: vps.id)
                )
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Health Status Item View

struct HealthStatusItemView: View {
    let vps: VPSInstance
    let health: ConnectionHealth?
    
    var healthColor: Color {
        switch health {
        case .healthy:
            return .green
        case .unhealthy:
            return .orange
        case .failed, .unrecoverable:
            return .red
        case .disconnected:
            return .gray
        case .none:
            return .gray
        }
    }
    
    var healthText: String {
        switch health {
        case .healthy:
            return "健康"
        case .unhealthy:
            return "异常"
        case .failed:
            return "失败"
        case .unrecoverable:
            return "不可恢复"
        case .disconnected:
            return "已断开"
        case .none:
            return "未知"
        }
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(vps.name)
                    .font(.headline)
                
                Text(vps.host)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(healthText)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(healthColor)
                
                Circle()
                    .fill(healthColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Performance Metrics View

struct PerformanceMetricsView: View {
    @ObservedObject var vpsManager: VPSManager
    
    var body: some View {
        List {
            Section("连接池性能") {
                let stats = vpsManager.getConnectionPoolStats()
                
                MetricRow(label: "总连接数", value: "\(stats.totalConnections)")
                MetricRow(label: "健康连接数", value: "\(stats.healthyConnections)")
                MetricRow(label: "使用中连接数", value: "\(stats.inUseConnections)")
                MetricRow(label: "空闲连接数", value: "\(stats.idleConnections)")
                MetricRow(label: "平均使用次数", value: "\(stats.averageUseCount)")
                MetricRow(label: "利用率", value: "\(String(format: "%.1f", stats.utilizationRate))%")
                MetricRow(label: "健康率", value: "\(String(format: "%.1f", stats.healthRate))%")
            }
            
            Section("连接指标") {
                ForEach(vpsManager.vpsInstances) { vps in
                    if let metrics = vpsManager.connectionPool.connectionMetrics[vps.id] {
                        VPSMetricsRow(vps: vps, metrics: metrics)
                    }
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - VPS Metrics Row

struct VPSMetricsRow: View {
    let vps: VPSInstance
    let metrics: ConnectionMetrics
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(vps.name)
                .font(.headline)
            
            HStack(spacing: 16) {
                MetricInfo(label: "总尝试", value: "\(metrics.totalAttempts)")
                MetricInfo(label: "成功", value: "\(metrics.successfulAttempts)")
                MetricInfo(label: "失败", value: "\(metrics.failedAttempts)")
                MetricInfo(label: "成功率", value: "\(String(format: "%.1f", metrics.successRate))%")
            }
            .font(.caption)
            
            if let lastError = metrics.lastError {
                Text("最后错误: \(lastError)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Metric Info

struct MetricInfo: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

struct ConnectionMonitorView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionMonitorView(vpsManager: VPSManager())
    }
}
