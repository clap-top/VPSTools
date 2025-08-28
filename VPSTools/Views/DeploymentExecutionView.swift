import SwiftUI
import Combine

// MARK: - Deployment Execution View

struct DeploymentExecutionView: View {
    let vps: VPSInstance
    let template: DeploymentTemplate
    let variables: [String: String]
    @ObservedObject var deploymentService: DeploymentService
    @Environment(\.dismiss) private var dismiss
    
    @State private var isExecuting = false
    @State private var currentTask: DeploymentTask?
    @State private var progressCancellable: AnyCancellable?
    
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
                // 设置初始状态
                isExecuting = true
                startDeployment()
            }
            .onDisappear {
                // 清理进度监听
                progressCancellable?.cancel()
                progressCancellable = nil
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
                InfoRow(label: "服务器", value: vps.displayName)
                InfoRow(label: "服务", value: template.name)
                InfoRow(label: "类型", value: template.serviceType.displayName)
                
                // 只显示关键的配置参数
                if let keyParams = getKeyParameters() {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("关键配置")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(keyParams, id: \.key) { param in
                            HStack {
                                Text(param.label)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(param.value)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
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
    
    /// 获取关键的配置参数，过滤掉技术性细节
    private func getKeyParameters() -> [(key: String, label: String, value: String)]? {
        var keyParams: [(key: String, label: String, value: String)] = []
        
        // 根据服务类型显示不同的关键参数
        switch template.serviceType {
        case .singbox:
            if let protocolType = variables["protocol"] {
                keyParams.append(("protocol", "协议", protocolType))
            }
            if let port = variables["port"] {
                keyParams.append(("port", "端口", port))
            }
            if let uuid = variables["uuid"] {
                keyParams.append(("uuid", "UUID", String(uuid.prefix(8)) + "..."))
            }
            if let password = variables["password"] ?? variables["hysteria_password"] ?? variables["hysteria2_password"] {
                keyParams.append(("password", "密码", String(password.prefix(8)) + "..."))
            }
            
        case .frp:
            if let bindPort = variables["bind_port"] {
                keyParams.append(("bind_port", "绑定端口", bindPort))
            }
            if let dashboardPort = variables["dashboard_port"] {
                keyParams.append(("dashboard_port", "管理端口", dashboardPort))
            }
            
        default:
            // 通用参数
            if let port = variables["port"] {
                keyParams.append(("port", "端口", port))
            }
        }
        
        return keyParams.isEmpty ? nil : keyParams
    }
    
    /// 获取进度描述
    private func getProgressDescription(_ progress: Double) -> String {
        switch progress {
        case 0.0..<0.1:
            return "准备中..."
        case 0.1..<0.2:
            return "连接服务器..."
        case 0.2..<0.3:
            return "检查环境..."
        case 0.3..<0.4:
            return "准备配置..."
        case 0.4..<0.6:
            return "执行部署..."
        case 0.6..<0.8:
            return "安装服务..."
        case 0.8..<0.9:
            return "启动服务..."
        case 0.9..<1.0:
            return "完成配置..."
        default:
            return "部署中..."
        }
    }
    
    // MARK: - Execution Status Section
    
    private var executionStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.executionStatus)
                .font(.headline)
                .fontWeight(.semibold)
            
            if let task = currentTask {
                VStack(spacing: 12) {
                    // 调试信息
                    #if DEBUG
                    Text("调试: 任务状态 = \(task.status.rawValue), 错误 = \(task.error ?? "无")")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    #endif
                    HStack {
                        Text(task.status.displayName)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(task.status.color)
                        
                        Spacer()
                        
                        if task.status == .running {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if task.status == .pending {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if task.status == .failed {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.title3)
                        }
                    }
                    
                    // 添加状态描述
                    if task.status == .pending {
                        Text("正在初始化部署任务...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    } else if task.status == .failed {
                        Text("部署失败，请检查配置参数")
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                    
                    if task.status == .running {
                        ProgressView(value: task.progress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        HStack {
                            Text("\(Int(task.progress * 100))%")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(getProgressDescription(task.progress))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let error = task.error {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            } else if isExecuting && currentTask == nil {
                VStack(spacing: 8) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("正在准备部署...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("请稍候，正在初始化部署环境")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("准备中...")
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
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(task.logs) { log in
                            LogRowView(log: log)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
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
    
    // MARK: - Progress Monitoring
    
    private func startProgressMonitoring(taskId: UUID) {
        let progressTimer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
        
        progressCancellable = progressTimer.sink { _ in
            if let updatedTask = deploymentService.deploymentTasks.first(where: { $0.id == taskId }) {
                let oldStatus = currentTask?.status
                currentTask = updatedTask
                
                // 打印状态变化
                if oldStatus != updatedTask.status {
                    print("任务状态变化: \(oldStatus?.rawValue ?? "nil") -> \(updatedTask.status.rawValue)")
                }
                
                // 如果任务状态变为 running，立即更新 UI
                if updatedTask.status == .running {
                    print("任务开始执行，进度: \(updatedTask.progress)")
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
                    print("任务创建成功，ID: \(task.id), 状态: \(task.status)")
                    // 立即开始监听任务状态变化
                    startProgressMonitoring(taskId: task.id)
                }
                
                // 检查任务状态，如果是失败状态，不执行部署
                if task.status == .failed {
                    print("任务创建失败，状态: \(task.status), 错误: \(task.error ?? "无")")
                    return
                }
                
                // 开始执行部署
                try await deploymentService.executeDeployment(task)
                
                // 停止进度监听
                await MainActor.run {
                    progressCancellable?.cancel()
                    progressCancellable = nil
                }
                
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
                    
                    // 停止进度监听
                    progressCancellable?.cancel()
                    progressCancellable = nil
                    
                    // 更新任务状态为失败
                    if let task = currentTask {
                        // 尝试从服务中获取更新后的任务
                        if let updatedTask = deploymentService.deploymentTasks.first(where: { $0.id == task.id }) {
                            currentTask = updatedTask
                            print("找到更新后的失败任务，状态: \(updatedTask.status)")
                        } else {
                            // 如果任务不在服务中，手动更新当前任务状态
                            var failedTask = task
                            failedTask.status = .failed
                            failedTask.error = error.localizedDescription
                            currentTask = failedTask
                            print("手动更新任务状态为失败")
                        }
                    } else {
                        print("当前没有任务，无法更新状态")
                    }
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
