import Foundation
import SwiftUI

// MARK: - SSH Connection Configuration

/// SSH连接配置管理
struct SSHConnectionConfig {

  // MARK: - Timeouts Configuration
  struct Timeouts {
    static let connection: TimeInterval = 5.0
    static let command: TimeInterval = 30.0
    static let authentication: TimeInterval = 10.0
    static let keepAlive: TimeInterval = 30.0
  }

  // MARK: - Connection Pool Configuration
  struct ConnectionPool {
    static let maxConnections: Int = 10
    static let maxSize: Int = 10
    static let maxIdleTime: TimeInterval = 300.0  // 5 minutes
    static let maxErrorCount: Int = 3
    static let healthCheckInterval: TimeInterval = 60.0  // 1 minute
    static let cleanupInterval: TimeInterval = 120.0  // 2 minutes
  }

  // MARK: - Keep Alive Configuration
  struct KeepAlive {
    static let interval: TimeInterval = 30.0
    static let command: String = "echo 'keepalive'"
    static let maxMissed: Int = 3
  }

  // MARK: - Security Configuration
  struct Security {
    static let allowedCiphers: [String] = [
      "aes128-ctr", "aes192-ctr", "aes256-ctr",
      "aes128-gcm@openssh.com", "aes256-gcm@openssh.com",
    ]
    static let allowedMACs: [String] = [
      "hmac-sha2-256", "hmac-sha2-512",
      "hmac-sha2-256-etm@openssh.com", "hmac-sha2-512-etm@openssh.com",
    ]
    static let allowedKeyExchanges: [String] = [
      "curve25519-sha256", "curve25519-sha256@libssh.org",
      "ecdh-sha2-nistp256", "ecdh-sha2-nistp384", "ecdh-sha2-nistp521",
    ]
    static let supportedKeyTypes: [SSHKeyType] = [.rsa, .ecdsa, .ed25519]
  }

  // MARK: - Performance Configuration
  struct Performance {
    static let commandQueueQoS: DispatchQoS = .userInitiated
    static let maxConcurrentCommands: Int = 5
    static let compressionEnabled: Bool = true
    static let tcpNoDelay: Bool = true
  }

  // MARK: - Retry Configuration
  struct Retry {
    static let maxAttempts: Int = 3
    static let baseInterval: TimeInterval = 2.0
    static let maxInterval: TimeInterval = 30.0
    static let backoffMultiplier: Double = 2.0
  }
  
  // MARK: - Reconnection Configuration
  struct Reconnection {
    static let maxAttempts: Int = 3
    static let baseDelay: TimeInterval = 2.0
    static let maxDelay: TimeInterval = 30.0
    static let delayMultiplier: Double = 2.0
  }
}

// MARK: - SSH Connection Options

/// SSH连接选项配置
struct SSHConnectionOptions: Codable {
  let timeout: TimeInterval
  let retryCount: Int
  let retryInterval: TimeInterval
  let keepAliveInterval: TimeInterval
  let compressionEnabled: Bool
  let proxyConfiguration: ProxyConfiguration?
  let securityLevel: SSHSecurityLevel
  let authenticationMethods: [SSHAuthenticationMethod]

  init(
    timeout: TimeInterval = SSHConnectionConfig.Timeouts.connection,
    retryCount: Int = SSHConnectionConfig.Retry.maxAttempts,
    retryInterval: TimeInterval = SSHConnectionConfig.Retry.baseInterval,
    keepAliveInterval: TimeInterval = SSHConnectionConfig.KeepAlive.interval,
    compressionEnabled: Bool = SSHConnectionConfig.Performance.compressionEnabled,
    proxyConfiguration: ProxyConfiguration? = nil,
    securityLevel: SSHSecurityLevel = .standard,
    authenticationMethods: [SSHAuthenticationMethod] = [.password, .publicKey]
  ) {
    self.timeout = timeout
    self.retryCount = retryCount
    self.retryInterval = retryInterval
    self.keepAliveInterval = keepAliveInterval
    self.compressionEnabled = compressionEnabled
    self.proxyConfiguration = proxyConfiguration
    self.securityLevel = securityLevel
    self.authenticationMethods = authenticationMethods
  }
}

// MARK: - SSH Security Level

/// SSH安全级别
enum SSHSecurityLevel: String, CaseIterable, Codable {
  case minimal = "minimal"
  case standard = "standard"
  case high = "high"
  case maximum = "maximum"

  var displayName: String {
    switch self {
    case .minimal: return "最低"
    case .standard: return "标准"
    case .high: return "高"
    case .maximum: return "最高"
    }
  }

  var description: String {
    switch self {
    case .minimal: return "基本安全设置，兼容性最好"
    case .standard: return "标准安全设置，推荐使用"
    case .high: return "高安全设置，更严格的验证"
    case .maximum: return "最高安全设置，可能影响兼容性"
    }
  }
}

// MARK: - SSH Authentication Method

/// SSH认证方法
enum SSHAuthenticationMethod: String, CaseIterable, Codable {
  case password = "password"
  case publicKey = "public_key"
  case keyboardInteractive = "keyboard_interactive"
  case gssapi = "gssapi"

  var displayName: String {
    switch self {
    case .password: return "密码认证"
    case .publicKey: return "公钥认证"
    case .keyboardInteractive: return "交互式认证"
    case .gssapi: return "GSSAPI认证"
    }
  }

  var isSupported: Bool {
    switch self {
    case .password, .publicKey: return true
    case .keyboardInteractive, .gssapi: return false  // 暂不支持
    }
  }
}

// MARK: - SSH Key Type

