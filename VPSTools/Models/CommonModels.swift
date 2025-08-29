import Foundation
import SwiftUI

// MARK: - Common Models and Utilities

/// Validation error enumeration
enum ValidationError: LocalizedError, Equatable {
    case missingField(String)
    case invalidPort(String)
    case invalidServer(String)
    case invalidAddress(String)
    case invalidConfiguration(String)
    case invalidURL(String)
    case invalidFormat(String)
    case invalidType(String)
    case invalidTag(String)
    case invalidReference(String)
    
    var errorDescription: String? {
        switch self {
        case .missingField(let message):
            return "Missing field: \(message)"
        case .invalidPort(let message):
            return "Invalid port: \(message)"
        case .invalidServer(let message):
            return "Invalid server: \(message)"
        case .invalidAddress(let message):
            return "Invalid address: \(message)"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .invalidURL(let message):
            return "Invalid URL: \(message)"
        case .invalidFormat(let message):
            return "Invalid format: \(message)"
        case .invalidType(let message):
            return "Invalid type: \(message)"
        case .invalidTag(let message):
            return "Invalid tag: \(message)"
        case .invalidReference(let message):
            return "Invalid reference: \(message)"
        }
    }
}

/// Application configuration model - Libbox compatible
struct AppConfig: Codable {
    // Log configuration
    var log: LogConfig = LogConfig()
    
    // DNS configuration
    var dns: DNSConfig = DNSConfig()
    
    // Inbounds configuration
    var inbounds: [InboundConfig] = []
    
    // Outbounds configuration
    var outbounds: [OutboundConfig] = []
    
    // Route configuration
    var route: RouteConfig = RouteConfig()
    
    /// Validates the entire application configuration
    func validate() throws {
        // Validate inbounds
        for inbound in inbounds {
            try inbound.validate()
        }
        
        // Validate outbounds
        for outbound in outbounds {
            try outbound.validate()
        }
        
        // Validate route
        try route.validate()
        
        // Validate DNS
        try dns.validate()
    }
    
    /// Gets the active outbounds (enabled ones)
    var activeOutbounds: [OutboundConfig] {
        return outbounds.filter { outbound in
            // Add logic to determine if outbound is active
            return true // Placeholder
        }
    }
}

/// Log configuration
struct LogConfig: Codable {
    var level: String = "info"
    var timestamp: Bool = true
    var output: String = "stdout"
    
    /// Validates the log configuration
    func validate() throws {
        let validLevels = ["debug", "info", "warning", "error"]
        guard validLevels.contains(level) else {
            throw ValidationError.invalidConfiguration("Invalid log level: \(level)")
        }
    }
}

/// DNS configuration - Libbox compatible
struct DNSConfig: Codable {
    var servers: [DNSServer] = []
    var rules: [DNSRule] = []
    var fakeip: FakeIPConfig?
    var strategy: String = "prefer_ipv4"
    
    /// Validates the DNS configuration
    func validate() throws {
        // Validate servers
        for server in servers {
            try server.validate()
        }
        
        // Validate rules
        for rule in rules {
            try rule.validate()
        }
        
        // Validate fakeip if present
        if let fakeip = fakeip {
            try fakeip.validate()
        }
    }
    
    struct DNSServer: Codable {
        var tag: String
        var address: String
        var detour: String?
        
        /// Validates the DNS server
        func validate() throws {
            guard !tag.isEmpty else {
                throw ValidationError.missingField("DNS server tag cannot be empty")
            }
            guard !address.isEmpty else {
                throw ValidationError.missingField("DNS server address cannot be empty")
            }
        }
    }
    
    struct DNSRule: Codable {
        var ruleSet: String?
        var server: String?
        var disableCache: Bool?
        var outbound: String?
        
        enum CodingKeys: String, CodingKey {
            case ruleSet = "rule_set"
            case server, disableCache = "disable_cache", outbound
        }
        
        /// Validates the DNS rule
        func validate() throws {
            // At least one of ruleSet or outbound should be present
            if ruleSet == nil && outbound == nil {
                throw ValidationError.missingField("DNS rule must have either rule_set or outbound")
            }
        }
    }
    
