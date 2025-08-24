import Foundation
import SwiftUI

// MARK: - VPS Models

/// VPS 实例模型
struct VPSInstance: Identifiable, Codable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var password: String?
    var sshKeyPath: String?
    var tags: [String]
    var group: String
    var isActive: Bool
    var lastConnected: Date?
    var createdAt: Date
    var updatedAt: Date
    
    // 系统信息
    var systemInfo: SystemInfo?
    
    // 服务列表
    var services: [VPSService]
    
    init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int = 22,
        username: String,
        password: String? = nil,
        sshKeyPath: String? = nil,
        tags: [String] = [],
        group: String = "默认分组",
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.sshKeyPath = sshKeyPath
        self.tags = tags
        self.group = group
        self.isActive = isActive
        self.createdAt = Date()
        self.updatedAt = Date()
        self.services = []
    }
}

/// 系统信息
struct SystemInfo: Codable {
    let osName: String
    let osVersion: String
    let kernelVersion: String
    let cpuModel: String
    let cpuCores: Int
    let memoryTotal: Int64
    let memoryAvailable: Int64
    let diskTotal: Int64
    let diskAvailable: Int64
    let uptime: TimeInterval
    let loadAverage: [Double]
    
    var memoryUsage: Double {
        guard memoryTotal > 0 else { return 0 }
        return Double(memoryTotal - memoryAvailable) / Double(memoryTotal) * 100
    }
    
    var diskUsage: Double {
        guard diskTotal > 0 else { return 0 }
        return Double(diskTotal - diskAvailable) / Double(diskTotal) * 100
    }
}

/// VPS 服务模型
struct VPSService: Identifiable, Codable {
    let id: UUID
    var name: String
    var type: ServiceType
    var status: ServiceStatus
    var port: Int?
    var config: [String: String]
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        type: ServiceType,
        status: ServiceStatus = .stopped,
        port: Int? = nil,
        config: [String: String] = [:]
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.status = status
        self.port = port
        self.config = config
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

/// 服务类型
enum ServiceType: String, CaseIterable, Codable {
    case singbox = "sing-box"
    case xray = "Xray"
    case shadowsocks = "Shadowsocks"
    case v2ray = "V2Ray"
    case wireguard = "WireGuard"
    case wordpress = "WordPress"
    case ghost = "Ghost"
    case hugo = "Hugo"
    case nginx = "Nginx"
    case nextcloud = "Nextcloud"
    case seafile = "Seafile"
    case minio = "MinIO"
    case fail2ban = "Fail2ban"
    case ufw = "UFW"
    case adguard = "AdGuard Home"
    case docker = "Docker"
    case gitlabRunner = "GitLab Runner"
    case nodejs = "Node.js"
    case frp = "FRP"
    case custom = "Custom"
    
    var displayName: String {
        switch self {
        case .singbox: return "sing-box"
        case .xray: return "Xray"
        case .shadowsocks: return "Shadowsocks"
        case .v2ray: return "V2Ray"
        case .wireguard: return "WireGuard"
        case .wordpress: return "WordPress"
        case .ghost: return "Ghost"
        case .hugo: return "Hugo"
        case .nginx: return "Nginx"
        case .nextcloud: return "Nextcloud"
        case .seafile: return "Seafile"
        case .minio: return "MinIO"
        case .fail2ban: return "Fail2ban"
        case .ufw: return "UFW"
        case .adguard: return "AdGuard Home"
        case .docker: return "Docker"
        case .gitlabRunner: return "GitLab Runner"
        case .nodejs: return "Node.js"
        case .frp: return "FRP"
        case .custom: return "自定义服务"
        }
    }
    
    var category: ServiceCategory {
        switch self {
        case .singbox, .xray, .shadowsocks, .v2ray, .wireguard:
            return .proxy
        case .wordpress, .ghost, .hugo, .nginx:
            return .website
        case .nextcloud, .seafile, .minio:
            return .storage
        case .fail2ban, .ufw, .adguard:
            return .security
        case .docker, .gitlabRunner, .nodejs:
            return .devops
        case .frp:
            return .proxy
        case .custom:
            return .custom
        }
    }
    
