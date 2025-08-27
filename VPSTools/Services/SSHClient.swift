import Foundation
import SwiftLibSSH

// MARK: - SSH Client

class SSHClient {
  // MARK: - Configuration
  private let connectionTimeout: TimeInterval = 30.0
  private let commandTimeout: TimeInterval = 60.0
  
  // MARK: - Connection State
  private var isConnected = false
  private var currentVPS: VPSInstance?
  private var libsshClient: SwiftLibSSH?
  
  // MARK: - Connection Metrics
  private var connectionMetrics = SSHConnectionMetrics()
  
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

      // Create SwiftLibSSH client
      let client = SwiftLibSSH(
        host: vps.host,
        port: Int32(vps.port),
        user: vps.username,
        methods: [SSHMethod.comp_cs : "aes128-ctr"],
        keepalive: true
      )
      client.sessionDelegate = self
      self.libsshClient = client
      
      // Connect
      let connectResult = await client.connect()
      if !connectResult {
        throw SSHError.connectionFailed
      }
      
      // Handshake
      let handshakeResult = await client.handshake()
      if !handshakeResult {
        throw SSHError.connectionFailed
      }
      
      // Authenticate
      var authResult = false
      if vps.password != nil {
        authResult = await client.authenticate(password: vps.password ?? "")
      } else if vps.privateKey != nil {
        authResult = await client.authenticate(privateKey: vps.privateKey ?? "", passphrase: vps.privateKeyPhrase ?? "")
      }
      
      if !authResult {
        throw SSHError.authenticationFailed("Authentication failed")
      }

      currentVPS = vps
      isConnected = true
      connectionMetrics.totalConnections += 1
      connectionMetrics.successfulConnections += 1
      connectionMetrics.lastConnectionTime = Date()

      print("Successfully connected to VPS: \(vps.name)")

    } catch {
      isConnected = false
      currentVPS = nil
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

    do {
      let result = await client.exec(command: command)
      guard let data = result.stdout else {
        return ""
      }
      
      connectionMetrics.totalCommands += 1
      connectionMetrics.successfulCommands += 1
      
      let output = String(data: data, encoding: .utf8) ?? ""
      print("Command executed successfully")
      return output
    } catch {
      connectionMetrics.totalCommands += 1
      connectionMetrics.failedCommands += 1
      print("Command execution failed: \(error)")
      throw SSHError.commandFailed(command)
    }
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
    do {
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
      
    } catch {
      return false
    }
  }

  /// Disconnect from VPS
  func disconnect() async {
    if let vps = currentVPS {
      print("Disconnecting from VPS: \(vps.name)")
    }

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