    struct FakeIPConfig: Codable {
        var enabled: Bool = true
        var inet4Range: String = "198.18.0.0/15"
        var inet6Range: String = "fc00::/18"
        
        enum CodingKeys: String, CodingKey {
            case enabled, inet4Range = "inet4_range", inet6Range = "inet6_range"
        }
        
        /// Validates the fake IP configuration
        func validate() throws {
            // Basic CIDR validation
            if !inet4Range.contains("/") || !inet6Range.contains("/") {
                throw ValidationError.invalidConfiguration("Invalid CIDR format for fake IP ranges")
            }
        }
    }
}

/// Inbound configuration - Libbox compatible
struct InboundConfig: Codable {
    var type: String
    var tag: String
    var interfaceName: String?
    var address: [String]?
    var autoRoute: Bool?
    var strictRoute: Bool?
    var sniff: Bool?
    var sniffOverrideDestination: Bool?
    var listen: String?
    var listenPort: UInt16?
    
    enum CodingKeys: String, CodingKey {
        case type, tag
        case interfaceName = "interface_name"
        case address, autoRoute = "auto_route"
        case strictRoute = "strict_route"
        case sniff, sniffOverrideDestination = "sniff_override_destination"
        case listen, listenPort = "listen_port"
    }
    
    /// Validates the inbound configuration
    func validate() throws {
        guard !type.isEmpty else {
            throw ValidationError.missingField("Inbound type cannot be empty")
        }
        
        guard !tag.isEmpty else {
            throw ValidationError.missingField("Inbound tag cannot be empty")
        }
        
        // Validate listen port if present
        if let port = listenPort {
            guard port > 0 && port <= 65535 else {
                throw ValidationError.invalidPort("Listen port must be between 1 and 65535")
            }
        }
    }
}

/// Outbound configuration - Libbox compatible
struct OutboundConfig: Codable {
    var type: String
    var tag: String
    var server: String?
    var serverPort: UInt16?
    
    // Protocol-specific configurations
    var uuid: String?
    var password: String?
    var method: String?
    var alterId: UInt16?
    var security: String?
    var flow: String?
    var packetEncoding: String?
    var congestionControl: String?
    var udpRelayMode: String?
    var udpOverStream: Bool?
    var zeroRttHandshake: Bool?
    var heartbeat: String?
    var network: String?
    var upMbps: Int?
    var downMbps: Int?
    
    // TLS configuration
    var tls: TLSConfig?
    
    // Transport configuration
    var transport: TransportConfig?
    
    // Multiplex configuration
    var multiplex: MultiplexConfig?
    
    // Reality configuration
    var reality: RealityConfig?
    
    // UTLS configuration
    var utls: UTLSConfig?
    
    // Outbound selector
    var outbounds: [String]?
    var interruptExistConnections: Bool?
    
    enum CodingKeys: String, CodingKey {
        case type, tag, server, serverPort = "server_port"
        case uuid, password, method, alterId = "alter_id"
        case security, flow, packetEncoding = "packet_encoding"
        case congestionControl = "congestion_control"
        case udpRelayMode = "udp_relay_mode"
        case udpOverStream = "udp_over_stream"
        case zeroRttHandshake = "zero_rtt_handshake"
        case heartbeat, network, upMbps = "up_mbps", downMbps = "down_mbps"
        case tls, transport, multiplex, reality, utls
        case outbounds, interruptExistConnections = "interrupt_exist_connections"
    }
    