    var icon: String {
        switch self {
        case .singbox, .xray, .shadowsocks, .v2ray, .wireguard:
            return "network"
        case .wordpress, .ghost, .hugo:
            return "doc.text"
        case .nginx:
            return "server.rack"
        case .nextcloud, .seafile, .minio:
            return "externaldrive"
        case .fail2ban, .ufw:
            return "shield"
        case .adguard:
            return "eye.slash"
        case .docker:
            return "cube"
        case .gitlabRunner, .nodejs:
            return "terminal"
        case .frp:
            return "network"
        case .custom:
            return "gear"
        }
    }
    
    var color: Color {
        switch self {
        case .singbox, .xray, .shadowsocks, .v2ray, .wireguard:
            return .blue
        case .wordpress, .ghost, .hugo:
            return .green
        case .nginx:
            return .orange
        case .nextcloud, .seafile, .minio:
            return .purple
        case .fail2ban, .ufw:
            return .red
        case .adguard:
            return .indigo
        case .docker:
            return .cyan
        case .gitlabRunner, .nodejs:
            return .mint
        case .frp:
            return .blue
        case .custom:
            return .gray
        }
    }
}

/// 服务分类
enum ServiceCategory: String, CaseIterable, Codable {
    case devops = "开发运维"
    case proxy = "网络服务"
    case website = "建站服务"
    case storage = "存储服务"
    case security = "安全服务"
    case custom = "自定义"
    
    var icon: String {
        switch self {
        case .proxy: return "network"
        case .website: return "doc.text"
        case .storage: return "externaldrive"
        case .security: return "shield"
        case .devops: return "terminal"
        case .custom: return "gear"
        }
    }
}

/// 服务状态
enum ServiceStatus: String, CaseIterable, Codable {
    case running = "running"
    case stopped = "stopped"
    case starting = "starting"
    case stopping = "stopping"
    case error = "error"
    case installing = "installing"
    
    var displayName: String {
        switch self {
        case .running: return "运行中"
        case .stopped: return "已停止"
        case .starting: return "启动中"
        case .stopping: return "停止中"
        case .error: return "错误"
        case .installing: return "安装中"
        }
    }
    
    var color: Color {
        switch self {
        case .running: return .green
        case .stopped: return .gray
        case .starting, .stopping, .installing: return .orange
        case .error: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .running: return "play.circle.fill"
        case .stopped: return "stop.circle"
        case .starting, .installing: return "arrow.clockwise.circle"
        case .stopping: return "pause.circle"
        case .error: return "exclamationmark.circle.fill"
        }
    }
}

/// 部署模板
struct DeploymentTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var serviceType: ServiceType
    var category: ServiceCategory
    var commands: [String]
    var configTemplate: String
    var serviceTemplate: String
    var variables: [TemplateVariable]
    var tags: [String]
    var rating: Double
    var downloads: Int
    var isOfficial: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        serviceType: ServiceType,
        category: ServiceCategory,
        commands: [String],
        configTemplate: String,
        serviceTemplate: String = "",
        variables: [TemplateVariable] = [],
        tags: [String] = [],
        rating: Double = Double.random(in: 4...5),
        downloads: Int = Int.random(in: 1000...5000),
        isOfficial: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.serviceType = serviceType
        self.category = category
        self.commands = commands
        self.configTemplate = configTemplate
        self.serviceTemplate = serviceTemplate
        self.variables = variables
        self.tags = tags
        self.rating = rating
        self.downloads = downloads
        self.isOfficial = isOfficial
    }
}

/// 模板变量
struct TemplateVariable: Identifiable, Codable {
    let id: UUID
    var name: String
    var description: String
    var type: VariableType
    var defaultValue: String?
    var required: Bool
    var options: [String]?
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        type: VariableType,
        defaultValue: String? = nil,
        required: Bool = false,
        options: [String]? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.defaultValue = defaultValue
        self.required = required
        self.options = options
    }
}