/// SSH密钥类型
enum SSHKeyType: String, CaseIterable, Codable {
  case rsa = "rsa"
  case ecdsa = "ecdsa"
  case ed25519 = "ed25519"
  case dsa = "dsa"

  var displayName: String {
    switch self {
    case .rsa: return "RSA"
    case .ecdsa: return "ECDSA"
    case .ed25519: return "Ed25519"
    case .dsa: return "DSA"
    }
  }

  var isRecommended: Bool {
    switch self {
    case .ed25519, .ecdsa: return true
    case .rsa: return true  // 仍然广泛使用
    case .dsa: return false  // 已弃用
    }
  }

  var keySize: [Int] {
    switch self {
    case .rsa: return [2048, 3072, 4096]
    case .ecdsa: return [256, 384, 521]
    case .ed25519: return [256]
    case .dsa: return [1024]  // 已弃用
    }
  }
}

// MARK: - Proxy Configuration

/// 代理配置
struct ProxyConfiguration: Codable {
  let type: ProxyType
  let host: String
  let port: Int
  let username: String?
  let password: String?

  enum ProxyType: String, CaseIterable, Codable {
    case http = "http"
    case https = "https"
    case socks5 = "socks5"

    var displayName: String {
      switch self {
      case .http: return "HTTP"
      case .https: return "HTTPS"
      case .socks5: return "SOCKS5"
      }
    }
  }
}

// MARK: - SSH Connection Status

/// SSH连接状态
enum SSHConnectionStatus: Equatable {
  case disconnected
  case connecting
  case authenticating
  case connected
  case reconnecting
  case error(SSHError)
  
  static func == (lhs: SSHConnectionStatus, rhs: SSHConnectionStatus) -> Bool {
    switch (lhs, rhs) {
    case (.disconnected, .disconnected),
         (.connecting, .connecting),
         (.authenticating, .authenticating),
         (.connected, .connected),
         (.reconnecting, .reconnecting):
      return true
    case (.error(let lhsError), .error(let rhsError)):
      return lhsError == rhsError
    default:
      return false
    }
  }

  var isActive: Bool {
    switch self {
    case .connected:
      return true
    default:
      return false
    }
  }

  var displayName: String {
    switch self {
    case .disconnected: return "已断开"
    case .connecting: return "连接中"
    case .authenticating: return "认证中"
    case .connected: return "已连接"
    case .reconnecting: return "重连中"
    case .error: return "连接错误"
    }
  }

  var color: Color {
    switch self {
    case .connected: return .green
    case .connecting, .authenticating, .reconnecting: return .orange
    case .disconnected: return .gray
    case .error: return .red
    }
  }
}

// MARK: - SSH Connection Metrics

/// SSH连接指标
struct SSHConnectionMetrics: Codable {
  var totalConnections: Int = 0
  var successfulConnections: Int = 0
  var failedConnections: Int = 0
  var totalCommands: Int = 0
  var successfulCommands: Int = 0
  var failedCommands: Int = 0
  var lastConnectionTime: Date?
  var lastDisconnectionTime: Date?
  var averageConnectionTime: TimeInterval = 0
  var totalDataTransferred: Int64 = 0

  var successRate: Double {
    guard totalConnections > 0 else { return 0.0 }
    return Double(successfulConnections) / Double(totalConnections) * 100.0
  }

  var commandSuccessRate: Double {
    guard totalCommands > 0 else { return 0.0 }
    return Double(successfulCommands) / Double(totalCommands) * 100.0
  }
}

// MARK: - SSH Security Features

/// SSH安全功能配置
struct SSHSecurityFeatures: Codable {
  var hostKeyVerification: Bool = true
  var strictHostKeyChecking: Bool = true
  var certificateValidation: Bool = true
  var attackDetection: Bool = true
  var secureLogging: Bool = true
  var memoryProtection: Bool = true

  static let `default` = SSHSecurityFeatures()
}

// MARK: - Host Key Verification Result

/// 主机密钥验证结果
enum HostKeyVerificationResult {
  case trusted
  case untrusted(fingerprint: String)
  case changed(oldFingerprint: String, newFingerprint: String)
  case firstTime(fingerprint: String)

  var isSecure: Bool {
    switch self {
    case .trusted: return true
    default: return false
    }
  }
}

// MARK: - Security Threat

/// 安全威胁类型
enum SecurityThreat: Codable {
  case mitm(description: String)
  case hostKeyMismatch(expected: String, actual: String)
  case suspiciousActivity(description: String)
  case bruteForceAttempt
  case unauthorizedAccess

  var severity: ThreatSeverity {
    switch self {
    case .mitm, .hostKeyMismatch: return .critical
    case .suspiciousActivity, .unauthorizedAccess: return .high
    case .bruteForceAttempt: return .medium
    }
  }

  var description: String {
    switch self {
    case .mitm(let desc): return "中间人攻击: \(desc)"
    case .hostKeyMismatch(let expected, let actual):
      return "主机密钥不匹配: 期望 \(expected), 实际 \(actual)"
    case .suspiciousActivity(let desc): return "可疑活动: \(desc)"
    case .bruteForceAttempt: return "暴力破解尝试"
    case .unauthorizedAccess: return "未授权访问"
    }
  }
}

/// 威胁严重程度
enum ThreatSeverity: String, CaseIterable, Codable {
  case low = "low"
  case medium = "medium"
  case high = "high"
  case critical = "critical"

  var displayName: String {
    switch self {
    case .low: return "低"
    case .medium: return "中"
    case .high: return "高"
    case .critical: return "严重"
    }
  }

  var color: Color {
    switch self {
    case .low: return .green
    case .medium: return .yellow
    case .high: return .orange
    case .critical: return .red
    }
  }
}
