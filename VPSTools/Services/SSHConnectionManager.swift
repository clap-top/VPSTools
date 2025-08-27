import Foundation
import Combine

// MARK: - SSH Connection Manager

/// SSH连接管理器
/// 负责统一管理所有SSH连接，包括连接池、负载均衡、故障转移等功能
@MainActor
class SSHConnectionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var connectionStats: ConnectionManagerStats = ConnectionManagerStats()
    @Published var isInitialized: Bool = false
    @Published var lastError: String?
    
    // MARK: - Private Properties
    
    private var sshClients: [UUID: SSHClient] = [:]
    private var connectionStates: [UUID: SSHConnectionState] = [:]
    private var connectionMetrics: [UUID: SSHConnectionMetrics] = [:]
    private var connectionPool: [String: SSHConnectionPool] = [:]
    
    private var cleanupTimer: Timer?
    private var healthCheckTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    
    private let config = SSHConnectionConfig.self
    private let maxConcurrentConnections: Int
    private let enableLoadBalancing: Bool
    private let enableFailover: Bool
    
    // MARK: - Initialization
    
    init(maxConcurrentConnections: Int = 10, enableLoadBalancing: Bool = true, enableFailover: Bool = true) {
        self.maxConcurrentConnections = maxConcurrentConnections
        self.enableLoadBalancing = enableLoadBalancing
        self.enableFailover = enableFailover
        
        setupTimers()
        validateConfiguration()
        isInitialized = true
        
        print("SSHConnectionManager initialized with configuration:")
        print(config.getConfigurationSummary())
    }
    
    deinit {
        // 在 deinit 中不能调用异步方法，所以只清理定时器
        cleanupTimer?.invalidate()
        healthCheckTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Public Methods
    
    /// 获取VPS的SSH客户端
    func getSSHClient(for vps: VPSInstance) -> SSHClient {
        if let existingClient = sshClients[vps.id] {
            return existingClient
        }
        
        let newClient = SSHClient()
        sshClients[vps.id] = newClient
        connectionStates[vps.id] = .disconnected
        connectionMetrics[vps.id] = SSHConnectionMetrics()
        
        print("Created new SSH client for VPS: \(vps.name)")
        return newClient
    }
    
    /// 连接到VPS
    func connect(to vps: VPSInstance) async throws {
        // 检查并发连接限制
        guard getActiveConnectionCount() < maxConcurrentConnections else {
            throw SSHConnectionManagerError.maxConnectionsReached(maxConcurrentConnections)
        }
        
        let client = getSSHClient(for: vps)
        connectionStates[vps.id] = .connecting
        
        do {
            try await client.connect(to: vps)
            connectionStates[vps.id] = .connected
            updateConnectionStats()
            
            print("Successfully connected to VPS: \(vps.name)")
        } catch {
            connectionStates[vps.id] = .failed(error)
            updateConnectionStats()
            
            print("Failed to connect to VPS \(vps.name): \(error)")
            throw error
        }
    }
    
    /// 断开VPS连接
    func disconnect(from vps: VPSInstance) async {
        guard let client = sshClients[vps.id] else { return }
        
        await client.disconnect()
        connectionStates[vps.id] = .disconnected
        updateConnectionStats()
        
        print("Disconnected from VPS: \(vps.name)")
    }
    
    /// 执行SSH命令
    func executeCommand(_ command: String, on vps: VPSInstance) async throws -> String {
        let client = getSSHClient(for: vps)
        
        // 确保连接状态
        if connectionStates[vps.id] != .connected {
            try await connect(to: vps)
        }
        
        return try await client.executeCommand(command)
    }
    
    /// 测试VPS连接
    func testConnection(for vps: VPSInstance) async -> SSHConnectionTestResult {
        let client = getSSHClient(for: vps)
        
        do {
            let isReachable = try await client.testConnection(vps)
            return SSHConnectionTestResult(
                isConnected: isReachable,
                sshError: nil,
                systemInfo: nil
            )
        } catch {
            return SSHConnectionTestResult(
                isConnected: false,
                sshError: error.localizedDescription,
                systemInfo: nil
            )
        }
    }
    
    /// 获取连接统计信息
    func getConnectionStats() -> ConnectionManagerStats {
        return connectionStats
    }
    
    /// 获取VPS连接状态
    func getConnectionState(for vps: VPSInstance) -> SSHConnectionState {
        return connectionStates[vps.id] ?? .disconnected
    }
    
    /// 获取VPS连接指标
    func getConnectionMetrics(for vps: VPSInstance) -> SSHConnectionMetrics? {
        return connectionMetrics[vps.id]
    }
    
    /// 清理所有连接
    func disconnectAll() async {
        for (vpsId, client) in sshClients {
            await client.disconnect()
            connectionStates[vpsId] = .disconnected
        }
        updateConnectionStats()
        print("Disconnected all SSH connections")
    }
    
    /// 清理VPS连接
    func removeVPSConnection(for vps: VPSInstance) async {
        await disconnect(from: vps)
        sshClients.removeValue(forKey: vps.id)
        connectionStates.removeValue(forKey: vps.id)
        connectionMetrics.removeValue(forKey: vps.id)
        print("Removed SSH connection for VPS: \(vps.name)")
    }
    
    /// 执行健康检查
    func performHealthCheck() async {
        print("Performing SSH connection health check...")
        
        for (vpsId, state) in connectionStates {
            if case .connected = state {
                guard let vps = getVPSById(vpsId) else { continue }
                
                do {
                    _ = try await executeCommand("echo 'health_check'", on: vps)
                    print("Health check passed for VPS: \(vps.name)")
                } catch {
                    print("Health check failed for VPS: \(vps.name): \(error)")
                    connectionStates[vpsId] = .failed(error)
                    
                    // 尝试重连
                    if enableFailover {
                        await attemptReconnection(for: vps)
                    }
                }
            }
        }
        
        updateConnectionStats()
    }
    
    /// 获取最佳连接（负载均衡）
    func getBestConnection(for vpsInstances: [VPSInstance]) -> VPSInstance? {
        guard enableLoadBalancing else {
            return vpsInstances.first
        }
        
        // 按连接状态和性能指标排序
        let sortedVPS = vpsInstances.sorted { vps1, vps2 in
            let state1 = connectionStates[vps1.id] ?? .disconnected
            let state2 = connectionStates[vps2.id] ?? .disconnected
            
            // 优先选择已连接的VPS
            if state1 == .connected && state2 != .connected {
                return true
            }
            if state1 != .connected && state2 == .connected {
                return false
            }
            
            // 如果都是已连接状态，按响应时间排序
            if state1 == .connected && state2 == .connected {
                let metrics1 = connectionMetrics[vps1.id]
                let metrics2 = connectionMetrics[vps2.id]
                return (metrics1?.averageResponseTime ?? Double.infinity) < (metrics2?.averageResponseTime ?? Double.infinity)
            }
            
            return false
        }
        
        return sortedVPS.first
    }
    
    // MARK: - Private Methods
    
    /// 设置定时器
    private func setupTimers() {
        // 清理定时器
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: config.ConnectionPool.cleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performCleanup()
            }
        }
        
        // 健康检查定时器
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: config.KeepAlive.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performHealthCheck()
            }
        }
    }
    
    /// 验证配置
    private func validateConfiguration() {
        let errors = config.validate()
        if !errors.isEmpty {
            print("SSH Connection Configuration Errors:")
            for error in errors {
                print("- \(error)")
            }
            lastError = "Configuration validation failed: \(errors.joined(separator: ", "))"
        }
    }
    
    /// 更新连接统计信息
    private func updateConnectionStats() {
        let total = sshClients.count
        let active = connectionStates.values.filter { state in
            if case .connected = state { return true }
            return false
        }.count
        let connecting = connectionStates.values.filter { state in
            if case .connecting = state { return true }
            return false
        }.count
        let failed = connectionStates.values.filter { state in
            if case .failed = state { return true }
            return false
        }.count
        
        connectionStats = ConnectionManagerStats(
            totalConnections: total,
            activeConnections: active,
            connectingConnections: connecting,
            failedConnections: failed,
            maxConcurrentConnections: maxConcurrentConnections
        )
    }
    
    /// 获取活跃连接数
    private func getActiveConnectionCount() -> Int {
        return connectionStates.values.filter { state in
            if case .connected = state { return true }
            return false
        }.count
    }
    
    /// 根据ID获取VPS实例
    private func getVPSById(_ id: UUID) -> VPSInstance? {
        // 这里需要从VPSManager获取VPS实例
        // 暂时返回nil，实际使用时需要注入VPSManager
        return nil
    }
    
    /// 尝试重连
    private func attemptReconnection(for vps: VPSInstance) async {
        print("Attempting reconnection for VPS: \(vps.name)")
        
        do {
            try await connect(to: vps)
            print("Reconnection successful for VPS: \(vps.name)")
        } catch {
            print("Reconnection failed for VPS: \(vps.name): \(error)")
        }
    }
    
    /// 执行清理
    private func performCleanup() async {
        print("Performing SSH connection cleanup...")
        
        let now = Date()
        let maxIdleTime = config.ConnectionPool.maxIdleTime
        
        for (vpsId, metrics) in connectionMetrics {
            if let lastActivity = metrics.lastConnectionTime,
               now.timeIntervalSince(lastActivity) > maxIdleTime {
                
                guard let vps = getVPSById(vpsId) else { continue }
                
                print("Cleaning up idle connection for VPS: \(vps.name)")
                await removeVPSConnection(for: vps)
            }
        }
        
        updateConnectionStats()
    }
    
    /// 清理资源
    private func cleanup() {
        cleanupTimer?.invalidate()
        healthCheckTimer?.invalidate()
        cancellables.removeAll()
        
        Task {
            await disconnectAll()
        }
    }
}

