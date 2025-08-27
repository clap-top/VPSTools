import Foundation
import SwiftLibSSH
import Combine

// MARK: - SSH Client

class SSHClient {
  // MARK: - Configuration
  private let connectionTimeout: TimeInterval = SSHConnectionConfig.Timeouts.connection
  private let commandTimeout: TimeInterval = SSHConnectionConfig.Timeouts.command
  private let authenticationTimeout: TimeInterval = SSHConnectionConfig.Timeouts.authentication
  
  // MARK: - Connection State
  private var isConnected = false
  private var currentVPS: VPSInstance?
  private var libsshClient: SwiftLibSSH?
  private var connectionStartTime: Date?
  private var lastActivityTime: Date?
  
  // MARK: - Connection Metrics
  private var connectionMetrics = SSHConnectionMetrics()
  private var commandQueue = DispatchQueue(label: "ssh.command.queue", qos: SSHConnectionConfig.Performance.commandQueueQoS)
  
  // MARK: - Error Tracking
  private var consecutiveErrors: Int = 0
  private var lastError: Error?
  private var errorHistory: [SSHError] = []
  
  // MARK: - Health Monitoring
  private var healthCheckTimer: Timer?
  private var keepAliveTimer: Timer?
  
  // MARK: - Deinitialization
  
  deinit {
    // 立即停止定时器
    healthCheckTimer?.invalidate()
    keepAliveTimer?.invalidate()
    
    // 清理连接状态
    libsshClient = nil
    isConnected = false
    currentVPS = nil
    
    print("SSHClient: Deinitializing")
  }
  
  // MARK: - Public Methods
  
  /// Connect to VPS instance
  func connect(to vps: VPSInstance) async throws {
    if isConnected {
      if let current = currentVPS, current.id == vps.id {
        return  // Already connected to this VPS
      } else {
        await disconnect()  // Disconnect from current VPS
      }
    }

    do {
      print("Connecting to VPS: \(vps.name) at \(vps.host):\(vps.port)")
      
      // 重置错误计数
      consecutiveErrors = 0
      lastError = nil

      // Create SwiftLibSSH client with enhanced configuration
      let client = SwiftLibSSH(
        host: vps.host,
        port: Int32(vps.port),
        user: vps.username,
        methods: [
          SSHMethod.comp_cs : SSHConnectionConfig.Security.allowedCiphers,
          SSHMethod.mac_cs : SSHConnectionConfig.Security.allowedMACs,
          SSHMethod.kex : SSHConnectionConfig.Security.allowedKeyExchanges
        ],
        keepalive: true
      )
      client.sessionDelegate = self
      self.libsshClient = client
      
      // 设置连接超时
      let connectTask = Task {
        await client.connect()
      }
      
      let connectResult = try await withTimeout(seconds: connectionTimeout) {
        await connectTask.value
      }
      
      if !connectResult {
        throw SSHError.connectionFailed
      }
      
      // Handshake with timeout
      let handshakeTask = Task {
        await client.handshake()
      }
      
      let handshakeResult = try await withTimeout(seconds: connectionTimeout) {
        await handshakeTask.value
      }
      
      if !handshakeResult {
        throw SSHError.connectionFailed
      }
      
      // Authenticate with timeout
      var authResult = false
      if vps.password != nil {
        let authTask = Task {
          await client.authenticate(password: vps.password ?? "")
        }
        authResult = try await withTimeout(seconds: authenticationTimeout) {
          await authTask.value
        }
      } else if vps.privateKey != nil {
        let authTask = Task {
          await client.authenticate(privateKey: vps.privateKey ?? "", passphrase: vps.privateKeyPhrase ?? "")
        }
        authResult = try await withTimeout(seconds: authenticationTimeout) {
          await authTask.value
        }
      }
      
      if !authResult {
        throw SSHError.authenticationFailed("Authentication failed")
      }

      currentVPS = vps
      isConnected = true
      connectionStartTime = Date()
      lastActivityTime = Date()
      
      connectionMetrics.totalConnections += 1
      connectionMetrics.successfulConnections += 1
      connectionMetrics.lastConnectionTime = Date()
      
      // 启动健康检查和保活
      startHealthMonitoring()

      print("Successfully connected to VPS: \(vps.name)")

    } catch {
      isConnected = false
      currentVPS = nil
      consecutiveErrors += 1
      lastError = error
      
      if let sshError = error as? SSHError {
        errorHistory.append(sshError)
      }
      
      connectionMetrics.totalConnections += 1
      connectionMetrics.failedConnections += 1
      print("Failed to connect to VPS \(vps.name): \(error)")
      throw error
    }
  }

  /// Execute command on connected VPS
  func executeCommand(_ command: String) async throws -> String {
    guard isConnected, let client = libsshClient else {
      throw SSHError.connectionFailed
    }

    print("Executing command: \(command)")

    
    let result = await client.exec(command: command)
      guard let data = result.stdout else {
          return ""
    }

    connectionMetrics.totalCommands += 1
    connectionMetrics.successfulCommands += 1

    let output = String(data: data, encoding: .utf8) ?? ""
    print("Command executed successfully")
    return output
  }

