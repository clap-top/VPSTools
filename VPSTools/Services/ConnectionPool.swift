import Foundation
import Combine
import SwiftUI

// MARK: - Connection Pool Manager

/// 智能连接池管理器
@MainActor
class ConnectionPool: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var poolStatus: PoolStatus = .idle
    @Published var activeConnections: Int = 0
    @Published var connectionMetrics: [UUID: ConnectionMetrics] = [:]
    @Published var healthStatus: [UUID: ConnectionHealth] = [:]
    
    // MARK: - Private Properties
    
    private var connections: [UUID: PooledConnection] = [:]
    private var connectionQueue: [UUID] = []
    private var healthCheckTimer: Timer?
    private var cleanupTimer: Timer?
    private var reconnectionTasks: [UUID: Task<Void, Never>] = [:]
    
    private let maxPoolSize: Int
    private let maxIdleTime: TimeInterval
    private let healthCheckInterval: TimeInterval
    private let cleanupInterval: TimeInterval
    
    // MARK: - Initialization
    
    init(
        maxPoolSize: Int = SSHConnectionConfig.ConnectionPool.maxSize,
        maxIdleTime: TimeInterval = SSHConnectionConfig.ConnectionPool.maxIdleTime,
        healthCheckInterval: TimeInterval = SSHConnectionConfig.KeepAlive.interval,
        cleanupInterval: TimeInterval = SSHConnectionConfig.ConnectionPool.cleanupInterval
    ) {
        self.maxPoolSize = maxPoolSize
        self.maxIdleTime = maxIdleTime
        self.healthCheckInterval = healthCheckInterval
        self.cleanupInterval = cleanupInterval
        
        setupTimers()
    }
    
    deinit {
        healthCheckTimer?.invalidate()
        cleanupTimer?.invalidate()
        // 在deinit中直接清理，避免异步调用
        // 注意：在deinit中不能修改MainActor隔离的属性
        connections.removeAll()
        connectionQueue.removeAll()
        reconnectionTasks.values.forEach { $0.cancel() }
        reconnectionTasks.removeAll()
        // activeConnections 是 @Published 属性，在deinit中不能修改
    }
    
    // MARK: - Public Methods
    
    /// 获取连接
    func getConnection(for vps: VPSInstance) async throws -> SSHClient {
        // 检查是否已有可用连接
        if let existingConnection = connections[vps.id], existingConnection.isHealthy {
            existingConnection.lastUsed = Date()
            existingConnection.useCount += 1
            return existingConnection.client
        }
        
        // 检查连接池是否已满
        if connections.count >= maxPoolSize {
            try await evictLeastUsedConnection()
        }
        
        // 创建新连接
        let client = SSHClient()
        let connection = PooledConnection(
            id: vps.id,
            client: client,
            vps: vps,
            createdAt: Date()
        )
        
        // 尝试连接
        do {
            try await client.connect(to: vps)
            connection.isConnected = true
            connection.isHealthy = true
            connection.lastUsed = Date()
            
            connections[vps.id] = connection
            connectionQueue.append(vps.id)
            activeConnections = connections.count
            
            updateMetrics(for: vps.id, success: true)
            updateHealthStatus(for: vps.id, health: .healthy)
            
            print("ConnectionPool: Successfully created connection for VPS: \(vps.name)")
            return client
            
        } catch {
            updateMetrics(for: vps.id, success: false, error: error)
            updateHealthStatus(for: vps.id, health: .failed(error))
            
            // 启动自动重连
            startReconnection(for: vps)
            
            throw error
        }
    }
    
    /// 释放连接
    func releaseConnection(for vpsId: UUID) {
        guard let connection = connections[vpsId] else { return }
        
        connection.lastUsed = Date()
        connection.isInUse = false
        
        // 如果连接不健康，标记为需要重连
        if !connection.isHealthy {
            startReconnection(for: connection.vps)
        }
        
        print("ConnectionPool: Released connection for VPS ID: \(vpsId)")
    }
    
    /// 强制断开连接
    func disconnectConnection(for vpsId: UUID) async {
        guard let connection = connections[vpsId] else { return }
        
        await connection.client.disconnect()
        connections.removeValue(forKey: vpsId)
        connectionQueue.removeAll { $0 == vpsId }
        reconnectionTasks[vpsId]?.cancel()
        reconnectionTasks.removeValue(forKey: vpsId)
        
        activeConnections = connections.count
        updateHealthStatus(for: vpsId, health: .disconnected)
        
        print("ConnectionPool: Forcefully disconnected connection for VPS ID: \(vpsId)")
    }
    
    /// 获取连接状态
    func getConnectionStatus(for vpsId: UUID) -> ConnectionStatus? {
        guard let connection = connections[vpsId] else { return nil }
        
        return ConnectionStatus(
            isConnected: connection.isConnected,
            isHealthy: connection.isHealthy,
            isInUse: connection.isInUse,
            lastUsed: connection.lastUsed,
            useCount: connection.useCount,
            createdAt: connection.createdAt
        )
    }
    
    /// 获取池统计信息
    func getPoolStats() -> PoolStats {
        let total = connections.count
        let healthy = connections.values.filter { $0.isHealthy }.count
        let inUse = connections.values.filter { $0.isInUse }.count
        let idle = total - inUse
        
        let avgUseCount = connections.values.isEmpty ? 0 : 
            connections.values.map { $0.useCount }.reduce(0, +) / connections.count
        
        return PoolStats(
            totalConnections: total,
            healthyConnections: healthy,
            inUseConnections: inUse,
            idleConnections: idle,
            averageUseCount: avgUseCount,
            maxPoolSize: maxPoolSize
        )
    }
    
    // MARK: - Private Methods
    
    private func setupTimers() {
        // 健康检查定时器
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performHealthChecks()
            }
        }
        
        // 清理定时器
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: cleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.cleanupIdleConnections()
            }
        }
    }
    
    private func performHealthChecks() async {
        print("ConnectionPool: Performing health checks for \(connections.count) connections")
        
        for (vpsId, connection) in connections {
            guard !connection.isInUse else { continue }
            
            let isHealthy = await connection.client.checkConnectionHealth()
            connection.isHealthy = isHealthy
            
            if isHealthy {
                updateHealthStatus(for: vpsId, health: .healthy)
            } else {
                updateHealthStatus(for: vpsId, health: .unhealthy)
                startReconnection(for: connection.vps)
            }
        }
    }
    
    private func cleanupIdleConnections() async {
        let now = Date()
        let idleConnections = connections.filter { connection in
            guard let lastUsed = connection.value.lastUsed else { return false }
            return now.timeIntervalSince(lastUsed) > maxIdleTime
        }
        
        for (vpsId, _) in idleConnections {
            await disconnectConnection(for: vpsId)
        }
        
        if !idleConnections.isEmpty {
            print("ConnectionPool: Cleaned up \(idleConnections.count) idle connections")
        }
    }
    
    private func evictLeastUsedConnection() async throws {
        guard let leastUsed = connections.values.min(by: { 
            ($0.lastUsed ?? $0.createdAt) < ($1.lastUsed ?? $1.createdAt) 
        }) else {
            throw ConnectionPoolError.poolFull
        }
        
        await disconnectConnection(for: leastUsed.id)
    }
    
    private func startReconnection(for vps: VPSInstance) {
        // 取消现有的重连任务
        reconnectionTasks[vps.id]?.cancel()
        
        let task = Task<Void, Never> { [weak self] in
            await self?.performReconnection(for: vps)
        }
        
        reconnectionTasks[vps.id] = task
    }
    
    private func performReconnection(for vps: VPSInstance) async {
        print("ConnectionPool: Starting reconnection for VPS: \(vps.name)")
        
        for attempt in 1...SSHConnectionConfig.Reconnection.maxAttempts {
            do {
                // 计算延迟时间
                let delay = min(
                    SSHConnectionConfig.Reconnection.baseDelay * pow(SSHConnectionConfig.Reconnection.delayMultiplier, Double(attempt - 1)),
                    SSHConnectionConfig.Reconnection.maxDelay
                )
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                // 尝试重新连接
                let client = SSHClient()
                try await client.connect(to: vps)
                
                // 更新连接
                let connection = PooledConnection(
                    id: vps.id,
                    client: client,
                    vps: vps,
                    createdAt: Date()
                )
                connection.isConnected = true
                connection.isHealthy = true
                
                connections[vps.id] = connection
                updateHealthStatus(for: vps.id, health: .healthy)
                
                print("ConnectionPool: Successfully reconnected to VPS: \(vps.name) after \(attempt) attempts")
                return
                
            } catch {
                print("ConnectionPool: Reconnection attempt \(attempt) failed for VPS: \(vps.name): \(error)")
                updateHealthStatus(for: vps.id, health: .failed(error))
            }
        }
        
        print("ConnectionPool: Failed to reconnect to VPS: \(vps.name) after \(SSHConnectionConfig.Reconnection.maxAttempts) attempts")
        updateHealthStatus(for: vps.id, health: .unrecoverable)
    }
    
    private func updateMetrics(for vpsId: UUID, success: Bool, error: Error? = nil) {
        if connectionMetrics[vpsId] == nil {
            connectionMetrics[vpsId] = ConnectionMetrics()
        }
        
        connectionMetrics[vpsId]?.totalAttempts += 1
        if success {
            connectionMetrics[vpsId]?.successfulAttempts += 1
        } else {
            connectionMetrics[vpsId]?.failedAttempts += 1
            connectionMetrics[vpsId]?.lastError = error?.localizedDescription
        }
    }
    
    private func updateHealthStatus(for vpsId: UUID, health: ConnectionHealth) {
        healthStatus[vpsId] = health
    }
    
    private func cleanupAllConnections() {
        Task {
            for (vpsId, _) in connections {
                await disconnectConnection(for: vpsId)
            }
        }
    }
    

}

