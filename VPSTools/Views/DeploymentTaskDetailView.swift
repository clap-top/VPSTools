import SwiftUI

// MARK: - Deployment Task Detail View

struct DeploymentTaskDetailView: View {
    let task: DeploymentTask
    @ObservedObject var vpsManager: VPSManager
    @ObservedObject var deploymentService: DeploymentService
    @Environment(\.dismiss) private var dismiss
    @State private var isRetrying = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 任务信息
                    taskInfoSection
                    
                    // 模板信息（如果有）
                    if task.templateId != nil {
                        templateInfoSection
                    }
                    
                    // VPS 信息
                    vpsInfoSection
                    
                    // 执行状态
                    executionStatusSection
                    
                    // 日志列表
                    logsSection
                }
                .padding()
            }
            .navigationTitle("部署任务详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("返回") {
//                        dismiss()
//                    }
//                }
                if task.status == .failed || task.status == .cancelled {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            if task.status == .failed || task.status == .cancelled {
                                Button(isRetrying ? "执行中..." : "重新执行") {
                                    Task {
                                        await retryDeployment()
                                    }
                                }
                                .disabled(isRetrying)
                            }
                            
                            //                        Button("复制配置") {
                            //                            copyTaskConfiguration()
                            //                        }
                            //
                            //                        Button("删除任务") {
                            //                            showingDeleteConfirmation = true
                            //                        }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .alert("错误", isPresented: $showingErrorAlert) {
            Button("确定") { }
        } message: {
            Text(errorMessage)
        }
        .alert("成功", isPresented: $showingSuccessAlert) {
            Button("确定") { }
        } message: {
            Text(successMessage)
        }
        .confirmationDialog("确认删除", isPresented: $showingDeleteConfirmation) {
            Button("删除", role: .destructive) {
                deleteTask()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要删除这个部署任务吗？此操作无法撤销。")
        }
    }
    
    // MARK: - Task Info Section
    
    private var taskInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("任务信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(label: "任务 ID", value: task.id.uuidString.prefix(8).description)
                
                if let startedAt = task.startedAt {
                    InfoRow(label: "开始时间", value: startedAt.formatted())
                }
                
                if let completedAt = task.completedAt {
                    InfoRow(label: "完成时间", value: completedAt.formatted())
                }
                
                if let startedAt = task.startedAt, let completedAt = task.completedAt {
                    let duration = completedAt.timeIntervalSince(startedAt)
                    InfoRow(label: "执行时长", value: formatDuration(duration))
                }
                
                if !task.variables.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("配置参数")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(Array(task.variables.keys.sorted()), id: \.self) { key in
                            if let value = task.variables[key] {
                                HStack {
                                    Text(key)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(value)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Template Info Section
    
    private var templateInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("部署模板")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let templateId = task.templateId,
               let template = deploymentService.templates.first(where: { $0.id == templateId }) {
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(template.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(template.serviceType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(template.serviceType.category == .proxy ? Color.blue : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    
                    if !template.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(template.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("模板不存在或已被删除")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - VPS Info Section
    
    private var vpsInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("目标 VPS")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let vps = vpsManager.vpsInstances.first(where: { $0.id == task.vpsId }) {
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vps.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
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
                                    .fill(connectionStatusColor(for: vps))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                    
                    if let systemInfo = vps.systemInfo {
                        HStack {
                            Text("内存: \(Int(systemInfo.memoryUsage))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("磁盘: \(Int(systemInfo.diskUsage))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("VPS 不存在或已被删除")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Execution Status Section
    
    private var executionStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("执行状态")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Text(task.status.displayName)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(task.status.color)
                    
                    Spacer()
                    
                    Image(systemName: task.status.icon)
                        .font(.title2)
                        .foregroundColor(task.status.color)
                }
                
                ProgressView(value: task.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text("\(Int(task.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let error = task.error {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("错误信息")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Logs Section
    
    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("执行日志")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(task.logs.count) 条")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if task.logs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("暂无日志")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(task.logs) { log in
                        LogRowView(log: log)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Private Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
    
    private func connectionStatusColor(for vps: VPSInstance) -> Color {
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
    
    // MARK: - Action Methods
    
    private func retryDeployment() async {
        isRetrying = true
        defer { isRetrying = false }
        
        do {
            try await deploymentService.executeDeployment(task)
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
    
    private func copyTaskConfiguration() {
        var configText = "部署任务配置\n"
        configText += "任务 ID: \(task.id.uuidString)\n"
        configText += "VPS ID: \(task.vpsId.uuidString)\n"
        
        if let templateId = task.templateId {
            configText += "模板 ID: \(templateId.uuidString)\n"
        }
        
        if let customCommands = task.customCommands {
            configText += "自定义命令:\n"
            for command in customCommands {
                configText += "  \(command)\n"
            }
        }
        
        configText += "变量:\n"
        for (key, value) in task.variables {
            configText += "  \(key): \(value)\n"
        }
        
        UIPasteboard.general.string = configText
        successMessage = "配置已复制到剪贴板"
        showingSuccessAlert = true
    }
    
    private func deleteTask() {
        // 从 deploymentService 中删除任务
        deploymentService.deleteTask(task.id)
        dismiss()
    }
}



// MARK: - Preview

struct DeploymentTaskDetailView_Previews: PreviewProvider {
    static var previews: some View {
        DeploymentTaskDetailView(
            task: DeploymentTask(
                vpsId: UUID(),
                customCommands: ["echo 'test'", "whoami"],
                variables: ["port": "8080", "password": "test123"]
            ),
            vpsManager: VPSManager(),
            deploymentService: DeploymentService(vpsManager: VPSManager())
        )
    }
}
