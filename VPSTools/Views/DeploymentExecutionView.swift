import SwiftUI

// MARK: - Deployment Execution View

struct DeploymentExecutionView: View {
    let vps: VPSInstance
    let template: DeploymentTemplate
    let variables: [String: String]
    @ObservedObject var deploymentService: DeploymentService
    @Environment(\.dismiss) private var dismiss
    
    @State private var isExecuting = false
    @State private var currentTask: DeploymentTask?
    @State private var showingLogs = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 部署信息
                deploymentInfoSection
                
                // 执行状态
                executionStatusSection
                
                // 日志输出
                if let task = currentTask {
                    logsSection(task: task)
                }
                
                Spacer()
                
                // 操作按钮
                actionButtonsSection
            }
            .padding()
            .navigationTitle("部署执行")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                startDeployment()
            }
        }
    }
    
    // MARK: - Deployment Info Section
    
    private var deploymentInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.deploymentInfo)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(label: "VPS", value: vps.displayName)
                InfoRow(label: "模板", value: template.name)
                InfoRow(label: "服务类型", value: template.serviceType.displayName)
                
                if !variables.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.configParameters)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(Array(variables.keys.sorted()), id: \.self) { key in
                            if let value = variables[key] {
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
    
    // MARK: - Execution Status Section
    
    private var executionStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.executionStatus)
                .font(.headline)
                .fontWeight(.semibold)
            
            if let task = currentTask {
                VStack(spacing: 12) {
                    HStack {
                        Text(task.status.displayName)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(task.status.color)
                        
                        Spacer()
                        
                        if task.status == .running {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    
                    if task.status == .running {
                        ProgressView(value: task.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text("\(Int(task.progress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // 显示最新命令结果
                        if let lastResult = task.lastCommandResult, !lastResult.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(.latestCommandResult)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Text(lastResult)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                                    .padding(8)
                                    .background(Color(.tertiarySystemBackground))
                                    .cornerRadius(6)
                                    .lineLimit(3)
                            }
                            .padding(.top, 8)
                        }
                    }
                    
                    if let error = task.error {
                                            Text(.error, arguments: error)
                        .font(.caption)
                        .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(.preparing)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Logs Section
    
    private func logsSection(task: DeploymentTask) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(.executionLog)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("查看全部") {
                    showingLogs = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(task.logs.suffix(10)) { log in
                        LogRowView(log: log)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingLogs) {
            DeploymentLogsView(task: task)
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if let task = currentTask {
                switch task.status {
                case .running:
                    Button("取消部署") {
                        cancelDeployment()
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
                    
                case .completed:
                    Button("完成") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    
                case .failed:
                    VStack(spacing: 8) {
                        Button("重试") {
                            retryDeployment()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("关闭") {
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                default:
                    Button("关闭") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func startDeployment() {
        Task {
            do {
                let task = try await deploymentService.createDeploymentFromTemplate(
                    vpsId: vps.id,
                    templateId: template.id,
                    variables: variables
                )
                
                await MainActor.run {
                    currentTask = task
                }
                
                // 监听任务进度更新
                let taskId = task.id
                let progressTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
                
                let progressCancellable = progressTimer.sink { _ in
                    if let updatedTask = deploymentService.deploymentTasks.first(where: { $0.id == taskId }) {
                        Task { @MainActor in
                            currentTask = updatedTask
                        }
                    }
                }
                
                try await deploymentService.executeDeployment(task)
                
                // 停止进度监听
                progressCancellable.cancel()
                
                await MainActor.run {
                    // 更新任务状态
                    if let updatedTask = deploymentService.deploymentTasks.first(where: { $0.id == task.id }) {
                        currentTask = updatedTask
                    }
                }
            } catch {
                await MainActor.run {
                    // 处理错误
                    print("部署失败: \(error)")
                }
            }
        }
    }
    
    private func cancelDeployment() {
        guard let task = currentTask else { return }
        
        Task {
            try await deploymentService.cancelDeployment(task)
            await MainActor.run {
                // 更新任务状态
                if let updatedTask = deploymentService.deploymentTasks.first(where: { $0.id == task.id }) {
                    currentTask = updatedTask
                }
            }
        }
    }
    
    private func retryDeployment() {
        guard let task = currentTask else { return }
        
        Task {
            do {
                try await deploymentService.executeDeployment(task)
                await MainActor.run {
                    // 更新任务状态
                    if let updatedTask = deploymentService.deploymentTasks.first(where: { $0.id == task.id }) {
                        currentTask = updatedTask
                    }
                }
            } catch {
                await MainActor.run {
                    print("重试失败: \(error)")
                }
            }
        }
    }
}





// MARK: - Preview

struct DeploymentExecutionView_Previews: PreviewProvider {
    static var previews: some View {
        DeploymentExecutionView(
            vps: VPSInstance(name: "测试 VPS", host: "192.168.1.100", username: "root"),
            template: DeploymentTemplate(
                name: "测试模板",
                description: "测试描述",
                serviceType: .singbox,
                category: .proxy,
                commands: ["echo 'test'"],
                configTemplate: "",
                serviceTemplate: ""
            ),
            variables: [:],
            deploymentService: DeploymentService(vpsManager: VPSManager())
        )
    }
}
