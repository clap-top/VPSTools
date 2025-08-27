import Foundation

// MARK: - SSH Connection Configuration

/// SSH连接配置管理
struct SSHConnectionConfig {
    
    // MARK: - Timeout Configuration
    struct Timeouts {
        /// 连接超时时间（秒）
        static let connection: TimeInterval = 30.0
        /// 命令执行超时时间（秒）
        static let command: TimeInterval = 60.0
        /// 认证超时时间（秒）
        static let authentication: TimeInterval = 20.0
        /// 网络可达性测试超时时间（秒）
        static let networkReachability: TimeInterval = 15.0
        /// TCP连接测试超时时间（秒）
        static let tcpConnection: TimeInterval = 10.0
        /// SSH握手测试超时时间（秒）
        static let sshHandshake: TimeInterval = 10.0
    }
    
    // MARK: - Connection Pool Configuration
    struct ConnectionPool {
        /// 最大连接池大小
        static let maxSize: Int = 5
        /// 连接池清理间隔（秒）
        static let cleanupInterval: TimeInterval = 300.0 // 5分钟
        /// 连接最大空闲时间（秒）
        static let maxIdleTime: TimeInterval = 1800.0 // 30分钟
        /// 连接最大错误次数
        static let maxErrorCount: Int = 3
    }
    
    // MARK: - Reconnection Configuration
    struct Reconnection {
        /// 最大重连尝试次数
        static let maxAttempts: Int = 3
        /// 基础重连延迟时间（秒）
        static let baseDelay: TimeInterval = 2.0
        /// 重连延迟倍数
        static let delayMultiplier: Double = 1.5
        /// 最大重连延迟时间（秒）
        static let maxDelay: TimeInterval = 30.0
    }
    
    // MARK: - Keep-Alive Configuration
    struct KeepAlive {
        /// 保活间隔时间（秒）
        static let interval: TimeInterval = 30.0
        /// 保活命令
        static let command: String = "echo 'keepalive'"
        /// 保活失败后的重试次数
        static let maxRetries: Int = 2
    }
    
    // MARK: - Performance Configuration
    struct Performance {
        /// 命令执行队列优先级
        static let commandQueueQoS: DispatchQoS = .userInitiated
        /// 连接池队列优先级
        static let poolQueueQoS: DispatchQoS = .userInitiated
        /// 网络测试队列优先级
        static let networkQueueQoS: DispatchQoS = .utility
        /// 最大并发连接数
        static let maxConcurrentConnections: Int = 10
    }
    
    // MARK: - Security Configuration
    struct Security {
        /// 是否验证服务器指纹
        static let verifyFingerprint: Bool = true
        /// 允许的加密算法
        static let allowedCiphers: String = "aes128-ctr,aes192-ctr,aes256-ctr"
        /// 允许的MAC算法
        static let allowedMACs: String = "hmac-sha2-256,hmac-sha2-512"
        /// 允许的密钥交换算法
        static let allowedKeyExchanges: String = "diffie-hellman-group14-sha256,diffie-hellman-group14-sha1,curve25519-sha256,ecdh-sha2-nistp256"
    }
    
    // MARK: - Logging Configuration
    struct Logging {
        /// 是否启用详细日志
        static let verbose: Bool = false
        /// 是否记录连接统计信息
        static let enableMetrics: Bool = true
        /// 是否记录性能数据
        static let enablePerformanceLogging: Bool = true
        /// 日志级别
        static let level: LogLevel = .info
    }
    
