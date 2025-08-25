//
//  MonitoringView.swift
//  SwiftUIApp
//
//  Created by Song.Wang on 2025/8/23.
//

import SwiftUI
import Charts

// MARK: - Monitoring View
struct MonitoringView: View {
    @ObservedObject var vpsManager: VPSManager
    @State private var selectedVPS: VPSInstance?
    @State private var showingVPSDetail = false
    @State private var refreshInterval: TimeInterval = 30
    @State private var isAutoRefresh = true
    @State private var isLoading = false
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部控制栏
                topControlBar
                
                // 主要内容区域
                if vpsManager.vpsInstances.isEmpty {
                    emptyStateView
                } else {
                    monitoringContent
                }
            }
            .navigationTitle(Text(.monitorViewTitle))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                MonitoringSettingsView(
                    refreshInterval: $refreshInterval,
                    isAutoRefresh: $isAutoRefresh
                )
            }
            .sheet(item: $selectedVPS) { vps in
                VPSMonitoringDetailView(vps: vps, vpsManager: vpsManager)
            }
            .onAppear {
                startAutoRefresh()
            }
            .onDisappear {
                stopAutoRefresh()
            }
        }
    }
    
    // MARK: - Top Control Bar
    
    private var topControlBar: some View {
        HStack {
            Button(action: refreshAllData) {
                HStack(spacing: 4) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(.refresh)
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            .disabled(isLoading)
            
            Spacer()
            
            HStack(spacing: 8) {
                Text(.autoRefresh)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Toggle("", isOn: $isAutoRefresh)
                    .labelsHidden()
                    .scaleEffect(0.8)
                    .onChange(of: isAutoRefresh) { oldValue, newValue in
                        if newValue {
                            startAutoRefresh()
                        } else {
                            stopAutoRefresh()
                        }
                    }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(.noMonitoringData)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(.addVPSInstanceToMonitor)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(String(.addVPS)) {
                // TODO: 导航到添加 VPS 页面
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Monitoring Content
    
    private var monitoringContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // 概览卡片
                overviewSection
                
                // VPS 监控列表
                vpsMonitoringList
            }
            .padding()
        }
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.systemOverview)
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                OverviewCard(
                    title: "在线 VPS",
                    value: "\(onlineVPSCount)",
                    total: "\(vpsManager.vpsInstances.count)",
                    icon: "server.rack",
                    color: .green
                )
                
                OverviewCard(
                    title: "平均 CPU",
                    value: "\(Int(averageCPUUsage))%",
                    total: "",
                    icon: "cpu",
                    color: .blue
                )
                
                OverviewCard(
                    title: "平均内存",
                    value: "\(Int(averageMemoryUsage))%",
                    total: "",
                    icon: "memorychip",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - VPS Monitoring List
    
    private var vpsMonitoringList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.vpsMonitoring)
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(vpsManager.vpsInstances) { vps in
                VPSMonitoringCard(
                    vps: vps,
                    vpsManager: vpsManager
                ) {
                    selectedVPS = vps
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var onlineVPSCount: Int {
        vpsManager.vpsInstances.filter { vps in
            if let testResult = vpsManager.connectionTestResults[vps.id] {
                return testResult.sshSuccess
            }
            return false
        }.count
    }
    
    private var averageCPUUsage: Double {
        let vpsWithSystemInfo = vpsManager.vpsInstances.compactMap { $0.systemInfo }
        guard !vpsWithSystemInfo.isEmpty else { return 0.0 }
        
        // 注意：SystemInfo 中没有 CPU 使用率，这里返回 0
        // 实际应用中需要扩展 SystemInfo 模型
        return 0.0
    }
    
    private var averageMemoryUsage: Double {
        let vpsWithSystemInfo = vpsManager.vpsInstances.compactMap { $0.systemInfo }
        guard !vpsWithSystemInfo.isEmpty else { return 0.0 }
        
        let totalMemory = vpsWithSystemInfo.reduce(0.0) { $0 + $1.memoryUsage }
        return totalMemory / Double(vpsWithSystemInfo.count)
    }
    
    // MARK: - Private Methods
    
    private func refreshAllData() {
        isLoading = true
        
        Task {
            await vpsManager.testAllConnections()
            
            // 并发刷新所有VPS的系统信息
            await withTaskGroup(of: Void.self) { group in
                for vps in vpsManager.vpsInstances {
                    group.addTask {
                        let testResult = await self.vpsManager.testConnection(for: vps)
                        if testResult.sshSuccess {
                            _ = try? await self.vpsManager.getSystemInfo(for: vps)
                        }
                    }
                }
            }
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func startAutoRefresh() {
        guard isAutoRefresh else { return }
        
        Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { _ in
            refreshAllData()
        }
    }
    
    private func stopAutoRefresh() {
        // 停止定时器
    }
}

// MARK: - Overview Card

struct OverviewCard: View {
    let title: String
    let value: String
    let total: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Spacer()
                
                if !total.isEmpty {
                    Text(total)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - VPS Monitoring Card

struct VPSMonitoringCard: View {
    let vps: VPSInstance
    @ObservedObject var vpsManager: VPSManager
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // 头部信息
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vps.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(vps.host)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // 连接状态指示器
                    HStack(spacing: 6) {
                        if vpsManager.isConnectionTesting(for: vps) {
                            ProgressView()
                                .scaleEffect(0.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        } else {
                            Circle()
                                .fill(connectionStatusColor)
                                .frame(width: 8, height: 8)
                        }
                        
                        Text(connectionStatusText)
                            .font(.caption)
                            .foregroundColor(connectionStatusColor)
                    }
                }
                
                // 性能指标
                if let systemInfo = vps.systemInfo {
                    HStack(spacing: 16) {
                        PerformanceIndicator(
                            title: "CPU",
                            value: "\(systemInfo.cpuCores)核",
                            icon: "cpu",
                            color: .blue
                        )
                        
                        PerformanceIndicator(
                            title: "内存",
                            value: "\(Int(systemInfo.memoryUsage))%",
                            icon: "memorychip",
                            color: memoryUsageColor(systemInfo.memoryUsage)
                        )
                        
                        PerformanceIndicator(
                            title: "磁盘",
                            value: "\(Int(systemInfo.diskUsage))%",
                            icon: "externaldrive",
                            color: diskUsageColor(systemInfo.diskUsage)
                        )
                    }
                } else {
                    HStack {
                        Text(.noSystemInfo)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(String(.refresh)) {
                            Task {
                                _ = try? await vpsManager.getSystemInfo(for: vps)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var connectionStatusColor: Color {
        if let testResult = vpsManager.connectionTestResults[vps.id] {
            return testResult.sshSuccess ? .green : .red
        }
        return .gray
    }
    
    private var connectionStatusText: String {
        if let testResult = vpsManager.connectionTestResults[vps.id] {
            return testResult.sshSuccess ? "在线" : "离线"
        }
        return "未知"
    }
    
    private func memoryUsageColor(_ usage: Double) -> Color {
        if usage < 70 { return .green }
        if usage < 90 { return .orange }
        return .red
    }
    
    private func diskUsageColor(_ usage: Double) -> Color {
        if usage < 80 { return .green }
        if usage < 95 { return .orange }
        return .red
    }
}

// MARK: - Performance Indicator

struct PerformanceIndicator: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Monitoring Settings View

struct MonitoringSettingsView: View {
    @Binding var refreshInterval: TimeInterval
    @Binding var isAutoRefresh: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("自动刷新") {
                    Toggle("启用自动刷新", isOn: $isAutoRefresh)
                    
                    if isAutoRefresh {
                        Picker("刷新间隔", selection: $refreshInterval) {
                            Text("15\(String(.secondsShort))").tag(TimeInterval(15))
                            Text("30\(String(.secondsShort))").tag(TimeInterval(30))
                            Text("1\(String(.minutesShort))").tag(TimeInterval(60))
                            Text("5\(String(.minutesShort))").tag(TimeInterval(300))
                        }
                    }
                }
                
                Section("说明") {
                    Text(.autoRefreshDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Monitoring Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - VPS Monitoring Detail View

struct VPSMonitoringDetailView: View {
    let vps: VPSInstance
    @ObservedObject var vpsManager: VPSManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTimeRange: TimeRange = .hour
    @State private var showingCharts = true
    
    enum TimeRange: String, CaseIterable {
        case hour = "1小时"
        case day = "24小时"
        case week = "7天"
        case month = "30天"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // VPS 信息卡片
                    vpsInfoCard
                    
                    // 时间范围选择器
                    timeRangeSelector
                    
                    // 性能图表
                    if showingCharts {
                        performanceCharts
                    }
                    
                    // 系统信息
                    systemInfoSection
                    
                    // 服务状态
                    servicesSection
                }
                .padding()
            }
            .navigationTitle(vps.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCharts.toggle() }) {
                        Image(systemName: showingCharts ? "chart.bar" : "chart.bar.fill")
                    }
                }
            }
        }
    }
    
    // MARK: - VPS Info Card
    
    private var vpsInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vps.displayName)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(vps.host)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 连接状态
                HStack(spacing: 6) {
                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(connectionStatusText)
                        .font(.caption)
                        .foregroundColor(connectionStatusColor)
                }
            }
            
            if let systemInfo = vps.systemInfo {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.cpu)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(.cpu, arguments: String(systemInfo.cpuCores))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.memory)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(formatBytes(systemInfo.memoryTotal))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.disk)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(formatBytes(systemInfo.diskTotal))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Time Range Selector
    
    private var timeRangeSelector: some View {
        HStack {
            Text(.timeRange)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Picker("时间范围", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    // MARK: - Performance Charts
    
    private var performanceCharts: some View {
        VStack(spacing: 16) {
            // CPU 使用率图表
            ChartCard(
                title: String(.cpuUsageChart),
                icon: "cpu",
                color: .blue
            ) {
                // 这里应该显示实际的 CPU 使用率数据
                Text(.cpuUsageChart)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 内存使用率图表
            ChartCard(
                title: "内存使用率",
                icon: "memorychip",
                color: .green
            ) {
                if let systemInfo = vps.systemInfo {
                    VStack(spacing: 8) {
                        HStack {
                            Text(.currentUsage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(systemInfo.memoryUsage))%")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        ProgressView(value: systemInfo.memoryUsage / 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: memoryUsageColor(systemInfo.memoryUsage)))
                    }
                } else {
                    Text(.noData)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 磁盘使用率图表
            ChartCard(
                title: "磁盘使用率",
                icon: "externaldrive",
                color: .orange
            ) {
                if let systemInfo = vps.systemInfo {
                    VStack(spacing: 8) {
                        HStack {
                            Text(.currentUsage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(systemInfo.diskUsage))%")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        ProgressView(value: systemInfo.diskUsage / 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: diskUsageColor(systemInfo.diskUsage)))
                    }
                } else {
                    Text(.noData)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - System Info Section
    
    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.systemInfo)
                .font(.headline)
                .fontWeight(.semibold)
            
            if let systemInfo = vps.systemInfo {
                VStack(spacing: 8) {
                    InfoRow(label: "操作系统", value: systemInfo.osName)
                    InfoRow(label: "内核版本", value: systemInfo.kernelVersion)
                    InfoRow(label: "CPU 型号", value: systemInfo.cpuModel)
                    InfoRow(label: "运行时间", value: formatUptime(systemInfo.uptime))
                    InfoRow(label: "负载", value: formatLoadAverage(systemInfo.loadAverage))
                }
                            } else {
                    Text(.noSystemInfo)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Services Section
    
    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.serviceStatus)
                .font(.headline)
                .fontWeight(.semibold)
            
            if vps.services.isEmpty {
                Text(.noServices)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(vps.services) { service in
                    ServiceStatusRow(service: service)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Computed Properties
    
    private var connectionStatusColor: Color {
        if let testResult = vpsManager.connectionTestResults[vps.id] {
            return testResult.sshSuccess ? .green : .red
        }
        return .gray
    }
    
    private var connectionStatusText: String {
        if let testResult = vpsManager.connectionTestResults[vps.id] {
            return testResult.sshSuccess ? "在线" : "离线"
        }
        return "未知"
    }
    
    private func memoryUsageColor(_ usage: Double) -> Color {
        if usage < 70 { return .green }
        if usage < 90 { return .orange }
        return .red
    }
    
    private func diskUsageColor(_ usage: Double) -> Color {
        if usage < 80 { return .green }
        if usage < 95 { return .orange }
        return .red
    }
    
    // MARK: - Helper Methods
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatUptime(_ uptime: TimeInterval) -> String {
        let days = Int(uptime) / 86400
        let hours = Int(uptime) % 86400 / 3600
        let minutes = Int(uptime) % 3600 / 60
        
        if days > 0 {
            return "\(days)天 \(hours)小时"
        } else if hours > 0 {
            return "\(hours)小时 \(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
    
    private func formatLoadAverage(_ loadAverage: [Double]) -> String {
        guard loadAverage.count >= 3 else {
            return "暂无数据"
        }
        
        let load1 = String(format: "%.2f", loadAverage[0])
        let load5 = String(format: "%.2f", loadAverage[1])
        let load15 = String(format: "%.2f", loadAverage[2])
        
        return "\(load1) \(load5) \(load15)"
    }
}

// MARK: - Chart Card

struct ChartCard<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            content
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Info Row
// InfoRow is already defined in SharedComponents.swift

// MARK: - Service Status Row

struct ServiceStatusRow: View {
    let service: VPSService
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(service.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(service.type.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Circle()
                    .fill(service.status.color)
                    .frame(width: 8, height: 8)
                
                Text(service.status.displayName)
                    .font(.caption)
                    .foregroundColor(service.status.color)
            }
        }
        .padding(.vertical, 4)
    }
}