  /// Write file content to remote path using SSH
  func writeFile(content: String, to remotePath: String) async throws {
    guard isConnected else {
      throw SSHError.connectionFailed
    }

    guard let vps = currentVPS else {
      throw SSHError.connectionFailed
    }

    print("Writing file to \(remotePath)")

    // Validate file path
    guard remotePath.hasPrefix("/"), !remotePath.contains("..") else {
      throw SSHError.commandFailed("Invalid file path: \(remotePath)")
    }

    do {
      try await writeFileOverSSH(content: content, to: remotePath, vps: vps)
      print("Successfully wrote \(content.count) bytes to \(remotePath)")
    } catch {
      throw SSHError.commandFailed(
        "Failed to write file to \(remotePath): \(error.localizedDescription)")
    }
  }

  /// Write file over SSH using base64 encoding
  private func writeFileOverSSH(content: String, to remotePath: String, vps: VPSInstance)
    async throws
  {
    // Create temporary file with unique name
    let tempFile = "/tmp/ssh_upload_\(UUID().uuidString)"

    // Encode content as base64 to handle binary data and special characters
    let contentData = content.data(using: .utf8) ?? Data()
    let base64Content = contentData.base64EncodedString()

    // Split into chunks to avoid command line length limits
    let chunkSize = 1024
    let chunks = stride(from: 0, to: base64Content.count, by: chunkSize).map {
      String(
        base64Content[
          base64Content.index(
            base64Content.startIndex, offsetBy: $0)..<base64Content.index(
              base64Content.startIndex, offsetBy: min($0 + chunkSize, base64Content.count))])
    }

    // Clear temp file first
    _ = try await executeCommand("> \(tempFile)")

    // Write content in chunks
    for chunk in chunks {
      let command = "echo '\(chunk)' >> \(tempFile)"
      _ = try await executeCommand(command)
    }

    // Decode base64 and write to final location
    _ = try await executeCommand("base64 -d \(tempFile) > \(remotePath)")

    // Clean up temp file
    _ = try await executeCommand("rm -f \(tempFile)")

    // Verify file was written
    let verifyCommand = "test -f \(remotePath) && echo 'file_exists'"
    let result = try await executeCommand(verifyCommand)

    if !result.contains("file_exists") {
      throw SSHError.commandFailed("File verification failed")
    }
  }

  /// Test connection to VPS
  func testConnection(_ vps: VPSInstance) async throws -> Bool {
      // Try to connect temporarily
      let tempClient = SwiftLibSSH(
        host: vps.host,
        port: Int32(vps.port),
        user: vps.username,
        methods: [SSHMethod.comp_cs : "aes128-ctr"],
        keepalive: false
      )
      
      let connectResult = await tempClient.connect()
      if !connectResult {
        return false
      }
      
      let handshakeResult = await tempClient.handshake()
      return handshakeResult
  }

  /// Disconnect from VPS
  func disconnect() async {
    if let vps = currentVPS {
      print("Disconnecting from VPS: \(vps.name)")
    }

    // 停止定时器
    healthCheckTimer?.invalidate()
    keepAliveTimer?.invalidate()
    healthCheckTimer = nil
    keepAliveTimer = nil

    libsshClient = nil
    isConnected = false
    currentVPS = nil
    connectionMetrics.lastDisconnectionTime = Date()

    print("Disconnected from VPS")
  }

  /// Get connection statistics
  func getConnectionStats() -> (vpsName: String, host: String, connectedSince: Date, lastActivity: Date, isHealthy: Bool)? {
    guard let vps = currentVPS, let startTime = connectionMetrics.lastConnectionTime else {
      return nil
    }

    return (
      vpsName: vps.name,
      host: vps.host,
      connectedSince: startTime,
      lastActivity: connectionMetrics.lastDisconnectionTime ?? startTime,
      isHealthy: isConnected
    )
  }
  
  /// 检查连接健康状态
  func checkConnectionHealth() async -> Bool {
    guard isConnected, let client = libsshClient else {
      return false
    }
    
    do {
      // 执行一个简单的命令来测试连接
      let result = try await withTimeout(seconds: 5.0) {
        await client.exec(command: "echo 'health_check'")
      }
      
      let isHealthy = result.stdout != nil
      if isHealthy {
        consecutiveErrors = 0
        lastActivityTime = Date()
      } else {
        consecutiveErrors += 1
      }
      
      return isHealthy
    } catch {
      consecutiveErrors += 1
      lastError = error
      return false
    }
  }
  
  // MARK: - Private Methods
  