    // MARK: - Log Level Enum
    enum LogLevel: Int, CaseIterable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        
        var description: String {
            switch self {
            case .debug: return "DEBUG"
            case .info: return "INFO"
            case .warning: return "WARNING"
            case .error: return "ERROR"
            }
        }
    }
    
    // MARK: - Validation Methods
    
    /// 验证配置的有效性
    static func validate() -> [String] {
        var errors: [String] = []
        
        // 验证超时配置
        if Timeouts.connection <= 0 {
            errors.append("Connection timeout must be positive")
        }
        if Timeouts.command <= 0 {
            errors.append("Command timeout must be positive")
        }
        if Timeouts.authentication <= 0 {
            errors.append("Authentication timeout must be positive")
        }
        
        // 验证连接池配置
        if ConnectionPool.maxSize <= 0 {
            errors.append("Connection pool max size must be positive")
        }
        if ConnectionPool.maxIdleTime <= 0 {
            errors.append("Connection pool max idle time must be positive")
        }
        
        // 验证重连配置
        if Reconnection.maxAttempts <= 0 {
            errors.append("Max reconnection attempts must be positive")
        }
        if Reconnection.baseDelay <= 0 {
            errors.append("Base reconnection delay must be positive")
        }
        
        // 验证保活配置
        if KeepAlive.interval <= 0 {
            errors.append("Keep-alive interval must be positive")
        }
        
        return errors
    }
    
    /// 获取配置摘要
    static func getConfigurationSummary() -> String {
        return """
        SSH Connection Configuration:
        - Connection Timeout: \(Timeouts.connection)s
        - Command Timeout: \(Timeouts.command)s
        - Authentication Timeout: \(Timeouts.authentication)s
        - Connection Pool Size: \(ConnectionPool.maxSize)
        - Max Reconnection Attempts: \(Reconnection.maxAttempts)
        - Keep-Alive Interval: \(KeepAlive.interval)s
        - Max Concurrent Connections: \(Performance.maxConcurrentConnections)
        - Log Level: \(Logging.level.description)
        """
    }
}

// MARK: - Connection Metrics

/// 连接性能指标
struct SSHConnectionMetrics {
    var totalConnections: Int = 0
    var successfulConnections: Int = 0
    var failedConnections: Int = 0
    var totalCommands: Int = 0
    var successfulCommands: Int = 0
    var failedCommands: Int = 0
    var averageResponseTime: TimeInterval = 0
    var lastConnectionTime: Date?
    var lastDisconnectionTime: Date?
    var totalReconnections: Int = 0
    var successfulReconnections: Int = 0
    var failedReconnections: Int = 0
    
    /// 计算连接成功率
    var connectionSuccessRate: Double {
        guard totalConnections > 0 else { return 0.0 }
        return Double(successfulConnections) / Double(totalConnections) * 100.0
    }
    
    /// 计算命令执行成功率
    var commandSuccessRate: Double {
        guard totalCommands > 0 else { return 0.0 }
        return Double(successfulCommands) / Double(totalCommands) * 100.0
    }
    
    /// 计算重连成功率
    var reconnectionSuccessRate: Double {
        guard totalReconnections > 0 else { return 0.0 }
        return Double(successfulReconnections) / Double(totalReconnections) * 100.0
    }
    
    /// 获取连接持续时间
    var connectionDuration: TimeInterval? {
        guard let start = lastConnectionTime, let end = lastDisconnectionTime else {
            return nil
        }
        return end.timeIntervalSince(start)
    }
    
    /// 重置指标
    mutating func reset() {
        totalConnections = 0
        successfulConnections = 0
        failedConnections = 0
        totalCommands = 0
        successfulCommands = 0
        failedCommands = 0
        averageResponseTime = 0
        lastConnectionTime = nil
        lastDisconnectionTime = nil
        totalReconnections = 0
        successfulReconnections = 0
        failedReconnections = 0
    }
    
    /// 获取指标摘要
    func getSummary() -> String {
        return """
        Connection Metrics:
        - Total Connections: \(totalConnections)
        - Successful Connections: \(successfulConnections) (\(String(format: "%.1f", connectionSuccessRate))%)
        - Failed Connections: \(failedConnections)
        - Total Commands: \(totalCommands)
        - Successful Commands: \(successfulCommands) (\(String(format: "%.1f", commandSuccessRate))%)
        - Failed Commands: \(failedCommands)
        - Average Response Time: \(String(format: "%.2f", averageResponseTime))s
        - Total Reconnections: \(totalReconnections)
        - Successful Reconnections: \(successfulReconnections) (\(String(format: "%.1f", reconnectionSuccessRate))%)
        - Failed Reconnections: \(failedReconnections)
        """
    }
}
