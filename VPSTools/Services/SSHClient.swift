import CryptoKit
import Foundation
import Network
import SwiftLibSSH

// MARK: - SSH Client

class SSHClient {
  private let connectionTimeout: TimeInterval = 30.0
  private var isConnected = false
  private var currentHost: String?
  private var currentVPS: VPSInstance?
  private var connectionStartTime: Date?
  private var lastActivityTime: Date?
  private var connectionMonitorTimer: Timer?
  private var activeConnection: NWConnection?
  private var connectionQueue = DispatchQueue(label: "ssh-connection-queue")
    
  // SwiftLibSSH client
  private var libsshClient: SwiftLibSSH?

  // SSH Protocol State
  private var sshState: SSHState = .disconnected
  private var serverVersion: String?
  private var clientVersion: String = "SSH-2.0-SwiftSSHClient_1.0"
  private var nextChannelId: UInt32 = 0
  private var receiveBuffer: Data = Data()
  private var isAuthenticated: Bool = false

  // Cryptographic state (simplified)
  private var sessionId: Data?
  private var encryptionKey: Data?
  private var macKey: Data?

  enum SSHState {
    case disconnected
    case versionExchange
    case keyExchange
    case authentication
    case connected
  }

  // MARK: - Connection Testing

  /// Tests SSH connection to VPS
  func testConnection(host: String, port: UInt16, username: String, authMethod: AuthMethod)
    async throws -> Bool
  {
    print("Testing connection to \(host):\(port)")

    // First test basic network connectivity
    let isReachable = await testNetworkReachability(host: host, port: port)
    guard isReachable else {
      print("Network unreachable for \(host):\(port)")
      return false
    }

    // Test SSH protocol handshake
    do {
      let sshReachable = try await testSSHHandshake(host: host, port: port)
      if sshReachable {
        print("SSH handshake successful for \(host):\(port)")
        return true
      } else {
        print("SSH handshake failed for \(host):\(port)")
        return false
      }
    } catch {
      print("SSH connection test failed: \(error)")
      return false
    }
  }

  /// Test SSH protocol handshake
  private func testSSHHandshake(host: String, port: UInt16) async throws -> Bool {
    return await withCheckedContinuation { continuation in
      let endpoint = NWEndpoint.hostPort(
        host: NWEndpoint.Host(host),
        port: NWEndpoint.Port(rawValue: port)!)
      let connection = NWConnection(to: endpoint, using: .tcp)

      var hasResumed = false
      let resumeQueue = DispatchQueue(label: "ssh-test-resume")

      func safeResume(_ value: Bool) {
        resumeQueue.sync {
          guard !hasResumed else { return }
          hasResumed = true
          continuation.resume(returning: value)
        }
      }

      connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
          // Send SSH version string to test SSH protocol
          let sshVersionCheck = "SSH-2.0-TestClient\r\n".data(using: .utf8)!
          connection.send(
            content: sshVersionCheck,
            completion: .contentProcessed { error in
              if error != nil {
                connection.cancel()
                safeResume(false)
                return
              }

              // Try to receive SSH server version
              connection.receive(minimumIncompleteLength: 1, maximumLength: 256) {
                data, _, isComplete, error in
                connection.cancel()

                if let data = data, let response = String(data: data, encoding: .utf8) {
                  // Check if response looks like SSH protocol
                  let isSSH = response.hasPrefix("SSH-") || response.contains("SSH")
                  safeResume(isSSH)
                } else {
                  safeResume(false)
                }
              }
            })

        case .failed(let error):
          print("SSH test connection failed: \(error)")
          connection.cancel()
          safeResume(false)

        default:
          break
        }
      }

      connection.start(queue: DispatchQueue.global())