    /// Validates the outbound configuration
    func validate() throws {
        guard !type.isEmpty else {
            throw ValidationError.missingField("Outbound type cannot be empty")
        }
        
        guard !tag.isEmpty else {
            throw ValidationError.missingField("Outbound tag cannot be empty")
        }
        
        // Validate server-based outbounds
        if type != "direct" && type != "block" && type != "dns" && type != "selector" {
            guard let server = server, !server.isEmpty else {
                throw ValidationError.missingField("Server address is required for \(type)")
            }
            
            guard let port = serverPort, port > 0 && port <= 65535 else {
                throw ValidationError.invalidPort("Server port must be between 1 and 65535")
            }
        }
        
        // Type-specific validation
        switch type {
        case "shadowsocks":
            guard let method = method, !method.isEmpty else {
                throw ValidationError.missingField("Encryption method is required for Shadowsocks")
            }
            guard let password = password, !password.isEmpty else {
                throw ValidationError.missingField("Password is required for Shadowsocks")
            }
        case "vmess", "vless":
            guard let uuid = uuid, !uuid.isEmpty else {
                throw ValidationError.missingField("UUID is required for \(type)")
            }
            // Basic UUID format validation
            guard UUID(uuidString: uuid) != nil else {
                throw ValidationError.invalidFormat("Invalid UUID format for \(type)")
            }
        case "trojan":
            guard let password = password, !password.isEmpty else {
                throw ValidationError.missingField("Password is required for Trojan")
            }
        case "tuic":
            guard let uuid = uuid, !uuid.isEmpty else {
                throw ValidationError.missingField("UUID is required for TUIC")
            }
            guard let password = password, !password.isEmpty else {
                throw ValidationError.missingField("Password is required for TUIC")
            }
        case "hysteria2":
            guard let password = password, !password.isEmpty else {
                throw ValidationError.missingField("Password is required for Hysteria2")
            }
        case "selector":
            guard let outbounds = outbounds, !outbounds.isEmpty else {
                throw ValidationError.missingField("Outbounds list is required for selector")
            }
        case "direct", "block", "dns":
            // No additional validation needed
            break
        default:
            // For other types, basic validation is sufficient
            break
        }
    }
}

/// TLS configuration
struct TLSConfig: Codable {
    var enabled: Bool = true
    var serverName: String?
    var insecure: Bool = false
    var alpn: [String]?
    var publicKey: String?
    var shortId: String?
    
    enum CodingKeys: String, CodingKey {
        case enabled, serverName = "server_name", insecure, alpn
        case publicKey = "public_key", shortId = "short_id"
    }
}

/// Transport configuration
struct TransportConfig: Codable {
    var type: String?
    var host: String?
    var path: String?
    var method: String?
    var headers: [String: [String]]?
}

/// Multiplex configuration
struct MultiplexConfig: Codable {
    var enabled: Bool = true
    var `protocol`: String = "h2mux"
    var maxConnections: Int = 1
    var minStreams: Int = 4
    var padding: Bool = true
    var brutal: BrutalConfig?
    
    enum CodingKeys: String, CodingKey {
        case enabled, `protocol`, maxConnections = "max_connections"
        case minStreams = "min_streams", padding, brutal
    }
    
    struct BrutalConfig: Codable {
        var enabled: Bool = true
        var upMbps: Int = 50
        var downMbps: Int = 100
        
        enum CodingKeys: String, CodingKey {
            case enabled, upMbps = "up_mbps", downMbps = "down_mbps"
        }
    }
}

/// Reality configuration
struct RealityConfig: Codable {
    var enabled: Bool = true
    var publicKey: String
    var shortId: String
    
    enum CodingKeys: String, CodingKey {
        case enabled, publicKey = "public_key", shortId = "short_id"
    }
}

/// UTLS configuration
struct UTLSConfig: Codable {
    var enabled: Bool = true
    var fingerprint: String = "chrome"
}

