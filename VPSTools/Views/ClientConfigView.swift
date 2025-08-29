import SwiftUI
import Combine

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
    
    private var configListView: some View {
        List {
            ForEach(clientConfigGenerator.clientConfigurations) { config in
                ClientConfigRowView(
                    config: config,
                    vpsManager: vpsManager,
                    onTap: {
                        selectedConfig = config
                    },
                    onExport: { format, appType in
                        selectedConfig = config
                        selectedFormat = format
                        selectedAppType = appType
                    },
                    onShowQRCode: { format in
                        generateQRCode(for: config, format: format)
                    }
                )
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    // MARK: - Private Methods
    
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
    let onTap: () -> Void
    let onExport: (ClientConfigFormat, ClientAppType) -> Void
    let onShowQRCode: (ClientConfigFormat) -> Void
    
    @State private var showingActionSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(config.protocolType.uppercased()) - \(config.serverAddress)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("端口: \(config.port)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let vps = vpsManager.vpsInstances.first(where: { $0.id == config.vpsId }) {
                        Text("服务器: \(vps.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showingActionSheet = true
                }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.accentColor)
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
                    .default(Text("导出 sing-box 配置")) {
                        onExport(.singBox, .singBox)
                    },
                    .default(Text("导出 Clash 配置")) {
                        onExport(.clash, .clash)
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
        }
    }
    
    private var configInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("配置信息")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(label: "协议", value: config.protocolType.uppercased())
                InfoRow(label: "服务器", value: config.serverAddress)
                InfoRow(label: "端口", value: "\(config.port)")
                
                if let password = config.password {
                    InfoRow(label: "密码", value: password)
                }
                
                if let uuid = config.uuid {
                    InfoRow(label: "UUID", value: uuid)
                }
                
                if let method = config.method {
                    InfoRow(label: "加密方法", value: method)
                }
                
                if let vps = vpsManager.vpsInstances.first(where: { $0.id == config.vpsId }) {
                    InfoRow(label: "服务器名称", value: vps.displayName)
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
        HStack(spacing: 16) {
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
        .padding()
    }
    
    private func updateConfigContent() {
        do {
            configContent = try clientConfigGenerator.generateConfigContent(for: config, format: selectedFormat)
        } catch {
            configContent = "生成配置失败: \(error.localizedDescription)"
        }
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


