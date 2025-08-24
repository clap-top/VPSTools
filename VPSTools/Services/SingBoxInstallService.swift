import Foundation
import Combine

// MARK: - SingBox Install Service

/// SingBox安装服务 - 负责获取最新版本并匹配VPS架构
@MainActor
class SingBoxInstallService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isInstalling = false
    @Published var currentStep: SingBoxInstallStep = .idle
    @Published var progress: Double = 0.0
    @Published var lastError: String?
    @Published var installLogs: [String] = []
    
    // MARK: - Private Properties
    
    private let sshClient: SSHClient
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - SingBox Release Info
    
    struct SingBoxRelease: Codable {
        let tagName: String
        let name: String
        let body: String
        let assets: [ReleaseAsset]
        
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name, body, assets
        }
    }
    
    struct ReleaseAsset: Codable {
        let name: String
        let browserDownloadUrl: String
        let size: Int
        
        enum CodingKeys: String, CodingKey {
            case name, size
            case browserDownloadUrl = "browser_download_url"
        }
    }
    
    // MARK: - System Architecture
    
    enum SystemArchitecture: String, CaseIterable {
        case amd64 = "amd64"
        case arm64 = "arm64"
        case armv7 = "armv7"
        case armv6 = "armv6"
        case armv5 = "armv5"
        case mips64 = "mips64"
        case mips64le = "mips64le"
        case mips = "mips"
        case mipsle = "mipsle"
        case ppc64 = "ppc64"
        case ppc64le = "ppc64le"
        case s390x = "s390x"
        case riscv64 = "riscv64"
        
        var displayName: String {
            switch self {
            case .amd64: return "x86_64 (AMD64)"
            case .arm64: return "ARM64 (AArch64)"
            case .armv7: return "ARMv7"
            case .armv6: return "ARMv6"
            case .armv5: return "ARMv5"
            case .mips64: return "MIPS64"
            case .mips64le: return "MIPS64LE"
            case .mips: return "MIPS"
            case .mipsle: return "MIPSLE"
            case .ppc64: return "PowerPC64"
            case .ppc64le: return "PowerPC64LE"
            case .s390x: return "S390x"
            case .riscv64: return "RISC-V64"
            }
        }
        
        var downloadSuffix: String {
            return self.rawValue
        }
    }
    
    // MARK: - Installation Steps
    
    enum SingBoxInstallStep: String, CaseIterable {
        case idle = "空闲"
        case detectingArchitecture = "检测系统架构"
        case fetchingLatestVersion = "获取最新版本"
        case downloadingSingBox = "下载sing-box"
        case installingSingBox = "安装sing-box"
        case configuringService = "配置服务"
        case startingService = "启动服务"
        case verifyingInstallation = "验证安装"
        case completed = "安装完成"
        case failed = "安装失败"
        
        var progress: Double {
            switch self {
            case .idle: return 0.0
            case .detectingArchitecture: return 0.1
            case .fetchingLatestVersion: return 0.2
            case .downloadingSingBox: return 0.4
            case .installingSingBox: return 0.6
            case .configuringService: return 0.75
            case .startingService: return 0.85
            case .verifyingInstallation: return 0.95
            case .completed: return 1.0
            case .failed: return 0.0
            }
        }
    }
    
    // MARK: - Initialization
    
    init(sshClient: SSHClient = SSHClient()) {
        self.sshClient = sshClient
    }
    
    // MARK: - Public Methods
    
    /// 安装SingBox到指定的VPS
    func installSingBox(to vps: VPSInstance) async throws {
        isInstalling = true
        lastError = nil
        installLogs.removeAll()
        
        do {
            // 1. 检测系统架构
            updateStep(.detectingArchitecture)
            let architecture = try await detectSystemArchitecture(vps: vps)
            addLog("检测到系统架构: \(architecture.displayName)")
            updateProgress(within: .detectingArchitecture, progress: 1.0)
            
            // 2. 获取最新版本
            updateStep(.fetchingLatestVersion)
            let latestRelease = try await fetchLatestSingBoxRelease()
            addLog("获取到最新版本: \(latestRelease.tagName)")
            updateProgress(within: .fetchingLatestVersion, progress: 1.0)
            
            // 3. 下载SingBox
            updateStep(.downloadingSingBox)
            let downloadUrl = try await getDownloadUrl(for: architecture, release: latestRelease)
            addLog("开始下载: \(downloadUrl)")
            updateProgress(within: .downloadingSingBox, progress: 0.3)
            
            try await downloadSingBox(from: downloadUrl, vps: vps)
            addLog("下载完成: \(downloadUrl)")
            updateProgress(within: .downloadingSingBox, progress: 1.0)
            
            // 4. 安装SingBox
            updateStep(.installingSingBox)
            addLog("开始安装SingBox二进制文件...")
            updateProgress(within: .installingSingBox, progress: 0.2)
            
            try await installSingBoxBinary(vps: vps)
            addLog("安装完成")
            updateProgress(within: .installingSingBox, progress: 1.0)
            
            // 5. 配置服务
            updateStep(.configuringService)
            addLog("开始配置SingBox服务...")
            updateProgress(within: .configuringService, progress: 0.3)
            
            try await configureSingBoxService(vps: vps)
            addLog("服务配置完成")
            updateProgress(within: .configuringService, progress: 1.0)
            
            // 6. 启动服务
            updateStep(.startingService)
            addLog("开始启动SingBox服务...")
            updateProgress(within: .startingService, progress: 0.5)
            
            try await startSingBoxService(vps: vps)
            addLog("服务启动完成")
            updateProgress(within: .startingService, progress: 1.0)
            
            // 7. 验证安装
            updateStep(.verifyingInstallation)
            addLog("开始验证SingBox安装...")
            updateProgress(within: .verifyingInstallation, progress: 0.3)
            
            let isRunning = try await verifySingBoxInstallation(vps: vps)
            if isRunning {
                updateProgress(within: .verifyingInstallation, progress: 1.0)
                updateStep(.completed)
                addLog("SingBox安装成功并正在运行")
            } else {
                throw SingBoxInstallError.serviceNotRunning
            }
            
        } catch {
            updateStep(.failed)
            lastError = error.localizedDescription
            addLog("安装失败: \(error.localizedDescription)")
            throw error
        }
        
        isInstalling = false
    }
    
    // MARK: - Private Methods
    
    /// 检测系统架构
    private func detectSystemArchitecture(vps: VPSInstance) async throws -> SystemArchitecture {
        addLog("正在检测系统架构...")
        
        // 尝试多种检测方法
        let commands = [
            "uname -m",
            "arch",
            "dpkg --print-architecture",
            "rpm --eval '%{_arch}'"
        ]
        
        for command in commands {
            do {
                let output = try await sshClient.executeCommand(command)
                let arch = output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                
                // 映射架构名称
                let detectedArch = mapArchitecture(arch)
                if let detectedArch = detectedArch {
                    addLog("架构检测命令: \(command)")
                    addLog("检测结果: \(arch) -> \(detectedArch.displayName)")
                    return detectedArch
                }
            } catch {
                addLog("架构检测命令失败: \(command)")
                continue
            }
        }
        
        // 如果所有命令都失败，尝试检测操作系统类型
        addLog("尝试通过操作系统类型推断架构...")
        let osType = try await detectOperatingSystem(vps: vps)
        
        // 根据操作系统推断默认架构
        let defaultArch: SystemArchitecture
        switch osType {
        case "debian", "ubuntu":
            defaultArch = .amd64 // 大多数Debian/Ubuntu系统是amd64
        case "centos", "rhel", "fedora":
            defaultArch = .amd64 // 大多数CentOS/RHEL系统是amd64
        default:
            defaultArch = .amd64 // 默认使用amd64
        }
        
        addLog("使用默认架构: \(defaultArch.displayName)")
        return defaultArch
    }
    
    /// 映射架构名称
    private func mapArchitecture(_ arch: String) -> SystemArchitecture? {
        switch arch {
        case "x86_64", "amd64", "x64":
            return .amd64
        case "aarch64", "arm64", "armv8":
            return .arm64
        case "armv7l", "armv7":
            return .armv7
        case "armv6l", "armv6":
            return .armv6
        case "armv5l", "armv5":
            return .armv5
        case "mips64":
            return .mips64
        case "mips64el", "mips64le":
            return .mips64le
        case "mips", "mipsel":
            return .mips
        case "mipsle":
            return .mipsle
        case "ppc64":
            return .ppc64
        case "ppc64le":
            return .ppc64le
        case "s390x":
            return .s390x
        case "riscv64":
            return .riscv64
        default:
            return nil
        }
    }
    
    /// 检测操作系统类型
    private func detectOperatingSystem(vps: VPSInstance) async throws -> String {
        let commands = [
            ("cat /etc/os-release | grep '^ID=' | cut -d'=' -f2 | tr -d '\"'", "debian"),
            ("cat /etc/redhat-release", "centos"),
            ("cat /etc/issue", "unknown")
        ]
        
        for (command, fallback) in commands {
            do {
                let output = try await sshClient.executeCommand(command)
                let os = output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !os.isEmpty && os != fallback {
                    return os
                }
            } catch {
                continue
            }
        }
        
        return "unknown"
    }
    
    /// 获取最新版本信息
    private func fetchLatestSingBoxRelease() async throws -> SingBoxRelease {
        addLog("正在获取最新版本信息...")
        
        let url = URL(string: "https://api.github.com/repos/SagerNet/sing-box/releases/latest")!
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SingBoxInstallError.failedToFetchRelease
        }
        
        let release = try JSONDecoder().decode(SingBoxRelease.self, from: data)
        addLog("最新版本: \(release.tagName)")
        addLog("版本名称: \(release.name)")
        
        return release
    }
    
    /// 获取下载URL
    private func getDownloadUrl(for architecture: SystemArchitecture, release: SingBoxRelease) async throws -> String {
        addLog("正在查找适合的下载链接...")
        
        // 构建期望的文件名模式
        let patterns = [
            "sing-box-\(release.tagName)-\(architecture.downloadSuffix).tar.gz",
            "sing-box-\(release.tagName)-\(architecture.downloadSuffix).zip",
            "sing-box-\(release.tagName)-linux-\(architecture.downloadSuffix).tar.gz",
            "sing-box-\(release.tagName)-linux-\(architecture.downloadSuffix).zip"
        ]
        
        for pattern in patterns {
            if let asset = release.assets.first(where: { $0.name.contains(pattern) || $0.name.contains(architecture.downloadSuffix) }) {
                addLog("找到下载链接: \(asset.name)")
                return asset.browserDownloadUrl
            }
        }
        
        // 如果没有找到精确匹配，尝试模糊匹配
        if let asset = release.assets.first(where: { $0.name.contains(architecture.downloadSuffix) }) {
            addLog("找到模糊匹配的下载链接: \(asset.name)")
            return asset.browserDownloadUrl
        }
        
        throw SingBoxInstallError.noSuitableVersion(architecture: architecture.displayName)
    }
    
    /// 下载SingBox
    private func downloadSingBox(from url: String, vps: VPSInstance) async throws {
        addLog("开始下载SingBox...")
        addLog("下载地址: \(url)")
        
        // 使用wget下载，带进度显示
        let downloadCommand = "cd /tmp && wget --progress=bar:force:noscroll -O sing-box.tar.gz '\(url)'"
        
        do {
            updateProgress(within: .downloadingSingBox, progress: 0.4)
            addLog("正在下载文件...")
            
            let output = try await sshClient.executeCommand(downloadCommand)
            updateProgress(within: .downloadingSingBox, progress: 0.8)
            addLog("下载完成")
            
            // 验证文件是否存在
            let checkCommand = "ls -la /tmp/sing-box.tar.gz"
            let checkOutput = try await sshClient.executeCommand(checkCommand)
            addLog("文件信息: \(checkOutput)")
            
        } catch {
            addLog("wget下载失败，尝试使用curl...")
            updateProgress(within: .downloadingSingBox, progress: 0.5)
            
            // 备用方案：使用curl
            let curlCommand = "cd /tmp && curl -L -o sing-box.tar.gz '\(url)'"
            let output = try await sshClient.executeCommand(curlCommand)
            updateProgress(within: .downloadingSingBox, progress: 0.8)
            addLog("curl下载完成")
        }
    }
    
    /// 安装SingBox二进制文件
    private func installSingBoxBinary(vps: VPSInstance) async throws {
        addLog("正在安装SingBox二进制文件...")
        
        let commands = [
            // 解压文件
            "cd /tmp && tar -xzf sing-box.tar.gz",
            
            // 查找sing-box二进制文件
            "find /tmp -name 'sing-box' -type f -executable",
            
            // 移动到系统目录
            "sudo mv /tmp/sing-box /usr/local/bin/",
            
            // 设置权限
            "sudo chmod +x /usr/local/bin/sing-box",
            
            // 创建软链接
            "sudo ln -sf /usr/local/bin/sing-box /usr/bin/sing-box",
            
            // 清理临时文件
            "rm -f /tmp/sing-box.tar.gz",
            "rm -rf /tmp/sing-box*"
        ]
        
        for (index, command) in commands.enumerated() {
            do {
                let progress = Double(index + 1) / Double(commands.count)
                updateProgress(within: .installingSingBox, progress: 0.2 + (progress * 0.6))
                
                let output = try await sshClient.executeCommand(command)
                if !output.isEmpty {
                    addLog("命令输出: \(output)")
                }
            } catch {
                addLog("命令执行失败: \(command)")
                throw error
            }
        }
        
        // 验证安装
        updateProgress(within: .installingSingBox, progress: 0.9)
        let versionCommand = "sing-box version"
        let versionOutput = try await sshClient.executeCommand(versionCommand)
        addLog("SingBox版本: \(versionOutput)")
    }
    
        /// 配置SingBox服务
    private func configureSingBoxService(vps: VPSInstance) async throws {
        addLog("正在配置SingBox服务...")
        
        // 创建配置目录
        let createDirCommands = [
            "sudo mkdir -p /etc/sing-box",
            "sudo mkdir -p /var/log/sing-box",
            "sudo mkdir -p /var/lib/sing-box"
        ]
        
        for (index, command) in createDirCommands.enumerated() {
            let progress = Double(index + 1) / Double(createDirCommands.count)
            updateProgress(within: .configuringService, progress: 0.3 + (progress * 0.2))
            try await sshClient.executeCommand(command)
        }
        
        // 创建systemd服务文件
        updateProgress(within: .configuringService, progress: 0.6)
        let serviceContent = """
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
        """
        
        // 写入服务文件
        try await sshClient.writeFile(content: serviceContent, to: "/tmp/sing-box.service")
        updateProgress(within: .configuringService, progress: 0.8)
        
        // 安装服务文件
        let serviceCommands = [
            "sudo mv /tmp/sing-box.service /etc/systemd/system/",
            "sudo systemctl daemon-reload",
            "sudo systemctl enable sing-box"
        ]
        
        for (index, command) in serviceCommands.enumerated() {
            let progress = Double(index + 1) / Double(serviceCommands.count)
            updateProgress(within: .configuringService, progress: 0.8 + (progress * 0.2))
            try await sshClient.executeCommand(command)
        }
        
        addLog("服务配置完成")
    }
    
    /// 启动SingBox服务
    private func startSingBoxService(vps: VPSInstance) async throws {
        addLog("正在启动SingBox服务...")
        
        let startCommand = "sudo systemctl start sing-box"
        try await sshClient.executeCommand(startCommand)
        
        // 等待服务启动
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2秒
        
        addLog("服务启动命令已执行")
    }
    
    /// 验证SingBox安装
    private func verifySingBoxInstallation(vps: VPSInstance) async throws -> Bool {
        addLog("正在验证SingBox安装...")
        
        let verificationCommands = [
            ("sing-box version", "检查版本"),
            ("systemctl is-active sing-box", "检查服务状态"),
            ("systemctl is-enabled sing-box", "检查服务自启"),
            ("netstat -tlnp | grep sing-box", "检查端口监听")
        ]
        
        for (index, (command, description)) in verificationCommands.enumerated() {
            let progress = Double(index + 1) / Double(verificationCommands.count)
            updateProgress(within: .verifyingInstallation, progress: 0.3 + (progress * 0.6))
            
            do {
                let output = try await sshClient.executeCommand(command)
                addLog("\(description): \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
            } catch {
                addLog("\(description)失败: \(error.localizedDescription)")
            }
        }
        
        // 检查服务是否正在运行
        updateProgress(within: .verifyingInstallation, progress: 0.9)
        let isActiveCommand = "systemctl is-active sing-box"
        let isActiveOutput = try await sshClient.executeCommand(isActiveCommand)
        
        let isRunning = isActiveOutput.trimmingCharacters(in: .whitespacesAndNewlines) == "active"
        addLog("服务运行状态: \(isRunning ? "运行中" : "未运行")")
        
        return isRunning
    }
    
    // MARK: - Helper Methods
    
    private func updateStep(_ step: SingBoxInstallStep) {
        currentStep = step
        progress = step.progress
        addLog("步骤更新: \(step.rawValue)")
    }
    
    /// 更新当前步骤内的进度
    private func updateProgress(within step: SingBoxInstallStep, progress stepProgress: Double) {
        let stepIndex = SingBoxInstallStep.allCases.firstIndex(of: step) ?? 0
        let totalSteps = SingBoxInstallStep.allCases.count - 2 // 排除 idle 和 failed
        
        // 计算当前步骤的进度范围
        let stepStartProgress = Double(stepIndex) / Double(totalSteps)
        let stepEndProgress = Double(stepIndex + 1) / Double(totalSteps)
        let stepRange = stepEndProgress - stepStartProgress
        
        // 计算总体进度
        let overallProgress = stepStartProgress + (stepRange * stepProgress)
        
        // 更新进度，确保在合理范围内
        self.progress = min(max(overallProgress, 0.0), 1.0)
        
        addLog("进度更新: \(Int(self.progress * 100))%")
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)"
        installLogs.append(logMessage)
        print(logMessage)
    }
}

// MARK: - Errors

enum SingBoxInstallError: LocalizedError {
    case failedToFetchRelease
    case noSuitableVersion(architecture: String)
    case downloadFailed
    case installationFailed
    case serviceNotRunning
    case configurationFailed
    
    var errorDescription: String? {
        switch self {
        case .failedToFetchRelease:
            return "无法获取最新版本信息"
        case .noSuitableVersion(let architecture):
            return "没有找到适合 \(architecture) 架构的版本"
        case .downloadFailed:
            return "下载失败"
        case .installationFailed:
            return "安装失败"
        case .serviceNotRunning:
            return "服务未正常运行"
        case .configurationFailed:
            return "配置失败"
        }
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
