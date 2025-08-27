import SwiftUI

// MARK: - Home View

struct HomeView: View {
    @ObservedObject var vpsManager: VPSManager
    @ObservedObject var deploymentService: DeploymentService
    @State private var selectedVPS: VPSInstance?
    @State private var selectedDeploymentTask: DeploymentTask?
    @State private var showingAddVPS = false
    @State private var showingDeployment = false
    @State private var showingMonitoring = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {      
                    // 快速统计
                    statisticsSection
                    
                    // VPS 状态概览
                    vpsOverviewSection
                    
                    // 最近部署
                    recentDeploymentsSection
                }
                .padding()
            }
            .navigationTitle(Text(.homeViewTitle))
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await refreshData()
            }
            .sheet(item: $selectedVPS, onDismiss: {
                selectedVPS = nil
            }, content:  {  vps in
                QuickDeployView(vps: vps, vpsManager: vpsManager, deploymentService: deploymentService)
            })
            .sheet(isPresented: $showingAddVPS) {
                AddVPSView(vpsManager: vpsManager)
            }
            .sheet(isPresented: $showingDeployment) {
                DeploymentView(vpsManager: vpsManager, deploymentService: deploymentService)
            }
            .sheet(isPresented: $showingMonitoring) {
                MonitoringView(vpsManager: vpsManager)
            }
            .sheet(item: $selectedDeploymentTask, onDismiss: {
                selectedDeploymentTask = nil
            }, content: { task in
                DeploymentTaskDetailView(task: task, vpsManager: vpsManager, deploymentService: deploymentService)
            })
            .onAppear {
                // 只在需要时进行初始连接检测
                if vpsManager.needsInitialConnectionTest() {
                    Task {
                        await refreshData()
                    }
                }
            }
        }
    }
    
    // MARK: - Welcome Section
    
    private var welcomeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(.welcomeBack)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(.manageVPSServers)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await refreshData()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                }
                .disabled(isLoading)
            }
            
            // 快速状态指示器
            if !vpsManager.vpsInstances.isEmpty {
                HStack(spacing: 16) {
                    StatusIndicator(
                        title: "在线",
                        count: onlineVPSCount,
                        total: vpsManager.vpsInstances.count,
                        color: .green
                    )
                    
                    StatusIndicator(
                        title: "离线",
                        count: offlineVPSCount,
                        total: vpsManager.vpsInstances.count,
                        color: .red
                    )
                    
                    StatusIndicator(
                        title: "服务",
                        count: runningServicesCount,
                        total: totalServicesCount,
                        color: .blue
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        HStack(spacing: 16) {
            StatCard(
                title: LocalizationManager.shared.localizedString(.vpsTotal),
                value: "\(vpsManager.vpsInstances.count)",
                icon: "server.rack",
                color: .blue,
                action: { showingAddVPS = true }
            )
            
            StatCard(
                title: LocalizationManager.shared.localizedString(.onlineVPS),
                value: "\(onlineVPSCount)",
                icon: "checkmark.circle",
                color: .green,
                action: { /* 可以导航到在线VPS列表 */ }
            )
            
            StatCard(
                title: LocalizationManager.shared.localizedString(.deploymentTasks),
                value: "\(deploymentService.deploymentTasks.count)",
                icon: "brain.head.profile",
                color: .purple,
                action: { showingDeployment = true }
            )
       
        }
    }
    
    // MARK: - VPS Overview Section
    
    private var vpsOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(.vpsOverview)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink(destination: VPSManagementView(vpsManager: vpsManager)) {
                    Text(.viewAll)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if vpsManager.vpsInstances.isEmpty {
                EmptyVPSState {
                    showingAddVPS = true
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(vpsManager.vpsInstances.prefix(3)) { vps in
                            VPSOverviewCard(vps: vps, vpsManager: vpsManager) {
                                selectedVPS = vps
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Recent Deployments Section
    
    private var recentDeploymentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(.recentDeployments)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink(destination: DeploymentView(vpsManager: vpsManager, deploymentService: deploymentService)) {
                    Text(.viewAll)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if deploymentService.deploymentTasks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text(.noDeploymentRecords)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("Start Deployment") {
                        showingDeployment = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 12) {
                    ForEach(recentDeployments) { task in
                        DeploymentTaskRow(
                            task: task,
                            vpsManager: vpsManager,
                            deploymentService: deploymentService
                        ) {
                            selectedDeploymentTask = task
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - System Status Section
    
    private var systemStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(.systemStatus)
                .font(.headline)
                .fontWeight(.semibold)
            
            if vpsManager.vpsInstances.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text(.noSystemStatusData)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                VStack(spacing: 12) {
                    // 系统健康度
                    SystemHealthCard(healthScore: systemHealthScore)
                    
                    // 资源使用情况
                    ResourceUsageCard(
                        cpuUsage: averageCPUUsage,
                        memoryUsage: averageMemoryUsage,
                        diskUsage: averageDiskUsage
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Computed Properties
    
    private var onlineVPSCount: Int {
        vpsManager.vpsInstances.filter { vps in
            // 优先使用连接测试结果
            if let testResult = vpsManager.connectionTestResults[vps.id] {
                return testResult.sshSuccess
            }
            
            // 如果没有测试结果，使用最后连接时间
            guard let lastConnected = vps.lastConnected else { return false }
            return Date().timeIntervalSince(lastConnected) < 300 // 5 minutes
        }.count
    }
    
    private var offlineVPSCount: Int {
        vpsManager.vpsInstances.count - onlineVPSCount
    }
    
    private var runningServicesCount: Int {
        vpsManager.vpsInstances.reduce(into: 0) { total, vps in
            total += vps.services.filter { $0.status == .running }.count
        }
    }
    
    private var totalServicesCount: Int {
        vpsManager.vpsInstances.reduce(into: 0) { total, vps in
            total += vps.services.count
        }
    }
    
    private var systemHealthScore: Double {
        let vpsWithSystemInfo = vpsManager.vpsInstances.filter { $0.systemInfo != nil }
        guard !vpsWithSystemInfo.isEmpty else { return 0.0 }
        
        let totalHealth = vpsWithSystemInfo.reduce(0.0) { total, vps in
            guard let systemInfo = vps.systemInfo else { return total }
            
            // 计算健康度：内存、磁盘使用率的综合评分（SystemInfo 中没有 CPU 使用率）
            let memoryHealth = max(0, 100 - systemInfo.memoryUsage) / 100
            let diskHealth = max(0, 100 - systemInfo.diskUsage) / 100
            
            return total + (memoryHealth + diskHealth) / 2
        }
        
        return (totalHealth / Double(vpsWithSystemInfo.count)) * 100
    }
    
    private var averageCPUUsage: Double {
        // SystemInfo 中没有 CPU 使用率，返回 0
        return 0.0
    }
    
    private var averageMemoryUsage: Double {
        let vpsWithSystemInfo = vpsManager.vpsInstances.compactMap { $0.systemInfo }
        guard !vpsWithSystemInfo.isEmpty else { return 0.0 }
        
        let totalMemory = vpsWithSystemInfo.reduce(0.0) { $0 + $1.memoryUsage }
        return totalMemory / Double(vpsWithSystemInfo.count)
    }
    
    private var averageDiskUsage: Double {
        let vpsWithSystemInfo = vpsManager.vpsInstances.compactMap { $0.systemInfo }
        guard !vpsWithSystemInfo.isEmpty else { return 0.0 }
        
        let totalDisk = vpsWithSystemInfo.reduce(0.0) { $0 + $1.diskUsage }
        return totalDisk / Double(vpsWithSystemInfo.count)
    }
    
    private var recentDeployments: [DeploymentTask] {
        return deploymentService.deploymentTasks
            .sorted { ($0.startedAt ?? Date.distantPast) > ($1.startedAt ?? Date.distantPast) }
            .prefix(3)
            .map { $0 }
    }
    
    // MARK: - Private Methods
    
    private func refreshData() async {
        isLoading = true
        defer { isLoading = false }
        
        // 强制刷新所有连接测试（清除缓存）
        await vpsManager.testAllConnections()
        
        // 并发刷新所有VPS的系统信息
        await withTaskGroup(of: Void.self) { group in
            for vps in vpsManager.vpsInstances {
                group.addTask {
                    // 检查连接状态
                    let testResult = await self.vpsManager.testConnection(for: vps)
                    if testResult.sshSuccess {
                        // 获取系统信息
                        _ = try? await self.vpsManager.getSystemInfo(for: vps)
                    }
                }
            }
        }
        
        // 标记初始化完成（如果还没有标记的话）
        vpsManager.markInitialConnectionTestComplete()
        
        // 强制UI更新
        await MainActor.run {
            vpsManager.objectWillChange.send()
        }
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatusIndicator: View {
    let title: String
    let count: Int
    let total: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if total > 0 {
                ProgressView(value: Double(count), total: Double(total))
                    .progressViewStyle(LinearProgressViewStyle(tint: color))
                    .frame(height: 2)
            }
        }
    }
}

struct EmptyVPSState: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "server.rack")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(.noVPSYet)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(.addFirstVPSServer)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Button(String(.addVPS), action: action)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

struct VPSOverviewCard: View {
    let vps: VPSInstance
    let vpsManager: VPSManager
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
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
                    }
                }
                
                // 服务状态
                if !vps.services.isEmpty {
                    HStack {
                        Text("\(String(.services)): \(vps.services.filter { $0.status == .running }.count)/\(vps.services.count)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                
                // 系统信息（如果有）
                if let systemInfo = vps.systemInfo {
                    VStack(spacing: 4) {
                        HStack {
                            Text("\(String(.memory)): \(Int(systemInfo.memoryUsage))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(String(.disk)): \(Int(systemInfo.diskUsage))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: systemInfo.memoryUsage / 100)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .frame(height: 2)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .frame(width: 200)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var connectionStatusColor: Color {
        // 优先使用连接测试结果
        if let testResult = vpsManager.connectionTestResults[vps.id] {
            if testResult.sshSuccess {
                return .green
            } else {
                return .red
            }
        }
        
        // 如果没有测试结果，使用最后连接时间
        if let lastConnected = vps.lastConnected {
            let timeSinceLastConnection = Date().timeIntervalSince(lastConnected)
            if timeSinceLastConnection < 300 { // 5 minutes
                return .green
            } else if timeSinceLastConnection < 3600 { // 1 hour
                return .orange
            } else {
                return .red
            }
        }
        
        return .gray
    }
}

struct DeploymentTaskRow: View {
    let task: DeploymentTask
    let vpsManager: VPSManager
    let deploymentService: DeploymentService
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 状态图标
                Image(systemName: statusIcon)
                    .font(.title3)
                    .foregroundColor(statusColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(taskName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(taskDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(statusColor)
                    
                    if let startedAt = task.startedAt {
                        Text(startedAt.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var taskName: String {
        if let templateId = task.templateId,
           let template = deploymentService.templates.first(where: { $0.id == templateId }) {
            return template.name
        }
        return LocalizationManager.shared.localizedString(.customDeploymentStatus)
    }
    
    private var taskDescription: String {
        if let vps = vpsManager.vpsInstances.first(where: { $0.id == task.vpsId }) {
            return "\(LocalizationManager.shared.localizedString(.deployTo)) \(vps.displayName)"
        }
        return LocalizationManager.shared.localizedString(.unknownVPS)
    }
    
    private var statusIcon: String {
        switch task.status {
        case .pending:
            return "clock"
        case .running:
            return "play.circle"
        case .completed:
            return "checkmark.circle"
        case .failed:
            return "xmark.circle"
        case .cancelled:
            return "stop.circle"
        }
    }
    
    private var statusColor: Color {
        switch task.status {
        case .pending:
            return .orange
        case .running:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        case .cancelled:
            return .gray
        }
    }
    
    private var statusText: String {
        switch task.status {
        case .pending:
            return LocalizationManager.shared.localizedString(.waiting)
        case .running:
            return LocalizationManager.shared.localizedString(.running)
        case .completed:
            return LocalizationManager.shared.localizedString(.completed)
        case .failed:
            return LocalizationManager.shared.localizedString(.failed)
        case .cancelled:
            return LocalizationManager.shared.localizedString(.cancelled)
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SystemHealthCard: View {
    let healthScore: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundColor(healthColor)
                
                Text(.systemHealth)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(Int(healthScore))%")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(healthColor)
            }
            
            ProgressView(value: healthScore / 100)
                .progressViewStyle(LinearProgressViewStyle(tint: healthColor))
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private var healthColor: Color {
        if healthScore >= 80 {
            return .green
        } else if healthScore >= 60 {
            return .orange
        } else {
            return .red
        }
    }
}

struct ResourceUsageCard: View {
    let cpuUsage: Double
    let memoryUsage: Double
    let diskUsage: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.resourceUsage)
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(spacing: 8) {
                ResourceBar(title: "CPU", usage: cpuUsage, color: .blue)
                ResourceBar(title: String(.memory), usage: memoryUsage, color: .green)
                ResourceBar(title: String(.disk), usage: diskUsage, color: .orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

struct ResourceBar: View {
    let title: String
    let usage: Double
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(usage))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            ProgressView(value: usage / 100)
                .progressViewStyle(LinearProgressViewStyle(tint: color))
                .frame(height: 4)
        }
    }
}

// MARK: - Preview

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(
            vpsManager: VPSManager(),
            deploymentService: DeploymentService(vpsManager: VPSManager())
        )
    }
}