/// 变量类型
enum VariableType: String, CaseIterable, Codable {
    case string = "string"
    case number = "number"
    case boolean = "boolean"
    case select = "select"
    case password = "password"
    
    var displayName: String {
        switch self {
        case .string: return "文本"
        case .number: return "数字"
        case .boolean: return "布尔值"
        case .select: return "选择"
        case .password: return "密码"
        }
    }
}

/// 部署任务
struct DeploymentTask: Identifiable, Codable {
    let id: UUID
    var vpsId: UUID
    var templateId: UUID?
    var customCommands: [String]?
    var variables: [String: String]
    var status: DeploymentStatus
    var progress: Double
    var logs: [DeploymentLog]
    var startedAt: Date?
    var completedAt: Date?
    var error: String?
    var lastCommandResult: String? // 最新命令的执行结果
    
    init(
        id: UUID = UUID(),
        vpsId: UUID,
        templateId: UUID? = nil,
        customCommands: [String]? = nil,
        variables: [String: String] = [:],
        status: DeploymentStatus = .pending
    ) {
        self.id = id
        self.vpsId = vpsId
        self.templateId = templateId
        self.customCommands = customCommands
        self.variables = variables
        self.status = status
        self.progress = 0
        self.logs = []
        self.lastCommandResult = nil
    }
}

/// 部署状态
enum DeploymentStatus: String, CaseIterable, Codable {
    case pending = "pending"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return "等待中"
        case .running: return "执行中"
        case .completed: return "已完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .gray
        case .running: return .blue
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .orange
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .running: return "play.circle"
        case .completed: return "checkmark.circle"
        case .failed: return "xmark.circle"
        case .cancelled: return "stop.circle"
        }
    }
}

/// 部署日志
struct DeploymentLog: Identifiable, Codable {
    let id: UUID
    var timestamp: Date
    var level: LogLevel
    var message: String
    var command: String?
    var output: String?
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel,
        message: String,
        command: String? = nil,
        output: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.message = message
        self.command = command
        self.output = output
    }
}

/// 日志级别
enum LogLevel: String, CaseIterable, Codable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case success = "success"
    
    var displayName: String {
        switch self {
        case .info: return "信息"
        case .warning: return "警告"
        case .error: return "错误"
        case .success: return "成功"
        }
    }
    
    var color: Color {
        switch self {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.circle"
        case .success: return "checkmark.circle"
        }
    }
}

/// 连接测试结果
struct ConnectionTestResult: Codable {
    var pingSuccess: Bool
    var pingLatency: Double?
    var sshSuccess: Bool
    var sshError: String?
    var systemInfo: SystemInfo?
    var timestamp: Date
    
    init(pingSuccess: Bool = false, pingLatency: Double? = nil, sshSuccess: Bool = false, sshError: String? = nil, systemInfo: SystemInfo? = nil, timestamp: Date = Date()) {
        self.pingSuccess = pingSuccess
        self.pingLatency = pingLatency
        self.sshSuccess = sshSuccess
        self.sshError = sshError
        self.systemInfo = systemInfo
        self.timestamp = timestamp
    }
    
    var isConnected: Bool {
        return pingSuccess && sshSuccess
    }
}

/// 监控数据
struct MonitoringData: Codable {
    var timestamp: Date
    var cpuUsage: Double
    var memoryUsage: Double
    var diskUsage: Double
    var networkIn: Int64
    var networkOut: Int64
    var loadAverage: [Double]
}

// MARK: - Extensions

extension VPSInstance {
    var displayName: String {
        return name.isEmpty ? host : name
    }
    
    var connectionString: String {
        return "\(username)@\(host):\(port)"
    }
    
    var statusColor: Color {
        guard let lastConnected = lastConnected else { return .gray }
        let timeSinceLastConnection = Date().timeIntervalSince(lastConnected)
        if timeSinceLastConnection < 300 { // 5 minutes
            return .green
        } else if timeSinceLastConnection < 3600 { // 1 hour
            return .orange
        } else {
            return .red
        }
    }
}

extension VPSService {
    var displayName: String {
        return name.isEmpty ? type.displayName : name
    }
}