/// Route configuration - Libbox compatible
struct RouteConfig: Codable {
    var rules: [RouteRule] = []
    var ruleSet: [RuleSet] = []
    var final: String = "Proxy"
    var autoDetectInterface: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case rules, ruleSet = "rule_set", final, autoDetectInterface = "auto_detect_interface"
    }
    
    /// Validates the route configuration
    func validate() throws {
        // Validate rules
        for rule in rules {
            try rule.validate()
        }
        
        // Validate rule sets
        for ruleSet in ruleSet {
            try ruleSet.validate()
        }
        
        guard !final.isEmpty else {
            throw ValidationError.missingField("Final outbound cannot be empty")
        }
    }
    
    struct RouteRule: Codable {
        var type: String?
        var mode: String?
        var rules: [RouteRule]?
        var `protocol`: String?
        var port: Int?
        var outbound: String?
        var ruleSet: String?
        var ipIsPrivate: Bool?
        
        enum CodingKeys: String, CodingKey {
            case type, mode, rules, `protocol`, port, outbound
            case ruleSet = "rule_set", ipIsPrivate = "ip_is_private"
        }
        
        /// Validates the route rule
        func validate() throws {
            // Basic validation - at least one condition should be present
            if `protocol` == nil && port == nil && ruleSet == nil && ipIsPrivate == nil {
                throw ValidationError.missingField("Route rule must have at least one condition")
            }
            
            // Validate nested rules if present
            if let rules = rules {
                for rule in rules {
                    try rule.validate()
                }
            }
        }
    }
    
    struct RuleSet: Codable {
        var type: String
        var tag: String
        var format: String = "binary"
        var url: String?
        var path: String?
        
        /// Validates the rule set
        func validate() throws {
            guard !type.isEmpty else {
                throw ValidationError.missingField("Rule set type cannot be empty")
            }
            
            guard !tag.isEmpty else {
                throw ValidationError.missingField("Rule set tag cannot be empty")
            }
            
            // Either url or path should be present
            if url == nil && path == nil {
                throw ValidationError.missingField("Rule set must have either URL or path")
            }
        }
    }
}



/// Application theme enumeration
enum AppTheme: String, Codable, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    /// Gets the display name for the theme
    var displayName: String {
        switch self {
        case .light:
            return "浅色"
        case .dark:
            return "深色"
        case .system:
            return "跟随系统"
        }
    }
}



/// Rule type enumeration
enum RuleType: String, Codable, CaseIterable {
    case domain = "domain"
    case domainSuffix = "domain_suffix"
    case domainKeyword = "domain_keyword"
    case ipCIDR = "ip_cidr"
    case geoIP = "geoip"
    case geoSite = "geosite"
    case port = "port"
    case processName = "process_name"
    
    /// Gets the display name for the rule type
    var displayName: String {
        switch self {
        case .domain:
            return "域名"
        case .domainSuffix:
            return "域名后缀"
        case .domainKeyword:
            return "域名关键词"
        case .ipCIDR:
            return "IP CIDR"
        case .geoIP:
            return "地理位置 IP"
        case .geoSite:
            return "地理位置站点"
        case .port:
            return "端口"
        case .processName:
            return "进程名"
        }
    }
    
    /// Gets the placeholder text for the rule type
    var placeholder: String {
        switch self {
        case .domain:
            return "example.com"
        case .domainSuffix:
            return ".google.com"
        case .domainKeyword:
            return "google"
        case .ipCIDR:
            return "192.168.1.0/24"
        case .geoIP:
            return "CN"
        case .geoSite:
            return "google"
        case .port:
            return "80,443"
        case .processName:
            return "chrome.exe"
        }
    }
}

/// Subscription configuration
struct Subscription: Codable, Identifiable {
    let id = UUID()
    var name: String
    var url: String
    var updateInterval: TimeInterval = 86400 // 24 hours
    var lastUpdate: Date?
    var isEnabled: Bool = true
    var userAgent: String?
    var customHeaders: [String: String]?
    var nodeCount: Int = 0
    var lastError: String?
    
    private enum CodingKeys: String, CodingKey {
        case name, url, updateInterval, lastUpdate, isEnabled, userAgent, customHeaders, nodeCount, lastError
    }
    
    init(name: String, url: String) {
        self.name = name
        self.url = url
    }
    
    /// Validates the subscription
    func validate() throws {
        guard !name.isEmpty else {
            throw ValidationError.missingField("Subscription name cannot be empty")
        }
        
        guard !url.isEmpty else {
            throw ValidationError.missingField("Subscription URL cannot be empty")
        }
        
        guard URL(string: url) != nil else {
            throw ValidationError.invalidConfiguration("Invalid subscription URL")
        }
        
        guard updateInterval > 0 else {
            throw ValidationError.invalidConfiguration("Update interval must be greater than 0")
        }
    }
    