      // Timeout after 10 seconds
      DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
        connection.cancel()
        safeResume(false)
      }
    }
  }

  /// Tests SSH connection to VPS instance
  func testConnection(_ vps: VPSInstance) async throws -> Bool {
    do {
      // Validate VPS configuration
      // VPS 验证逻辑已移至 VPSManager

      // Test network connectivity first
      let isReachable = await testNetworkReachability(host: vps.host, port: UInt16(vps.port))
      guard isReachable else {
        throw SSHError.networkUnreachable
      }

      print("Testing SSH connection to \(vps.host):\(vps.port)")

      // Test SSH handshake
      let sshReachable = try await testSSHHandshake(host: vps.host, port: UInt16(vps.port))
      guard sshReachable else {
        throw SSHError.connectionFailed
      }

      print("SSH connection test successful for \(vps.name)")
      return true

    } catch {
      print("SSH connection test failed for \(vps.name): \(error)")
      return false
    }
  }

  /// Connect to VPS with individual parameters
  func connect(to host: String, port: UInt16, username: String, password: String) async throws {
    print("Connecting to \(host):\(port) as \(username)")

    // Validate parameters
    guard !host.isEmpty else {
      throw SSHError.connectionFailed
    }

    guard port > 0 && port <= 65535 else {
      throw SSHError.connectionFailed
    }

    guard !username.isEmpty else {
      throw SSHError.authenticationFailed("Username cannot be empty")
    }

    // Test network connectivity first
    let isReachable = await testNetworkReachability(host: host, port: port)
    guard isReachable else {
      throw SSHError.networkUnreachable
    }

    // Establish connection
    try await establishDirectConnection(host: host, port: port)

    isConnected = true
    currentHost = host
    print("Successfully connected to \(host):\(port)")
  }

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

      // Test connection first
      let connectionSuccessful = try await testConnection(vps)
      if !connectionSuccessful {
        throw SSHError.connectionFailed
      }

      // Establish persistent SSH connection (SwiftLibSSH or Citadel)
      try await establishSSHConnection(to: vps)

      // Authenticate with the server
      try await authenticateSSH(vps: vps)

      currentVPS = vps
      isConnected = true
      currentHost = vps.host
      connectionStartTime = Date()
      lastActivityTime = Date()

      // Start connection monitoring
      startConnectionMonitoring()

      print("Successfully connected to VPS: \(vps.name)")

    } catch {
      isConnected = false
      currentVPS = nil
      currentHost = nil
      print("Failed to connect to VPS \(vps.name): \(error)")
      throw error
    }
  }

  /// Execute command on connected VPS
  func executeCommand(_ command: String) async throws -> String {
    guard isConnected else {
      throw SSHError.connectionFailed
    }

    guard let vps = currentVPS else {
      throw SSHError.connectionFailed
    }

    print("Executing command: \(command)")

    do {
      let result = try await executeCommandOverSSH(command, vps: vps)
      lastActivityTime = Date()
      print("Command executed successfully")
      return result
    } catch {
      print("Command execution failed: \(error)")
      throw SSHError.commandFailed(command)
    }
  }

  /// Execute command over SSH connection using library
  private func executeCommandOverSSH(_ command: String, vps: VPSInstance)
    async throws -> String
  {
    guard isAuthenticated else {
      throw SSHError.authenticationFailed("Not authenticated")
    }
    if let client = self.libsshClient {
        let result = await client.exec(command: command)
        guard let data = result.stdout else {
            return ""
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    throw SSHError.connectionFailed
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

  /// Disconnect from VPS
  func disconnect() async {
    stopConnectionMonitoring()

    if let vps = currentVPS, let startTime = connectionStartTime {
      let duration = Date().timeIntervalSince(startTime)
      print(
        "Disconnecting from VPS: \(vps.name) (connected for \(String(format: "%.1f", duration))s)")
    }

    // Close active NW connection (legacy)
    activeConnection?.cancel()
    activeConnection = nil
    libsshClient = nil

    // Reset SSH state
    sshState = .disconnected
    serverVersion = nil
    nextChannelId = 0
    receiveBuffer.removeAll()
    isAuthenticated = false
    sessionId = nil
    encryptionKey = nil
    macKey = nil

    isConnected = false
    currentHost = nil
    currentVPS = nil
    connectionStartTime = nil
    lastActivityTime = nil

    print("Disconnected from VPS")
  }

  /// Get connection statistics
  func getConnectionStats() -> (vpsName: String, host: String, connectedSince: Date, lastActivity: Date, isHealthy: Bool)? {
    guard let vps = currentVPS, let startTime = connectionStartTime else {
      return nil
    }

    return (
      vpsName: vps.name,
      host: vps.host,
      connectedSince: startTime,
      lastActivity: lastActivityTime ?? startTime,
      isHealthy: isConnected
    )
  }

  // MARK: - Private Connection Methods

  /// Establish direct connection for simple cases
  private func establishDirectConnection(host: String, port: UInt16) async throws {
    let endpoint = NWEndpoint.hostPort(
      host: NWEndpoint.Host(host),
      port: NWEndpoint.Port(rawValue: port)!
    )

    let connection = NWConnection(to: endpoint, using: .tcp)

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      var hasResumed = false
      let resumeQueue = DispatchQueue(label: "direct-connection-resume")

      @Sendable func safeResume(with result: Result<Void, Error>) {
        resumeQueue.sync {
          guard !hasResumed else { return }
          hasResumed = true
          continuation.resume(with: result)
        }
      }

      connection.stateUpdateHandler = { state in
        switch state {
        case .ready:
          self.activeConnection = connection
          safeResume(with: .success(()))

        case .failed(_):
          connection.cancel()
          safeResume(with: .failure(SSHError.connectionFailed))

        default:
          break
        }
      }

      connection.start(queue: connectionQueue)

      // Connection timeout
      DispatchQueue.global().asyncAfter(deadline: .now() + connectionTimeout) {
        connection.cancel()
        safeResume(with: .failure(SSHError.timeout))
      }
    }
  }

  /// Establish SSH connection to VPS (prefer SwiftLibSSH, otherwise Citadel)
  private func establishSSHConnection(to vps: VPSInstance) async throws {
    print("Establishing SSH (SwiftLibSSH) connection to \(vps.host):\(vps.port)")
    
    // 使用超时机制避免连接卡住
    try await withTimeout(30.0) { [weak self] in
      guard let self = self else { throw SSHError.connectionFailed }
      
      let client = SwiftLibSSH(
          host: vps.host,
          port: Int32(Int(vps.port)),
          user: vps.username,
          keepalive: true,
          )
      client.sessionDelegate = self
      self.libsshClient = client
      
      print("连接到 SSH 服务器...")
      let connectResult = await client.connect()
      print("连接结果: \(connectResult)")
      
      if !connectResult {
        throw SSHError.connectionFailed
      }
      
      print("执行 SSH 握手...")
      let handshakeResult = await client.handshake()
      print("握手结果: \(handshakeResult)")
      
      if !handshakeResult {
        throw SSHError.connectionFailed
      }
      
      print("SSH (SwiftLibSSH) connection prepared for \(vps.name)")
    }
  }
  
  /// 带超时的异步操作
  private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
      group.addTask {
        try await operation()
      }
      
      group.addTask {
        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        throw SSHError.timeout
      }
      
      guard let result = try await group.next() else {
        throw SSHError.timeout
      }
      
      group.cancelAll()
      return result
    }
  }

  /// Perform complete SSH protocol handshake
  private func performSSHHandshake(connection: NWConnection) async throws {
    // Deprecated by NIOSSH pipeline; kept for compatibility no-op
    sshState = .connected
  }

  /// Perform SSH version exchange
  private func performVersionExchange(connection: NWConnection) async throws {
    // Deprecated by NIOSSH pipeline; no-op
  }

  /// Perform SSH key exchange
  private func performKeyExchange(connection: NWConnection) async throws {
    // Deprecated by NIOSSH pipeline; no-op
  }

  /// Simplified key exchange (for demonstration)
  private func performSimplifiedKeyExchange(connection: NWConnection) async throws {
    // Deprecated by NIOSSH pipeline; no-op
  }

  /// Request SSH connection service
  private func requestSSHConnection(connection: NWConnection) async throws {
    // Deprecated by NIOSSH pipeline; no-op
  }

  /// Authenticate SSH connection using full protocol
  private func authenticateSSH(vps: VPSInstance) async throws {
    print("Authenticating SSH connection for user: \(vps.username)")
    
    guard let client = self.libsshClient else {
        throw SSHError.authenticationFailed("SSH client not initialized")
    }
    
    // 使用超时机制避免认证卡住
    try await withTimeout(20.0) { [weak self] in
      guard let self = self else { throw SSHError.authenticationFailed("Client released") }
      
      print("开始 SSH 认证...")
      var authResult = false
      if(vps.password != nil) {
        authResult = await client.authenticate(password: vps.password ?? "")
      } else if(vps.privateKey != nil) {
        authResult = await client.authenticate(privateKey: vps.privateKey ?? "", passphrase: vps.keyPassphrase ?? "")
      }
      print("认证结果: \(authResult)")
      
      if !authResult {
        throw SSHError.authenticationFailed("Password authentication failed")
      }
      
      self.sshState = .authentication
      self.isAuthenticated = true
      print("SSH authentication successful for \(vps.name)")
    }
  }

  /// Authenticate using password with full SSH protocol
  private func authenticateWithPassword(connection: NWConnection, vps: VPSInstance) async throws {
    // Deprecated legacy path
    throw SSHError.authenticationFailed("Use library authentication")
  }

  /// Authenticate using public key
  private func authenticateWithPublicKey(vps: VPSInstance) async throws {
    throw SSHError.authenticationFailed("Public key authentication not yet implemented")
  }

  /// Authenticate using key file
  private func authenticateWithKeyFile(vps: VPSInstance) async throws {
    throw SSHError.authenticationFailed("Key file authentication not yet implemented")
  }

  // MARK: - Connection Monitoring

  private func startConnectionMonitoring() {
    connectionMonitorTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) {
      [weak self] _ in
      Task {
        await self?.checkConnectionHealth()
      }
    }
  }

  private func stopConnectionMonitoring() {
    connectionMonitorTimer?.invalidate()
    connectionMonitorTimer = nil
  }

  private func checkConnectionHealth() async {
    guard isConnected, let vps = currentVPS else { return }
    do {
      _ = try await executeCommand("echo 'connection_test'")
      lastActivityTime = Date()
      print("Connection health check passed for \(vps.name)")
    } catch {
      print("Connection health check failed for \(vps.name): \(error)")
      await disconnect()
    }
  }

  // MARK: - Network Testing

  private func testNetworkReachability(host: String, port: UInt16) async -> Bool {
    print("Testing network reachability to \(host):\(port)")

    return await withCheckedContinuation { continuation in
      var hasResumed = false
      let resumeQueue = DispatchQueue(label: "network-reachability-resume")

      @Sendable func safeResume(_ value: Bool) {
        resumeQueue.sync {
          guard !hasResumed else { return }
          hasResumed = true
          continuation.resume(returning: value)
        }
      }

      let monitor = NWPathMonitor()
      let monitorQueue = DispatchQueue(label: "network-monitor")

      monitor.pathUpdateHandler = { path in
        monitor.cancel()

        guard path.status == .satisfied else {
          print("Network path not satisfied: \(path.status)")
          safeResume(false)
          return
        }

        print("Network path satisfied, testing connection to \(host):\(port)")

        self.testTCPConnection(host: host, port: port) { success in
          if success {
            print("TCP connection test successful to \(host):\(port)")
          } else {
            print("TCP connection test failed to \(host):\(port)")
          }
          safeResume(success)
        }
      }

      monitor.start(queue: monitorQueue)

      DispatchQueue.global().asyncAfter(deadline: .now() + 15) {
        monitor.cancel()
        print("Network reachability test timed out for \(host):\(port)")
        safeResume(false)
      }
    }
  }

  private func testTCPConnection(host: String, port: UInt16, completion: @escaping (Bool) -> Void) {
    let endpoint = NWEndpoint.hostPort(
      host: NWEndpoint.Host(host),
      port: NWEndpoint.Port(rawValue: port)!)
    let connection = NWConnection(to: endpoint, using: .tcp)

    var hasCompleted = false
    let completionQueue = DispatchQueue(label: "tcp-test-completion")

    func safeComplete(_ success: Bool) {
      completionQueue.sync {
        guard !hasCompleted else { return }
        hasCompleted = true
        connection.cancel()
        completion(success)
      }
    }

    connection.stateUpdateHandler = { state in
      switch state {
      case .ready:
        print("TCP connection established to \(host):\(port)")
        safeComplete(true)

      case .failed(let error):
        print("TCP connection failed to \(host):\(port): \(error)")
        safeComplete(false)

      case .cancelled:
        if !hasCompleted {
          print("TCP connection cancelled to \(host):\(port)")
          safeComplete(false)
        }

      default:
        break
      }
    }

    let connectionQueue = DispatchQueue(label: "tcp-connection")
    connection.start(queue: connectionQueue)

    DispatchQueue.global().asyncAfter(deadline: .now() + 10) {
      safeComplete(false)
    }
  }
}

// MARK: - SSH Errors

enum SSHError: Error, LocalizedError {
  case connectionFailed
  case authenticationFailed(String)
  case commandFailed(String)
  case networkUnreachable
  case timeout

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
    }
  }
}

extension SSHClient: SessionDelegate {
    func disconnect(ssh: SwiftLibSSH) {
        print("disconnect")
    }
    
    func connect(ssh: SwiftLibSSH, fingerprint: String) -> Bool {
        print("connect")
        return true
    }
    
    func keyboardInteractive(ssh: SwiftLibSSH, prompt: String) -> String {
        return ""
    }
    
    func send(ssh: SwiftLibSSH, size: Int) async {
        print("send size: \(size)")
    }
    
    func recv(ssh: SwiftLibSSH, size: Int) async {
        print("recv size: \(size)")
    }
    
    func debug(ssh: SwiftLibSSH, message: String) async {
        print("debug: \(message)")
    }
    
    func trace(ssh: SwiftLibSSH, message: String) async {
        print("trace: \(message)")
    }
    
    
}
