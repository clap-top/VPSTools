import Foundation
import Combine
import SwiftUI

// MARK: - VPS Manager

/// VPS 管理服务
@MainActor
class VPSManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var vpsInstances: [VPSInstance] = []
    @Published var selectedVPS: VPSInstance?
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    @Published var connectionTestResults: [UUID: ConnectionTestResult] = [:]
    @Published var monitoringData: [UUID: [MonitoringData]] = [:]
    
    // MARK: - Private Properties
    
    // SSH客户端管理
    private var sshClients: [UUID: SSHClient] = [:]
    private var sshConnectionStates: [UUID: SSHConnectionState] = [:]
    @Published var activeSSHConnections: Int = 0
    private let maxConcurrentConnections: Int = 10
    
    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimers: [UUID: Timer] = [:]
    
    // 连接检测状态跟踪
    private var connectionTestTasks: [UUID: Task<Void, Never>] = [:]
    private var connectionTestStatus: [UUID: ConnectionTestStatus] = [:]
    
    // App 生命周期内的状态管理
    private var hasInitializedConnections = false
    
    // MARK: - Initialization
    
    init() {
        loadVPSInstances()
        setupBindings()
    }
    
    deinit {
        // 在 deinit 中直接清理定时器，避免调用 @MainActor 方法
        monitoringTimers.values.forEach { $0.invalidate() }
        monitoringTimers.removeAll()
        
        // 清理SSH连接（异步执行）
        Task { [weak self] in
            await self?.disconnectAllSSHClients()
        }
    }
    
    // MARK: - Public Methods
    
    /// 添加 VPS 实例
    func addVPS(_ vps: VPSInstance) async throws {
        // 验证 VPS 配置
        try validateVPS(vps)
        
        // 测试连接
        let testResult = await testConnection(for: vps)
        if !testResult.isConnected {
            let errorMessage = testResult.sshError ?? "未知连接错误"
            throw VPSManagerError.connectionFailed(errorMessage)
        }
        
        // 检查是否已存在相同的主机和端口
        let existingVPS = vpsInstances.first { existing in
            existing.host == vps.host && existing.port == vps.port
        }
        
        if let existing = existingVPS {
            throw VPSManagerError.invalidConfiguration("已存在相同的主机地址和端口：\(existing.name)")
        }
        
        // 获取系统信息
        var vpsWithSystemInfo = vps
        if let systemInfo = try? await getSystemInfo(for: vps) {
            vpsWithSystemInfo.systemInfo = systemInfo
        }
        
        // 设置连接时间和更新时间
        vpsWithSystemInfo.lastConnected = Date()
        vpsWithSystemInfo.updatedAt = Date()
        
        // 添加到列表
        vpsInstances.append(vpsWithSystemInfo)
        saveVPSInstances()
        
        // 开始监控
        startMonitoring(for: vpsWithSystemInfo)
        
        // 重置初始化状态，以便下次可以检测新添加的 VPS
        resetInitializationState()
    }
    
    /// 更新 VPS 实例
    func updateVPS(_ vps: VPSInstance) async throws {
        guard let index = vpsInstances.firstIndex(where: { $0.id == vps.id }) else {
            throw VPSManagerError.vpsNotFound
        }
        
        // 验证 VPS 配置
        try validateVPS(vps)
        
        // 测试连接
        let testResult = await testConnection(for: vps)
        if !testResult.isConnected {
            throw VPSManagerError.connectionFailed(testResult.sshError ?? "未知连接错误")
        }
        
        // 更新实例
        var updatedVPS = vps
        updatedVPS.updatedAt = Date()
        updatedVPS.lastConnected = Date()
        updatedVPS.systemInfo = testResult.systemInfo
        
        vpsInstances[index] = updatedVPS
        saveVPSInstances()
        
        // 重新开始监控
        stopMonitoring(for: vps)
        startMonitoring(for: updatedVPS)
    }
    
    /// 删除 VPS 实例
    func deleteVPS(_ vps: VPSInstance) async {
        // 停止监控
        stopMonitoring(for: vps)
        
        // 取消正在进行的连接检测
        connectionTestTasks[vps.id]?.cancel()
        connectionTestTasks.removeValue(forKey: vps.id)
        
        // 清理SSH客户端
        await removeSSHClient(for: vps)
        
        // 从列表中移除
        vpsInstances.removeAll { $0.id == vps.id }
        saveVPSInstances()
        
        // 清理相关数据
        connectionTestResults.removeValue(forKey: vps.id)
        connectionTestStatus.removeValue(forKey: vps.id)
        monitoringData.removeValue(forKey: vps.id)
    }
    
    /// 测试 VPS 连接
    func testConnection(for vps: VPSInstance) async -> ConnectionTestResult {
        // 检查是否已有正在进行的检测
        if let existingTask = connectionTestTasks[vps.id] {
            // 等待现有任务完成
            await existingTask.value
            return connectionTestResults[vps.id] ?? ConnectionTestResult(pingSuccess: false, sshSuccess: false)
        }
        
        // 检查是否在短时间内已经测试过
        if let lastTest = connectionTestResults[vps.id]?.timestamp,
           Date().timeIntervalSince(lastTest) < 10 { // 减少到10秒内不重复测试
            return connectionTestResults[vps.id] ?? ConnectionTestResult(pingSuccess: false, sshSuccess: false)
        }
        
        // 创建新的检测任务
        let task = Task {
            await performConnectionTest(for: vps)
        }
        
        connectionTestTasks[vps.id] = task
        connectionTestStatus[vps.id] = .testing
        
        // 等待任务完成
        await task.value
        
        // 清理任务引用
        connectionTestTasks.removeValue(forKey: vps.id)
        
        return connectionTestResults[vps.id] ?? ConnectionTestResult(pingSuccess: false, sshSuccess: false)
    }
    
    /// 获取系统信息
    func getSystemInfo(for vps: VPSInstance) async throws -> SystemInfo {
        guard let index = vpsInstances.firstIndex(where: { $0.id == vps.id }) else {
            throw VPSManagerError.vpsNotFound
        }
        
        let systemInfo = try await fetchSystemInfo(for: vps)
        
        // 更新 VPS 实例
        vpsInstances[index].systemInfo = systemInfo
        vpsInstances[index].lastConnected = Date()
        saveVPSInstances()
        
        return systemInfo
    }
    
    /// 获取监控数据
    func getMonitoringData(for vps: VPSInstance) async throws -> [MonitoringData] {
        let data = try await fetchMonitoringData(for: vps)
        
        // 保存监控数据
        if monitoringData[vps.id] == nil {
            monitoringData[vps.id] = []
        }
        monitoringData[vps.id]?.append(data)
        
        // 保持最近 100 条记录
        if let count = monitoringData[vps.id]?.count, count > 100 {
            monitoringData[vps.id] = Array(monitoringData[vps.id]!.suffix(100))
        }
        
        return monitoringData[vps.id] ?? []
    }
    
    /// 获取 VPS 连接检测状态
    func getConnectionTestStatus(for vps: VPSInstance) -> ConnectionTestStatus {
        return connectionTestStatus[vps.id] ?? .idle
    }
    
    /// 检查 VPS 是否正在检测中
    func isConnectionTesting(for vps: VPSInstance) -> Bool {
        return connectionTestStatus[vps.id] == .testing
    }
    
    /// 检查是否需要初始化连接检测
    func needsInitialConnectionTest() -> Bool {
        return !hasInitializedConnections && !vpsInstances.isEmpty
    }
    
    /// 标记已初始化连接检测
    func markInitialConnectionTestComplete() {
        hasInitializedConnections = true
    }
    
    /// 重置初始化状态（当添加新 VPS 时调用）
    func resetInitializationState() {
        hasInitializedConnections = false
    }
    
    /// 开始监控
    func startMonitoring(for vps: VPSInstance) {
        guard monitoringTimers[vps.id] == nil else { return }
        
        let timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMonitoringData(for: vps)
            }
        }
        monitoringTimers[vps.id] = timer
    }
    
    /// 停止监控
    func stopMonitoring(for vps: VPSInstance) {
        monitoringTimers[vps.id]?.invalidate()
        monitoringTimers.removeValue(forKey: vps.id)
    }
    
    /// 停止所有监控
    @MainActor
    func stopAllMonitoring() {
        monitoringTimers.values.forEach { $0.invalidate() }
        monitoringTimers.removeAll()
    }
    
    /// 批量测试连接
    func testAllConnections() async {
        isLoading = true
        defer { isLoading = false }
        
        // 清除所有连接测试缓存，强制重新测试
        connectionTestResults.removeAll()
        connectionTestStatus.removeAll()
        
        // 并发测试所有 VPS 连接
        await withTaskGroup(of: Void.self) { group in
            for vps in vpsInstances {
                group.addTask {
                    _ = await self.testConnection(for: vps)
                }
            }
        }
        
        // 标记初始化完成
        markInitialConnectionTestComplete()
        
        // 通知 UI 更新
        objectWillChange.send()
    }
    
    /// 执行单个 VPS 连接检测
    private func performConnectionTest(for vps: VPSInstance) async {
        var result = ConnectionTestResult(
            pingSuccess: false,
            sshSuccess: false,
            timestamp: Date()
        )
        
        // 并发执行 Ping 和 SSH 测试
        async let pingResult = pingTest(host: vps.host)
        async let sshResult = sshTest(for: vps)
        
        // 等待两个测试完成
        let (pingSuccess, sshTestResult) = await (pingResult, sshResult)
        
        result.pingSuccess = pingSuccess
        result.sshSuccess = sshTestResult.success
        result.sshError = sshTestResult.error
        result.systemInfo = sshTestResult.systemInfo
        
        // 更新连接状态
        await updateVPSConnectionStatus(vps, isConnected: result.isConnected)
        
        // 保存测试结果
        connectionTestResults[vps.id] = result
        connectionTestStatus[vps.id] = result.isConnected ? .completed : .failed
        
        // 通知 UI 更新
        objectWillChange.send()
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // 监听 VPS 列表变化
        $vpsInstances
            .sink { [weak self] _ in
                self?.saveVPSInstances()
            }
            .store(in: &cancellables)
    }
    
    private func validateVPS(_ vps: VPSInstance) throws {
        // 验证名称
        if vps.name.isEmpty {
            throw VPSManagerError.invalidName("VPS 名称不能为空")
        }
        
        if vps.name.count > 50 {
            throw VPSManagerError.invalidName("VPS 名称不能超过 50 个字符")
        }
        
        // 验证主机地址
        if vps.host.isEmpty {
            throw VPSManagerError.invalidHost("主机地址不能为空")
        }
        
        // 简单的 IP 地址或域名验证
        let hostPattern = #"^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$|^(\d{1,3}\.){3}\d{1,3}$"#
        if (vps.host.range(of: hostPattern, options: .regularExpression) == nil) {
            throw VPSManagerError.invalidHost("主机地址格式不正确，请输入有效的 IP 地址或域名")
        }
        
        // 验证用户名
        if vps.username.isEmpty {
            throw VPSManagerError.invalidUsername("用户名不能为空")
        }
        
        if vps.username.count > 32 {
            throw VPSManagerError.invalidUsername("用户名不能超过 32 个字符")
        }
        
        // 验证端口
        if vps.port <= 0 || vps.port > 65535 {
            throw VPSManagerError.invalidPort("端口号必须在 1-65535 之间")
        }
        
        // 验证认证信息
        if vps.password == nil && vps.sshKeyPath == nil {
            throw VPSManagerError.invalidAuth("必须提供密码或 SSH 密钥")
        }
        
        if let password = vps.password, password.isEmpty {
            throw VPSManagerError.invalidAuth("密码不能为空")
        }
        
        if let sshKeyPath = vps.sshKeyPath, sshKeyPath.isEmpty {
            throw VPSManagerError.invalidAuth("SSH 密钥路径不能为空")
        }
        
        // 验证分组
        if vps.group.isEmpty {
            throw VPSManagerError.invalidConfiguration("分组名称不能为空")
        }
        
        if vps.group.count > 30 {
            throw VPSManagerError.invalidConfiguration("分组名称不能超过 30 个字符")
        }
    }
    
    private func pingTest(host: String) async -> Bool {
        // 简单的 ping 测试实现
        // 在实际应用中，这里应该使用更复杂的网络检测
        return true // 暂时返回 true
    }
    
    private func sshTest(for vps: VPSInstance) async -> (success: Bool, error: String?, systemInfo: SystemInfo?) {
        // 使用内置的SSH客户端管理进行连接测试
        return await testSSHConnection(for: vps)
    }
    
    private func fetchSystemInfo(for vps: VPSInstance) async throws -> SystemInfo {
        // 执行系统信息获取命令
        let osInfo = try await executeSSHCommand("cat /etc/os-release | grep PRETTY_NAME | cut -d '\"' -f2", on: vps)
        let kernelInfo = try await executeSSHCommand("uname -r", on: vps)
        let cpuInfo = try await executeSSHCommand("cat /proc/cpuinfo | grep 'model name' | head -1 | cut -d ':' -f2 | xargs", on: vps)
        let cpuCores = try await executeSSHCommand("nproc", on: vps)
        let memoryInfo = try await executeSSHCommand("free -b", on: vps)
        let diskInfo = try await executeSSHCommand("df -B1 / | tail -1", on: vps)
        let uptime = try await executeSSHCommand("cat /proc/uptime | cut -d ' ' -f1", on: vps)
        let loadAvg = try await executeSSHCommand("cat /proc/loadavg | cut -d ' ' -f1,2,3", on: vps)
        
        // 解析内存信息
        let memoryLines = memoryInfo.components(separatedBy: .newlines)
        let memTotal = memoryLines.first { $0.contains("Mem:") }?.components(separatedBy: .whitespaces).compactMap { Int64($0) } ?? []
        let memAvailable = memoryLines.first { $0.contains("Mem:") }?.components(separatedBy: .whitespaces).compactMap { Int64($0) } ?? []
        
        // 解析磁盘信息
        let diskParts = diskInfo.components(separatedBy: .whitespaces).compactMap { Int64($0) }
        
        // 解析负载平均值
        let loadParts = loadAvg.components(separatedBy: .whitespaces).compactMap { Double($0) }
        
        return SystemInfo(
            osName: osInfo.trimmingCharacters(in: .whitespacesAndNewlines),
            osVersion: "",
            kernelVersion: kernelInfo.trimmingCharacters(in: .whitespacesAndNewlines),
            cpuModel: cpuInfo.trimmingCharacters(in: .whitespacesAndNewlines),
            cpuCores: Int(cpuCores.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1,
            memoryTotal: memTotal.count > 1 ? memTotal[0] : 0,
            memoryAvailable: memAvailable.count > 2 ? memAvailable[2] : 0,
            diskTotal: diskParts.count > 1 ? diskParts[0] : 0,
            diskAvailable: diskParts.count > 2 ? diskParts[2] : 0,
            uptime: Double(uptime.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
            loadAverage: loadParts
        )
    }
    
    private func fetchMonitoringData(for vps: VPSInstance) async throws -> MonitoringData {
        // 获取 CPU 使用率
        let cpuUsage = try await executeSSHCommand("top -bn1 | grep 'Cpu(s)' | awk '{print $2}' | cut -d'%' -f1", on: vps)
        
        // 获取内存使用率
        let memoryUsage = try await executeSSHCommand("free | grep Mem | awk '{printf \"%.2f\", $3/$2 * 100.0}'", on: vps)
        
        // 获取磁盘使用率
        let diskUsage = try await executeSSHCommand("df / | tail -1 | awk '{print $5}' | cut -d'%' -f1", on: vps)
        
        // 获取网络流量
        let networkInfo = try await executeSSHCommand("cat /proc/net/dev | grep -E '^(eth0|ens3|enp0s3)' | awk '{print $2, $10}'", on: vps)
        
        // 获取负载平均值
        let loadAvg = try await executeSSHCommand("cat /proc/loadavg | cut -d ' ' -f1,2,3", on: vps)
        
        // 解析网络信息
        let networkParts = networkInfo.components(separatedBy: .whitespaces).compactMap { Int64($0) }
        let networkIn = networkParts.count > 0 ? networkParts[0] : 0
        let networkOut = networkParts.count > 1 ? networkParts[1] : 0
        
        // 解析负载平均值
        let loadParts = loadAvg.components(separatedBy: .whitespaces).compactMap { Double($0) }
        
        return MonitoringData(
            timestamp: Date(),
            cpuUsage: Double(cpuUsage.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
            memoryUsage: Double(memoryUsage.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
            diskUsage: Double(diskUsage.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0,
            networkIn: networkIn,
            networkOut: networkOut,
            loadAverage: loadParts
        )
    }
    
    private func updateVPSConnectionStatus(_ vps: VPSInstance, isConnected: Bool) async {
        guard let index = vpsInstances.firstIndex(where: { $0.id == vps.id }) else { return }
        
        vpsInstances[index].lastConnected = isConnected ? Date() : nil
        saveVPSInstances()
    }
    
    private func updateMonitoringData(for vps: VPSInstance) async {
        do {
            let data = try await fetchMonitoringData(for: vps)
            
            if monitoringData[vps.id] == nil {
                monitoringData[vps.id] = []
            }
            monitoringData[vps.id]?.append(data)
            
            // 保持最近 100 条记录
            if let count = monitoringData[vps.id]?.count, count > 100 {
                monitoringData[vps.id] = Array(monitoringData[vps.id]!.suffix(100))
            }
        } catch {
            print("Failed to update monitoring data for VPS \(vps.name): \(error)")
        }
    }
    
    private func loadVPSInstances() {
        guard let data = UserDefaults.standard.data(forKey: "vpsInstances") else { return }
        
        do {
            let instances = try JSONDecoder().decode([VPSInstance].self, from: data)
            vpsInstances = instances
            
            // 为所有 VPS 开始监控
            for vps in instances {
                startMonitoring(for: vps)
            }
        } catch {
            print("Failed to load VPS instances: \(error)")
        }
    }
    
    private func saveVPSInstances() {
        do {
            let data = try JSONEncoder().encode(vpsInstances)
            UserDefaults.standard.set(data, forKey: "vpsInstances")
        } catch {
            print("Failed to save VPS instances: \(error)")
        }
    }
    
    // MARK: - SSH Client Management
    
    /// SSH连接状态
    enum SSHConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(Error)
        case timeout
        
        static func == (lhs: SSHConnectionState, rhs: SSHConnectionState) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected),
                 (.connecting, .connecting),
                 (.connected, .connected),
                 (.timeout, .timeout):
                return true
            case (.failed, .failed):
                return true  // 简化处理，认为所有失败状态相等
            default:
                return false
            }
        }
    }
    
    /// 获取VPS的SSH客户端，如果不存在则创建
    private func getSSHClient(for vps: VPSInstance) -> SSHClient {
        if let existingClient = sshClients[vps.id] {
            return existingClient
        }
        
        let newClient = SSHClient()
        sshClients[vps.id] = newClient
        sshConnectionStates[vps.id] = .disconnected
        
        print("Created new SSH client for VPS: \(vps.name)")
        return newClient
    }
    
    /// 连接到VPS
    private func connectSSH(to vps: VPSInstance) async throws {
        // 检查并发连接限制
        guard activeSSHConnections < maxConcurrentConnections else {
            throw VPSManagerError.connectionFailed("达到最大并发连接数限制")
        }
        
        let client = getSSHClient(for: vps)
        sshConnectionStates[vps.id] = .connecting
        
        do {
            try await client.connect(to: vps)
            sshConnectionStates[vps.id] = .connected
            activeSSHConnections += 1
            print("Successfully connected to VPS: \(vps.name)")
        } catch {
            sshConnectionStates[vps.id] = .failed(error)
            print("Failed to connect to VPS \(vps.name): \(error)")
            throw error
        }
    }
    
    /// 断开VPS连接
    private func disconnectSSH(from vps: VPSInstance) async {
        guard let client = sshClients[vps.id] else { return }
        
        await client.disconnect()
        sshConnectionStates[vps.id] = .disconnected
        
        if activeSSHConnections > 0 {
            activeSSHConnections -= 1
        }
        
        print("Disconnected from VPS: \(vps.name)")
    }
    
    /// 执行SSH命令
    private func executeSSHCommand(_ command: String, on vps: VPSInstance) async throws -> String {
        let client = getSSHClient(for: vps)
        
        // 确保连接状态
        if sshConnectionStates[vps.id] != .connected {
            try await connectSSH(to: vps)
        }
        
        return try await client.executeCommand(command)
    }
    
    /// 测试VPS连接
    private func testSSHConnection(for vps: VPSInstance) async -> (success: Bool, error: String?, systemInfo: SystemInfo?) {
        let client = getSSHClient(for: vps)
        
        do {
            // 测试基本连接
            let isReachable = try await client.testConnection(vps)
            
            if isReachable {
                // 尝试获取系统信息
                do {
                    try await connectSSH(to: vps)
                    let systemInfo = try await fetchSystemInfo(for: vps)
                    await disconnectSSH(from: vps)
                    
                    return (success: true, error: nil, systemInfo: systemInfo)
                } catch {
                    return (success: true, error: "Connection successful but failed to get system info: \(error.localizedDescription)", systemInfo: nil)
                }
            } else {
                return (success: false, error: "Connection test failed", systemInfo: nil)
            }
        } catch {
            return (success: false, error: error.localizedDescription, systemInfo: nil)
        }
    }
    
    /// 检查是否已连接
    private func isSSHConnected(to vps: VPSInstance) -> Bool {
        return sshConnectionStates[vps.id] == .connected
    }
    
    /// 清理VPS的SSH客户端
    private func removeSSHClient(for vps: VPSInstance) async {
        await disconnectSSH(from: vps)
        sshClients.removeValue(forKey: vps.id)
        sshConnectionStates.removeValue(forKey: vps.id)
        print("Removed SSH client for VPS: \(vps.name)")
    }
    
    /// 清理所有连接
    func disconnectAllSSHClients() async {
        for (vpsId, client) in sshClients {
            await client.disconnect()
            sshConnectionStates[vpsId] = .disconnected
        }
        activeSSHConnections = 0
        print("Disconnected all SSH clients")
    }
    
    /// 获取连接统计信息
    func getSSHConnectionStats() -> (total: Int, active: Int, failed: Int) {
        let total = sshClients.count
        let active = sshConnectionStates.values.filter { state in
            if case .connected = state { return true }
            return false
        }.count
        let failed = sshConnectionStates.values.filter { state in
            if case .failed = state { return true }
            return false
        }.count
        
        return (total: total, active: active, failed: failed)
    }
    
    // MARK: - Public SSH Methods for External Services
    
    /// 执行SSH命令（供外部服务使用）
    func executeSSHCommandForService(_ command: String, on vps: VPSInstance) async throws -> String {
        return try await executeSSHCommand(command, on: vps)
    }
    
    /// 写入文件到VPS（供外部服务使用）
    func writeFile(content: String, to path: String, on vps: VPSInstance) async throws {
        let client = getSSHClient(for: vps)
        
        // 确保连接状态
        if sshConnectionStates[vps.id] != .connected {
            try await connectSSH(to: vps)
        }
        
        try await client.writeFile(content: content, to: path)
    }
    
    /// 连接到VPS（供外部服务使用）
    func connectToVPS(_ vps: VPSInstance) async throws {
        try await connectSSH(to: vps)
    }
    
    /// 断开VPS连接（供外部服务使用）
    func disconnectFromVPS(_ vps: VPSInstance) async {
        await disconnectSSH(from: vps)
    }
    
    /// 清除所有 VPS 数据
    func clearAllData() {
        // 停止所有监控
        monitoringTimers.values.forEach { $0.invalidate() }
        monitoringTimers.removeAll()
        
        // 断开所有 SSH 连接
        Task {
            await disconnectAllSSHClients()
        }
        
        // 清除数据
        vpsInstances.removeAll()
        selectedVPS = nil
        connectionTestResults.removeAll()
        monitoringData.removeAll()
        sshClients.removeAll()
        sshConnectionStates.removeAll()
        activeSSHConnections = 0
        lastError = nil
        isLoading = false
        
        // 清除连接测试状态
        connectionTestTasks.values.forEach { $0.cancel() }
        connectionTestTasks.removeAll()
        connectionTestStatus.removeAll()
        
        // 保存空数据到本地存储
        saveVPSInstances()
        
        print("All VPS data cleared")
    }
}

// MARK: - Connection Test Status

enum ConnectionTestStatus {
    case idle
    case testing
    case completed
    case failed
}

// MARK: - VPS Manager Errors

enum VPSManagerError: LocalizedError {
    case vpsNotFound
    case invalidName(String)
    case invalidHost(String)
    case invalidUsername(String)
    case invalidPort(String)
    case invalidAuth(String)
    case invalidConfiguration(String)
    case connectionFailed(String)
    case systemInfoFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .vpsNotFound:
            return "VPS 实例未找到"
        case .invalidName(let message):
            return message
        case .invalidHost(let message):
            return message
        case .invalidUsername(let message):
            return message
        case .invalidPort(let message):
            return message
        case .invalidAuth(let message):
            return message
        case .invalidConfiguration(let message):
            return "配置错误: \(message)"
        case .connectionFailed(let message):
            return "连接失败: \(message)"
        case .systemInfoFailed(let message):
            return "获取系统信息失败: \(message)"
        }
    }
}
