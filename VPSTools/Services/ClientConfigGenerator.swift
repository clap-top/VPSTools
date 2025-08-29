import Foundation
import Combine

// MARK: - Client Configuration Generator Service

/// 客户端配置生成服务
@MainActor
class ClientConfigGenerator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var clientConfigurations: [ClientConfiguration] = []
    @Published var isLoading: Bool = false
    @Published var lastError: String?
    
    // MARK: - Private Properties
    
    private let vpsManager: VPSManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(vpsManager: VPSManager) {
        self.vpsManager = vpsManager
        loadClientConfigurations()
    }
    
    // MARK: - Public Methods
    
    /// 从部署任务生成客户端配置
    func generateClientConfiguration(from deploymentTask: DeploymentTask) async throws -> ClientConfiguration {
        isLoading = true
        defer { isLoading = false }
        
        // 获取 VPS 实例
        guard let vps = vpsManager.vpsInstances.first(where: { $0.id == deploymentTask.vpsId }) else {
            throw ClientConfigGeneratorError.vpsNotFound
        }
        
        // 解析部署变量
        let config = try parseDeploymentVariables(deploymentTask.variables, vps: vps)
        
        // 创建客户端配置
        let clientConfig = ClientConfiguration(
            deploymentTaskId: deploymentTask.id,
            vpsId: vps.id,
            protocolType: config.protocolType,
            serverAddress: vps.host,
            port: config.port,
            password: config.password,
            uuid: config.uuid,
            method: config.method,
            transport: config.transport,
            tls: config.tls
        )
        
        // 保存配置
        clientConfigurations.append(clientConfig)
        saveClientConfigurations()
        
        return clientConfig
    }
    
    /// 删除客户端配置
    func deleteConfiguration(_ configId: UUID) {
        clientConfigurations.removeAll { $0.id == configId }
        saveClientConfigurations()
    }
    
    /// 批量删除客户端配置
    func deleteConfigurations(_ configIds: [UUID]) {
        clientConfigurations.removeAll { configIds.contains($0.id) }
        saveClientConfigurations()
    }
    
    /// 生成指定格式的客户端配置
    func generateConfigContent(
        for clientConfig: ClientConfiguration,
        format: ClientConfigFormat,
        appType: ClientAppType? = nil
    ) throws -> String {
        switch format {
        case .singBox:
            return try generateSingBoxConfig(clientConfig)
        case .clash:
            return try generateClashConfig(clientConfig)
        case .v2ray:
            return try generateV2RayConfig(clientConfig)
        }
    }
    
    /// 生成协议URL
    func generateProtocolURL(
        for clientConfig: ClientConfiguration,
        protocol: ProtocolType
    ) throws -> String {
        switch `protocol` {
        case .shadowsocks:
            return try generateShadowsocksConfig(clientConfig)
        case .vmess:
            return try generateVMessConfig(clientConfig)
        case .vless:
            return try generateVLESSConfig(clientConfig)
        case .trojan:
            return try generateTrojanConfig(clientConfig)
        case .hysteria:
            return try generateHysteriaConfig(clientConfig)
        case .hysteria2:
            return try generateHysteria2Config(clientConfig)
        case .tuic:
            return try generateTUICConfig(clientConfig)
        case .naive:
            return try generateNaiveConfig(clientConfig)
        case .shadowtls:
            return try generateShadowTLSConfig(clientConfig)
        }
    }
    
    /// 生成二维码
    func generateQRCode(for clientConfig: ClientConfiguration, format: ClientConfigFormat) throws -> String {
        let configContent = try generateConfigContent(for: clientConfig, format: format)
        return configContent
    }
    
    /// 导出配置文件
    func exportConfig(
        for clientConfig: ClientConfiguration,
        format: ClientConfigFormat,
        appType: ClientAppType? = nil
    ) throws -> URL {
        let configContent = try generateConfigContent(for: clientConfig, format: format, appType: appType)
        
        // 创建临时文件
        let fileName = "\(clientConfig.protocolType)_\(clientConfig.serverAddress)_\(clientConfig.port).\(format.fileExtension)"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        try configContent.write(to: tempURL, atomically: true, encoding: .utf8)
        
        return tempURL
    }
    
    // MARK: - Private Methods
    
    /// 解析部署变量
    private func parseDeploymentVariables(_ variables: [String: String], vps: VPSInstance) throws -> ParsedConfig {
        let protocolType = variables["protocol"] ?? "shadowsocks"
        let port = Int(variables["port"] ?? "8080") ?? 8080
        let password = variables["password"]
        let uuid = variables["uuid"]
        let method = variables["method"]
        
        // 解析传输配置
        var transport: ClientTransportConfig?
        if let transportType = variables["vless_transport_type"] {
            transport = ClientTransportConfig(
                type: transportType,
                path: variables["vless_transport_path"],
                host: variables["vless_transport_host"],
                serviceName: variables["vless_transport_service_name"],
                idleTimeout: variables["vless_transport_idle_timeout"],
                pingTimeout: variables["vless_transport_ping_timeout"],
                permitWithoutStream: variables["vless_transport_permit_without_stream"] == "true"
            )
        }
        
        // 解析TLS配置
        var tls: ClientTLSConfig?
        if let tlsEnabled = variables["tls_enabled"], tlsEnabled == "true" {
            tls = ClientTLSConfig(
                enabled: true,
                serverName: variables["tls_server_name"],
                allowInsecure: variables["tls_allow_insecure"] == "true",
                alpn: variables["tls_alpn"]?.components(separatedBy: ",")
            )
        }
        
        return ParsedConfig(
            protocolType: protocolType,
            port: port,
            password: password,
            uuid: uuid,
            method: method,
            transport: transport,
            tls: tls
        )
    }
    
    /// 生成 sing-box 配置
    private func generateSingBoxConfig(_ config: ClientConfiguration) throws -> String {
        var outbound: [String: Any] = [
            "type": config.protocolType,
            "tag": "proxy",
            "server": config.serverAddress,
            "server_port": config.port
        ]
        
        // 添加协议特定配置
        switch config.protocolType {
        case "shadowsocks":
            outbound["method"] = config.method ?? "aes-256-gcm"
            outbound["password"] = config.password ?? ""
        case "vmess":
            outbound["uuid"] = config.uuid ?? ""
            outbound["alter_id"] = 0
            outbound["security"] = "auto"
        case "vless":
            outbound["uuid"] = config.uuid ?? ""
            outbound["flow"] = ""
        case "trojan":
            outbound["password"] = config.password ?? ""
        case "hysteria":
            outbound["up_mbps"] = 100
            outbound["down_mbps"] = 100
            outbound["password"] = config.password ?? ""
        case "hysteria2":
            outbound["password"] = config.password ?? ""
        case "tuic":
            outbound["uuid"] = config.uuid ?? ""
            outbound["password"] = config.password ?? ""
        case "naive":
            outbound["username"] = "user"
            outbound["password"] = config.password ?? ""
        case "shadowtls":
            outbound["password"] = config.password ?? ""
        default:
            break
        }
        
        // 添加传输配置
        if let transport = config.transport {
            var transportConfig: [String: Any] = ["type": transport.type]
            
            switch transport.type {
            case "ws":
                if let path = transport.path {
                    transportConfig["path"] = path
                }
                if let host = transport.host {
                    transportConfig["headers"] = ["Host": host]
                }
            case "grpc":
                if let serviceName = transport.serviceName {
                    transportConfig["service_name"] = serviceName
                }
                if let idleTimeout = transport.idleTimeout {
                    transportConfig["idle_timeout"] = idleTimeout
                }
                if let pingTimeout = transport.pingTimeout {
                    transportConfig["ping_timeout"] = pingTimeout
                }
                if let permitWithoutStream = transport.permitWithoutStream {
                    transportConfig["permit_without_stream"] = permitWithoutStream
                }
            default:
                break
            }
            
            outbound["transport"] = transportConfig
        }
        
        // 添加TLS配置
        if let tls = config.tls, tls.enabled {
            var tlsConfig: [String: Any] = [
                "enabled": true,
                "server_name": tls.serverName ?? config.serverAddress,
                "insecure": tls.allowInsecure
            ]
            
            if let alpn = tls.alpn {
                tlsConfig["alpn"] = alpn
            }
            
            outbound["tls"] = tlsConfig
        }
        
        let configDict: [String: Any] = [
            "log": [
                "level": "info",
                "timestamp": true,
                "output": "stdout"
            ],
            "outbounds": [
                outbound,
                [
                    "type": "direct",
                    "tag": "direct"
                ],
                [
                    "type": "block",
                    "tag": "block"
                ]
            ],
            "route": [
                "rules": [
                    [
                        "ip_cidr": [
                            "127.0.0.1/32",
                            "10.0.0.0/8",
                            "172.16.0.0/12",
                            "192.168.0.0/16",
                            "169.254.0.0/16",
                            "::1/128",
                            "fc00::/7",
                            "fe80::/10"
                        ],
                        "outbound": "direct"
                    ]
                ],
                "final": "direct"
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configDict, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
    
    /// 生成 Clash 配置
    private func generateClashConfig(_ config: ClientConfiguration) throws -> String {
        var proxy: [String: Any] = [
            "name": "\(config.protocolType)-\(config.serverAddress)",
            "type": config.protocolType,
            "server": config.serverAddress,
            "port": config.port
        ]
        
        // 添加协议特定配置
        switch config.protocolType {
        case "shadowsocks":
            proxy["cipher"] = config.method ?? "aes-256-gcm"
            proxy["password"] = config.password ?? ""
        case "vmess":
            proxy["uuid"] = config.uuid ?? ""
            proxy["alterId"] = 0
            proxy["security"] = "auto"
        case "vless":
            proxy["uuid"] = config.uuid ?? ""
            proxy["flow"] = ""
        case "trojan":
            proxy["password"] = config.password ?? ""
        case "hysteria":
            proxy["up_mbps"] = 100
            proxy["down_mbps"] = 100
            proxy["password"] = config.password ?? ""
        case "hysteria2":
            proxy["password"] = config.password ?? ""
        case "tuic":
            proxy["uuid"] = config.uuid ?? ""
            proxy["password"] = config.password ?? ""
        case "naive":
            proxy["username"] = "user"
            proxy["password"] = config.password ?? ""
        case "shadowtls":
            proxy["password"] = config.password ?? ""
        default:
            break
        }
        
        // 添加传输配置
        if let transport = config.transport {
            switch transport.type {
            case "ws":
                proxy["network"] = "ws"
                if let path = transport.path {
                    proxy["ws-path"] = path
                }
                if let host = transport.host {
                    proxy["ws-headers"] = ["Host": host]
                }
            case "grpc":
                proxy["network"] = "grpc"
                if let serviceName = transport.serviceName {
                    proxy["grpc-opts"] = ["grpc-service-name": serviceName]
                }
            default:
                break
            }
        }
        
        // 添加TLS配置
        if let tls = config.tls, tls.enabled {
            proxy["tls"] = true
            proxy["servername"] = tls.serverName ?? config.serverAddress
            proxy["skip-cert-verify"] = tls.allowInsecure
            if let alpn = tls.alpn {
                proxy["alpn"] = alpn
            }
        }
        
        let configDict: [String: Any] = [
            "port": 7890,
            "socks-port": 7891,
            "allow-lan": true,
            "mode": "rule",
            "log-level": "info",
            "external-controller": "127.0.0.1:9090",
            "proxies": [proxy],
            "proxy-groups": [
                [
                    "name": "Proxy",
                    "type": "select",
                    "proxies": ["\(config.protocolType)-\(config.serverAddress)"]
                ]
            ],
            "rules": [
                "DOMAIN-SUFFIX,google.com,Proxy",
                "DOMAIN-SUFFIX,facebook.com,Proxy",
                "DOMAIN-SUFFIX,youtube.com,Proxy",
                "DOMAIN-SUFFIX,twitter.com,Proxy",
                "DOMAIN-SUFFIX,instagram.com,Proxy",
                "DOMAIN-SUFFIX,github.com,Proxy",
                "GEOIP,CN,DIRECT",
                "MATCH,Proxy"
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configDict, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
    
    /// 生成 V2Ray 配置
    private func generateV2RayConfig(_ config: ClientConfiguration) throws -> String {
        var outbound: [String: Any] = [
            "protocol": config.protocolType,
            "settings": [:],
            "tag": "proxy"
        ]
        
        // 添加协议特定配置
        switch config.protocolType {
        case "shadowsocks":
            outbound["settings"] = [
                "servers": [
                    [
                        "address": config.serverAddress,
                        "port": config.port,
                        "method": config.method ?? "aes-256-gcm",
                        "password": config.password ?? ""
                    ]
                ]
            ]
        case "vmess":
            outbound["settings"] = [
                "vnext": [
                    [
                        "address": config.serverAddress,
                        "port": config.port,
                        "users": [
                            [
                                "id": config.uuid ?? "",
                                "alterId": 0,
                                "security": "auto"
                            ]
                        ]
                    ]
                ]
            ]
        case "vless":
            outbound["settings"] = [
                "vnext": [
                    [
                        "address": config.serverAddress,
                        "port": config.port,
                        "users": [
                            [
                                "id": config.uuid ?? "",
                                "encryption": "none",
                                "flow": ""
                            ]
                        ]
                    ]
                ]
            ]
        case "trojan":
            outbound["settings"] = [
                "servers": [
                    [
                        "address": config.serverAddress,
                        "port": config.port,
                        "password": config.password ?? ""
                    ]
                ]
            ]
        default:
            break
        }
        
        // 添加传输配置
        if let transport = config.transport {
            var streamSettings: [String: Any] = ["network": transport.type]
            
            switch transport.type {
            case "ws":
                var wsSettings: [String: Any] = [:]
                if let path = transport.path {
                    wsSettings["path"] = path
                }
                if let host = transport.host {
                    wsSettings["headers"] = ["Host": host]
                }
                streamSettings["wsSettings"] = wsSettings
            case "grpc":
                var grpcSettings: [String: Any] = [:]
                if let serviceName = transport.serviceName {
                    grpcSettings["serviceName"] = serviceName
                }
                streamSettings["grpcSettings"] = grpcSettings
            default:
                break
            }
            
            outbound["streamSettings"] = streamSettings
        }
        
        // 添加TLS配置
        if let tls = config.tls, tls.enabled {
            var tlsSettings: [String: Any] = [
                "allowInsecure": tls.allowInsecure
            ]
            
            if let serverName = tls.serverName {
                tlsSettings["serverName"] = serverName
            }
            
            if let alpn = tls.alpn {
                tlsSettings["alpn"] = alpn
            }
            
            var streamSettings = outbound["streamSettings"] as? [String: Any] ?? [:]
            streamSettings["security"] = "tls"
            streamSettings["tlsSettings"] = tlsSettings
            outbound["streamSettings"] = streamSettings
        }
        
        let configDict: [String: Any] = [
            "log": [
                "loglevel": "info"
            ],
            "inbounds": [
                [
                    "port": 1080,
                    "protocol": "socks",
                    "settings": [
                        "auth": "noauth",
                        "udp": true
                    ]
                ],
                [
                    "port": 1081,
                    "protocol": "http"
                ]
            ],
            "outbounds": [
                outbound,
                [
                    "protocol": "freedom",
                    "tag": "direct"
                ]
            ],
            "routing": [
                "rules": [
                    [
                        "type": "field",
                        "ip": [
                            "127.0.0.1/32",
                            "10.0.0.0/8",
                            "172.16.0.0/12",
                            "192.168.0.0/16",
                            "169.254.0.0/16",
                            "::1/128",
                            "fc00::/7",
                            "fe80::/10"
                        ],
                        "outboundTag": "direct"
                    ]
                ]
            ]
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: configDict, options: [.prettyPrinted, .sortedKeys])
        return String(data: jsonData, encoding: .utf8) ?? ""
    }
    
    /// 生成 VMess 配置
    private func generateVMessConfig(_ config: ClientConfiguration) throws -> String {
        let vmessURL = "vmess://\(generateVMessBase64(config))"
        return vmessURL
    }
    
    /// 生成 VLESS 配置
    private func generateVLESSConfig(_ config: ClientConfiguration) throws -> String {
        var vlessURL = "vless://\(config.uuid ?? "")@\(config.serverAddress):\(config.port)"
        
        if let transport = config.transport {
            vlessURL += "?type=\(transport.type)"
            if let path = transport.path {
                vlessURL += "&path=\(path)"
            }
            if let host = transport.host {
                vlessURL += "&host=\(host)"
            }
            if let serviceName = transport.serviceName {
                vlessURL += "&serviceName=\(serviceName)"
            }
        }
        
        if let tls = config.tls, tls.enabled {
            vlessURL += "&security=tls"
            if let serverName = tls.serverName {
                vlessURL += "&sni=\(serverName)"
            }
            if tls.allowInsecure {
                vlessURL += "&allowInsecure=1"
            }
        }
        
        vlessURL += "#\(config.protocolType)-\(config.serverAddress)"
        
        return vlessURL
    }
    
    /// 生成 Trojan 配置
    private func generateTrojanConfig(_ config: ClientConfiguration) throws -> String {
        var trojanURL = "trojan://\(config.password ?? "")@\(config.serverAddress):\(config.port)"
        
        if let tls = config.tls, tls.enabled {
            trojanURL += "?security=tls"
            if let serverName = tls.serverName {
                trojanURL += "&sni=\(serverName)"
            }
            if tls.allowInsecure {
                trojanURL += "&allowInsecure=1"
            }
        }
        
        trojanURL += "#\(config.protocolType)-\(config.serverAddress)"
        
        return trojanURL
    }
    
    /// 生成 Shadowsocks 配置
    private func generateShadowsocksConfig(_ config: ClientConfiguration) throws -> String {
        let method = config.method ?? "aes-256-gcm"
        let password = config.password ?? ""
        let server = config.serverAddress
        let port = config.port
        
        let ssURL = "ss://\(method):\(password)@\(server):\(port)#\(config.protocolType)-\(server)"
        
        return ssURL
    }
    
    /// 生成 Hysteria 配置
    private func generateHysteriaConfig(_ config: ClientConfiguration) throws -> String {
        var hysteriaURL = "hysteria://\(config.serverAddress):\(config.port)"
        
        if let password = config.password {
            hysteriaURL += "?auth=\(password)"
        }
        
        if let tls = config.tls, tls.enabled {
            hysteriaURL += "&insecure=\(tls.allowInsecure ? "1" : "0")"
            if let serverName = tls.serverName {
                hysteriaURL += "&sni=\(serverName)"
            }
        }
        
        hysteriaURL += "#\(config.protocolType)-\(config.serverAddress)"
        
        return hysteriaURL
    }
    
    /// 生成 Hysteria2 配置
    private func generateHysteria2Config(_ config: ClientConfiguration) throws -> String {
        var hysteria2URL = "hysteria2://\(config.password ?? "")@\(config.serverAddress):\(config.port)"
        
        if let tls = config.tls, tls.enabled {
            hysteria2URL += "?insecure=\(tls.allowInsecure ? "1" : "0")"
            if let serverName = tls.serverName {
                hysteria2URL += "&sni=\(serverName)"
            }
        }
        
        hysteria2URL += "#\(config.protocolType)-\(config.serverAddress)"
        
        return hysteria2URL
    }
    
    /// 生成 TUIC 配置
    private func generateTUICConfig(_ config: ClientConfiguration) throws -> String {
        var tuicURL = "tuic://\(config.serverAddress):\(config.port)"
        
        if let uuid = config.uuid {
            tuicURL += "?uuid=\(uuid)"
        }
        
        if let password = config.password {
            tuicURL += "&password=\(password)"
        }
        
        if let tls = config.tls, tls.enabled {
            tuicURL += "&insecure=\(tls.allowInsecure ? "1" : "0")"
            if let serverName = tls.serverName {
                tuicURL += "&sni=\(serverName)"
            }
        }
        
        tuicURL += "#\(config.protocolType)-\(config.serverAddress)"
        
        return tuicURL
    }
    
    /// 生成 Naive 配置
    private func generateNaiveConfig(_ config: ClientConfiguration) throws -> String {
        var naiveURL = "naive://\(config.password ?? "")@\(config.serverAddress):\(config.port)"
        
        if let tls = config.tls, tls.enabled {
            naiveURL += "?insecure=\(tls.allowInsecure ? "1" : "0")"
            if let serverName = tls.serverName {
                naiveURL += "&sni=\(serverName)"
            }
        }
        
        naiveURL += "#\(config.protocolType)-\(config.serverAddress)"
        
        return naiveURL
    }
    
    /// 生成 ShadowTLS 配置
    private func generateShadowTLSConfig(_ config: ClientConfiguration) throws -> String {
        var shadowtlsURL = "shadowtls://\(config.password ?? "")@\(config.serverAddress):\(config.port)"
        
        if let tls = config.tls, tls.enabled {
            shadowtlsURL += "?insecure=\(tls.allowInsecure ? "1" : "0")"
            if let serverName = tls.serverName {
                shadowtlsURL += "&sni=\(serverName)"
            }
        }
        
        shadowtlsURL += "#\(config.protocolType)-\(config.serverAddress)"
        
        return shadowtlsURL
    }
    
    /// 生成 VMess Base64 编码
    private func generateVMessBase64(_ config: ClientConfiguration) -> String {
        let vmessConfig: [String: Any] = [
            "v": "2",
            "ps": "\(config.protocolType)-\(config.serverAddress)",
            "add": config.serverAddress,
            "port": config.port,
            "id": config.uuid ?? "",
            "aid": 0,
            "net": config.transport?.type ?? "tcp",
            "type": "none",
            "host": config.transport?.host ?? "",
            "path": config.transport?.path ?? "",
            "tls": config.tls?.enabled == true ? "tls" : "none",
            "sni": config.tls?.serverName ?? "",
            "alpn": config.tls?.alpn?.joined(separator: ",") ?? ""
        ]
        
        let jsonData = try? JSONSerialization.data(withJSONObject: vmessConfig)
        let base64String = jsonData?.base64EncodedString() ?? ""
        
        return base64String
    }
    
    // MARK: - Persistence
    
    private func saveClientConfigurations() {
        do {
            let data = try JSONEncoder().encode(clientConfigurations)
            UserDefaults.standard.set(data, forKey: "client_configurations")
        } catch {
            print("Failed to save client configurations: \(error)")
        }
    }
    
    private func loadClientConfigurations() {
        guard let data = UserDefaults.standard.data(forKey: "client_configurations") else { return }
        
        do {
            clientConfigurations = try JSONDecoder().decode([ClientConfiguration].self, from: data)
        } catch {
            print("Failed to load client configurations: \(error)")
        }
    }
}

// MARK: - Supporting Types

/// 解析的配置信息
private struct ParsedConfig {
    let protocolType: String
    let port: Int
    let password: String?
    let uuid: String?
    let method: String?
    let transport: ClientTransportConfig?
    let tls: ClientTLSConfig?
}

/// 客户端配置生成错误
enum ClientConfigGeneratorError: LocalizedError {
    case vpsNotFound
    case invalidConfiguration
    case unsupportedProtocol
    case generationFailed
    
    var errorDescription: String? {
        switch self {
        case .vpsNotFound:
            return "VPS 实例未找到"
        case .invalidConfiguration:
            return "配置信息无效"
        case .unsupportedProtocol:
            return "不支持的协议类型"
        case .generationFailed:
            return "配置生成失败"
        }
    }
}
