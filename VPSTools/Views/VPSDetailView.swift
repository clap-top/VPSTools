import SwiftUI

// MARK: - VPS Detail View

struct VPSDetailView: View {
    let vps: VPSInstance
    @ObservedObject var vpsManager: VPSManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoading = false
    @State private var showingDeployment = false
    @State private var showingSingBoxInstall = false
    @State private var showingDeleteConfirmation = false
    @State private var showingEditVPS = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 连接状态
                    connectionStatusSection
                    
                    // 基本信息
                    basicInfoSection
                    
                    // 系统信息
                    if let systemInfo = vps.systemInfo {
                        systemInfoSection(systemInfo: systemInfo)
                    } else {
                        noSystemInfoSection
                    }
                    
                    // 服务列表
                    servicesSection
                    
                    // 连接测试
                    connectionTestSection
                    
                    // 操作按钮
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle(vps.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDeployment) {
                DeploymentView(
                    vpsManager: vpsManager, 
                    deploymentService: DeploymentService(vpsManager: vpsManager),
                    preSelectedVPS: vps
                )
            }
            .sheet(isPresented: $showingEditVPS) {
                EditVPSView(vps: vps, vpsManager: vpsManager)
            }
        }
    }
    
    // MARK: - Connection Status Section
    
    private var connectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(.connectionStatus)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // 连接状态指示器
                connectionStatusIndicator
            }
            
            VStack(spacing: 8) {
                InfoRow(label: "主机", value: "\(vps.host):\(vps.port)")
                InfoRow(label: "用户", value: vps.username)
                
                if let lastConnected = vps.lastConnected {
                    InfoRow(label: "最后连接", value: lastConnected.formatted(.relative(presentation: .named)))
                } else {
                    InfoRow(label: "连接状态", value: "从未连接")
                }
                
                // SSH 连接提示
                if vps.systemInfo == nil && vpsManager.connectionTestResults[vps.id] == nil {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(.needSSHConnection)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        
                        Button("立即连接") {
                            Task {
                                isLoading = true
                                _ = await vpsManager.testConnection(for: vps)
                                if vpsManager.connectionTestResults[vps.id]?.sshSuccess == true {
                                    _ = try? await vpsManager.getSystemInfo(for: vps)
                                }
                                isLoading = false
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var connectionStatusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connectionStatusColor)
                .frame(width: 8, height: 8)
            
            Text(connectionStatusText)
                .font(.caption)
                .foregroundColor(connectionStatusColor)
        }
    }
    
    private var connectionStatusColor: Color {
        if let testResult = vpsManager.connectionTestResults[vps.id] {
            return testResult.sshSuccess ? .green : .red
        } else if let lastConnected = vps.lastConnected {
            let timeSinceLastConnection = Date().timeIntervalSince(lastConnected)
            if timeSinceLastConnection < 300 { // 5 minutes
                return .green
            } else if timeSinceLastConnection < 3600 { // 1 hour
                return .orange
            } else {
                return .red
            }
        } else {
            return .gray
        }
    }
    
    private var connectionStatusText: String {
        if let testResult = vpsManager.connectionTestResults[vps.id] {
            return testResult.sshSuccess ? "已连接" : "连接失败"
        } else if let lastConnected = vps.lastConnected {
            let timeSinceLastConnection = Date().timeIntervalSince(lastConnected)
            if timeSinceLastConnection < 300 { // 5 minutes
                return "在线"
            } else if timeSinceLastConnection < 3600 { // 1 hour
                return "最近在线"
            } else {
                return "离线"
            }
        } else {
            return "未知"
        }
    }
    
    // MARK: - No System Info Section
    
    private var noSystemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.systemInfo)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Image(systemName: "server.rack")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text(.noSystemInfo)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("获取系统信息") {
                    Task {
                        isLoading = true
                        _ = try? await vpsManager.getSystemInfo(for: vps)
                        isLoading = false
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Basic Info Section
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.basicInfo)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(label: "名称", value: vps.displayName)
                InfoRow(label: "分组", value: vps.group.isEmpty ? "默认" : vps.group)
                
                if !vps.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(.tags)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(vps.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.accentColor.opacity(0.1))
                                        .foregroundColor(.accentColor)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                InfoRow(label: "创建时间", value: vps.createdAt.formatted(.dateTime.month().day().hour().minute()))
                InfoRow(label: "更新时间", value: vps.updatedAt.formatted(.dateTime.month().day().hour().minute()))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - System Info Section
    
    private func systemInfoSection(systemInfo: SystemInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.systemInfo)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // 操作系统信息
                VStack(alignment: .leading, spacing: 8) {
                    Text(.operatingSystem)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(spacing: 4) {
                        InfoRow(label: "系统", value: systemInfo.osName)
                        InfoRow(label: "内核", value: systemInfo.kernelVersion)
                        InfoRow(label: "CPU", value: systemInfo.cpuModel)
                        InfoRow(label: "核心数", value: "\(systemInfo.cpuCores)")
                    }
                }
                
                Divider()
                
                // 资源使用情况
                VStack(alignment: .leading, spacing: 8) {
                    Text(.resourceUsage)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(spacing: 12) {
                        // 内存使用
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(.memory)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(systemInfo.memoryUsage))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView(value: systemInfo.memoryUsage / 100)
                                .progressViewStyle(LinearProgressViewStyle(tint: systemInfo.memoryUsage > 80 ? .red : .blue))
                        }
                        
                        // 磁盘使用
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(.disk)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(systemInfo.diskUsage))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            ProgressView(value: systemInfo.diskUsage / 100)
                                .progressViewStyle(LinearProgressViewStyle(tint: systemInfo.diskUsage > 80 ? .red : .green))
                        }
                        
                        // 负载平均值
                        if !systemInfo.loadAverage.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(.loadAverage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 12) {
                                    ForEach(Array(systemInfo.loadAverage.enumerated()), id: \.offset) { index, load in
                                        VStack(spacing: 2) {
                                            Text(String(format: "%.2f", load))
                                                .font(.caption)
                                                .fontWeight(.medium)
                                            Text(index == 0 ? "1分钟" : index == 1 ? "5分钟" : "15分钟")
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                Divider()
                
                // 运行时间
                VStack(alignment: .leading, spacing: 4) {
                    Text(.uptime)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(formatUptime(systemInfo.uptime))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Services Section
    
    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.serviceList)
                .font(.headline)
                .fontWeight(.semibold)
            
            if vps.services.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text(.noServices)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("部署服务") {
                        showingDeployment = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(vps.services) { service in
                        ServiceRowView(service: service)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Connection Test Section
    
    private var connectionTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.connectionTest)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                if let testResult = vpsManager.connectionTestResults[vps.id] {
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: testResult.pingSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(testResult.pingSuccess ? .green : .red)
                            Text(.pingTest)
                            Spacer()
                            Text(testResult.pingSuccess ? "成功" : "失败")
                                .font(.caption)
                                .foregroundColor(testResult.pingSuccess ? .green : .red)
                        }
                        
                        HStack {
                            Image(systemName: testResult.sshSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(testResult.sshSuccess ? .green : .red)
                            Text(.sshConnection)
                            Spacer()
                            Text(testResult.sshSuccess ? "成功" : "失败")
                                .font(.caption)
                                .foregroundColor(testResult.sshSuccess ? .green : .red)
                        }
                        
                        if let error = testResult.sshError {
                            Text(.error, arguments: error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                } else {
                    Text(.noConnectionTest)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Button("测试连接") {
                    Task {
                        _ = await vpsManager.testConnection(for: vps)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading || vpsManager.isConnectionTesting(for: vps))
                .overlay(
                    Group {
                        if vpsManager.isConnectionTesting(for: vps) {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                                            Text(.detecting)
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                    }
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button("部署服务") {
                    showingDeployment = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("获取系统信息") {
                    Task {
                        _ = try? await vpsManager.getSystemInfo(for: vps)
                    }
                }
                .buttonStyle(.bordered)
            }
                
            // 管理按钮
            HStack(spacing: 12) {
                Button("编辑 VPS") {
                    showingEditVPS = true
                }
                .buttonStyle(.bordered)
                
                Button("删除 VPS") {
                    showingDeleteConfirmation = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .alert("确认删除", isPresented: $showingDeleteConfirmation) {
                    Button("删除", role: .destructive) {
                        Task {
                            await vpsManager.deleteVPS(vps)
                        }
                        dismiss()
                    }
                    Button("取消", role: .cancel) { }
                } message: {
                    Text(.confirmDeleteVPS, arguments: vps.name)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func formatUptime(_ uptime: TimeInterval) -> String {
        let days = Int(uptime) / 86400
        let hours = Int(uptime) % 86400 / 3600
        let minutes = Int(uptime) % 3600 / 60
        
        if days > 0 {
            return "\(days)天 \(hours)小时 \(minutes)分钟"
        } else if hours > 0 {
            return "\(hours)小时 \(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}



struct ServiceRowView: View {
    let service: VPSService
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: service.type.icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(service.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let port = service.port {
                    Text(.port, arguments: String(port))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(service.status.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(service.status.color.opacity(0.1))
                    .foregroundColor(service.status.color)
                    .cornerRadius(4)
                
                Text(service.updatedAt.formatted(.relative(presentation: .named)))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }
}

// MARK: - Preview

struct VPSDetailView_Previews: PreviewProvider {
    static var previews: some View {
        VPSDetailView(
            vps: VPSInstance(
                name: "测试 VPS",
                host: "192.168.1.100",
                username: "root"
            ),
            vpsManager: VPSManager()
        )
    }
}
