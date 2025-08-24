import Foundation
import Combine
import SwiftUI

// MARK: - Deployment Service

/// 智能部署助手服务
@MainActor
class DeploymentService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var deploymentTasks: [DeploymentTask] = []
    @Published var templates: [DeploymentTemplate] = []
    @Published var currentTask: DeploymentTask?
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    
    // MARK: - Private Properties
    
    private let vpsManager: VPSManager
    private var cancellables = Set<AnyCancellable>()
    
    // AI 部署计划缓存，避免重复调用接口
    private var deploymentPlanCache: [String: (plan: DeploymentPlan, timestamp: Date)] = [:]
    private let cacheExpirationInterval: TimeInterval = 300 // 5分钟缓存过期
    
    /// 架构映射
    private let architectureMapping: [String: String] = [
        "x86_64": "amd64",
        "aarch64": "arm64", 
        "arm64": "arm64",
        "armv7l": "armv7",
        "armv6l": "armv6"
    ]
    
    /// FRP 架构映射
    private let frpArchitectureMapping: [String: String] = [
        "x86_64": "amd64",
        "aarch64": "arm64", 
        "arm64": "arm64",
        "armv7l": "armv7",
        "armv6l": "armv6"
    ]
    
    // MARK: - Initialization
    
    init(vpsManager: VPSManager) {
        self.vpsManager = vpsManager
        loadTemplates()
        loadDeploymentTasks()
        setupBindings()
        
        // 定期清理过期缓存
        setupCacheCleanup()
    }
    
    // MARK: - Public Methods
    
    /// 使用自然语言创建部署任务
    func createDeploymentFromNaturalLanguage(
        vpsId: UUID,
        description: String,
        deploymentPlan: DeploymentPlan? = nil
    ) async throws -> DeploymentTask {
        isLoading = true
        defer { isLoading = false }
        
        // 获取 VPS 实例
        guard let vps = vpsManager.vpsInstances.first(where: { $0.id == vpsId }) else {
            throw DeploymentServiceError.vpsNotFound
        }
        
        // 如果没有提供部署计划，则生成一个
        let finalDeploymentPlan: DeploymentPlan
        if let plan = deploymentPlan {
            finalDeploymentPlan = plan
        } else {
            finalDeploymentPlan = try await generateDeploymentPlan(description: description, vps: vps)
        }
        
        // 创建部署任务
        let task = DeploymentTask(
            vpsId: vpsId,
            customCommands: finalDeploymentPlan.commands,
            variables: finalDeploymentPlan.variables
        )
        
        deploymentTasks.append(task)
        saveDeploymentTasks()
        
        return task
    }
    
    /// 使用模板创建部署任务
    func createDeploymentFromTemplate(
        vpsId: UUID,
        templateId: UUID,
        variables: [String: String]
    ) async throws -> DeploymentTask {
        isLoading = true
        defer { isLoading = false }
        
        // 获取 VPS 实例
        guard let vps = vpsManager.vpsInstances.first(where: { $0.id == vpsId }) else {
            throw DeploymentServiceError.vpsNotFound
        }
        
        // 获取模板
        guard let template = templates.first(where: { $0.id == templateId }) else {
            throw DeploymentServiceError.templateNotFound
        }
        
        // 如果是 SingBox 或 FRP 安装模板，预填充下载链接
        var finalVariables = variables
        if template.serviceType == .singbox {
            finalVariables = try await prefillSingBoxDownloadURL(vps: vps, variables: variables)
        } else if template.serviceType == .frp {
            finalVariables = try await prefillFRPDownloadURL(vps: vps, variables: variables)
        }
        
        // 验证变量
        try validateTemplateVariables(template: template, variables: finalVariables)
        
        // 创建部署任务
        let task = DeploymentTask(
            vpsId: vpsId,
            templateId: templateId,
            variables: finalVariables
        )
        
        deploymentTasks.append(task)
        saveDeploymentTasks()
        
        return task
    }
    
    /// 删除部署任务
    func deleteTask(_ taskId: UUID) {
        deploymentTasks.removeAll { $0.id == taskId }
        saveDeploymentTasks()
    }
    
    /// 执行部署任务
    func executeDeployment(_ task: DeploymentTask) async throws {
        guard let index = deploymentTasks.firstIndex(where: { $0.id == task.id }) else {
            throw DeploymentServiceError.taskNotFound
        }
        
        // 获取 VPS 实例
        guard let vps = vpsManager.vpsInstances.first(where: { $0.id == task.vpsId }) else {
            throw DeploymentServiceError.vpsNotFound
        }
        
        // 更新任务状态
        deploymentTasks[index].status = .running
        deploymentTasks[index].startedAt = Date()
        deploymentTasks[index].progress = 0.0
        currentTask = deploymentTasks[index]
        saveDeploymentTasks()
        
        do {
            // 连接 SSH
            addLog(to: task.id, level: .info, message: "正在连接 SSH...")
            updateTaskProgress(taskId: task.id, progress: 0.05)
            
            try await connectToVPS(vps)
            addLog(to: task.id, level: .success, message: "SSH 连接成功")
            updateTaskProgress(taskId: task.id, progress: 0.1)
            
            // 检测系统环境和sudo支持
            addLog(to: task.id, level: .info, message: "正在检测系统环境...")
            updateTaskProgress(taskId: task.id, progress: 0.15)
            
            let systemInfo = try await detectSystemEnvironment(vps: vps)
            addLog(to: task.id, level: .info, message: "系统检测: \(systemInfo.description)")
            updateTaskProgress(taskId: task.id, progress: 0.2)
            
            // 执行部署
            if let templateId = task.templateId {
                try await executeTemplateDeployment(task: task, vps: vps, templateId: templateId, systemInfo: systemInfo)
            } else if let commands = task.customCommands {
                try await executeCustomDeployment(task: task, vps: vps, commands: commands, systemInfo: systemInfo)
            } else {
                throw DeploymentServiceError.noDeploymentPlan
            }
            
            // 更新任务状态为完成
            deploymentTasks[index].status = .completed
            deploymentTasks[index].completedAt = Date()
            deploymentTasks[index].progress = 1.0
            addLog(to: task.id, level: .success, message: "部署完成")
            
        } catch {
            // 更新任务状态为失败
            deploymentTasks[index].status = .failed
            deploymentTasks[index].error = error.localizedDescription
            addLog(to: task.id, level: .error, message: "部署失败: \(error.localizedDescription)")
            
            // 尝试 AI 诊断和修复建议
            let diagnosis = await diagnoseDeploymentFailure(task: task, error: error)
            addLog(to: task.id, level: .info, message: "AI 诊断: \(diagnosis)")
            
            throw error
        }
        
        currentTask = nil
        saveDeploymentTasks()
    }
    
    /// 取消部署任务
    func cancelDeployment(_ task: DeploymentTask) async throws {
        guard let index = deploymentTasks.firstIndex(where: { $0.id == task.id }) else {
            throw DeploymentServiceError.taskNotFound
        }
        
        deploymentTasks[index].status = .cancelled
        saveDeploymentTasks()
        
        // 清理 SSH 连接
        guard let vps = vpsManager.vpsInstances.first(where: { $0.id == task.vpsId }) else { return }
        await vpsManager.disconnectFromVPS(vps)
    }
    
    /// 添加部署模板
    func addTemplate(_ template: DeploymentTemplate) {
        templates.append(template)
        saveTemplates()
    }
    
    /// 删除部署模板
    func deleteTemplate(_ template: DeploymentTemplate) {
        templates.removeAll { $0.id == template.id }
        saveTemplates()
    }
    
    /// 根据 ID 获取模板
    func getTemplate(by id: String) -> DeploymentTemplate? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return templates.first { $0.id == uuid }
    }
    
    /// 获取模板按分类
    func getTemplatesByCategory(_ category: ServiceCategory) -> [DeploymentTemplate] {
        return templates.filter { $0.category == category }
    }
    
    /// 搜索模板
    func searchTemplates(query: String) -> [DeploymentTemplate] {
        guard !query.isEmpty else { return templates }
        
        return templates.filter { template in
            template.name.localizedCaseInsensitiveContains(query) ||
            template.description.localizedCaseInsensitiveContains(query) ||
            template.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
    
    /// 预览部署命令
    func previewDeploymentCommands(
        template: DeploymentTemplate,
        variables: [String: String]
    ) -> [String] {
        // 替换模板变量
        let commands = template.commands.map { command in
            replaceTemplateVariables(command: command, variables: variables)
        }
        
        return commands
    }
    
    /// 预览配置文件
    func previewConfigurationFile(
        template: DeploymentTemplate,
        variables: [String: String]
    ) -> String {
        guard !template.configTemplate.isEmpty else { return "" }
        
        var configContent = template.configTemplate
        
        // 替换变量
        for (key, value) in variables {
            configContent = configContent.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        
        return configContent
    }
    
    /// 预览自然语言部署计划
    func previewNaturalLanguageDeployment(
        description: String,
        vps: VPSInstance
    ) async throws -> DeploymentPlan {
        return try await generateDeploymentPlan(description: description, vps: vps)
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // 监听任务变化
        $deploymentTasks
            .sink { [weak self] _ in
                self?.saveDeploymentTasks()
            }
            .store(in: &cancellables)
    }
    
    private func setupCacheCleanup() {
        // 每5分钟清理一次过期缓存
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.clearExpiredCache()
            }
            .store(in: &cancellables)
    }
    
    private func connectToVPS(_ vps: VPSInstance) async throws {
        addLog(to: currentTask?.id ?? UUID(), level: .info, message: "尝试连接到 \(vps.name) (\(vps.host):\(vps.port))")
        
        do {
            try await vpsManager.connectToVPS(vps)
            addLog(to: currentTask?.id ?? UUID(), level: .success, message: "SSH 连接建立成功")
        } catch {
            let errorMessage = "SSH 连接失败: \(error.localizedDescription)"
            addLog(to: currentTask?.id ?? UUID(), level: .error, message: errorMessage)
            
            // 提供更详细的错误信息和解决建议
            if let sshError = error as? SSHError {
                switch sshError {
                case .timeout:
                    addLog(to: currentTask?.id ?? UUID(), level: .warning, message: "连接超时，请检查：1) VPS 是否在线 2) 端口是否正确 3) 网络是否正常")
                case .networkUnreachable:
                    addLog(to: currentTask?.id ?? UUID(), level: .warning, message: "网络不可达，请检查：1) VPS IP 是否正确 2) 网络连接是否正常")
                case .authenticationFailed(let message):
                    addLog(to: currentTask?.id ?? UUID(), level: .warning, message: "认证失败：\(message)，请检查用户名和密码是否正确")
                case .connectionFailed:
                    addLog(to: currentTask?.id ?? UUID(), level: .warning, message: "连接失败，请检查 VPS 配置和网络连接")
                default:
                    addLog(to: currentTask?.id ?? UUID(), level: .warning, message: "SSH 连接遇到问题，请检查 VPS 配置")
                }
            }
            
            throw error
        }
    }
    
    private func executeTemplateDeployment(
        task: DeploymentTask,
        vps: VPSInstance,
        templateId: UUID,
        systemInfo: SystemEnvironmentInfo
    ) async throws {
        guard let template = templates.first(where: { $0.id == templateId }) else {
            throw DeploymentServiceError.templateNotFound
        }
        
        addLog(to: task.id, level: .info, message: "开始部署 \(template.name)")
        updateTaskProgress(taskId: task.id, progress: 0.25)
        
        // 替换模板变量
        addLog(to: task.id, level: .info, message: "正在处理模板变量...")
        updateTaskProgress(taskId: task.id, progress: 0.3)
        
        let commands = template.commands.map { command in
            replaceTemplateVariables(command: command, variables: task.variables)
        }
        
        addLog(to: task.id, level: .info, message: "准备执行 \(commands.count) 个命令")
        updateTaskProgress(taskId: task.id, progress: 0.35)
        
        // 执行命令 - 使用智能多行指令执行系统
        addLog(to: task.id, level: .info, message: "开始执行 \(commands.count) 个指令")
        updateTaskProgress(taskId: task.id, progress: 0.35)
        
        do {
            let outputs = try await executeSmartMultiLineCommands(commands, systemInfo: systemInfo, vps: vps)
            
            // 处理执行结果
            for (index, output) in outputs.enumerated() {
                if !output.isEmpty {
                    addLog(to: task.id, level: .success, message: "指令组 \(index + 1) 执行成功")
                    addLog(to: task.id, level: .info, message: "返回结果: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                    
                    // 更新进度并显示结果
                    let progress = 0.35 + (Double(index + 1) / Double(outputs.count) * 0.6)
                    updateTaskProgressWithResult(taskId: task.id, progress: progress, result: output.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    addLog(to: task.id, level: .success, message: "指令组 \(index + 1) 执行成功 (无输出)")
                    
                    // 更新进度
                    let progress = 0.35 + (Double(index + 1) / Double(outputs.count) * 0.6)
                    updateTaskProgress(taskId: task.id, progress: progress)
                }
            }
        } catch {
            addLog(to: task.id, level: .error, message: "指令执行失败: \(error.localizedDescription)")
            throw error
        }
        
        // 生成服务文件（如果有）
        if !template.serviceTemplate.isEmpty {
            addLog(to: task.id, level: .info, message: "正在生成服务文件...")
            updateTaskProgress(taskId: task.id, progress: 0.9)
            
            try await generateServiceFile(template: template, variables: task.variables, vps: vps)
            
            addLog(to: task.id, level: .success, message: "服务文件生成完成")
            updateTaskProgress(taskId: task.id, progress: 0.92)
            
            // 重新加载 systemd 并启动服务
            addLog(to: task.id, level: .info, message: "正在启动服务...")
            updateTaskProgress(taskId: task.id, progress: 0.93)
            
            try await executeServiceCommands(template: template, systemInfo: systemInfo, vps: vps)
            
            addLog(to: task.id, level: .success, message: "服务启动完成")
            updateTaskProgress(taskId: task.id, progress: 0.94)
        }
        
        // 生成配置文件（如果有）
        if !template.configTemplate.isEmpty {
            addLog(to: task.id, level: .info, message: "正在生成配置文件...")
            updateTaskProgress(taskId: task.id, progress: 0.95)
            
            try await generateConfigurationFile(template: template, variables: task.variables, vps: vps)
            
            addLog(to: task.id, level: .success, message: "配置文件生成完成")
            updateTaskProgress(taskId: task.id, progress: 0.98)
        } else {
            updateTaskProgress(taskId: task.id, progress: 0.98)
        }
    }
    
    private func executeCustomDeployment(
        task: DeploymentTask,
        vps: VPSInstance,
        commands: [String],
        systemInfo: SystemEnvironmentInfo
    ) async throws {
        addLog(to: task.id, level: .info, message: "开始执行自定义部署")
        updateTaskProgress(taskId: task.id, progress: 0.25)
        
        addLog(to: task.id, level: .info, message: "准备执行 \(commands.count) 个自定义命令")
        updateTaskProgress(taskId: task.id, progress: 0.3)
        
        // 执行命令 - 使用智能多行指令执行系统
        do {
            let outputs = try await executeSmartMultiLineCommands(commands, systemInfo: systemInfo, vps: vps)
            
            // 处理执行结果
            for (index, output) in outputs.enumerated() {
                let progress = 0.3 + (Double(index + 1) / Double(outputs.count) * 0.65)
                
                if !output.isEmpty {
                    addLog(to: task.id, level: .success, message: "指令组 \(index + 1) 执行成功")
                    addLog(to: task.id, level: .info, message: "返回结果: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
                    
                    // 更新进度并显示结果
                    updateTaskProgressWithResult(taskId: task.id, progress: progress, result: output.trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    addLog(to: task.id, level: .success, message: "指令组 \(index + 1) 执行成功 (无输出)")
                    
                    // 更新进度
                    updateTaskProgress(taskId: task.id, progress: progress)
                }
            }
        } catch {
            addLog(to: task.id, level: .error, message: "指令执行失败: \(error.localizedDescription)")
            throw error
        }
        
        updateTaskProgress(taskId: task.id, progress: 0.98)
    }
    
    func generateDeploymentPlan(description: String, vps: VPSInstance) async throws -> DeploymentPlan {
        // 生成缓存键，包含描述和VPS信息
        let cacheKey = generateCacheKey(description: description, vps: vps)
        
        // 检查缓存
        if let cached = deploymentPlanCache[cacheKey] {
            let timeSinceCache = Date().timeIntervalSince(cached.timestamp)
            if timeSinceCache < cacheExpirationInterval {
                addLog(to: currentTask?.id ?? UUID(), level: .info, message: "使用缓存的部署计划")
                return cached.plan
            } else {
                // 缓存过期，移除
                deploymentPlanCache.removeValue(forKey: cacheKey)
            }
        }
        
        // 构建 AI 提示词
        let prompt = buildAIDeploymentPrompt(description: description, vps: vps)
        
        // 调用 AI 服务来分析需求并生成部署计划
        let plan = try await analyzeAndGeneratePlan(prompt: prompt, description: description, vps: vps)
        
        // 缓存结果
        deploymentPlanCache[cacheKey] = (plan: plan, timestamp: Date())
        
        return plan
    }
    
    /// 构建 AI 部署提示词
    private func buildAIDeploymentPrompt(description: String, vps: VPSInstance) -> String {
        let systemInfo = vps.systemInfo
        
        return """
        ## 用户需求
        \(description)

        ## 服务器环境信息
        - 操作系统: \(systemInfo?.osName ?? "未知")
        - 内核版本: \(systemInfo?.kernelVersion ?? "未知")
        - CPU 架构: \(systemInfo?.cpuModel ?? "未知")
        - CPU 核心数: \(systemInfo?.cpuCores ?? 0)
        - 内存大小: \(formatBytes(systemInfo?.memoryTotal ?? 0))
        - 磁盘空间: \(formatBytes(systemInfo?.diskTotal ?? 0))
        """
    }
    
    /// 分析需求并生成部署计划
    private func analyzeAndGeneratePlan(prompt: String, description: String, vps: VPSInstance) async throws -> DeploymentPlan {
        // 调用 AI 服务接口
        let plan = try await callAIService(prompt: prompt, description: description, vps: vps)
        return plan
    }
    
    /// 调用 AI 服务接口
    private func callAIService(prompt: String, description: String, vps: VPSInstance) async throws -> DeploymentPlan {
        guard let url = URL(string: "https://n8n.clap.top/webhook/aivpstools") else {
            throw DeploymentServiceError.invalidConfiguration("无效的 API URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120 // 120 秒超时
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 构建请求参数
        let requestBody = [
            "chatInput": prompt
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw DeploymentServiceError.invalidConfiguration("请求参数序列化失败: \(error.localizedDescription)")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw DeploymentServiceError.connectionFailed("无效的 HTTP 响应")
            }
            
            guard httpResponse.statusCode == 200 else {
                throw DeploymentServiceError.connectionFailed("API 请求失败，状态码: \(httpResponse.statusCode)")
            }
            
            // 解析 AI 响应
            let plan = try await parseAIResponse(data: data, description: description, vps: vps)
            return plan
            
        } catch let error as DeploymentServiceError {
            throw error
        } catch {
            throw DeploymentServiceError.connectionFailed("API 调用失败: \(error.localizedDescription)")
        }
    }
    
    /// 解析 AI 响应
    private func parseAIResponse(data: Data, description: String, vps: VPSInstance) async throws -> DeploymentPlan {
        do {
            // 尝试解析 JSON 响应
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                return try await parseJSONResponse(json: json, description: description, vps: vps)
            }
            
            // 如果不是 JSON，尝试解析文本响应
            if let textResponse = String(data: data, encoding: .utf8) {
                return try await parseTextResponse(text: textResponse, description: description, vps: vps)
            }
            
            throw DeploymentServiceError.invalidConfiguration("无法解析 AI 响应")
            
        } catch {
            throw DeploymentServiceError.invalidConfiguration("响应解析失败: \(error.localizedDescription)")
        }
    }
    
    /// 解析 JSON 响应
    private func parseJSONResponse(json output: [String: Any], description: String, vps: VPSInstance) async throws -> DeploymentPlan {
        // 尝试从 JSON 中提取命令和变量
        var commands: [String] = []
        var variables: [String: String] = [:]
        
        guard let jsonString = output["output"] as? String else {
            throw DeploymentServiceError.invalidConfiguration("AI 响应格式不正确，缺少 output 字段")
        }
        
        // 清理JSON字符串，移除可能的markdown代码块标记
        var jsonStringCleaned = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 移除开头的 ```json 或 ``` 标记
        if jsonStringCleaned.hasPrefix("```json") {
            jsonStringCleaned = String(jsonStringCleaned.dropFirst(7))
        } else if jsonStringCleaned.hasPrefix("```") {
            jsonStringCleaned = String(jsonStringCleaned.dropFirst(3))
        }
        
        // 移除结尾的 ``` 标记
        if jsonStringCleaned.hasSuffix("```") {
            jsonStringCleaned = String(jsonStringCleaned.dropLast(3))
        }
        
        // 再次清理首尾空白字符
        jsonStringCleaned = jsonStringCleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = jsonStringCleaned.data(using: .utf8) else {
            throw DeploymentServiceError.invalidConfiguration("无法将JSON字符串转换为数据")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String : Any] else {
            throw DeploymentServiceError.invalidConfiguration("AI 响应格式不正确，缺少 output 字段")
        }
        
        
        if let commandsArray = json["commands"] as? [String] {
            commands = commandsArray
        } else if let commandsArray = json["command"] as? [String] {
            commands = commandsArray
        } else if let commandsArray = json["steps"] as? [String] {
            commands = commandsArray
        }
        
        if let variablesDict = json["variables"] as? [String: String] {
            variables = variablesDict
        } else if let variablesDict = json["params"] as? [String: String] {
            variables = variablesDict
        }
        
        // 提取额外的元数据
        let planDescription = json["description"] as? String
        let estimatedTime = json["estimatedTime"] as? String
        let requirements = json["requirements"] as? [String]
        let notes = json["notes"] as? [String]
        
        // 如果没有找到有效的命令，使用默认的智能分析
        if commands.isEmpty {
            return try await generateSmartPlan(description: description, vps: vps)
        }
        
        return DeploymentPlan(
            commands: commands,
            variables: variables,
            description: planDescription,
            estimatedTime: estimatedTime,
            requirements: requirements,
            notes: notes
        )
    }
    
    /// 解析文本响应
    private func parseTextResponse(text: String, description: String, vps: VPSInstance) async throws -> DeploymentPlan {
        // 尝试从文本中提取命令
        let lines = text.components(separatedBy: .newlines)
        var commands: [String] = []
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 跳过空行和注释
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") || trimmedLine.hasPrefix("//") {
                continue
            }
            
            // 检查是否是命令（以 sudo 开头或包含常见的命令关键词）
            if trimmedLine.hasPrefix("sudo ") || 
               trimmedLine.hasPrefix("apt ") || 
               trimmedLine.hasPrefix("wget ") || 
               trimmedLine.hasPrefix("curl ") || 
               trimmedLine.hasPrefix("echo ") ||
               trimmedLine.hasPrefix("mkdir ") ||
               trimmedLine.hasPrefix("tar ") ||
               trimmedLine.hasPrefix("systemctl ") ||
               trimmedLine.hasPrefix("ufw ") ||
               trimmedLine.contains("&&") ||
               trimmedLine.contains("|") {
                commands.append(trimmedLine)
            }
        }
        
        // 如果没有找到有效的命令，使用默认的智能分析
        if commands.isEmpty {
            return try await generateSmartPlan(description: description, vps: vps)
        }
        
        return DeploymentPlan(
            commands: commands,
            variables: [:],
            description: "基于文本解析生成的部署计划",
            estimatedTime: "大约5-10分钟",
            requirements: [
                "需要root权限或sudo权限",
                "需要访问外网下载相关软件包"
            ],
            notes: [
                "此计划基于AI返回的文本内容自动生成",
                "请检查命令的正确性和安全性"
            ]
        )
    }
    
    /// 基于规则的智能计划生成
    private func generateSmartPlan(description: String, vps: VPSInstance) async throws -> DeploymentPlan {
        let lowerDescription = description.lowercased()
        
        // 基于关键词匹配生成部署计划
        if lowerDescription.contains("shadowsocks") || lowerDescription.contains("ss") {
            return generateShadowsocksPlan(vps: vps)
        } else if lowerDescription.contains("v2ray") || lowerDescription.contains("vmess") {
            return generateV2RayPlan(vps: vps)
        } else if lowerDescription.contains("nginx") || lowerDescription.contains("web") {
            return generateNginxPlan(vps: vps)
        } else if lowerDescription.contains("wordpress") || lowerDescription.contains("博客") {
            return generateWordPressPlan(vps: vps)
        } else if lowerDescription.contains("docker") {
            return generateDockerPlan(vps: vps)
        } else if lowerDescription.contains("frp") || lowerDescription.contains("内网穿透") {
            return generateFRPPlan(vps: vps)
        } else if lowerDescription.contains("singbox") || lowerDescription.contains("sing-box") {
            return generateSingBoxPlan(vps: vps)
        } else {
            // 通用部署计划
            return generateGenericPlan(description: description, vps: vps)
        }
    }
    
    /// 生成 Shadowsocks 部署计划
    private func generateShadowsocksPlan(vps: VPSInstance) -> DeploymentPlan {
        let commands = [
            "sudo apt update && sudo apt install -y python3-pip",
            "sudo pip3 install shadowsocks",
            "sudo mkdir -p /etc/shadowsocks",
            "sudo tee /etc/shadowsocks/config.json << 'EOF'\n{\n  \"server\":\"0.0.0.0\",\n  \"server_port\":8388,\n  \"password\":\"your_password_here\",\n  \"timeout\":300,\n  \"method\":\"aes-256-gcm\",\n  \"fast_open\":false\n}\nEOF",
            "sudo systemctl enable shadowsocks",
            "sudo systemctl start shadowsocks",
            "sudo ufw allow 8388/tcp",
            "echo 'Shadowsocks 部署完成，端口: 8388'"
        ]
        
        return DeploymentPlan(
            commands: commands,
            variables: [
                "server_port": "8388",
                "password": "your_password_here",
                "method": "aes-256-gcm"
            ],
            description: "部署Shadowsocks代理服务器，提供安全的网络代理服务",
            estimatedTime: "大约3-5分钟",
            requirements: [
                "需要root权限或sudo权限",
                "需要访问外网下载Python包",
                "需要开放8388端口"
            ],
            notes: [
                "请修改默认密码以提高安全性",
                "建议配置防火墙规则",
                "可以通过修改配置文件调整加密方式"
            ]
        )
    }
    
    /// 生成 V2Ray 部署计划
    private func generateV2RayPlan(vps: VPSInstance) -> DeploymentPlan {
        let commands = [
            "bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)",
            "sudo systemctl enable v2ray",
            "sudo systemctl start v2ray",
            "sudo ufw allow 443/tcp",
            "echo 'V2Ray 部署完成，端口: 443'"
        ]
        
        return DeploymentPlan(
            commands: commands,
            variables: [
                "port": "443",
                "uuid": "your_uuid_here"
            ],
            description: "部署V2Ray代理服务器，支持多种协议和加密方式",
            estimatedTime: "大约5-8分钟",
            requirements: [
                "需要root权限或sudo权限",
                "需要访问外网下载V2Ray",
                "需要开放443端口"
            ],
            notes: [
                "请修改默认UUID以提高安全性",
                "建议配置TLS证书",
                "可以通过修改配置文件调整协议设置"
            ]
        )
    }
    
    /// 生成 Nginx 部署计划
    private func generateNginxPlan(vps: VPSInstance) -> DeploymentPlan {
        let commands = [
            "sudo apt update",
            "sudo apt install -y nginx",
            "sudo systemctl enable nginx",
            "sudo systemctl start nginx",
            "sudo ufw allow 'Nginx Full'",
            "echo 'Nginx 部署完成'"
        ]
        
        return DeploymentPlan(
            commands: commands,
            variables: [:],
            description: "部署Nginx Web服务器，提供高性能的HTTP服务",
            estimatedTime: "大约2-3分钟",
            requirements: [
                "需要root权限或sudo权限",
                "需要访问外网下载Nginx包",
                "需要开放80和443端口"
            ],
            notes: [
                "默认配置文件位于/etc/nginx/nginx.conf",
                "网站文件通常放在/var/www/html/",
                "建议配置SSL证书以提高安全性"
            ]
        )
    }
    
    /// 生成 WordPress 部署计划
    private func generateWordPressPlan(vps: VPSInstance) -> DeploymentPlan {
        let commands = [
            "sudo apt update",
            "sudo apt install -y nginx mysql-server php-fpm php-mysql",
            "sudo mysql_secure_installation",
            "sudo systemctl enable nginx mysql",
            "sudo systemctl start nginx mysql",
            "wget https://wordpress.org/latest.tar.gz",
            "tar -xzf latest.tar.gz",
            "sudo mv wordpress /var/www/html/",
            "sudo chown -R www-data:www-data /var/www/html/wordpress",
            "echo 'WordPress 部署完成'"
        ]
        
        return DeploymentPlan(
            commands: commands,
            variables: [
                "db_name": "wordpress",
                "db_user": "wp_user",
                "db_password": "your_db_password"
            ],
            description: "部署WordPress博客系统，包含Nginx、MySQL和PHP环境",
            estimatedTime: "大约10-15分钟",
            requirements: [
                "需要root权限或sudo权限",
                "需要访问外网下载软件包",
                "需要开放80和443端口",
                "需要配置MySQL数据库"
            ],
            notes: [
                "请修改默认数据库密码",
                "建议配置SSL证书",
                "可以通过WordPress管理界面进行进一步配置",
                "数据库文件位于/var/lib/mysql/"
            ]
        )
    }
    
    /// 生成 Docker 部署计划
    private func generateDockerPlan(vps: VPSInstance) -> DeploymentPlan {
        let commands = [
            "sudo apt update",
            "sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release",
            "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
            "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
            "sudo apt update",
            "sudo apt install -y docker-ce docker-ce-cli containerd.io",
            "sudo systemctl enable docker",
            "sudo systemctl start docker",
            "sudo usermod -aG docker $USER",
            "echo 'Docker 部署完成'"
        ]
        
        return DeploymentPlan(
            commands: commands,
            variables: [:],
            description: "部署Docker容器化平台，支持应用容器化部署和管理",
            estimatedTime: "大约5-8分钟",
            requirements: [
                "需要root权限或sudo权限",
                "需要访问外网下载Docker官方GPG密钥",
                "需要Ubuntu/Debian系统环境"
            ],
            notes: [
                "添加用户到docker组后需要重新登录生效",
                "建议配置Docker镜像加速器",
                "可以通过docker-compose管理多容器应用"
            ]
        )
    }
    
    /// 生成 FRP 部署计划
    private func generateFRPPlan(vps: VPSInstance) -> DeploymentPlan {
        let commands = [
            "wget https://github.com/fatedier/frp/releases/download/v0.51.3/frp_0.51.3_linux_amd64.tar.gz",
            "tar -xzf frp_0.51.3_linux_amd64.tar.gz",
            "sudo mv frp_0.51.3_linux_amd64 /opt/frp",
            "sudo mkdir -p /etc/frp",
            "sudo tee /etc/frp/frps.ini << 'EOF'\n[common]\nbind_port = 7000\ndashboard_port = 7500\ndashboard_user = admin\ndashboard_pwd = admin\nEOF",
            "sudo systemctl enable frps",
            "sudo systemctl start frps",
            "sudo ufw allow 7000/tcp",
            "sudo ufw allow 7500/tcp",
            "echo 'FRP 服务器部署完成'"
        ]
        
        return DeploymentPlan(
            commands: commands,
            variables: [
                "bind_port": "7000",
                "dashboard_port": "7500",
                "dashboard_user": "admin",
                "dashboard_pwd": "admin"
            ],
            description: "部署FRP内网穿透服务器，提供内网服务的外网访问能力",
            estimatedTime: "大约3-5分钟",
            requirements: [
                "需要root权限或sudo权限",
                "需要访问外网下载FRP",
                "需要开放7000和7500端口"
            ],
            notes: [
                "请修改默认的管理面板密码",
                "可以通过Web界面管理内网穿透规则",
                "建议配置SSL证书提高安全性"
            ]
        )
    }
    
    /// 生成 SingBox 部署计划
    private func generateSingBoxPlan(vps: VPSInstance) -> DeploymentPlan {
        let commands = [
            "sudo mkdir -p /etc/sing-box",
            "wget -O /tmp/sing-box.tar.gz https://github.com/SagerNet/sing-box/releases/download/v1.8.0/sing-box-1.8.0-linux-amd64.tar.gz",
            "tar -xzf /tmp/sing-box.tar.gz -C /tmp",
            "sudo mv /tmp/sing-box-*/sing-box /usr/local/bin/",
            "sudo chmod +x /usr/local/bin/sing-box",
            "sudo tee /etc/sing-box/config.json << 'EOF'\n{\n  \"log\": {\n    \"level\": \"info\"\n  },\n  \"inbounds\": [\n    {\n      \"type\": \"vmess\",\n      \"tag\": \"vmess-in\",\n      \"listen\": \"::\",\n      \"listen_port\": 443,\n      \"users\": [\n        {\n          \"uuid\": \"your_uuid_here\",\n          \"security\": \"auto\"\n        }\n      ]\n    }\n  ]\n}\nEOF",
            "sudo systemctl enable sing-box",
            "sudo systemctl start sing-box",
            "sudo ufw allow 443/tcp",
            "echo 'SingBox 部署完成'"
        ]
        
        return DeploymentPlan(
            commands: commands,
            variables: [
                "port": "443",
                "uuid": "your_uuid_here"
            ],
            description: "部署SingBox代理服务器，支持多种协议和加密方式",
            estimatedTime: "大约3-5分钟",
            requirements: [
                "需要root权限或sudo权限",
                "需要访问外网下载SingBox",
                "需要开放443端口"
            ],
            notes: [
                "请修改默认UUID以提高安全性",
                "支持多种协议：VMess、Shadowsocks、Trojan等",
                "建议配置TLS证书提高安全性"
            ]
        )
    }
    
    /// 生成通用部署计划
    private func generateGenericPlan(description: String, vps: VPSInstance) -> DeploymentPlan {
        let commands = [
            "echo '开始部署: \(description)'",
            "sudo apt update",
            "echo '系统更新完成'",
            "echo '请根据具体需求配置服务'"
        ]
        
        return DeploymentPlan(
            commands: commands,
            variables: [:],
            description: "通用部署计划，根据用户需求进行基础系统配置",
            estimatedTime: "大约1-2分钟",
            requirements: [
                "需要root权限或sudo权限",
                "需要访问外网更新系统包"
            ],
            notes: [
                "这是一个基础部署计划，请根据具体需求进行进一步配置",
                "建议在部署前备份重要数据"
            ]
        )
    }
    
    /// 生成缓存键
    private func generateCacheKey(description: String, vps: VPSInstance) -> String {
        let systemInfo = vps.systemInfo
        let systemSignature = "\(systemInfo?.osName ?? "unknown")_\(systemInfo?.cpuCores ?? 0)_\(systemInfo?.memoryTotal ?? 0)"
        return "\(description)_\(systemSignature)".lowercased().replacingOccurrences(of: " ", with: "_")
    }
    
    /// 格式化字节数
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func validateTemplateVariables(template: DeploymentTemplate, variables: [String: String]) throws {
        for variable in template.variables where variable.required {
            guard let value = variables[variable.name], !value.isEmpty else {
                throw DeploymentServiceError.missingRequiredVariable(variable.name)
            }
        }
    }
    
    private func replaceTemplateVariables(command: String, variables: [String: String]) -> String {
        var result = command
        
        for (key, value) in variables {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        
        return result
    }
    
    private func generateConfigurationFile(template: DeploymentTemplate, variables: [String: String], vps: VPSInstance) async throws {
        var configContent = template.configTemplate
        
        // 替换变量
        for (key, value) in variables {
            configContent = configContent.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        
        // 根据模板类型确定配置文件名和路径
        let configFileName: String
        let configPath: String
        
        switch template.serviceType {
        case .singbox:
            configFileName = "config.json"
            configPath = "/etc/sing-box/config.json"
        case .frp:
            if template.name == "FRP 客户端" {
                configFileName = "frpc.ini"
                configPath = "/etc/frp/frpc.ini"
            } else {
                configFileName = "frps.ini"
                configPath = "/etc/frp/frps.ini"
            }
        case .wordpress:
            // WordPress 配置通常通过 Web 界面完成
            addLog(to: currentTask?.id ?? UUID(), level: .info, message: "WordPress 配置将通过 Web 界面完成")
            return
        default:
            configFileName = "config.json"
            configPath = "/tmp/config.json"
        }
        
        // 写入配置文件
        try await vpsManager.writeFile(content: configContent, to: configPath, on: vps)
        addLog(to: currentTask?.id ?? UUID(), level: .success, message: "配置文件生成成功: \(configFileName)")
    }
    
    private func generateServiceFile(template: DeploymentTemplate, variables: [String: String], vps: VPSInstance) async throws {
        var serviceContent = template.serviceTemplate
        
        // 替换变量
        for (key, value) in variables {
            serviceContent = serviceContent.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        
        // 根据模板类型确定服务文件名
        let serviceFileName: String
        switch template.serviceType {
        case .singbox:
            serviceFileName = "sing-box.service"
        case .frp:
            if template.name == "FRP 客户端" {
                serviceFileName = "frpc.service"
            } else {
                serviceFileName = "frps.service"
            }
        case .wordpress:
            // WordPress 通常不需要额外的服务文件，使用 nginx 和 mysql
            addLog(to: currentTask?.id ?? UUID(), level: .info, message: "WordPress 使用系统默认的 nginx 和 mysql 服务")
            return
        default:
            serviceFileName = "custom.service"
        }
        
        // 写入服务文件
        let servicePath = "/etc/systemd/system/\(serviceFileName)"
        try await vpsManager.writeFile(content: serviceContent, to: servicePath, on: vps)
        addLog(to: currentTask?.id ?? UUID(), level: .success, message: "服务文件生成成功: \(serviceFileName)")
    }
    
    private func executeServiceCommands(template: DeploymentTemplate, systemInfo: SystemEnvironmentInfo, vps: VPSInstance) async throws {
        let serviceCommands: [String]
        
        // 根据模板类型确定服务名称和命令
        switch template.serviceType {
        case .singbox:
            serviceCommands = [
                "sudo systemctl daemon-reload",
                "sudo systemctl unmask sing-box 2>/dev/null || true",
                "sudo systemctl enable sing-box",
                "sudo systemctl start sing-box",
                "systemctl is-active sing-box"
            ]
            
        case .frp:
            if template.name == "FRP 服务端" {
                serviceCommands = [
                    "sudo systemctl daemon-reload",
                    "sudo systemctl unmask frps 2>/dev/null || true",
                    "sudo systemctl enable frps",
                    "sudo systemctl start frps",
                    "systemctl is-active frps"
                ]
            } else if template.name == "FRP 客户端" {
                serviceCommands = [
                    "sudo systemctl daemon-reload",
                    "sudo systemctl unmask frpc 2>/dev/null || true",
                    "sudo systemctl enable frpc",
                    "sudo systemctl start frpc",
                    "systemctl is-active frpc"
                ]
            } else {
                // 默认 FRP 服务端
                serviceCommands = [
                    "sudo systemctl daemon-reload",
                    "sudo systemctl unmask frps 2>/dev/null || true",
                    "sudo systemctl enable frps",
                    "sudo systemctl start frps",
                    "systemctl is-active frps"
                ]
            }
            
        case .wordpress:
            serviceCommands = [
                "sudo systemctl daemon-reload",
                "sudo systemctl enable nginx mysql",
                "sudo systemctl start nginx mysql",
                "systemctl is-active nginx",
                "systemctl is-active mysql"
            ]
            
        default:
            // 对于其他服务类型，使用通用的服务管理命令
            serviceCommands = [
                "sudo systemctl daemon-reload",
                "echo '服务启动完成'"
            ]
        }
        
        addLog(to: currentTask?.id ?? UUID(), level: .info, message: "执行服务命令，共 \(serviceCommands.count) 个命令")
        
        for (index, command) in serviceCommands.enumerated() {
            addLog(to: currentTask?.id ?? UUID(), level: .info, message: "执行服务命令 \(index + 1)/\(serviceCommands.count): \(command)")
            
            let output = try await executeSmartCommand(command, systemInfo: systemInfo, vps: vps)
            if !output.isEmpty {
                addLog(to: currentTask?.id ?? UUID(), level: .info, message: "服务命令输出: \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }
    }
    
    private func diagnoseDeploymentFailure(task: DeploymentTask, error: Error) async -> String {
        // 这里应该调用 AI 服务来分析失败原因并给出修复建议
        // 暂时返回一个简单的诊断
        
        return "部署失败，建议检查网络连接和服务器状态"
    }
    
    private func addLog(to taskId: UUID, level: LogLevel, message: String, command: String? = nil, output: String? = nil) {
        guard let index = deploymentTasks.firstIndex(where: { $0.id == taskId }) else { return }
        
        let log = DeploymentLog(
            level: level,
            message: message,
            command: command,
            output: output
        )
        
        deploymentTasks[index].logs.append(log)
        saveDeploymentTasks()
    }
    
    private func updateTaskProgress(taskId: UUID, progress: Double) {
        guard let index = deploymentTasks.firstIndex(where: { $0.id == taskId }) else { return }
        
        deploymentTasks[index].progress = progress
        saveDeploymentTasks()
    }
    
    private func updateTaskProgressWithResult(taskId: UUID, progress: Double, result: String) {
        guard let index = deploymentTasks.firstIndex(where: { $0.id == taskId }) else { return }
        
        deploymentTasks[index].progress = progress
        deploymentTasks[index].lastCommandResult = result
        saveDeploymentTasks()
    }
    
    private func loadTemplates() {
        // 加载内置模板
        loadBuiltinTemplates()
        
        // 加载用户自定义模板
        loadCustomTemplates()
    }
    
    private func loadBuiltinTemplates() {
        // WordPress 模板
        let wordpressTemplate = DeploymentTemplate(
            name: "WordPress 博客",
            description: "使用 Docker 部署 WordPress 博客系统（请确保Docker已安装）",
            serviceType: .wordpress,
            category: .website,
            commands: [
                "mkdir -p {{wordpress_directory}}",
                "cd {{wordpress_directory}} && cat > docker-compose.yml << 'EOF'\n{{wordpress_compose_config}}\nEOF",
                "cd {{wordpress_directory}} && mkdir -p wordpress-data",
                "cd {{wordpress_directory}} && mkdir -p mysql-data",
                "cd {{wordpress_directory}} && docker compose up -d",
                "echo '等待 WordPress 服务启动...'",
                "sleep 30",
                "cd {{wordpress_directory}} && docker compose ps",
                "echo 'WordPress 部署完成！访问地址: http://{{server_ip}}:{{web_port}}'"
            ],
            configTemplate: """
            version: '3.8'
            services:
              db:
                image: mysql:8.0
                container_name: wordpress-mysql
                restart: always
                environment:
                  - MYSQL_ROOT_PASSWORD={{mysql_root_password}}
                  - MYSQL_DATABASE={{db_name}}
                  - MYSQL_USER={{db_user}}
                  - MYSQL_PASSWORD={{db_password}}
                volumes:
                  - ./mysql-data:/var/lib/mysql
                networks:
                  - wordpress-network

              wordpress:
                image: wordpress:{{wordpress_version}}
                container_name: wordpress
                restart: always
                ports:
                  - "{{web_port}}:80"
                environment:
                  - WORDPRESS_DB_HOST=db:3306
                  - WORDPRESS_DB_NAME={{db_name}}
                  - WORDPRESS_DB_USER={{db_user}}
                  - WORDPRESS_DB_PASSWORD={{db_password}}
                  - WORDPRESS_TABLE_PREFIX={{table_prefix}}
                  - WORDPRESS_DEBUG={{debug_mode}}
                volumes:
                  - ./wordpress-data:/var/www/html
                depends_on:
                  - db
                networks:
                  - wordpress-network

            networks:
              wordpress-network:
                driver: bridge
            """,
            serviceTemplate: "",
            variables: [
                TemplateVariable(name: "wordpress_directory", description: "WordPress 安装目录", type: .string, defaultValue: "/opt/wordpress", required: true),
                TemplateVariable(name: "wordpress_version", description: "WordPress 版本", type: .select, defaultValue: "latest", required: true, options: ["latest", "6.4", "6.3", "6.2", "6.1", "6.0"]),
                TemplateVariable(name: "web_port", description: "Web 访问端口", type: .number, defaultValue: "8080", required: true),
                TemplateVariable(name: "server_ip", description: "服务器 IP 地址", type: .string, required: true),
                TemplateVariable(name: "mysql_root_password", description: "MySQL Root 密码", type: .password, required: true),
                TemplateVariable(name: "db_name", description: "数据库名称", type: .string, defaultValue: "wordpress", required: true),
                TemplateVariable(name: "db_user", description: "数据库用户名", type: .string, defaultValue: "wp_user", required: true),
                TemplateVariable(name: "db_password", description: "数据库密码", type: .password, required: true),
                TemplateVariable(name: "table_prefix", description: "数据表前缀", type: .string, defaultValue: "wp_", required: false),
                TemplateVariable(name: "debug_mode", description: "调试模式", type: .select, defaultValue: "false", required: false, options: ["true", "false"])
            ],
            tags: ["WordPress", "博客", "网站", "Docker", "CMS"],
            isOfficial: true
        )
        
        // 通用 SingBox 安装模板 - 使用多行指令系统（App端预构建下载链接）
        let singboxInstallTemplate = DeploymentTemplate(
            name: "Sing-Box",
            description: "智能安装 SingBox 代理服务，自动检测系统架构并下载最新版本",
            serviceType: .singbox,
            category: .proxy,
            commands: [
                "mkdir -p /tmp/singbox_install",
                "cd /tmp/singbox_install && curl -L -o sing-box.tar.gz \"{{download_url}}\"",
                "cd /tmp/singbox_install && tar -xzf sing-box.tar.gz",
                "cd /tmp/singbox_install && sudo mv sing-box-*/sing-box /usr/local/bin/",
                "sudo chmod +x /usr/local/bin/sing-box",
                "sudo ln -sf /usr/local/bin/sing-box /usr/bin/sing-box",
                "sudo mkdir -p /etc/sing-box",
                "sudo mkdir -p /var/log/sing-box",
                "sudo mkdir -p /var/lib/sing-box",
                "sing-box version",
                "cd / && sudo rm -rf /tmp/singbox_install"
            ],
            configTemplate: """
            {
                "log": {
                    "level": "{{log_level}}",
                    "timestamp": true,
                    "output": "stdout"
                },
                "inbounds": [
                    {
                        "type": "{{protocol}}",
                        "tag": "in",
                        "listen": "0.0.0.0",
                        "listen_port": {{port}},
                        "password": "{{password}}",
                        "method": "{{method}}"
                    }
                ],
                "outbounds": [
                    {
                        "type": "direct",
                        "tag": "direct"
                    }
                ],
                "route": {
                    "rules": [
                        {
                            "geoip": "private",
                            "outbound": "direct"
                        }
                    ]
                }
            }
            """,
            serviceTemplate: """
            [Unit]
            Description=sing-box service
            Documentation=https://sing-box.sagernet.org
            After=network.target nss-lookup.target

            [Service]
            Type=simple
            User=root
            Group=root
            CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
            AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
            ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
            Restart=on-failure
            RestartSec=1s
            LimitNOFILE=infinity

            [Install]
            WantedBy=multi-user.target
            """,
            variables: [
                TemplateVariable(name: "protocol", description: "代理协议", type: .select, defaultValue: "shadowsocks", required: true, options: ["shadowsocks", "vmess", "trojan", "hysteria2", "tuic"]),
                TemplateVariable(name: "port", description: "监听端口", type: .number, defaultValue: "8080", required: true),
                TemplateVariable(name: "password", description: "密码", type: .password, required: true),
                TemplateVariable(name: "method", description: "加密方法", type: .select, defaultValue: "aes-256-gcm", required: true, options: ["aes-256-gcm", "aes-128-gcm", "chacha20-poly1305", "none"]),
                TemplateVariable(name: "log_level", description: "日志级别", type: .select, defaultValue: "info", required: false, options: ["debug", "info", "warning", "error"])
            ],
            tags: ["SingBox", "代理", "智能安装", "自动检测", "最新版本"],
            isOfficial: true
        )

        // FRP 服务端模板
        let frpServerTemplate = DeploymentTemplate(
            name: "FRP 服务端",
            description: "部署 FRP 服务端，用于内网穿透",
            serviceType: .frp,
            category: .proxy,
            commands: [
                "mkdir -p /tmp/frp_install",
                "cd /tmp/frp_install && curl -L -o frp.tar.gz \"{{download_url}}\"",
                "cd /tmp/frp_install && tar -xzf frp.tar.gz",
                "cd /tmp/frp_install && sudo mv frp_*/frps /usr/local/bin/",
                "sudo chmod +x /usr/local/bin/frps",
                "sudo mkdir -p /etc/frp",
                "sudo mkdir -p /var/log/frp",
                "frps version",
                "cd / && sudo rm -rf /tmp/frp_install"
            ],
            configTemplate: """
            [common]
            bind_port = {{bind_port}}
            dashboard_port = {{dashboard_port}}
            dashboard_user = {{dashboard_user}}
            dashboard_pwd = {{dashboard_pwd}}
            token = {{token}}
            log_file = /var/log/frp/frps.log
            log_level = {{log_level}}
            log_max_days = 3
            detailed_errors_to_client = false
            """,
            serviceTemplate: """
            [Unit]
            Description=FRP Server
            After=network.target

            [Service]
            Type=simple
            User=root
            Group=root
            ExecStart=/usr/local/bin/frps -c /etc/frp/frps.ini
            Restart=on-failure
            RestartSec=5s

            [Install]
            WantedBy=multi-user.target
            """,
            variables: [
                TemplateVariable(name: "bind_port", description: "FRP 服务端口", type: .number, defaultValue: "7000", required: true),
                TemplateVariable(name: "dashboard_port", description: "管理面板端口", type: .number, defaultValue: "7500", required: true),
                TemplateVariable(name: "dashboard_user", description: "管理面板用户名", type: .string, defaultValue: "admin", required: true),
                TemplateVariable(name: "dashboard_pwd", description: "管理面板密码", type: .password, required: true),
                TemplateVariable(name: "token", description: "认证令牌", type: .password, required: true),
                TemplateVariable(name: "log_level", description: "日志级别", type: .select, defaultValue: "info", required: false, options: ["debug", "info", "warning", "error"])
            ],
            tags: ["FRP", "内网穿透", "服务端", "代理"],
            isOfficial: true
        )

        // FRP 客户端模板
        let frpClientTemplate = DeploymentTemplate(
            name: "FRP 客户端",
            description: "部署 FRP 客户端，连接服务端进行内网穿透",
            serviceType: .frp,
            category: .proxy,
            commands: [
                "mkdir -p /tmp/frp_install",
                "cd /tmp/frp_install && curl -L -o frp.tar.gz \"{{download_url}}\"",
                "cd /tmp/frp_install && tar -xzf frp.tar.gz",
                "cd /tmp/frp_install && sudo mv frp_*/frpc /usr/local/bin/",
                "sudo chmod +x /usr/local/bin/frpc",
                "sudo mkdir -p /etc/frp",
                "sudo mkdir -p /var/log/frp",
                "frpc version",
                "cd / && sudo rm -rf /tmp/frp_install"
            ],
            configTemplate: """
            [common]
            server_addr = {{server_addr}}
            server_port = {{server_port}}
            token = {{token}}
            log_file = /var/log/frp/frpc.log
            log_level = {{log_level}}
            log_max_days = 3

            [{{proxy_name}}]
            type = {{proxy_type}}
            local_ip = {{local_ip}}
            local_port = {{local_port}}
            remote_port = {{remote_port}}
            """,
            serviceTemplate: """
            [Unit]
            Description=FRP Client
            After=network.target

            [Service]
            Type=simple
            User=root
            Group=root
            ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.ini
            Restart=on-failure
            RestartSec=5s

            [Install]
            WantedBy=multi-user.target
            """,
            variables: [
                TemplateVariable(name: "server_addr", description: "FRP 服务端地址", type: .string, required: true),
                TemplateVariable(name: "server_port", description: "FRP 服务端端口", type: .number, defaultValue: "7000", required: true),
                TemplateVariable(name: "token", description: "认证令牌", type: .password, required: true),
                TemplateVariable(name: "proxy_name", description: "代理名称", type: .string, defaultValue: "web", required: true),
                TemplateVariable(name: "proxy_type", description: "代理类型", type: .select, defaultValue: "tcp", required: true, options: ["tcp", "udp", "http", "https"]),
                TemplateVariable(name: "local_ip", description: "本地IP", type: .string, defaultValue: "127.0.0.1", required: true),
                TemplateVariable(name: "local_port", description: "本地端口", type: .number, required: true),
                TemplateVariable(name: "remote_port", description: "远程端口", type: .number, required: true),
                TemplateVariable(name: "log_level", description: "日志级别", type: .select, defaultValue: "info", required: false, options: ["debug", "info", "warning", "error"])
            ],
            tags: ["FRP", "内网穿透", "客户端", "代理"],
            isOfficial: true
        )

        // Docker 安装模板
        let dockerInstallTemplate = DeploymentTemplate(
            name: "Docker 环境",
            description: "安装 Docker 和 Docker Compose 环境",
            serviceType: .docker,
            category: .devops,
            commands: [
                "sudo apt update",
                "sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release",
                "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg",
                "echo \"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null",
                "sudo apt update",
                "sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin",
                "sudo systemctl enable docker",
                "sudo systemctl start docker",
                "sudo usermod -aG docker $USER",
                "docker --version",
                "docker compose version"
            ],
            configTemplate: "",
            serviceTemplate: "",
            variables: [
                TemplateVariable(name: "docker_user", description: "Docker 用户组", type: .string, defaultValue: "$USER", required: false)
            ],
            tags: ["Docker", "容器", "DevOps", "环境"],
            isOfficial: true
        )
        
        // Docker Compose 应用模板
        let dockerComposeTemplate = DeploymentTemplate(
            name: "Docker Compose 应用",
            description: "使用 Docker Compose 部署多容器应用",
            serviceType: .docker,
            category: .devops,
            commands: [
                "mkdir -p {{app_directory}}",
                "cd {{app_directory}}",
                "cat > docker-compose.yml << 'EOF'\n{{docker_compose_config}}\nEOF",
                "docker compose up -d",
                "docker compose ps"
            ],
            configTemplate: """
            version: '3.8'
            services:
              app:
                image: {{image_name}}
                container_name: {{container_name}}
                ports:
                  - "{{host_port}}:{{container_port}}"
                environment:
                  - NODE_ENV={{node_env}}
                volumes:
                  - ./data:/app/data
                restart: unless-stopped
            """,
            serviceTemplate: "",
            variables: [
                TemplateVariable(name: "app_directory", description: "应用目录", type: .string, defaultValue: "/opt/docker-app", required: true),
                TemplateVariable(name: "image_name", description: "Docker 镜像名称", type: .string, defaultValue: "nginx:alpine", required: true),
                TemplateVariable(name: "container_name", description: "容器名称", type: .string, defaultValue: "my-app", required: true),
                TemplateVariable(name: "host_port", description: "主机端口", type: .number, defaultValue: "8080", required: true),
                TemplateVariable(name: "container_port", description: "容器端口", type: .number, defaultValue: "80", required: true),
                TemplateVariable(name: "node_env", description: "环境变量", type: .select, defaultValue: "production", required: false, options: ["development", "production", "test"])
            ],
            tags: ["Docker", "Compose", "容器", "应用部署"],
            isOfficial: true
        )
        
        // Docker 网络代理模板
        let dockerProxyTemplate = DeploymentTemplate(
            name: "Docker 网络代理",
            description: "部署基于 Docker 的网络代理服务",
            serviceType: .docker,
            category: .proxy,
            commands: [
                "mkdir -p {{proxy_directory}}",
                "cd {{proxy_directory}} && cat > docker-compose.yml << 'EOF'\n{{proxy_compose_config}}\nEOF",
                "cd {{proxy_directory}} && docker compose up -d",
                "cd {{proxy_directory}} && docker compose logs -f"
            ],
            configTemplate: """
            version: '3.8'
            services:
              {{proxy_service}}:
                image: {{proxy_image}}
                container_name: {{proxy_container_name}}
                ports:
                  - "{{proxy_port}}:{{proxy_container_port}}"
                environment:
                  - PASSWORD={{proxy_password}}
                  - METHOD={{proxy_method}}
                  - SERVER_PORT={{proxy_container_port}}
                volumes:
                  - ./config:/etc/{{proxy_service}}
                restart: unless-stopped
            """,
            serviceTemplate: "",
            variables: [
                TemplateVariable(name: "proxy_directory", description: "代理目录", type: .string, defaultValue: "/opt/docker-proxy", required: true),
                TemplateVariable(name: "proxy_service", description: "代理服务名称", type: .select, defaultValue: "shadowsocks", required: true, options: ["shadowsocks", "v2ray", "xray", "sing-box"]),
                TemplateVariable(name: "proxy_image", description: "代理镜像", type: .string, defaultValue: "shadowsocks/ssserver-rust:latest", required: true),
                TemplateVariable(name: "proxy_container_name", description: "容器名称", type: .string, defaultValue: "proxy-server", required: true),
                TemplateVariable(name: "proxy_port", description: "代理端口", type: .number, defaultValue: "8388", required: true),
                TemplateVariable(name: "proxy_container_port", description: "容器端口", type: .number, defaultValue: "8388", required: true),
                TemplateVariable(name: "proxy_password", description: "代理密码", type: .password, required: true),
                TemplateVariable(name: "proxy_method", description: "加密方法", type: .select, defaultValue: "aes-256-gcm", required: true, options: ["aes-256-gcm", "chacha20-poly1305", "aes-128-gcm"])
            ],
            tags: ["Docker", "代理", "网络", "容器"],
            isOfficial: true
        )

        // Seafile 私有云存储模板
        let seafileTemplate = DeploymentTemplate(
            name: "Seafile 私有云存储",
            description: "部署 Seafile 私有云存储服务，提供类似 Dropbox 的文件同步功能（请确保Docker已安装）",
            serviceType: .seafile,
            category: .storage,
            commands: [
                "mkdir -p {{seafile_directory}}",
                "cd {{seafile_directory}} && cat > docker-compose.yml << 'EOF'\n{{seafile_compose_config}}\nEOF",
                "cd {{seafile_directory}} && mkdir -p seafile-data",
                "cd {{seafile_directory}} && mkdir -p mysql-data",
                "cd {{seafile_directory}} && docker compose up -d",
                "echo '等待 Seafile 服务启动...'",
                "sleep 30",
                "cd {{seafile_directory}} && docker compose ps",
                "echo 'Seafile 部署完成！访问地址: http://{{server_ip}}:{{web_port}}'"
            ],
            configTemplate: """
            version: '3.8'
            services:
              db:
                image: mariadb:10.7
                container_name: seafile-mysql
                restart: always
                environment:
                  - MYSQL_ROOT_PASSWORD={{mysql_root_password}}
                  - MYSQL_DATABASE=seafile
                  - MYSQL_USER=seafile
                  - MYSQL_PASSWORD={{mysql_password}}
                volumes:
                  - ./mysql-data:/var/lib/mysql
                networks:
                  - seafile-network

              memcached:
                image: memcached:1.6
                container_name: seafile-memcached
                restart: always
                entrypoint: memcached -m 256
                networks:
                  - seafile-network

              seafile:
                image: seafileltd/seafile:{{seafile_version}}
                container_name: seafile
                restart: always
                ports:
                  - "{{web_port}}:80"
                volumes:
                  - ./seafile-data:/shared
                environment:
                  - DB_HOST=db
                  - DB_ROOT_PASSWD={{mysql_root_password}}
                  - TIME_ZONE={{timezone}}
                  - SEAFILE_ADMIN_EMAIL={{admin_email}}
                  - SEAFILE_ADMIN_PASSWORD={{admin_password}}
                  - SEAFILE_SERVER_LETSENCRYPT=false
                  - SEAFILE_SERVER_HOSTNAME={{server_ip}}
                depends_on:
                  - db
                  - memcached
                networks:
                  - seafile-network

            networks:
              seafile-network:
                driver: bridge
            """,
            serviceTemplate: "",
            variables: [
                TemplateVariable(name: "seafile_directory", description: "Seafile 安装目录", type: .string, defaultValue: "/opt/seafile", required: true),
                TemplateVariable(name: "seafile_version", description: "Seafile 版本", type: .select, defaultValue: "latest", required: true, options: ["latest", "9.0", "8.0", "7.1"]),
                TemplateVariable(name: "web_port", description: "Web 访问端口", type: .number, defaultValue: "8000", required: true),
                TemplateVariable(name: "server_ip", description: "服务器 IP 地址", type: .string, required: true),
                TemplateVariable(name: "mysql_root_password", description: "MySQL Root 密码", type: .password, required: true),
                TemplateVariable(name: "mysql_password", description: "MySQL Seafile 用户密码", type: .password, required: true),
                TemplateVariable(name: "admin_email", description: "管理员邮箱", type: .string, defaultValue: "admin@example.com", required: true),
                TemplateVariable(name: "admin_password", description: "管理员密码", type: .password, required: true),
                TemplateVariable(name: "timezone", description: "时区设置", type: .select, defaultValue: "Asia/Shanghai", required: false, options: ["Asia/Shanghai", "UTC", "America/New_York", "Europe/London"])
            ],
            tags: ["Seafile", "私有云", "文件同步", "存储", "Docker"],
            isOfficial: true
        )

        templates.append(contentsOf: [wordpressTemplate, frpServerTemplate, frpClientTemplate, singboxInstallTemplate, dockerInstallTemplate, dockerComposeTemplate, dockerProxyTemplate, seafileTemplate])
    }
    
    private func loadCustomTemplates() {
        guard let data = UserDefaults.standard.data(forKey: "customTemplates") else { return }
        
        do {
            let customTemplates = try JSONDecoder().decode([DeploymentTemplate].self, from: data)
            templates.append(contentsOf: customTemplates)
        } catch {
            print("Failed to load custom templates: \(error)")
        }
    }
    
    private func saveTemplates() {
        // 只保存用户自定义模板
        let customTemplates = templates.filter { !$0.isOfficial }
        
        do {
            let data = try JSONEncoder().encode(customTemplates)
            UserDefaults.standard.set(data, forKey: "customTemplates")
        } catch {
            print("Failed to save custom templates: \(error)")
        }
    }
    
    private func loadDeploymentTasks() {
        guard let data = UserDefaults.standard.data(forKey: "deploymentTasks") else { return }
        
        do {
            deploymentTasks = try JSONDecoder().decode([DeploymentTask].self, from: data)
        } catch {
            print("Failed to load deployment tasks: \(error)")
        }
    }
    
    private func saveDeploymentTasks() {
        do {
            let data = try JSONEncoder().encode(deploymentTasks)
            UserDefaults.standard.set(data, forKey: "deploymentTasks")
        } catch {
            print("Failed to save deployment tasks: \(error)")
        }
    }
    
    /// 检测系统环境信息
    private func detectSystemEnvironment(vps: VPSInstance) async throws -> SystemEnvironmentInfo {
        // 检测操作系统
        let osInfo = try await vpsManager.executeSSHCommandForService("cat /etc/os-release | grep PRETTY_NAME", on: vps)
        let osName = osInfo.contains("Debian") ? "Debian" : 
                    osInfo.contains("Ubuntu") ? "Ubuntu" : 
                    osInfo.contains("CentOS") ? "CentOS" : 
                    osInfo.contains("RHEL") ? "RHEL" : "Unknown"
        
        // 检测当前用户
        let currentUser = try await vpsManager.executeSSHCommandForService("whoami", on: vps).trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 检测sudo是否可用
        let sudoCheck = try await vpsManager.executeSSHCommandForService("which sudo", on: vps)
        let hasSudo = !sudoCheck.isEmpty
        
        // 检测是否为root用户
        let isRoot = currentUser == "root"
        
        // 检测sudo权限
        var hasSudoPrivileges = false
        if hasSudo && !isRoot {
            do {
                _ = try await vpsManager.executeSSHCommandForService("sudo -n true", on: vps)
                hasSudoPrivileges = true
            } catch {
                hasSudoPrivileges = false
            }
        }
        
        // 检测包管理器
        let packageManager = try await detectPackageManager(vps: vps)
        
        let systemInfo = SystemEnvironmentInfo(
            osName: osName,
            currentUser: currentUser,
            isRoot: isRoot,
            hasSudo: hasSudo,
            hasSudoPrivileges: hasSudoPrivileges,
            packageManager: packageManager
        )
        
        addLog(to: currentTask?.id ?? UUID(), level: .info, message: "系统环境: \(systemInfo.description)")
        
        return systemInfo
    }
    
    /// 检测包管理器
    private func detectPackageManager(vps: VPSInstance) async throws -> PackageManager {
        // 检测apt (Debian/Ubuntu)
        do {
            let aptCheck = try await vpsManager.executeSSHCommandForService("which apt", on: vps)
            if !aptCheck.isEmpty {
                return .apt
            }
        } catch {}
        
        // 检测yum (CentOS/RHEL)
        do {
            let yumCheck = try await vpsManager.executeSSHCommandForService("which yum", on: vps)
            if !yumCheck.isEmpty {
                return .yum
            }
        } catch {}
        
        // 检测dnf (Fedora/RHEL 8+)
        do {
            let dnfCheck = try await vpsManager.executeSSHCommandForService("which dnf", on: vps)
            if !dnfCheck.isEmpty {
                return .dnf
            }
        } catch {}
        
        return .unknown
    }
    
    /// 智能命令执行 - 自动处理sudo问题
    private func executeSmartCommand(_ command: String, systemInfo: SystemEnvironmentInfo, vps: VPSInstance) async throws -> String {
        var currentSystemInfo = systemInfo
        var processedCommand = processCommandForSystem(command: command, systemInfo: currentSystemInfo)
        
        addLog(to: currentTask?.id ?? UUID(), level: .info, message: "执行命令: \(processedCommand)")
        
        do {
            let output = try await vpsManager.executeSSHCommandForService(processedCommand, on: vps)
            addLog(to: currentTask?.id ?? UUID(), level: .success, message: "命令执行成功")
            if !output.isEmpty {
                addLog(to: currentTask?.id ?? UUID(), level: .info, message: "输出: \(output)")
            }
            return output
        } catch {
            addLog(to: currentTask?.id ?? UUID(), level: .error, message: "命令执行失败: \(error.localizedDescription)")
            
            // 如果命令失败且涉及sudo，尝试自动修复
            if command.hasPrefix("sudo") && !currentSystemInfo.hasSudoPrivileges && !currentSystemInfo.isRoot {
                addLog(to: currentTask?.id ?? UUID(), level: .warning, message: "检测到sudo问题，尝试自动修复...")
                
                do {
                    let fixed = try await autoFixSudoIssues(systemInfo: currentSystemInfo, vps: vps)
                    if fixed {
                        // 重新检测系统环境
                        currentSystemInfo = try await detectSystemEnvironment(vps: vps)
                        processedCommand = processCommandForSystem(command: command, systemInfo: currentSystemInfo)
                        
                        addLog(to: currentTask?.id ?? UUID(), level: .info, message: "sudo修复成功，重新执行命令: \(processedCommand)")
                        
                        // 重新执行命令
                        let output = try await vpsManager.executeSSHCommandForService(processedCommand, on: vps)
                        addLog(to: currentTask?.id ?? UUID(), level: .success, message: "命令执行成功")
                        if !output.isEmpty {
                            addLog(to: currentTask?.id ?? UUID(), level: .info, message: "输出: \(output)")
                        }
                        return output
                    }
                } catch {
                    addLog(to: currentTask?.id ?? UUID(), level: .error, message: "sudo自动修复失败: \(error.localizedDescription)")
                }
                
                // 如果自动修复失败，提供手动解决方案
                let solution = generateSudoSolution(systemInfo: currentSystemInfo)
                addLog(to: currentTask?.id ?? UUID(), level: .warning, message: "sudo权限问题: \(solution)")
            }
            
            throw error
        }
    }
    
    /// 智能多行指令执行 - 支持变量作用域和复杂脚本
    private func executeSmartMultiLineCommands(_ commands: [String], systemInfo: SystemEnvironmentInfo, vps: VPSInstance) async throws -> [String] {
        let currentSystemInfo = systemInfo
        var results: [String] = []
        var environmentVariables: [String: String] = [:]
        
        addLog(to: currentTask?.id ?? UUID(), level: .info, message: "开始执行多行指令，共 \(commands.count) 个指令")
        
        // 分析指令，识别多行脚本块
        let processedCommands = processMultiLineCommands(commands)
        
        for (index, commandGroup) in processedCommands.enumerated() {
            addLog(to: currentTask?.id ?? UUID(), level: .info, message: "执行指令组 \(index + 1)/\(processedCommands.count)")
            
            do {
                let result = try await executeCommandGroup(
                    commandGroup,
                    systemInfo: currentSystemInfo,
                    vps: vps,
                    environmentVariables: &environmentVariables
                )
                
                results.append(result)
                
            } catch {
                addLog(to: currentTask?.id ?? UUID(), level: .error, message: "指令组 \(index + 1) 执行失败: \(error.localizedDescription)")
                throw error
            }
        }
        
        addLog(to: currentTask?.id ?? UUID(), level: .success, message: "多行指令执行完成")
        return results
    }
    

    
    /// 处理命令以适应系统环境
    private func processCommandForSystem(command: String, systemInfo: SystemEnvironmentInfo) -> String {
        var processedCommand = command
        
        // 如果已经是root用户，移除sudo
        if systemInfo.isRoot && command.hasPrefix("sudo ") {
            processedCommand = String(command.dropFirst(5))
            addLog(to: currentTask?.id ?? UUID(), level: .info, message: "检测到root用户，移除sudo前缀")
        }
        
        // 如果没有sudo权限，提供替代方案
        if command.hasPrefix("sudo ") && !systemInfo.hasSudoPrivileges && !systemInfo.isRoot {
            processedCommand = generateSudoAlternative(command: command, systemInfo: systemInfo)
            addLog(to: currentTask?.id ?? UUID(), level: .warning, message: "sudo不可用，使用替代方案")
        }
        
        return processedCommand
    }
    
    /// 处理多行指令，识别脚本块和变量定义
    private func processMultiLineCommands(_ commands: [String]) -> [CommandGroup] {
        var commandGroups: [CommandGroup] = []
        var currentGroup: CommandGroup?
        var currentScriptLines: [String] = []
        var inScriptBlock = false
        
        for (_, command) in commands.enumerated() {
            let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 跳过空行和注释
            if trimmedCommand.isEmpty || trimmedCommand.hasPrefix("#") {
                continue
            }
            
            // 检查是否是脚本块开始
            if isScriptBlockStart(trimmedCommand) {
                // 如果有未完成的组，先保存
                if let group = currentGroup {
                    commandGroups.append(group)
                }
                
                // 开始新的脚本块
                inScriptBlock = true
                currentScriptLines = [trimmedCommand]
                currentGroup = CommandGroup(type: .script, commands: [], scriptContent: "")
                
            } else if inScriptBlock {
                // 在脚本块中
                currentScriptLines.append(trimmedCommand)
                
                // 检查是否是脚本块结束
                if isScriptBlockEnd(trimmedCommand) {
                    inScriptBlock = false
                    currentGroup?.scriptContent = currentScriptLines.joined(separator: "\n")
                    if let group = currentGroup {
                        commandGroups.append(group)
                    }
                    currentGroup = nil
                    currentScriptLines = []
                }
                
            } else {
                // 普通指令
                if let group = currentGroup {
                    commandGroups.append(group)
                }
                currentGroup = CommandGroup(type: .single, commands: [trimmedCommand], scriptContent: "")
            }
        }
        
        // 处理最后一个组
        if let group = currentGroup {
            commandGroups.append(group)
        }
        
        return commandGroups
    }
    
    /// 检查是否是脚本块开始
    private func isScriptBlockStart(_ command: String) -> Bool {
        let scriptStartPatterns = [
            "#!/bin/bash",
            "#!/bin/sh",
            "#!/usr/bin/env bash",
            "#!/usr/bin/env sh",
            "cat << 'EOF'",
            "cat << EOF",
            "tee << 'EOF'",
            "tee << EOF"
        ]
        
        return scriptStartPatterns.contains { command.hasPrefix($0) }
    }
    
    /// 检查是否是脚本块结束
    private func isScriptBlockEnd(_ command: String) -> Bool {
        return command == "EOF" || command == "'EOF'"
    }
    
    /// 执行指令组
    private func executeCommandGroup(
        _ group: CommandGroup,
        systemInfo: SystemEnvironmentInfo,
        vps: VPSInstance,
        environmentVariables: inout [String: String]
    ) async throws -> String {
        
        switch group.type {
        case .script:
            return try await executeScriptBlock(group.scriptContent, systemInfo: systemInfo, vps: vps, environmentVariables: &environmentVariables)
        case .single:
            return try await executeSingleCommand(group.commands.first ?? "", systemInfo: systemInfo, vps: vps, environmentVariables: &environmentVariables)
        }
    }
    
    /// 执行脚本块
    private func executeScriptBlock(
        _ scriptContent: String,
        systemInfo: SystemEnvironmentInfo,
        vps: VPSInstance,
        environmentVariables: inout [String: String]
    ) async throws -> String {
        
        addLog(to: currentTask?.id ?? UUID(), level: .info, message: "执行脚本块")
        
        // 创建临时脚本文件
        let scriptFileName = "deploy_script_\(UUID().uuidString).sh"
        let scriptPath = "/tmp/\(scriptFileName)"
        
        // 处理脚本内容，替换环境变量
        let processedScript = processScriptWithEnvironmentVariables(scriptContent, environmentVariables: environmentVariables)
        
        // 上传脚本文件
        try await vpsManager.writeFile(content: processedScript, to: scriptPath, on: vps)
        
        // 设置执行权限
        try await vpsManager.executeSSHCommandForService("chmod +x \(scriptPath)", on: vps)
        
        // 执行脚本
        let output = try await vpsManager.executeSSHCommandForService(scriptPath, on: vps)
        
        // 清理临时文件
        try? await vpsManager.executeSSHCommandForService("rm -f \(scriptPath)", on: vps)
        
        // 解析输出中的变量定义
        parseEnvironmentVariablesFromOutput(output, environmentVariables: &environmentVariables)
        
        return output
    }
    
    /// 执行单个指令
    private func executeSingleCommand(
        _ command: String,
        systemInfo: SystemEnvironmentInfo,
        vps: VPSInstance,
        environmentVariables: inout [String: String]
    ) async throws -> String {
        
        // 处理指令中的环境变量
        let processedCommand = processCommandWithEnvironmentVariables(command, environmentVariables: environmentVariables)
        
        // 执行指令
        let output = try await executeSmartCommand(processedCommand, systemInfo: systemInfo, vps: vps)
        
        // 解析输出中的变量定义
        parseEnvironmentVariablesFromOutput(output, environmentVariables: &environmentVariables)
        
        return output
    }
    
    /// 处理脚本中的环境变量
    private func processScriptWithEnvironmentVariables(_ script: String, environmentVariables: [String: String]) -> String {
        var processedScript = script
        
        // 替换环境变量引用
        for (key, value) in environmentVariables {
            processedScript = processedScript.replacingOccurrences(of: "$\(key)", with: value)
            processedScript = processedScript.replacingOccurrences(of: "${\(key)}", with: value)
        }
        
        return processedScript
    }
    
    /// 处理指令中的环境变量
    private func processCommandWithEnvironmentVariables(_ command: String, environmentVariables: [String: String]) -> String {
        var processedCommand = command
        
        // 替换环境变量引用
        for (key, value) in environmentVariables {
            processedCommand = processedCommand.replacingOccurrences(of: "$\(key)", with: value)
            processedCommand = processedCommand.replacingOccurrences(of: "${\(key)}", with: value)
        }
        
        return processedCommand
    }
    
    /// 从输出中解析环境变量定义
    private func parseEnvironmentVariablesFromOutput(_ output: String, environmentVariables: inout [String: String]) {
        let lines = output.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 匹配变量定义模式：VAR=value 或 export VAR=value
            let patterns = [
                #"^export\s+([A-Za-z_][A-Za-z0-9_]*)=(.*)$"#,
                #"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$"#
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: trimmedLine, options: [], range: NSRange(trimmedLine.startIndex..., in: trimmedLine)) {
                    
                    let varName = String(trimmedLine[Range(match.range(at: 1), in: trimmedLine)!])
                    let varValue = String(trimmedLine[Range(match.range(at: 2), in: trimmedLine)!])
                    
                    // 移除引号
                    let cleanValue = varValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    
                    environmentVariables[varName] = cleanValue
                    addLog(to: currentTask?.id ?? UUID(), level: .info, message: "解析到环境变量: \(varName)=\(cleanValue)")
                    break
                }
            }
        }
    }
    
    /// 生成sudo替代方案
    private func generateSudoAlternative(command: String, systemInfo: SystemEnvironmentInfo) -> String {
        let commandWithoutSudo = String(command.dropFirst(5))
        
        // 对于Debian/Ubuntu系统，尝试使用su
        if systemInfo.packageManager == .apt {
            return "su -c '\(commandWithoutSudo)'"
        }
        
        // 对于其他系统，尝试直接执行（可能需要手动处理权限）
        return commandWithoutSudo
    }
    
    /// 生成sudo问题解决方案
    private func generateSudoSolution(systemInfo: SystemEnvironmentInfo) -> String {
        if systemInfo.isRoot {
            return "当前已是root用户，无需sudo"
        }
        
        if !systemInfo.hasSudo {
            switch systemInfo.packageManager {
            case .apt:
                return "系统未安装sudo，请运行: apt update && apt install -y sudo"
            case .yum, .dnf:
                return "系统未安装sudo，请运行: yum install -y sudo 或 dnf install -y sudo"
            default:
                return "请手动安装sudo或切换到root用户"
            }
        }
        
        if !systemInfo.hasSudoPrivileges {
            return "当前用户没有sudo权限，请联系管理员或切换到root用户"
        }
        
        return "sudo配置异常，请检查/etc/sudoers文件"
    }
    
    /// 自动修复sudo问题
    private func autoFixSudoIssues(systemInfo: SystemEnvironmentInfo, vps: VPSInstance) async throws -> Bool {
        addLog(to: currentTask?.id ?? UUID(), level: .info, message: "尝试自动修复sudo问题...")
        
        // 使用SudoHandler诊断问题
        let problem = SudoHandler.diagnoseSudoProblem(systemInfo: systemInfo)
        let solution = SudoHandler.generateSolution(for: problem, systemInfo: systemInfo)
        
        addLog(to: currentTask?.id ?? UUID(), level: .info, message: "诊断结果: \(problem.description)")
        addLog(to: currentTask?.id ?? UUID(), level: .info, message: "解决方案: \(solution.description)")
        
        // 如果已经是root用户，无需修复
        if systemInfo.isRoot {
            addLog(to: currentTask?.id ?? UUID(), level: .success, message: "当前已是root用户，无需sudo")
            return true
        }
        
        // 如果有自动修复命令，执行它们
        if solution.isAutomatic {
            addLog(to: currentTask?.id ?? UUID(), level: .info, message: "执行自动修复命令...")
            
            for (index, command) in solution.commands.enumerated() {
                addLog(to: currentTask?.id ?? UUID(), level: .info, message: "执行修复命令 \(index + 1)/\(solution.commands.count): \(command)")
                if command.isEmpty || command.starts(with: "#") {
                    continue
                }
                do {
                    let output = try await vpsManager.executeSSHCommandForService(command, on: vps)
                    addLog(to: currentTask?.id ?? UUID(), level: .success, message: "修复命令执行成功")
                    if !output.isEmpty {
                        addLog(to: currentTask?.id ?? UUID(), level: .info, message: "输出: \(output)")
                    }
                } catch {
                    addLog(to: currentTask?.id ?? UUID(), level: .error, message: "修复命令执行失败: \(error.localizedDescription)")
                    return false
                }
            }
            
            // 验证修复结果
            let newSystemInfo = try await detectSystemEnvironment(vps: vps)
            if newSystemInfo.hasSudoPrivileges || newSystemInfo.isRoot {
                addLog(to: currentTask?.id ?? UUID(), level: .success, message: "sudo问题修复成功")
                return true
            } else {
                addLog(to: currentTask?.id ?? UUID(), level: .warning, message: "sudo问题修复失败，可能需要手动处理")
                return false
            }
        } else {
            // 提供手动修复步骤
            addLog(to: currentTask?.id ?? UUID(), level: .warning, message: "需要手动修复sudo问题")
            for (index, step) in solution.manualSteps.enumerated() {
                addLog(to: currentTask?.id ?? UUID(), level: .info, message: "手动步骤 \(index + 1): \(step)")
            }
            return false
        }
    }
    
    /// 安装sudo
    private func installSudo(systemInfo: SystemEnvironmentInfo, vps: VPSInstance) async throws -> Bool {
        addLog(to: currentTask?.id ?? UUID(), level: .info, message: "正在安装sudo...")
        
        let installCommand: String
        switch systemInfo.packageManager {
        case .apt:
            installCommand = "apt update && apt install -y sudo"
        case .yum:
            installCommand = "yum install -y sudo"
        case .dnf:
            installCommand = "dnf install -y sudo"
        case .unknown:
            addLog(to: currentTask?.id ?? UUID(), level: .error, message: "无法确定包管理器，无法自动安装sudo")
            return false
        }
        
        do {
            _ = try await vpsManager.executeSSHCommandForService(installCommand, on: vps)
            addLog(to: currentTask?.id ?? UUID(), level: .success, message: "sudo安装成功")
            return true
        } catch {
            addLog(to: currentTask?.id ?? UUID(), level: .error, message: "sudo安装失败: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 配置sudo权限
    private func configureSudoPrivileges(systemInfo: SystemEnvironmentInfo, vps: VPSInstance) async throws -> Bool {
        addLog(to: currentTask?.id ?? UUID(), level: .info, message: "正在配置sudo权限...")
        
        let currentUser = systemInfo.currentUser
        
        // 尝试将用户添加到sudo组
        let addToSudoGroupCommand: String
        switch systemInfo.packageManager {
        case .apt:
            addToSudoGroupCommand = "usermod -aG sudo \(currentUser)"
        case .yum, .dnf:
            addToSudoGroupCommand = "usermod -aG wheel \(currentUser)"
        case .unknown:
            addToSudoGroupCommand = "usermod -aG sudo \(currentUser)"
        }
        
        do {
            _ = try await vpsManager.executeSSHCommandForService(addToSudoGroupCommand, on: vps)
            addLog(to: currentTask?.id ?? UUID(), level: .success, message: "用户已添加到sudo组")
            
            // 验证sudo权限
            _ = try await vpsManager.executeSSHCommandForService("sudo -n true", on: vps)
            addLog(to: currentTask?.id ?? UUID(), level: .success, message: "sudo权限配置成功")
            return true
        } catch {
            addLog(to: currentTask?.id ?? UUID(), level: .warning, message: "sudo权限配置失败，可能需要重新登录或手动配置")
            return false
        }
    }
    
    /// 生成Debian系统的sudo安装和配置脚本
    private func generateDebianSudoScript() -> String {
        return """
        #!/bin/bash
        
        if [ "$EUID" -eq 0 ]; then
            exit 0
        fi
        
        if command -v sudo &> /dev/null; then
            if sudo -n true 2>/dev/null; then
                exit 0
            fi
        else
            apt update
            apt install -y sudo
        fi
        
        CURRENT_USER=$(whoami)
        usermod -aG sudo $CURRENT_USER
        
        if [ ! -f /etc/sudoers.d/$CURRENT_USER ]; then
            echo "$CURRENT_USER ALL=(ALL:ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/$CURRENT_USER
        fi
        """
    }
    
    /// 生成CentOS/RHEL系统的sudo安装和配置脚本
    private func generateCentOSSudoScript() -> String {
        return """
        #!/bin/bash
        
        if [ "$EUID" -eq 0 ]; then
            exit 0
        fi
        
        if command -v sudo &> /dev/null; then
            if sudo -n true 2>/dev/null; then
                exit 0
            fi
        else
            if command -v dnf &> /dev/null; then
                dnf install -y sudo
            elif command -v yum &> /dev/null; then
                yum install -y sudo
            else
                exit 1
            fi
        fi
        
        CURRENT_USER=$(whoami)
        usermod -aG wheel $CURRENT_USER
        
        if [ ! -f /etc/sudoers.d/$CURRENT_USER ]; then
            echo "$CURRENT_USER ALL=(ALL:ALL) NOPASSWD:ALL" | tee /etc/sudoers.d/$CURRENT_USER
        fi
        """
    }
}

// MARK: - Deployment Plan

struct DeploymentPlan {
    let commands: [String]
    let variables: [String: String]
    let description: String?
    let estimatedTime: String?
    let requirements: [String]?
    let notes: [String]?
    
    init(
        commands: [String],
        variables: [String: String] = [:],
        description: String? = nil,
        estimatedTime: String? = nil,
        requirements: [String]? = nil,
        notes: [String]? = nil
    ) {
        self.commands = commands
        self.variables = variables
        self.description = description
        self.estimatedTime = estimatedTime
        self.requirements = requirements
        self.notes = notes
    }
}

// MARK: - Deployment Service Errors

enum DeploymentServiceError: LocalizedError {
    case vpsNotFound
    case templateNotFound
    case taskNotFound
    case noDeploymentPlan
    case missingRequiredVariable(String)
    case deploymentFailed(String)
    case invalidConfiguration(String)
    case connectionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .vpsNotFound:
            return "VPS 实例未找到"
        case .templateNotFound:
            return "部署模板未找到"
        case .taskNotFound:
            return "部署任务未找到"
        case .noDeploymentPlan:
            return "没有部署计划"
        case .missingRequiredVariable(let name):
            return "缺少必需变量: \(name)"
        case .deploymentFailed(let message):
            return "部署失败: \(message)"
        case .invalidConfiguration(let message):
            return "配置错误: \(message)"
        case .connectionFailed(let message):
            return "连接失败: \(message)"
        }
    }
}

// MARK: - System Environment Info

struct SystemEnvironmentInfo {
    let osName: String
    let currentUser: String
    let isRoot: Bool
    let hasSudo: Bool
    let hasSudoPrivileges: Bool
    let packageManager: PackageManager
    
    var description: String {
        var desc = "OS: \(osName), User: \(currentUser)"
        
        if isRoot {
            desc += " (root)"
        } else if hasSudoPrivileges {
            desc += " (sudo可用)"
        } else if hasSudo {
            desc += " (sudo无权限)"
        } else {
            desc += " (无sudo)"
        }
        
        desc += ", Package Manager: \(packageManager.rawValue)"
        return desc
    }
}

// MARK: - Command Group

struct CommandGroup {
    enum GroupType {
        case single
        case script
    }
    
    let type: GroupType
    let commands: [String]
    var scriptContent: String
    
    init(type: GroupType, commands: [String], scriptContent: String) {
        self.type = type
        self.commands = commands
        self.scriptContent = scriptContent
    }
}

// MARK: - Package Manager

enum PackageManager: String, CaseIterable {
    case apt = "apt"
    case yum = "yum"
    case dnf = "dnf"
    case unknown = "unknown"
    
    var installCommand: String {
        switch self {
        case .apt:
            return "apt install -y"
        case .yum:
            return "yum install -y"
        case .dnf:
            return "dnf install -y"
        case .unknown:
            return "unknown"
        }
    }
    
    var updateCommand: String {
        switch self {
        case .apt:
            return "apt update"
        case .yum:
            return "yum update -y"
        case .dnf:
            return "dnf update -y"
        case .unknown:
            return "unknown"
        }
    }
}

// MARK: - SingBox 预填充方法

extension DeploymentService {
    
    /// 获取 SingBox 最新版本
    private func getLatestSingBoxVersion() async -> String? {
        let urlString = "https://api.github.com/repos/SagerNet/sing-box/releases/latest"
        
        guard let url = URL(string: urlString) else {
            print("无效的 URL: \(urlString)")
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("HTTP 请求失败: \(response)")
                return nil
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                print("JSON 解析失败")
                return nil
            }
            
            // 移除版本号前面的 'v' 字符
            let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            return version
            
        } catch {
            print("获取最新版本失败: \(error)")
            return nil
        }
    }
    
    /// 构建 SingBox 下载链接
    private func buildSingBoxDownloadURL(version: String, architecture: String) -> String {
        let archName = architectureMapping[architecture] ?? "amd64"
        return "https://github.com/SagerNet/sing-box/releases/download/v\(version)/sing-box-\(version)-linux-\(archName).tar.gz"
    }
    
    /// 预填充 SingBox 下载链接
    /// - Parameters:
    ///   - vps: VPS 实例
    ///   - variables: 原始变量
    /// - Returns: 包含下载链接的变量
    private func prefillSingBoxDownloadURL(vps: VPSInstance, variables: [String: String]) async throws -> [String: String] {
        var finalVariables = variables
        
        // 并行获取最新版本和 VPS 架构
        async let versionTask = getLatestSingBoxVersion()
        async let architectureTask = detectVPSArchitecture(vps: vps)
        
        let (version, architecture) = await (versionTask, architectureTask)
        
        guard let version = version, let architecture = architecture else {
            throw DeploymentServiceError.deploymentFailed("无法获取 SingBox 下载信息")
        }
        
        // 构建下载链接并自动填充
        let downloadURL = buildSingBoxDownloadURL(version: version, architecture: architecture)
        finalVariables["download_url"] = downloadURL
        
        return finalVariables
    }
    
    /// 检测 VPS 系统架构
    private func detectVPSArchitecture(vps: VPSInstance) async -> String? {
        do {
            // 使用VPSManager的SSH客户端管理
            let result = try await vpsManager.executeSSHCommandForService("uname -m", on: vps)
            
            let architecture = result.trimmingCharacters(in: .whitespacesAndNewlines)
            addLog(to: currentTask?.id ?? UUID(), level: .info, message: "检测到系统架构: \(architecture)")
            return architecture
            
        } catch {
            addLog(to: currentTask?.id ?? UUID(), level: .warning, message: "检测 VPS 架构失败: \(error.localizedDescription)")
            print("检测 VPS 架构失败: \(error)")
            return "x86_64" // 默认架构
        }
    }
}

// MARK: - FRP 预填充方法

extension DeploymentService {
    
    /// 获取 FRP 最新版本
    private func getLatestFRPVersion() async -> String? {
        let urlString = "https://api.github.com/repos/fatedier/frp/releases/latest"
        
        guard let url = URL(string: urlString) else {
            print("无效的 URL: \(urlString)")
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("HTTP 请求失败: \(response)")
                return nil
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else {
                print("JSON 解析失败")
                return nil
            }
            
            // 移除版本号前面的 'v' 字符
            let version = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            return version
            
        } catch {
            print("获取最新版本失败: \(error)")
            return nil
        }
    }
    
    /// 构建 FRP 下载链接
    private func buildFRPDownloadURL(version: String, architecture: String) -> String {
        let archName = frpArchitectureMapping[architecture] ?? "amd64"
        return "https://github.com/fatedier/frp/releases/download/v\(version)/frp_\(version)_linux_\(archName).tar.gz"
    }
    
    /// 预填充 FRP 下载链接
    /// - Parameters:
    ///   - vps: VPS 实例
    ///   - variables: 原始变量
    /// - Returns: 包含下载链接的变量
    private func prefillFRPDownloadURL(vps: VPSInstance, variables: [String: String]) async throws -> [String: String] {
        var finalVariables = variables
        
        // 并行获取最新版本和 VPS 架构
        async let versionTask = getLatestFRPVersion()
        async let architectureTask = detectVPSArchitecture(vps: vps)
        
        let (version, architecture) = await (versionTask, architectureTask)
        
        guard let version = version, let architecture = architecture else {
            throw DeploymentServiceError.deploymentFailed("无法获取 FRP 下载信息")
        }
        
        // 构建下载链接并自动填充
        let downloadURL = buildFRPDownloadURL(version: version, architecture: architecture)
        finalVariables["download_url"] = downloadURL
        
        return finalVariables
    }
    
    /// 清除所有部署任务
    func clearAllTasks() {
        // 取消所有正在进行的任务
        currentTask = nil
        
        // 清除所有部署任务
        deploymentTasks.removeAll()
        
        // 保存空数据到本地存储
        saveDeploymentTasks()
        
        print("All deployment tasks cleared")
    }
    
    /// 清除AI部署计划缓存
    func clearDeploymentPlanCache() {
        deploymentPlanCache.removeAll()
        print("Deployment plan cache cleared")
    }
    
    /// 清除过期的缓存
    func clearExpiredCache() {
        let now = Date()
        let expiredKeys = deploymentPlanCache.compactMap { key, value in
            now.timeIntervalSince(value.timestamp) >= cacheExpirationInterval ? key : nil
        }
        
        for key in expiredKeys {
            deploymentPlanCache.removeValue(forKey: key)
        }
        
        if !expiredKeys.isEmpty {
            print("Cleared \(expiredKeys.count) expired cache entries")
        }
    }
}