    /// Checks if the subscription needs to be updated
    var needsUpdate: Bool {
        guard let lastUpdate = lastUpdate else { return true }
        return Date().timeIntervalSince(lastUpdate) >= updateInterval
    }
    
    /// Gets the next update time
    var nextUpdateTime: Date? {
        guard let lastUpdate = lastUpdate else { return nil }
        return lastUpdate.addingTimeInterval(updateInterval)
    }
    
    /// Gets formatted last update time
    var formattedLastUpdate: String {
        guard let lastUpdate = lastUpdate else { return "从未更新" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh-CN")
        return formatter.localizedString(for: lastUpdate, relativeTo: Date())
    }
    
    /// Gets formatted next update time
    var formattedNextUpdate: String {
        guard let nextUpdate = nextUpdateTime else { return "N/A" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh-CN")
        return formatter.localizedString(for: nextUpdate, relativeTo: Date())
    }
}

/// Configuration source enumeration
enum ConfigSource: String, CaseIterable {
    case file = "file"
    case url = "url"
    case clipboard = "clipboard"
    case qrCode = "qr_code"
    
    /// Gets the display name for the config source
    var displayName: String {
        switch self {
        case .file:
            return "文件"
        case .url:
            return "URL"
        case .clipboard:
            return "剪贴板"
        case .qrCode:
            return "二维码"
        }
    }
}

/// Configuration format enumeration
enum ConfigFormat: String, CaseIterable {
    case json = "json"
    case yaml = "yaml"
    case singBox = "sing-box"
    case clash = "clash"
    case v2ray = "v2ray"
    
    /// Gets the display name for the config format
    var displayName: String {
        switch self {
        case .json:
            return "JSON"
        case .yaml:
            return "YAML"
        case .singBox:
            return "sing-box"
        case .clash:
            return "Clash"
        case .v2ray:
            return "V2Ray"
        }
    }
    
    /// Gets the file extension for the config format
    var fileExtension: String {
        switch self {
        case .json, .singBox, .clash, .v2ray:
            return "json"
        case .yaml:
            return "yaml"
        }
    }
}

// MARK: - System Information Models



// MARK: - Network Models

/// Network status information
struct NetworkStatus: Codable {
    var isConnected: Bool = false
    var publicIP: String?
    var dnsWorking: Bool = false
    var targetPortOpen: Bool = false
    var lastCheck: Date = Date()
    var latency: TimeInterval?
    var connectionType: ConnectionType = .unknown
    
    /// Gets formatted latency
    var formattedLatency: String {
        guard let latency = latency else { return "N/A" }
        return String(format: "%.0f ms", latency * 1000)
    }
    
    /// Gets the overall status
    var overallStatus: NetworkStatusLevel {
        if !isConnected {
            return .disconnected
        } else if !dnsWorking || !targetPortOpen {
            return .limited
        } else {
            return .connected
        }
    }
}

/// Connection type enumeration
enum ConnectionType: String, Codable {
    case unknown = "unknown"
    case wifi = "wifi"
    case cellular = "cellular"
    case ethernet = "ethernet"
    case vpn = "vpn"
    
    /// Gets the display name for the connection type
    var displayName: String {
        switch self {
        case .unknown:
            return "未知"
        case .wifi:
            return "Wi-Fi"
        case .cellular:
            return "蜂窝网络"
        case .ethernet:
            return "以太网"
        case .vpn:
            return "VPN"
        }
    }
    
    /// Gets the system image name for the connection type
    var systemImageName: String {
        switch self {
        case .unknown:
            return "questionmark.circle"
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .ethernet:
            return "cable.connector"
        case .vpn:
            return "lock.shield"
        }
    }
}

/// Network status level enumeration
enum NetworkStatusLevel: String, Codable {
    case connected = "connected"
    case limited = "limited"
    case disconnected = "disconnected"
    
    /// Gets the display name for the status level
    var displayName: String {
        switch self {
        case .connected:
            return "已连接"
        case .limited:
            return "受限连接"
        case .disconnected:
            return "未连接"
        }
    }
    
    /// Gets the color for the status level
    var color: Color {
        switch self {
        case .connected:
            return .green
        case .limited:
            return .orange
        case .disconnected:
            return .red
        }
    }
    
    /// Gets the system image name for the status level
    var systemImageName: String {
        switch self {
        case .connected:
            return "checkmark.circle.fill"
        case .limited:
            return "exclamationmark.triangle.fill"
        case .disconnected:
            return "xmark.circle.fill"
        }
    }
}

// MARK: - Client Configuration Models

/// 客户端配置信息
struct ClientConfiguration: Identifiable, Codable {
    let id: UUID
    let deploymentTaskId: UUID
    let vpsId: UUID
    let protocolType: String
    let serverAddress: String
    let port: Int
    let password: String?
    let uuid: String?
    let method: String?
    let transport: ClientTransportConfig?
    let tls: ClientTLSConfig?
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        deploymentTaskId: UUID,
        vpsId: UUID,
        protocolType: String,
        serverAddress: String,
        port: Int,
        password: String? = nil,
        uuid: String? = nil,
        method: String? = nil,
        transport: ClientTransportConfig? = nil,
        tls: ClientTLSConfig? = nil
    ) {
        self.id = id
        self.deploymentTaskId = deploymentTaskId
        self.vpsId = vpsId
        self.protocolType = protocolType
        self.serverAddress = serverAddress
        self.port = port
        self.password = password
        self.uuid = uuid
        self.method = method
        self.transport = transport
        self.tls = tls
        self.createdAt = Date()
    }
}

/// 客户端传输配置
struct ClientTransportConfig: Codable {
    let type: String
    let path: String?
    let host: String?
    let headers: [String: String]?
    let serviceName: String?
    let idleTimeout: String?
    let pingTimeout: String?
    let permitWithoutStream: Bool?
    
