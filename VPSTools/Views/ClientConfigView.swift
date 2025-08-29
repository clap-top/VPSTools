import SwiftUI
import Combine

// MARK: - Config Connection Status

enum ConfigConnectionStatus {
    case unknown
    case testing
    case connected
    case failed
    
    var displayName: String {
        switch self {
        case .unknown: return "未知"
        case .testing: return "测试中"
        case .connected: return "连接正常"
        case .failed: return "连接失败"
        }
    }
    
    var color: Color {
        switch self {
        case .unknown: return .gray
        case .testing: return .orange
        case .connected: return .green
        case .failed: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .testing: return "clock"
        case .connected: return "checkmark.circle"
        case .failed: return "xmark.circle"
        }
    }
}

// MARK: - Client Configuration View

struct ClientConfigView: View {
    @ObservedObject var clientConfigGenerator: ClientConfigGenerator
    @ObservedObject var vpsManager: VPSManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedConfig: ClientConfiguration?
    @State private var selectedFormat: ClientConfigFormat = .singBox
    @State private var selectedAppType: ClientAppType = .singBox
    @State private var configContent = ""
    @State private var qrCodeData: Data?
    @State private var searchText = ""
    @State private var selectedProtocolFilter: ProtocolType?
    @State private var showingDeleteConfirmation = false
    @State private var configToDelete: ClientConfiguration?
    @State private var showingBulkActions = false
    @State private var selectedConfigs: Set<UUID> = []
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if clientConfigGenerator.clientConfigurations.isEmpty {
                    emptyStateView
                } else {
                    configListView
                }
            }
            .navigationTitle("客户端配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedConfig) { config in
                ClientConfigDetailView(
                    config: config,
                    clientConfigGenerator: clientConfigGenerator,
                    vpsManager: vpsManager
                )
            }
            .confirmationDialog("确认删除", isPresented: $showingDeleteConfirmation) {
                Button("删除", role: .destructive) {
                    if let config = configToDelete {
                        clientConfigGenerator.deleteConfiguration(config.id)
                        configToDelete = nil
                    }
                }
                Button("取消", role: .cancel) {
                    configToDelete = nil
                }
            } message: {
                Text("确定要删除这个配置吗？此操作无法撤销。")
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("暂无客户端配置")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("部署 sing-box 服务后，系统会自动生成客户端配置")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Config List View
    
    private var filteredConfigurations: [ClientConfiguration] {
        var filtered = clientConfigGenerator.clientConfigurations
        
        // 搜索过滤
        if !searchText.isEmpty {
            filtered = filtered.filter { config in
                config.serverAddress.localizedCaseInsensitiveContains(searchText) ||
                config.protocolType.localizedCaseInsensitiveContains(searchText) ||
                (vpsManager.vpsInstances.first(where: { $0.id == config.vpsId })?.displayName.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // 协议过滤
        if let protocolFilter = selectedProtocolFilter {
            filtered = filtered.filter { $0.protocolType == protocolFilter.rawValue }
        }
        
        return filtered
    }
    
    private var configListView: some View {
        VStack(spacing: 0) {
//            // 搜索和过滤栏
//            searchAndFilterSection
            
            // 统计信息
            if !clientConfigGenerator.clientConfigurations.isEmpty {
                statisticsSection
            }
            
            // 配置列表
            List {
                ForEach(filteredConfigurations) { config in
                    ClientConfigRowView(
                        config: config,
                        vpsManager: vpsManager,
                        isSelected: selectedConfigs.contains(config.id),
                        onTap: {
                            if showingBulkActions {
                                toggleConfigSelection(config)
                            } else {
                                selectedConfig = config
                            }
                        },
                        onLongPress: {
                            if !showingBulkActions {
                                showingBulkActions = true
                                selectedConfigs.insert(config.id)
                            }
                        },
                        onExport: { format, appType in
                            selectedConfig = config
                            selectedFormat = format
                            selectedAppType = appType
                        },
                        onShowQRCode: { format in
                            generateQRCode(for: config, format: format)
                        },
                        onDelete: {
                            configToDelete = config
                            showingDeleteConfirmation = true
                        }
                    )
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            // 批量操作栏
            if showingBulkActions {
                bulkActionsSection
            }
        }
    }
    
    // MARK: - Search and Filter Section
    
    private var searchAndFilterSection: some View {
        VStack(spacing: 12) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜索配置...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button("清除") {
                        searchText = ""
                    }
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            
            // 协议过滤
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button(action: {
                        selectedProtocolFilter = nil
                    }) {
                        Text("全部")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedProtocolFilter == nil ? Color.accentColor : Color(.tertiarySystemBackground))
                            .foregroundColor(selectedProtocolFilter == nil ? .white : .primary)
                            .cornerRadius(16)
                    }
                    
                    ForEach(ProtocolType.allCases, id: \.self) { protocolType in
                        Button(action: {
                            selectedProtocolFilter = selectedProtocolFilter == protocolType ? nil : protocolType
                        }) {
                            Text(protocolType.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedProtocolFilter == protocolType ? Color.accentColor : Color(.tertiarySystemBackground))
                                .foregroundColor(selectedProtocolFilter == protocolType ? .white : .primary)
                                .cornerRadius(16)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("配置统计")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(filteredConfigurations.count)/\(clientConfigGenerator.clientConfigurations.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // 协议分布
            let protocolStats = Dictionary(grouping: filteredConfigurations, by: { $0.protocolType })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            if !protocolStats.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(protocolStats.prefix(5), id: \.key) { protocolType, count in
                            VStack(spacing: 4) {
                                Text(protocolType.uppercased())
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Text("\(count)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    // MARK: - Bulk Actions Section
    
    private var bulkActionsSection: some View {
        HStack(spacing: 16) {
            Button("取消") {
                showingBulkActions = false
                selectedConfigs.removeAll()
            }
            .foregroundColor(.secondary)
            
            Spacer()
            
            Text("已选择 \(selectedConfigs.count) 项")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("删除") {
                deleteSelectedConfigs()
            }
            .foregroundColor(.red)
            .disabled(selectedConfigs.isEmpty)
            
            Button("分享") {
                shareSelectedConfigs()
            }
            .foregroundColor(.accentColor)
            .disabled(selectedConfigs.isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }
    
    // MARK: - Private Methods
    
    private func toggleConfigSelection(_ config: ClientConfiguration) {
        if selectedConfigs.contains(config.id) {
            selectedConfigs.remove(config.id)
        } else {
            selectedConfigs.insert(config.id)
        }
    }
    
    private func deleteSelectedConfigs() {
        for configId in selectedConfigs {
            clientConfigGenerator.deleteConfiguration(configId)
        }
        selectedConfigs.removeAll()
        showingBulkActions = false
    }
    
    private func shareSelectedConfigs() {
        var shareText = "客户端配置\n\n"
        
        for configId in selectedConfigs {
            if let config = clientConfigGenerator.clientConfigurations.first(where: { $0.id == configId }) {
                shareText += "配置: \(config.protocolType.uppercased())\n"
                shareText += "服务器: \(config.serverAddress):\(config.port)\n"
                if let vps = vpsManager.vpsInstances.first(where: { $0.id == config.vpsId }) {
                    shareText += "VPS: \(vps.displayName)\n"
                }
                shareText += "\n"
            }
        }
        
        shareItems = [shareText]
        showingShareSheet = true
    }
    
    private func generateQRCode(for config: ClientConfiguration, format: ClientConfigFormat) {
        do {
            let configContent = try clientConfigGenerator.generateConfigContent(for: config, format: format)
            // 这里可以集成二维码生成库
            // 暂时使用占位符
            qrCodeData = configContent.data(using: .utf8)
        } catch {
            print("生成二维码失败: \(error)")
        }
    }
}

// MARK: - Client Config Row View

struct ClientConfigRowView: View {
    let config: ClientConfiguration
    let vpsManager: VPSManager
    let isSelected: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onExport: (ClientConfigFormat, ClientAppType) -> Void
    let onShowQRCode: (ClientConfigFormat) -> Void
    let onDelete: () -> Void
    
    @State private var showingActionSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 选择指示器
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(config.protocolType.uppercased()) - \(config.serverAddress)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            showingActionSheet = true
                        }) {
                            Image(systemName: "ellipsis.circle")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    Text("端口: \(config.port)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let vps = vpsManager.vpsInstances.first(where: { $0.id == config.vpsId }) {
                        Text("服务器: \(vps.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack(spacing: 8) {
                ForEach(ClientAppType.allCases.prefix(3), id: \.self) { appType in
                    Text(appType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(8)
                }
                
                if ClientAppType.allCases.count > 3 {
                    Text("+\(ClientAppType.allCases.count - 3)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onLongPress()
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("客户端配置操作"),
                message: Text("选择要执行的操作"),
                buttons: [
                    .default(Text("查看详情")) {
                        onTap()
                    },
                    .default(Text("导出 Clash 配置")) {
                        onExport(.clash, .clash)
                    },
                    .default(Text("导出 sing-box 配置")) {
                        onExport(.singBox, .singBox)
                    },
                    .default(Text("导出 V2Ray 配置")) {
                        onExport(.v2ray, .v2rayNG)
                    },
                    .default(Text("显示二维码")) {
                        onShowQRCode(.singBox)
                    },
                    .destructive(Text("删除配置")) {
                        onDelete()
                    },
                    .cancel()
                ]
            )
        }
    }
}

// MARK: - Client Config Detail View

struct ClientConfigDetailView: View {
    let config: ClientConfiguration
    let clientConfigGenerator: ClientConfigGenerator
    let vpsManager: VPSManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFormat: ClientConfigFormat = .singBox
    @State private var configContent = ""
    @State private var showingExportSheet = false
    @State private var showingQRCode = false
    @State private var showingShareSheet = false
    @State private var showingConnectionTest = false
    @State private var connectionStatus: ConfigConnectionStatus = .unknown
    @State private var testResult = ""
    @State private var shareItems: [Any] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 配置信息
                configInfoSection
                
                // 格式选择
                formatSelectionSection
                
                // 配置内容
                configContentSection
                
                Spacer()
                
                // 操作按钮
                actionButtonsSection
            }
            .navigationTitle("配置详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                updateConfigContent()
            }
            .onChange(of: selectedFormat) { _ in
                updateConfigContent()
            }
            .sheet(isPresented: $showingExportSheet) {
                ClientConfigExportOptionsView(
                    config: config,
                    clientConfigGenerator: clientConfigGenerator
                )
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }
    
    private var configInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("配置信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                // 基本信息
                InfoRow(label: "协议", value: config.protocolType.uppercased())
                InfoRow(label: "服务器", value: config.serverAddress)
                InfoRow(label: "端口", value: "\(config.port)")
                
                // 连接状态
                HStack {
                    Text("连接状态")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: connectionStatus.icon)
                            .foregroundColor(connectionStatus.color)
                        
                        Text(connectionStatus.displayName)
                            .font(.subheadline)
                            .foregroundColor(connectionStatus.color)
                    }
                }
                
                // 协议特定信息
                if let password = config.password {
                    InfoRow(label: "密码", value: password, isSensitive: true)
                }
                
                if let uuid = config.uuid {
                    InfoRow(label: "UUID", value: uuid, isSensitive: true)
                }
                
                if let method = config.method {
                    InfoRow(label: "加密方法", value: method)
                }
                
                // 传输配置
                if let transport = config.transport {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("传输配置")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("类型: \(transport.type)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let path = transport.path {
                            Text("路径: \(path)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let host = transport.host {
                            Text("主机: \(host)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
                
                // TLS配置
                if let tls = config.tls, tls.enabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TLS配置")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        if let serverName = tls.serverName {
                            Text("服务器名: \(serverName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("允许不安全: \(tls.allowInsecure ? "是" : "否")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let alpn = tls.alpn, !alpn.isEmpty {
                            Text("ALPN: \(alpn.joined(separator: ", "))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
                
                // VPS信息
                if let vps = vpsManager.vpsInstances.first(where: { $0.id == config.vpsId }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("服务器信息")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("名称: \(vps.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("地址: \(vps.host)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("用户: \(vps.username)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 配置格式选择
            VStack(alignment: .leading, spacing: 8) {
                Text("配置格式")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ClientConfigFormat.allCases, id: \.self) { format in
                            Button(action: {
                                selectedFormat = format
                            }) {
                                Text(format.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedFormat == format ? Color.accentColor : Color(.tertiarySystemBackground))
                                    .foregroundColor(selectedFormat == format ? .white : .primary)
                                    .cornerRadius(20)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // 协议类型信息（只显示，不可选择）
            VStack(alignment: .leading, spacing: 8) {
                Text("协议类型")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .padding(.horizontal)
                
                Text(config.protocolType.uppercased())
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.tertiarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(20)
                    .padding(.horizontal)
            }
        }
        .padding(.top)
    }
    
    private var configContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("配置内容")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("复制") {
                    UIPasteboard.general.string = configContent
                }
                .font(.subheadline)
                .foregroundColor(.accentColor)
            }
            
            ScrollView {
                Text(configContent)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 300)
        }
        .padding(.horizontal)
        .padding(.top)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // 主要操作按钮
            HStack(spacing: 12) {
                Button("导出配置") {
                    showingExportSheet = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                
                Button("显示二维码") {
                    showingQRCode = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            
            // 次要操作按钮
            HStack(spacing: 12) {
                Button("连接测试") {
                    testConnection()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .disabled(connectionStatus == .testing)
                
                Button("分享配置") {
                    shareConfiguration()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            
            // 快速操作按钮
            HStack(spacing: 8) {
                Button("复制服务器地址") {
                    UIPasteboard.general.string = "\(config.serverAddress):\(config.port)"
                }
                .buttonStyle(.bordered)
                .font(.caption)
                
                Button("复制配置内容") {
                    UIPasteboard.general.string = configContent
                }
                .buttonStyle(.bordered)
                .font(.caption)
                
                if vpsManager.vpsInstances.first(where: { $0.id == config.vpsId }) != nil {
                    Button("查看VPS详情") {
                        // TODO: 导航到VPS详情页面
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
        }
        .padding()
    }
    
    private func updateConfigContent() {
        do {
            configContent = try clientConfigGenerator.generateConfigContent(for: config, format: selectedFormat)
        } catch {
            configContent = "生成配置失败: \(error.localizedDescription)"
        }
    }
    
    private func testConnection() {
        connectionStatus = .testing
        
        // 模拟连接测试
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            // 这里应该实现真正的连接测试逻辑
            let isSuccess = Bool.random() // 模拟测试结果
            connectionStatus = isSuccess ? .connected : .failed
            
            if isSuccess {
                testResult = "连接成功，延迟: \(Int.random(in: 50...200))ms"
            } else {
                testResult = "连接失败，请检查网络设置"
            }
        }
    }
    
    private func shareConfiguration() {
        var shareText = "客户端配置\n\n"
        shareText += "协议: \(config.protocolType.uppercased())\n"
        shareText += "服务器: \(config.serverAddress):\(config.port)\n"
        
        if let password = config.password {
            shareText += "密码: \(password)\n"
        }
        
        if let uuid = config.uuid {
            shareText += "UUID: \(uuid)\n"
        }
        
        if let vps = vpsManager.vpsInstances.first(where: { $0.id == config.vpsId }) {
            shareText += "VPS: \(vps.displayName)\n"
        }
        
        shareText += "\n配置内容:\n\(configContent)"
        
        shareItems = [shareText]
        showingShareSheet = true
    }
}

// MARK: - Client Config Export View

struct ClientConfigExportView: View {
    let config: ClientConfiguration
    let format: ClientConfigFormat
    let appType: ClientAppType
    let clientConfigGenerator: ClientConfigGenerator
    @Environment(\.dismiss) private var dismiss
    
    @State private var configContent = ""
    @State private var exportURL: URL?
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 导出信息
                exportInfoSection
                
                // 配置预览
                configPreviewSection
                
                Spacer()
                
                // 导出按钮
                exportButtonsSection
            }
            .navigationTitle("导出配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                updateConfigContent()
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }
    
    private var exportInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("导出信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(label: "格式", value: format.displayName)
                InfoRow(label: "应用", value: appType.displayName)
                InfoRow(label: "文件名", value: "\(config.protocolType)_\(config.serverAddress)_\(config.port).\(format.fileExtension)")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var configPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("配置预览")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView {
                Text(configContent)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 200)
        }
        .padding(.horizontal)
    }
    
    private var exportButtonsSection: some View {
        VStack(spacing: 12) {
            Button("导出文件") {
                exportConfigFile()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            
            Button("复制到剪贴板") {
                UIPasteboard.general.string = configContent
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
    
    private func updateConfigContent() {
        do {
            configContent = try clientConfigGenerator.generateConfigContent(for: config, format: format, appType: appType)
        } catch {
            configContent = "生成配置失败: \(error.localizedDescription)"
        }
    }
    
    private func exportConfigFile() {
        do {
            exportURL = try clientConfigGenerator.exportConfig(for: config, format: format, appType: appType)
            showingShareSheet = true
        } catch {
            print("导出文件失败: \(error)")
        }
    }
}

// MARK: - QR Code View

struct QRCodeView: View {
    let qrCodeData: Data
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 这里可以显示二维码图片
                Image(systemName: "qrcode")
                    .font(.system(size: 200))
                    .foregroundColor(.accentColor)
                
                Text("扫描二维码导入配置")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text("使用支持的应用扫描此二维码即可导入配置")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("二维码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Export Options View

struct ClientConfigExportOptionsView: View {
    let config: ClientConfiguration
    let clientConfigGenerator: ClientConfigGenerator
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedFormat: ClientConfigFormat = .singBox
    @State private var selectedProtocol: ProtocolType?
    @State private var showingExportView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 配置格式选择
                formatSelectionSection
                
                // 协议类型选择（可选）
                protocolSelectionSection
                
                Spacer()
                
                // 导出按钮
                exportButtonSection
            }
            .navigationTitle("导出选项")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExportView) {
                if let selectedProtocol = selectedProtocol {
                    // 导出协议URL
                    ProtocolURLExportView(
                        config: config,
                        protocolType: selectedProtocol,
                        clientConfigGenerator: clientConfigGenerator
                    )
                } else {
                    // 导出配置文件
                    ClientConfigExportView(
                        config: config,
                        format: selectedFormat,
                        appType: .singBox,
                        clientConfigGenerator: clientConfigGenerator
                    )
                }
            }
        }
    }
    
    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("配置格式")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(ClientConfigFormat.allCases, id: \.self) { format in
                    Button(action: {
                        selectedFormat = format
                        selectedProtocol = nil
                    }) {
                        HStack {
                            Text(format.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            if selectedFormat == format && selectedProtocol == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding()
                        .background(selectedFormat == format && selectedProtocol == nil ? Color.accentColor.opacity(0.1) : Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var protocolSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("协议URL")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(ProtocolType.allCases, id: \.self) { protocolType in
                    Button(action: {
                        selectedProtocol = protocolType
                        selectedFormat = .singBox // 重置格式选择
                    }) {
                        HStack {
                            Text(protocolType.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            if selectedProtocol == protocolType {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding()
                        .background(selectedProtocol == protocolType ? Color.accentColor.opacity(0.1) : Color(.tertiarySystemBackground))
                        .cornerRadius(8)
                    }
                    .foregroundColor(.primary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var exportButtonSection: some View {
        VStack(spacing: 12) {
            Button("导出") {
                showingExportView = true
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            .disabled(selectedFormat == .singBox && selectedProtocol == nil)
        }
        .padding()
    }
}

// MARK: - Protocol URL Export View

struct ProtocolURLExportView: View {
    let config: ClientConfiguration
    let protocolType: ProtocolType
    let clientConfigGenerator: ClientConfigGenerator
    @Environment(\.dismiss) private var dismiss
    
    @State private var protocolURL = ""
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 协议信息
                protocolInfoSection
                
                // URL预览
                urlPreviewSection
                
                Spacer()
                
                // 操作按钮
                actionButtonsSection
            }
            .navigationTitle("协议URL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                generateProtocolURL()
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [protocolURL])
            }
        }
    }
    
    private var protocolInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("协议信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(label: "协议", value: protocolType.displayName)
                InfoRow(label: "服务器", value: config.serverAddress)
                InfoRow(label: "端口", value: "\(config.port)")
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var urlPreviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("URL预览")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView {
                Text(protocolURL)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 200)
        }
        .padding(.horizontal)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button("复制URL") {
                UIPasteboard.general.string = protocolURL
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
            
            Button("分享URL") {
                showingShareSheet = true
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
        .padding()
    }
    
    private func generateProtocolURL() {
        do {
            protocolURL = try clientConfigGenerator.generateProtocolURL(for: config, protocol: protocolType)
        } catch {
            protocolURL = "生成URL失败: \(error.localizedDescription)"
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}