  /// 超时处理
  private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask {
        await operation()
      }
      
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        throw SSHError.timeout
      }
      
      let result = try await group.next()!
      group.cancelAll()
      return result
    }
  }
  
  /// 启动健康监控
  private func startHealthMonitoring() {
    // 健康检查定时器
    healthCheckTimer = Timer.scheduledTimer(withTimeInterval: SSHConnectionConfig.KeepAlive.interval, repeats: true) { [weak self] _ in
      Task {
        await self?.performHealthCheck()
      }
    }
    
    // 保活定时器
    keepAliveTimer = Timer.scheduledTimer(withTimeInterval: SSHConnectionConfig.KeepAlive.interval * 2, repeats: true) { [weak self] _ in
      Task {
        await self?.performKeepAlive()
      }
    }
  }
  
  /// 执行健康检查
  private func performHealthCheck() async {
    guard isConnected else { return }
    
    let isHealthy = await checkConnectionHealth()
    if !isHealthy {
      print("SSHClient: Health check failed for VPS: \(currentVPS?.name ?? "Unknown")")
      
      // 如果连续错误次数过多，标记连接为不健康
      if consecutiveErrors >= SSHConnectionConfig.ConnectionPool.maxErrorCount {
        isConnected = false
        print("SSHClient: Connection marked as unhealthy due to consecutive errors")
      }
    }
  }
  
  /// 执行保活
  private func performKeepAlive() async {
    guard isConnected, let client = libsshClient else { return }
    
    do {
      let result = try await withTimeout(seconds: 5.0) {
        await client.exec(command: SSHConnectionConfig.KeepAlive.command)
      }
      
      if result.stdout != nil {
        lastActivityTime = Date()
      }
    } catch {
      print("SSHClient: Keep-alive failed for VPS: \(currentVPS?.name ?? "Unknown"): \(error)")
    }
  }
  
  /// 获取连接统计信息
  func getDetailedStats() -> SSHConnectionStats {
    return SSHConnectionStats(
      isConnected: isConnected,
      vpsName: currentVPS?.name ?? "Unknown",
      host: currentVPS?.host ?? "Unknown",
      connectedSince: connectionStartTime,
      lastActivity: lastActivityTime,
      consecutiveErrors: consecutiveErrors,
      totalErrors: errorHistory.count,
      connectionDuration: connectionStartTime.map { Date().timeIntervalSince($0) },
      metrics: connectionMetrics
    )
  }
}

// MARK: - SSH Errors

enum SSHError: Error, LocalizedError {
  case connectionFailed
  case authenticationFailed(String)
  case commandFailed(String)
  case networkUnreachable
  case timeout
  case connectionPoolFull
  case reconnectionFailed

  var errorDescription: String? {
    switch self {
    case .connectionFailed:
      return "SSH连接失败"
    case .authenticationFailed(let message):
      return "SSH认证失败: \(message)"
    case .commandFailed(let command):
      return "命令执行失败: \(command)"
    case .networkUnreachable:
      return "网络不可达"
    case .timeout:
      return "连接超时"
    case .connectionPoolFull:
      return "连接池已满"
    case .reconnectionFailed:
      return "重连失败"
    }
  }
}

// MARK: - Session Delegate

extension SSHClient: SessionDelegate {
  func disconnect(ssh: SwiftLibSSH) {
    print("SSH session disconnected")
  }
  
  func connect(ssh: SwiftLibSSH, fingerprint: String) -> Bool {
    print("SSH session connected with fingerprint: \(fingerprint)")
    return true
  }
  
  func keyboardInteractive(ssh: SwiftLibSSH, prompt: String) -> String {
    print("SSH keyboard interactive prompt: \(prompt)")
    return ""
  }
  
  func send(ssh: SwiftLibSSH, size: Int) async {
    print("SSH send size: \(size)")
  }
  
  func recv(ssh: SwiftLibSSH, size: Int) async {
    print("SSH recv size: \(size)")
  }
  
  func debug(ssh: SwiftLibSSH, message: String) async {
    print("SSH debug: \(message)")
  }
  
  func trace(ssh: SwiftLibSSH, message: String) async {
    print("SSH trace: \(message)")
  }
}

// MARK: - SSH Connection Stats

/// SSH连接详细统计信息
struct SSHConnectionStats {
  let isConnected: Bool
  let vpsName: String
  let host: String
  let connectedSince: Date?
  let lastActivity: Date?
  let consecutiveErrors: Int
  let totalErrors: Int
  let connectionDuration: TimeInterval?
  let metrics: SSHConnectionMetrics
  
  var isHealthy: Bool {
    return isConnected && consecutiveErrors < SSHConnectionConfig.ConnectionPool.maxErrorCount
  }
  
  var uptime: String {
    guard let duration = connectionDuration else { return "Unknown" }
    let hours = Int(duration) / 3600
    let minutes = Int(duration) % 3600 / 60
    let seconds = Int(duration) % 60
    return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
  }
  
  var errorRate: Double {
    guard metrics.totalCommands > 0 else { return 0.0 }
    return Double(metrics.failedCommands) / Double(metrics.totalCommands) * 100.0
  }
}