// MARK: - Supporting Types

/// 连接池状态
enum PoolStatus: String, CaseIterable {
    case idle = "空闲"
    case active = "活跃"
    case full = "已满"
    case error = "错误"
}

/// 连接健康状态
enum ConnectionHealth: Equatable {
    case healthy
    case unhealthy
    case failed(Error)
    case unrecoverable
    case disconnected
    
    static func == (lhs: ConnectionHealth, rhs: ConnectionHealth) -> Bool {
        switch (lhs, rhs) {
        case (.healthy, .healthy),
             (.unhealthy, .unhealthy),
             (.unrecoverable, .unrecoverable),
             (.disconnected, .disconnected):
            return true
        case (.failed, .failed):
            return true
        default:
            return false
        }
    }
}

/// 池化连接
class PooledConnection {
    let id: UUID
    let client: SSHClient
    let vps: VPSInstance
    let createdAt: Date
    
    var isConnected: Bool = false
    var isHealthy: Bool = false
    var isInUse: Bool = false
    var lastUsed: Date?
    var useCount: Int = 0
    
    init(id: UUID, client: SSHClient, vps: VPSInstance, createdAt: Date) {
        self.id = id
        self.client = client
        self.vps = vps
        self.createdAt = createdAt
    }
}

/// 连接状态
struct ConnectionStatus {
    let isConnected: Bool
    let isHealthy: Bool
    let isInUse: Bool
    let lastUsed: Date?
    let useCount: Int
    let createdAt: Date
}

