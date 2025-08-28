import SwiftUI

// MARK: - Config Parameter

struct ConfigParameter {
    let key: String
    let label: String
    let value: String
}

// MARK: - Deployment Task Detail View

struct DeploymentTaskDetailView: View {
    let task: DeploymentTask
    @ObservedObject var vpsManager: VPSManager
    @ObservedObject var deploymentService: DeploymentService
    @Environment(\.dismiss) private var dismiss
    @State private var isRetrying = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var showingDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 任务信息
                    taskInfoSection
                    
                    // 模板信息（如果有）
                    if task.templateId != nil {
                        templateInfoSection
                    }
                    
                    // VPS 信息
                    vpsInfoSection
                    
                    // 执行状态
                    executionStatusSection
                    
                    // 日志列表
                    logsSection
                }
                .padding()
            }
            .navigationTitle("部署任务详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("返回") {
//                        dismiss()
//                    }
//                }
                if task.status == .failed || task.status == .cancelled {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            if task.status == .failed || task.status == .cancelled {
                                Button(isRetrying ? "执行中..." : "重新执行") {
                                    Task {
                                        await retryDeployment()
                                    }
                                }
                                .disabled(isRetrying)
                            }
                            
                            //                        Button("复制配置") {
                            //                            copyTaskConfiguration()
                            //                        }
                            //
                            //                        Button("删除任务") {
                            //                            showingDeleteConfirmation = true
                            //                        }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .alert("错误", isPresented: $showingErrorAlert) {
            Button("确定") { }
        } message: {
            Text(errorMessage)
        }
        .alert("成功", isPresented: $showingSuccessAlert) {
            Button("确定") { }
        } message: {
            Text(successMessage)
        }
        .confirmationDialog("确认删除", isPresented: $showingDeleteConfirmation) {
            Button("删除", role: .destructive) {
                deleteTask()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("确定要删除这个部署任务吗？此操作无法撤销。")
        }
    }
    
    // MARK: - Task Info Section
    
    private var taskInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("任务信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(label: "任务 ID", value: task.id.uuidString.prefix(8).description)
                
                if let startedAt = task.startedAt {
                    InfoRow(label: "开始时间", value: startedAt.formatted())
                }
                
                if let completedAt = task.completedAt {
                    InfoRow(label: "完成时间", value: completedAt.formatted())
                }
                
                if let startedAt = task.startedAt, let completedAt = task.completedAt {
                    let duration = completedAt.timeIntervalSince(startedAt)
                    InfoRow(label: "执行时长", value: formatDuration(duration))
                }
                
                if !task.variables.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("配置参数")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(getFilteredVariables(), id: \.key) { param in
                            HStack {
                                Text(param.label)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(param.value)
                                    .font(.caption)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Template Info Section
    
    private var templateInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("部署模板")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let templateId = task.templateId,
               let template = deploymentService.templates.first(where: { $0.id == templateId }) {
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(template.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(template.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(template.serviceType.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(template.serviceType.category == .proxy ? Color.blue : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    
                    if !template.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(template.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            } else {
                Text("模板不存在或已被删除")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - VPS Info Section
    
    private var vpsInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("目标 VPS")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let vps = vpsManager.vpsInstances.first(where: { $0.id == task.vpsId }) {
                VStack(spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vps.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(vps.host)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // 连接状态指示器
                        HStack(spacing: 6) {
                            if vpsManager.isConnectionTesting(for: vps) {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            } else {
                                Circle()
                                    .fill(connectionStatusColor(for: vps))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                    
                    if let systemInfo = vps.systemInfo {
                        HStack {
                            Text("内存: \(Int(systemInfo.memoryUsage))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("磁盘: \(Int(systemInfo.diskUsage))%")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                Text("VPS 不存在或已被删除")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Execution Status Section
    
    private var executionStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("执行状态")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Text(task.status.displayName)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(task.status.color)
                    
                    Spacer()
                    
                    Image(systemName: task.status.icon)
                        .font(.title2)
                        .foregroundColor(task.status.color)
                }
                
                ProgressView(value: task.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                
                Text("\(Int(task.progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let error = task.error {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("错误信息")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.red)
                        
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Logs Section
    
    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("执行日志")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(task.logs.count) 条")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if task.logs.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("暂无日志")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(task.logs) { log in
                        LogRowView(log: log)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Private Methods
    
    /// 获取过滤后的配置参数，针对 SingBox 协议只显示已配置的参数
    private func getFilteredVariables() -> [ConfigParameter] {
        var filteredParams: [ConfigParameter] = []
        
        // 检查是否是 SingBox 模板
        let isSingBoxTemplate = task.templateId != nil && 
            deploymentService.templates.first(where: { $0.id == task.templateId })?.serviceType == .singbox
        
        if isSingBoxTemplate {
            // 针对 SingBox 协议进行智能过滤
            filteredParams = getSingBoxFilteredVariables()
        } else {
            // 对于其他模板，显示所有变量
            for (key, value) in task.variables.sorted(by: { $0.key < $1.key }) {
                if !value.isEmpty {
                    filteredParams.append(ConfigParameter(
                        key: key,
                        label: getParameterLabel(key),
                        value: value
                    ))
                }
            }
        }
        
        return filteredParams
    }
    
    /// 获取 SingBox 协议过滤后的配置参数
    private func getSingBoxFilteredVariables() -> [ConfigParameter] {
        var params: [ConfigParameter] = []
        
        // 基础配置参数
        if let protocolType = task.variables["protocol"], !protocolType.isEmpty {
            params.append(ConfigParameter(
                key: "protocol",
                label: "协议类型",
                value: getProtocolDisplayName(protocolType)
            ))
        }
        
        if let port = task.variables["port"], !port.isEmpty {
            params.append(ConfigParameter(
                key: "port",
                label: "监听端口",
                value: port
            ))
        }
        
        // 协议特定参数
        if let protocolType = task.variables["protocol"] {
            params.append(contentsOf: getProtocolSpecificParameters(protocolType: protocolType))
        }
        
        // TLS 配置参数
        if let tlsEnabled = task.variables["tls_enabled"], tlsEnabled == "true" {
            params.append(contentsOf: getTLSParameters())
        }
        
        // 传输配置参数
        if let transportType = task.variables["vless_transport_type"], 
           transportType != "tcp" && !transportType.isEmpty {
            params.append(contentsOf: getTransportParameters())
        }
        
        // 多路复用配置参数
        if let multiplexEnabled = task.variables["vless_multiplex_enabled"], 
           multiplexEnabled == "true" {
            params.append(contentsOf: getMultiplexParameters())
        }
        
        return params
    }
    
    /// 获取协议特定参数
    private func getProtocolSpecificParameters(protocolType: String) -> [ConfigParameter] {
        var params: [ConfigParameter] = []
        
        switch protocolType {
        case "vless":
            if let uuid = task.variables["vless_uuid"], !uuid.isEmpty {
                params.append(ConfigParameter(key: "vless_uuid", label: "VLESS UUID", value: maskSensitiveValue(uuid)))
            }
            if let flow = task.variables["vless_flow"], !flow.isEmpty {
                params.append(ConfigParameter(key: "vless_flow", label: "VLESS Flow", value: flow))
            }
            
        case "vmess":
            if let uuid = task.variables["vmess_uuid"], !uuid.isEmpty {
                params.append(ConfigParameter(key: "vmess_uuid", label: "VMess UUID", value: maskSensitiveValue(uuid)))
            }
            if let alterId = task.variables["vmess_alter_id"], !alterId.isEmpty {
                params.append(ConfigParameter(key: "vmess_alter_id", label: "Alter ID", value: alterId))
            }
            
        case "trojan":
            if let uuid = task.variables["trojan_uuid"], !uuid.isEmpty {
                params.append(ConfigParameter(key: "trojan_uuid", label: "Trojan UUID", value: maskSensitiveValue(uuid)))
            }
            
        case "shadowsocks":
            if let password = task.variables["password"], !password.isEmpty {
                params.append(ConfigParameter(key: "password", label: "密码", value: maskSensitiveValue(password)))
            }
            if let method = task.variables["method"], !method.isEmpty {
                params.append(ConfigParameter(key: "method", label: "加密方法", value: method))
            }
            
        case "hysteria", "hysteria2":
            if let password = task.variables["\(protocolType)_password"], !password.isEmpty {
                params.append(ConfigParameter(key: "\(protocolType)_password", label: "密码", value: maskSensitiveValue(password)))
            }
            if let upMbps = task.variables["\(protocolType)_up_mbps"], !upMbps.isEmpty {
                params.append(ConfigParameter(key: "\(protocolType)_up_mbps", label: "上行带宽", value: "\(upMbps) Mbps"))
            }
            if let downMbps = task.variables["\(protocolType)_down_mbps"], !downMbps.isEmpty {
                params.append(ConfigParameter(key: "\(protocolType)_down_mbps", label: "下行带宽", value: "\(downMbps) Mbps"))
            }
            
        case "tuic":
            if let uuid = task.variables["tuic_uuid"], !uuid.isEmpty {
                params.append(ConfigParameter(key: "tuic_uuid", label: "TUIC UUID", value: maskSensitiveValue(uuid)))
            }
            if let password = task.variables["tuic_password"], !password.isEmpty {
                params.append(ConfigParameter(key: "tuic_password", label: "TUIC 密码", value: maskSensitiveValue(password)))
            }
            
        case "naive":
            if let username = task.variables["naive_username"], !username.isEmpty {
                params.append(ConfigParameter(key: "naive_username", label: "用户名", value: username))
            }
            if let password = task.variables["naive_password"], !password.isEmpty {
                params.append(ConfigParameter(key: "naive_password", label: "密码", value: maskSensitiveValue(password)))
            }
            
        default:
            // 对于其他协议，显示所有非空参数
            for (key, value) in task.variables {
                if !value.isEmpty && key != "protocol" && key != "port" {
                    params.append(ConfigParameter(
                        key: key,
                        label: getParameterLabel(key),
                        value: value
                    ))
                }
            }
        }
        
        return params
    }
    
    /// 获取 TLS 配置参数
    private func getTLSParameters() -> [ConfigParameter] {
        var params: [ConfigParameter] = []
        
        if let serverName = task.variables["tls_server_name"], !serverName.isEmpty {
            params.append(ConfigParameter(key: "tls_server_name", label: "TLS 服务器名", value: serverName))
        }
        
        if let alpn = task.variables["tls_alpn"], !alpn.isEmpty {
            params.append(ConfigParameter(key: "tls_alpn", label: "ALPN", value: alpn))
        }
        
        // Reality 配置
        if let realityEnabled = task.variables["tls_reality_enabled"], realityEnabled == "true" {
            params.append(ConfigParameter(key: "tls_reality_enabled", label: "Reality", value: "已启用"))
            
            if let handshakeServer = task.variables["tls_reality_handshake_server"], !handshakeServer.isEmpty {
                params.append(ConfigParameter(key: "tls_reality_handshake_server", label: "握手服务器", value: handshakeServer))
            }
            
            if let shortId = task.variables["tls_reality_short_id"], !shortId.isEmpty {
                params.append(ConfigParameter(key: "tls_reality_short_id", label: "Short ID", value: shortId))
            }
        }
        
        // ACME 配置
        if let acmeEnabled = task.variables["tls_acme_enabled"], acmeEnabled == "true" {
            params.append(ConfigParameter(key: "tls_acme_enabled", label: "ACME", value: "已启用"))
            
            if let domain = task.variables["tls_acme_domain"], !domain.isEmpty {
                params.append(ConfigParameter(key: "tls_acme_domain", label: "ACME 域名", value: domain))
            }
        }
        
        return params
    }
    
    /// 获取传输配置参数
    private func getTransportParameters() -> [ConfigParameter] {
        var params: [ConfigParameter] = []
        
        if let transportType = task.variables["vless_transport_type"], !transportType.isEmpty {
            params.append(ConfigParameter(key: "vless_transport_type", label: "传输类型", value: getTransportDisplayName(transportType)))
        }
        
        if let transportPath = task.variables["vless_transport_path"], !transportPath.isEmpty {
            params.append(ConfigParameter(key: "vless_transport_path", label: "传输路径", value: transportPath))
        }
        
        if let transportHost = task.variables["vless_transport_host"], !transportHost.isEmpty {
            params.append(ConfigParameter(key: "vless_transport_host", label: "传输主机", value: transportHost))
        }
        
        return params
    }
    
    /// 获取多路复用配置参数
    private func getMultiplexParameters() -> [ConfigParameter] {
        var params: [ConfigParameter] = []
        
        params.append(ConfigParameter(key: "vless_multiplex_enabled", label: "多路复用", value: "已启用"))
        
        if let padding = task.variables["vless_multiplex_padding"], padding == "true" {
            params.append(ConfigParameter(key: "vless_multiplex_padding", label: "Padding", value: "已启用"))
        }
        
        if let brutalEnabled = task.variables["vless_multiplex_brutal_enabled"], brutalEnabled == "true" {
            params.append(ConfigParameter(key: "vless_multiplex_brutal_enabled", label: "Brutal", value: "已启用"))
            
            if let upMbps = task.variables["vless_multiplex_brutal_up_mbps"], !upMbps.isEmpty {
                params.append(ConfigParameter(key: "vless_multiplex_brutal_up_mbps", label: "Brutal 上行", value: "\(upMbps) Mbps"))
            }
            
            if let downMbps = task.variables["vless_multiplex_brutal_down_mbps"], !downMbps.isEmpty {
                params.append(ConfigParameter(key: "vless_multiplex_brutal_down_mbps", label: "Brutal 下行", value: "\(downMbps) Mbps"))
            }
        }
        
        return params
    }
    
    /// 获取参数标签
    private func getParameterLabel(_ key: String) -> String {
        let labelMapping: [String: String] = [
            "port": "端口",
            "password": "密码",
            "method": "加密方法",
            "uuid": "UUID",
            "server_name": "服务器名",
            "alpn": "ALPN",
            "min_version": "最小版本",
            "max_version": "最大版本",
            "certificate_path": "证书路径",
            "key_path": "密钥路径",
            "insecure": "不安全连接",
            "domain": "域名",
            "email": "邮箱",
            "provider": "提供商",
            "private_key": "私钥",
            "public_key": "公钥",
            "handshake_server": "握手服务器",
            "server_port": "服务器端口",
            "short_id": "Short ID",
            "fingerprint": "指纹",
            "fragment": "分片",
            "record_fragment": "记录分片",
            "congestion_control": "拥塞控制",
            "udp_relay_mode": "UDP 中继模式",
            "max_datagram_size": "最大数据报大小",
            "username": "用户名",
            "server": "服务器",
            "mode": "模式",
            "network": "网络",
            "interface_name": "接口名",
            "mtu": "MTU",
            "auto_route": "自动路由",
            "to": "重定向到",
            "redirect_to": "重定向到"
        ]
        
        return labelMapping[key] ?? key
    }
    
    /// 获取协议显示名称
    private func getProtocolDisplayName(_ protocolType: String) -> String {
        let protocolNames: [String: String] = [
            "vless": "VLESS",
            "vmess": "VMess",
            "trojan": "Trojan",
            "shadowsocks": "Shadowsocks",
            "hysteria": "Hysteria",
            "hysteria2": "Hysteria2",
            "tuic": "TUIC",
            "naive": "Naive",
            "shadowtls": "ShadowTLS",
            "anytls": "AnyTLS",
            "direct": "Direct",
            "mixed": "Mixed",
            "socks": "SOCKS",
            "http": "HTTP",
            "tun": "TUN",
            "redirect": "Redirect",
            "tproxy": "TProxy"
        ]
        
        return protocolNames[protocolType] ?? protocolType.uppercased()
    }
    
    /// 获取传输类型显示名称
    private func getTransportDisplayName(_ transportType: String) -> String {
        let transportNames: [String: String] = [
            "tcp": "TCP",
            "ws": "WebSocket",
            "grpc": "gRPC",
            "quic": "QUIC"
        ]
        
        return transportNames[transportType] ?? transportType.uppercased()
    }
    
    /// 掩码敏感值
    private func maskSensitiveValue(_ value: String) -> String {
        if value.count <= 8 {
            return String(repeating: "*", count: value.count)
        } else {
            let prefix = String(value.prefix(4))
            let suffix = String(value.suffix(4))
            return "\(prefix)****\(suffix)"
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return "\(minutes)分\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
    
    private func connectionStatusColor(for vps: VPSInstance) -> Color {
        // 优先使用连接测试结果
        if let testResult = vpsManager.connectionTestResults[vps.id] {
            if testResult.sshSuccess {
                return .green
            } else {
                return .red
            }
        }
        
        // 如果没有测试结果，使用最后连接时间
        if let lastConnected = vps.lastConnected {
            let timeSinceLastConnection = Date().timeIntervalSince(lastConnected)
            if timeSinceLastConnection < 300 { // 5 minutes
                return .green
            } else if timeSinceLastConnection < 3600 { // 1 hour
                return .orange
            } else {
                return .red
            }
        }
        
        return .gray
    }
    
    // MARK: - Action Methods
    
    private func retryDeployment() async {
        isRetrying = true
        defer { isRetrying = false }
        
        do {
            try await deploymentService.executeDeployment(task)
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
    
    private func copyTaskConfiguration() {
        var configText = "部署任务配置\n"
        configText += "任务 ID: \(task.id.uuidString)\n"
        configText += "VPS ID: \(task.vpsId.uuidString)\n"
        
        if let templateId = task.templateId {
            configText += "模板 ID: \(templateId.uuidString)\n"
        }
        
        if let customCommands = task.customCommands {
            configText += "自定义命令:\n"
            for command in customCommands {
                configText += "  \(command)\n"
            }
        }
        
        configText += "变量:\n"
        for (key, value) in task.variables {
            configText += "  \(key): \(value)\n"
        }
        
        UIPasteboard.general.string = configText
        successMessage = "配置已复制到剪贴板"
        showingSuccessAlert = true
    }
    
    private func deleteTask() {
        // 从 deploymentService 中删除任务
        deploymentService.deleteTask(task.id)
        dismiss()
    }
}



// MARK: - Preview

struct DeploymentTaskDetailView_Previews: PreviewProvider {
    static var previews: some View {
        DeploymentTaskDetailView(
            task: DeploymentTask(
                vpsId: UUID(),
                customCommands: ["echo 'test'", "whoami"],
                variables: ["port": "8080", "password": "test123"]
            ),
            vpsManager: VPSManager(),
            deploymentService: DeploymentService(vpsManager: VPSManager())
        )
    }
}