    init(
        type: String,
        path: String? = nil,
        host: String? = nil,
        headers: [String: String]? = nil,
        serviceName: String? = nil,
        idleTimeout: String? = nil,
        pingTimeout: String? = nil,
        permitWithoutStream: Bool? = nil
    ) {
        self.type = type
        self.path = path
        self.host = host
        self.headers = headers
        self.serviceName = serviceName
        self.idleTimeout = idleTimeout
        self.pingTimeout = pingTimeout
        self.permitWithoutStream = permitWithoutStream
    }
}

/// 客户端TLS配置
struct ClientTLSConfig: Codable {
    let enabled: Bool
    let serverName: String?
    let allowInsecure: Bool
    let alpn: [String]?
    let certificatePath: String?
    let keyPath: String?
    
    init(
        enabled: Bool,
        serverName: String? = nil,
        allowInsecure: Bool = false,
        alpn: [String]? = nil,
        certificatePath: String? = nil,
        keyPath: String? = nil
    ) {
        self.enabled = enabled
        self.serverName = serverName
        self.allowInsecure = allowInsecure
        self.alpn = alpn
        self.certificatePath = certificatePath
        self.keyPath = keyPath
    }
}

/// 客户端配置格式
enum ClientConfigFormat: String, CaseIterable, Codable {
    case singBox = "sing-box"
    case clash = "clash"
    case v2ray = "v2ray"
    
    var displayName: String {
        switch self {
        case .singBox: return "sing-box"
        case .clash: return "Clash"
        case .v2ray: return "V2Ray"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .singBox, .clash, .v2ray:
            return "json"
        }
    }
    
    var mimeType: String {
        return "application/json"
    }
}

/// 协议类型
enum ProtocolType: String, CaseIterable, Codable {
    case shadowsocks = "shadowsocks"
    case vmess = "vmess"
    case vless = "vless"
    case trojan = "trojan"
    case hysteria = "hysteria"
    case hysteria2 = "hysteria2"
    case tuic = "tuic"
    case naive = "naive"
    case shadowtls = "shadowtls"
    