/// 连接指标
struct ConnectionMetrics {
    var totalAttempts: Int = 0
    var successfulAttempts: Int = 0
    var failedAttempts: Int = 0
    var lastError: String?
    var averageResponseTime: TimeInterval = 0
    
    var successRate: Double {
        guard totalAttempts > 0 else { return 0.0 }
        return Double(successfulAttempts) / Double(totalAttempts) * 100.0
    }
}

/// 池统计信息
struct PoolStats {
    let totalConnections: Int
    let healthyConnections: Int
    let inUseConnections: Int
    let idleConnections: Int
    let averageUseCount: Int
    let maxPoolSize: Int
    
    var utilizationRate: Double {
        guard maxPoolSize > 0 else { return 0.0 }
        return Double(totalConnections) / Double(maxPoolSize) * 100.0
    }
    
    var healthRate: Double {
        guard totalConnections > 0 else { return 0.0 }
        return Double(healthyConnections) / Double(totalConnections) * 100.0
    }
}

/// 连接池错误
enum ConnectionPoolError: Error, LocalizedError {
    case poolFull
    case connectionNotFound
    case connectionUnhealthy
    case reconnectionFailed
    
    var errorDescription: String? {
        switch self {
        case .poolFull:
            return "连接池已满"
        case .connectionNotFound:
            return "连接未找到"
        case .connectionUnhealthy:
            return "连接不健康"
        case .reconnectionFailed:
            return "重连失败"
        }
    }
}