// MARK: - Supporting Types

/// 连接管理器统计信息
struct ConnectionManagerStats {
    var totalConnections: Int = 0
    var activeConnections: Int = 0
    var connectingConnections: Int = 0
    var failedConnections: Int = 0
    var maxConcurrentConnections: Int = 0
    
    var connectionUtilization: Double {
        guard maxConcurrentConnections > 0 else { return 0.0 }
        return Double(activeConnections) / Double(maxConcurrentConnections) * 100.0
    }
    
    var successRate: Double {
        guard totalConnections > 0 else { return 0.0 }
        return Double(activeConnections) / Double(totalConnections) * 100.0
    }
}

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

/// 连接池
struct SSHConnectionPool {
    let id: String
    var connections: [SSHClient] = []
    let maxSize: Int
    let createdAt: Date
    
    init(id: String, maxSize: Int) {
        self.id = id
        self.maxSize = maxSize
        self.createdAt = Date()
    }
    
    var isFull: Bool {
        return connections.count >= maxSize
    }
    
    var availableConnections: Int {
        return maxSize - connections.count
    }
}

/// SSH连接测试结果
struct SSHConnectionTestResult {
    let isConnected: Bool
    let sshError: String?
    let systemInfo: SSHSystemInfo?
}

/// SSH系统信息
struct SSHSystemInfo {
    let osName: String
    let osVersion: String
    let architecture: String
    let hostname: String
    let uptime: TimeInterval
    let memoryTotal: Int64
    let memoryAvailable: Int64
    let cpuCount: Int
    let loadAverage: [Double]
}

// MARK: - Errors

enum SSHConnectionManagerError: Error, LocalizedError {
    case maxConnectionsReached(Int)
    case vpsNotFound(UUID)
    case connectionPoolFull
    case invalidConfiguration(String)
    
    var errorDescription: String? {
        switch self {
        case .maxConnectionsReached(let max):
            return "已达到最大连接数限制: \(max)"
        case .vpsNotFound(let id):
            return "未找到VPS实例: \(id)"
        case .connectionPoolFull:
            return "连接池已满"
        case .invalidConfiguration(let message):
            return "配置无效: \(message)"
        }
    }
}