    var displayName: String {
        switch self {
        case .shadowsocks: return "Shadowsocks"
        case .vmess: return "VMess"
        case .vless: return "VLESS"
        case .trojan: return "Trojan"
        case .hysteria: return "Hysteria"
        case .hysteria2: return "Hysteria2"
        case .tuic: return "TUIC"
        case .naive: return "Naive"
        case .shadowtls: return "ShadowTLS"
        }
    }
    
    var urlScheme: String {
        switch self {
        case .shadowsocks: return "ss"
        case .vmess: return "vmess"
        case .vless: return "vless"
        case .trojan: return "trojan"
        case .hysteria: return "hysteria"
        case .hysteria2: return "hysteria2"
        case .tuic: return "tuic"
        case .naive: return "naive"
        case .shadowtls: return "shadowtls"
        }
    }
}

/// 客户端应用类型
enum ClientAppType: String, CaseIterable, Codable {
    case clash = "clash"
    case shadowrocket = "shadowrocket"
    case v2rayNG = "v2rayng"
    case singBox = "sing-box"
    case clashForWindows = "clash_for_windows"
    case clashX = "clashx"
    case v2rayU = "v2rayu"
    case quantumultX = "quantumult_x"
    case surge = "surge"
    case loon = "loon"
    case stash = "stash"
    case hiddify = "hiddify"
    
    var displayName: String {
        switch self {
        case .clash: return "Clash"
        case .shadowrocket: return "Shadowrocket"
        case .v2rayNG: return "V2rayNG"
        case .singBox: return "sing-box"
        case .clashForWindows: return "Clash for Windows"
        case .clashX: return "ClashX"
        case .v2rayU: return "V2rayU"
        case .quantumultX: return "Quantumult X"
        case .surge: return "Surge"
        case .loon: return "Loon"
        case .stash: return "Stash"
        case .hiddify: return "Hiddify"
        }
    }
    
    var supportedFormats: [ClientConfigFormat] {
        switch self {
        case .clash, .clashForWindows, .clashX, .stash:
            return [.clash]
        case .shadowrocket:
            return [.singBox, .clash, .v2ray]
        case .v2rayNG, .v2rayU:
            return [.v2ray, .singBox]
        case .singBox:
            return [.singBox]
        case .quantumultX:
            return [.singBox, .clash, .v2ray]
        case .surge:
            return [.singBox, .clash, .v2ray]
        case .loon:
            return [.singBox, .clash, .v2ray]
        case .hiddify:
            return [.clash, .singBox, .v2ray]
        }
    }
    
    var supportedProtocols: [ProtocolType] {
        switch self {
        case .clash, .clashForWindows, .clashX, .stash:
            return [.shadowsocks, .vmess, .vless, .trojan, .hysteria, .hysteria2, .tuic, .naive, .shadowtls]
        case .shadowrocket:
            return [.shadowsocks, .vmess, .vless, .trojan, .hysteria, .hysteria2, .tuic, .naive, .shadowtls]
        case .v2rayNG, .v2rayU:
            return [.shadowsocks, .vmess, .vless, .trojan]
        case .singBox:
            return [.shadowsocks, .vmess, .vless, .trojan, .hysteria, .hysteria2, .tuic, .naive, .shadowtls]
        case .quantumultX:
            return [.shadowsocks, .vmess, .vless, .trojan, .hysteria, .hysteria2, .tuic, .naive, .shadowtls]
        case .surge:
            return [.shadowsocks, .vmess, .vless, .trojan, .hysteria, .hysteria2, .tuic, .naive, .shadowtls]
        case .loon:
            return [.shadowsocks, .vmess, .vless, .trojan, .hysteria, .hysteria2, .tuic, .naive, .shadowtls]
        case .hiddify:
            return [.shadowsocks, .vmess, .vless, .trojan, .hysteria, .hysteria2, .tuic, .naive, .shadowtls]
        }
    }
}
