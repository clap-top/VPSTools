import SwiftUI

// MARK: - Natural Language Deployment Execution View

struct NaturalLanguageDeploymentExecutionView: View {
    let vps: VPSInstance
    let description: String
    @ObservedObject var deploymentService: DeploymentService
    let preGeneratedPlan: DeploymentPlan?
    @Environment(\.dismiss) private var dismiss
    
    @State private var isExecuting = false
    @State private var currentTask: DeploymentTask?
    @State private var showingLogs = false
    @State private var generatedPlan: DeploymentPlan?
    @State private var showingPlanConfirmation = false
    
    init(vps: VPSInstance, description: String, deploymentService: DeploymentService, preGeneratedPlan: DeploymentPlan? = nil) {
        self.vps = vps
        self.description = description
        self.deploymentService = deploymentService
        self.preGeneratedPlan = preGeneratedPlan
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 部署信息
                deploymentInfoSection
                
                // AI 生成的计划
                if let plan = generatedPlan {
                    generatedPlanSection(plan: plan)
                }
                
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
            .navigationTitle("AI 部署执行")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let prePlan = preGeneratedPlan {
                    // 使用预生成的计划
                    generatedPlan = prePlan
                    showingPlanConfirmation = true
                } else {
                    // 生成新的部署计划
                    generateDeploymentPlan()
                }
            }
            .hideKeyboardOnTap()
            .sheet(isPresented: $showingPlanConfirmation) {
                if let plan = generatedPlan {
                    PlanConfirmationView(
                        vps: vps,
                        description: description,
                        plan: plan,
                        deploymentService: deploymentService
                    ) { confirmedPlan in
                        self.generatedPlan = confirmedPlan
                        self.showingPlanConfirmation = false
                        self.startDeployment()
                    }
                }
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
                InfoRow(label: "需求描述", value: description)
                
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(.purple)
                    Text("AI 智能分析")
                        .font(.subheadline)
                        .foregroundColor(.purple)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Generated Plan Section
    
    private func generatedPlanSection(plan: DeploymentPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.aiGeneratedPlan)
                .font(.headline)
                .fontWeight(.semibold)
            
            // 部署计划描述
            if let description = plan.description {
                VStack(alignment: .leading, spacing: 4) {
                    Text("部署说明")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                }
                .padding(.bottom, 8)
            }
            
            // 预计时间和要求
            HStack(spacing: 16) {
                if let estimatedTime = plan.estimatedTime {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("预计时间")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(estimatedTime)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                if let requirements = plan.requirements, !requirements.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("系统要求")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(requirements.count) 项要求")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            .padding(.bottom, 8)
            
            // 执行命令
            VStack(alignment: .leading, spacing: 8) {
                Text(.willExecuteFollowingCommands)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                ForEach(Array(plan.commands.enumerated()), id: \.offset) { index, command in
                    HStack(alignment: .top, spacing: 8) {
                        Text("\(index + 1).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .leading)
                        
                        Text(command)
                            .font(.caption)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(8)
            
            // 注意事项
            if let notes = plan.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("注意事项")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(note)
                                .font(.caption)
                                .foregroundColor(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
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
                    }
                    
                    if let error = task.error {
                        Text("错误: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            } else if generatedPlan == nil {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("AI 正在分析需求...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text("计划已生成，等待确认")
                        .font(.subheadline)
                        .foregroundColor(.green)
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
                Text("执行日志")
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
            } else if generatedPlan != nil {
                Button("开始部署") {
                    startDeployment()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExecuting)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func generateDeploymentPlan() {
        Task {
            do {
                let plan = try await deploymentService.generateDeploymentPlan(description: description, vps: vps)
                
                await MainActor.run {
                    self.generatedPlan = plan
                    self.showingPlanConfirmation = true
                }
            } catch {
                await MainActor.run {
                    print("生成部署计划失败: \(error)")
                }
            }
        }
    }
    
    private func startDeployment() {
        guard let plan = generatedPlan else { return }
        
        Task {
            do {
                // 传递已生成的部署计划，避免重复调用AI接口
                let task = try await deploymentService.createDeploymentFromNaturalLanguage(
                    vpsId: vps.id,
                    description: description,
                    deploymentPlan: plan
                )
                
                await MainActor.run {
                    currentTask = task
                }
                
                try await deploymentService.executeDeployment(task)
                
                await MainActor.run {
                    // 更新任务状态
                    if let updatedTask = deploymentService.deploymentTasks.first(where: { $0.id == task.id }) {
                        currentTask = updatedTask
                    }
                }
            } catch {
                await MainActor.run {
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

// MARK: - Plan Confirmation View

struct PlanConfirmationView: View {
    let vps: VPSInstance
    let description: String
    let plan: DeploymentPlan
    @ObservedObject var deploymentService: DeploymentService
    let onConfirm: (DeploymentPlan) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedCommands: [String]
    @State private var editedVariables: [String: String]
    
    init(vps: VPSInstance, description: String, plan: DeploymentPlan, deploymentService: DeploymentService, onConfirm: @escaping (DeploymentPlan) -> Void) {
        self.vps = vps
        self.description = description
        self.plan = plan
        self.deploymentService = deploymentService
        self.onConfirm = onConfirm
        self._editedCommands = State(initialValue: plan.commands)
        self._editedVariables = State(initialValue: plan.variables)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 部署信息
                VStack(alignment: .leading, spacing: 12) {
                    Text("确认部署计划")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    VStack(spacing: 8) {
                        InfoRow(label: "VPS", value: vps.displayName)
                        InfoRow(label: "需求描述", value: description)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // 命令列表
                VStack(alignment: .leading, spacing: 12) {
                    Text("执行命令")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    ForEach(Array(editedCommands.enumerated()), id: \.offset) { index, command in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("命令 \(index + 1)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Button("删除") {
                                    editedCommands.remove(at: index)
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                            
                            TextEditor(text: Binding(
                                get: { command },
                                set: { editedCommands[index] = $0 }
                            ))
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 60)
                            .padding(8)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                    
                    Button("添加命令") {
                        editedCommands.append("")
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                Spacer()
                
                // 操作按钮
                HStack(spacing: 12) {
                    Button("取消") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("确认部署") {
                        let confirmedPlan = DeploymentPlan(
                            commands: editedCommands.filter { !$0.isEmpty },
                            variables: editedVariables
                        )
                        onConfirm(confirmedPlan)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editedCommands.filter { !$0.isEmpty }.isEmpty)
                }
            }
            .padding()
            .navigationTitle("确认部署计划")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}



struct DeploymentLogsView: View {
    let task: DeploymentTask
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if task.logs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text("暂无日志")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        Text("部署过程中将显示详细日志")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(task.logs) { log in
                                    LogRowView(log: log)
                                        .id(log.id)
                                }
                            }
                            .padding()
                        }
                        .onAppear {
                            if let lastLog = task.logs.last {
                                withAnimation {
                                    proxy.scrollTo(lastLog.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("部署日志")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct NaturalLanguageDeploymentExecutionView_Previews: PreviewProvider {
    static var previews: some View {
        NaturalLanguageDeploymentExecutionView(
            vps: VPSInstance(name: "测试 VPS", host: "192.168.1.100", username: "root"),
            description: "部署一个 sing-box 代理服务器",
            deploymentService: DeploymentService(vpsManager: VPSManager()),
            preGeneratedPlan: nil
        )
    }
}

// MARK: - Natural Language Command Preview View

struct NaturalLanguageCommandPreviewView: View {
    let vps: VPSInstance
    let description: String
    @ObservedObject var deploymentService: DeploymentService
    let preGeneratedPlan: DeploymentPlan?
    @Environment(\.dismiss) private var dismiss
    
    @State private var generatedPlan: DeploymentPlan?
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    init(vps: VPSInstance, description: String, deploymentService: DeploymentService, preGeneratedPlan: DeploymentPlan? = nil) {
        self.vps = vps
        self.description = description
        self.deploymentService = deploymentService
        self.preGeneratedPlan = preGeneratedPlan
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isLoading {
                    loadingSection
                } else if let plan = generatedPlan {
                    planPreviewSection(plan: plan)
                } else if !errorMessage.isEmpty {
                    errorSection
                } else {
                    emptySection
                }
                
                Spacer()
                
                // 操作按钮
                actionButtonsSection
            }
            .padding()
            .navigationTitle("AI 命令预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let prePlan = preGeneratedPlan {
                    // 使用预生成的计划
                    generatedPlan = prePlan
                } else {
                    // 生成新的预览
                    generatePreview()
                }
            }
        }
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            VStack(spacing: 8) {
                Text("AI 正在分析您的需求...")
                    .font(.headline)
                
                Text("正在生成部署计划")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Plan Preview Section
    
    private func planPreviewSection(plan: DeploymentPlan) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 部署信息
                deploymentInfoSection
                
                // AI 生成的命令
                commandsSection(plan: plan)
                
                // 变量信息
                if !plan.variables.isEmpty {
                    variablesSection(plan: plan)
                }
            }
        }
    }
    
    private var deploymentInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("部署信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(label: "VPS", value: vps.displayName)
                InfoRow(label: "需求描述", value: description)
                
                HStack {
                    Image(systemName: "brain")
                        .foregroundColor(.purple)
                    Text("AI 智能分析")
                        .font(.subheadline)
                        .foregroundColor(.purple)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func commandsSection(plan: DeploymentPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI 生成的命令")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("以下命令将根据您的需求自动生成并执行")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVStack(spacing: 12) {
                ForEach(Array(plan.commands.enumerated()), id: \.offset) { index, command in
                    CommandRowView(
                        index: index + 1,
                        command: command,
                        total: plan.commands.count
                    )
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private func variablesSection(plan: DeploymentPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("部署变量")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("以下变量将在部署过程中使用")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVStack(spacing: 8) {
                ForEach(Array(plan.variables.keys.sorted()), id: \.self) { key in
                    if let value = plan.variables[key] {
                        HStack {
                            Text(key)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text(value)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Error Section
    
    private var errorSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("生成失败")
                    .font(.headline)
                
                Text(errorMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Empty Section
    
    private var emptySection: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain")
                .font(.system(size: 50))
                .foregroundColor(.purple)
            
            VStack(spacing: 8) {
                Text("准备生成预览")
                    .font(.headline)
                
                Text("AI 将分析您的需求并生成部署命令")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if generatedPlan != nil {
                HStack(spacing: 12) {
                    Button("重新生成") {
                        generatePreview()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("开始部署") {
                        // 这里可以触发部署
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if !errorMessage.isEmpty {
                Button("重试") {
                    generatePreview()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func generatePreview() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let plan = try await deploymentService.previewNaturalLanguageDeployment(
                    description: description,
                    vps: vps
                )
                
                await MainActor.run {
                    self.generatedPlan = plan
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
