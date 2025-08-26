import SwiftUI

// MARK: - Settings View

/// Main settings interface
struct SettingsView: View {
    @EnvironmentObject var appLifecycleManager: AppLifecycleManager
    @EnvironmentObject var localizationManager: LocalizationManager
    @ObservedObject var vpsManager: VPSManager
    @ObservedObject var deploymentService: DeploymentService
    
    @State private var showingDataManagement = false
    @State private var showingMonitoringSettings = false
    @State private var showingSecuritySettings = false
    @State private var showingThemeSettings = false
    @State private var showingAbout = false
    @State private var showingTerms = false
    @State private var showingPrivacy = false
    @State private var showingFeedback = false
    @State private var showingExportData = false
    @State private var showingImportData = false
    @State private var showingLocalizationDemo = false
    
    // 设置状态
    @State private var isMonitoringNotificationEnabled = true
    @State private var isAutoDisconnectEnabled = true
    
    var body: some View {
        NavigationView {
            List {
//                // 应用状态
//                appStatusSection
                
//                // 数据管理
//                dataManagementSection
                
//                // 监控设置
//                monitoringSection
                
                // 语言设置
                languageSection
                
                // SSH 连接管理
                sshConnectionSection
                
//                // 安全设置
//                securitySection
                
//                // 主题设置
//                themeSection
                
                // 系统信息
                systemInfoSection
                
                // 支持与反馈
                supportSection
                
                // 关于
                aboutSection
            }
            .navigationTitle(Text(.settingViewTitle))
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingDataManagement) {
                DataManagementView(vpsManager: vpsManager, deploymentService: deploymentService)
            }
            .sheet(isPresented: $showingMonitoringSettings) {
                MonitoringSettingsView(refreshInterval: .constant(30), isAutoRefresh: .constant(true))
            }
            .sheet(isPresented: $showingSecuritySettings) {
                SecuritySettingsView()
            }
            .sheet(isPresented: $showingThemeSettings) {
                ThemeSettingsView()
            }
            .sheet(isPresented: $showingAbout) {
                AboutView()
            }
            .sheet(isPresented: $showingTerms) {
                TermsView()
            }
            .sheet(isPresented: $showingPrivacy) {
                PrivacyView()
            }
            .sheet(isPresented: $showingFeedback) {
                FeedbackView()
            }
            .sheet(isPresented: $showingExportData) {
                ExportDataView(vpsManager: vpsManager, deploymentService: deploymentService)
            }
            .sheet(isPresented: $showingImportData) {
                ImportDataView(vpsManager: vpsManager, deploymentService: deploymentService)
            }
        }
    }
    
    // MARK: - App Status Section
    
    private var appStatusSection: some View {
        Section("应用状态") {
            HStack {
                Image(systemName: appLifecycleManager.isAppActive ? "checkmark.circle.fill" : "pause.circle.fill")
                    .foregroundColor(appLifecycleManager.isAppActive ? .green : .orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(.appStatus)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(appLifecycleManager.getAppStatusInfo().statusDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if let lastBackgroundTime = appLifecycleManager.lastBackgroundTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.lastBackgroundTime)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(lastBackgroundTime, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            if let lastForegroundTime = appLifecycleManager.lastForegroundTime {
                HStack {
                    Image(systemName: "play.circle")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.lastForegroundTime)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(lastForegroundTime, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            
            if appLifecycleManager.backgroundDuration > 0 {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.backgroundDuration)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(appLifecycleManager.getAppStatusInfo().formattedBackgroundDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Data Management Section
    
    private var dataManagementSection: some View {
        Section(String(.dataManagement)) {
            Button(action: { showingDataManagement = true }) {
                HStack {
                    Image(systemName: "folder")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.dataManagement)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(.manageVPSData)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            Button(action: { showingExportData = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.green)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.exportData)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(.exportVPSConfig)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            Button(action: { showingImportData = true }) {
                HStack {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.importData)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(.importDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
    }
    
    // MARK: - Monitoring Section
    
    private var monitoringSection: some View {
        Section(String(.monitoringSettings)) {
            Button(action: { showingMonitoringSettings = true }) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.monitoringSettings)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(.monitoringSettings)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            HStack {
                Image(systemName: "bell")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(.monitoringNotification)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    
                    Text(.vpsStatusNotification)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isMonitoringNotificationEnabled)
                    .labelsHidden()
            }
        }
    }
    
    // MARK: - Language Section
    
    private var languageSection: some View {
        Section(String(.languageSettings)) {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.blue)
                
                Text(.appLanguage)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    
                Spacer()
                
                Picker("", selection: $localizationManager.currentLanguage) {
                    ForEach(Language.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
        }
    }
    
    // MARK: - SSH Connection Section
    
    private var sshConnectionSection: some View {
        Section(String(.sshConnectionManagement)) {
            HStack {
                Image(systemName: "network")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(.autoDisconnect)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(.autoDisconnectBackground)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isAutoDisconnectEnabled)
                    .labelsHidden()
            }
            
            Button(action: {
                // TODO: 实现连接超时设置功能
            }) {
                HStack {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.connectionTimeout)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(.sshTimeout)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("30\(String(.secondsShort))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
//            Button(action: {
//                Task {
//                    await appLifecycleManager.disconnectAllSSHConnections()
//                }
//            }) {
//                HStack {
//                    Image(systemName: "network.slash")
//                        .foregroundColor(.red)
//                    
//                    Text("立即断开所有 SSH 连接")
//                        .foregroundColor(.red)
//                    
//                    Spacer()
//                }
//            }
        }
    }
    
    // MARK: - Security Section
    
    private var securitySection: some View {
        Section(String(.securitySettings)) {
            Button(action: { showingSecuritySettings = true }) {
                HStack {
                    Image(systemName: "lock.shield")
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.securitySettings)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(.securitySettings)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            Button(action: {
                // TODO: 实现密钥管理功能
            }) {
                HStack {
                    Image(systemName: "key")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.manageSSHKeys)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(.manageSSHKeys)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
    }
    
    // MARK: - Theme Section
    
    private var themeSection: some View {
        Section(String(.themeSettings)) {
            Button(action: { showingThemeSettings = true }) {
                HStack {
                    Image(systemName: "paintbrush")
                        .foregroundColor(.purple)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.themeSettings)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(.themeSettings)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
            
            Button(action: {
                // TODO: 实现字体大小设置功能
            }) {
                HStack {
                    Image(systemName: "textformat.size")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(.fontSize)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(.fontSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(.standard)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
    }
    
    // MARK: - System Info Section
    
    private var systemInfoSection: some View {
        Section("系统信息") {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(.iosVersion)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(UIDevice.current.systemVersion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack {
                Image(systemName: "iphone")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(.deviceModel)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(UIDevice.current.model)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            HStack {
                Image(systemName: "memorychip")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(.appVersion)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(.appVersion)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Support Section
    
    private var supportSection: some View {
        Section("支持与反馈") {
//            Button(action: { showingFeedback = true }) {
//                HStack {
//                    Image(systemName: "envelope")
//                        .foregroundColor(.blue)
//                    
//                    VStack(alignment: .leading, spacing: 4) {
//                        Text("意见反馈")
//                            .font(.subheadline)
//                            .fontWeight(.medium)
//                        
//                        Text("发送反馈和建议")
//                            .font(.caption)
//                            .foregroundColor(.secondary)
//                    }
//                    
//                    Spacer()
//                    
//                    Image(systemName: "chevron.right")
//                        .font(.caption)
//                        .foregroundColor(.secondary)
//                }
//            }
//            .foregroundColor(.primary)
            
            Button(action: { showingTerms = true }) {
                HStack {
                    Image(systemName: "doc.text")
                        .foregroundColor(.blue)
                    
                    Text(.userPolicy)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: { showingPrivacy = true }) {
                HStack {
                    Image(systemName: "hand.raised")
                        .foregroundColor(.blue)
                    
                    Text(.privacyPolicy)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section("关于") {
            Button(action: { showingAbout = true }) {
                HStack {
                    Image(systemName: "app.badge")
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                                            Text(.vpsManagementTool)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(.appDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .foregroundColor(.primary)
        }
    }
}

// MARK: - Data Management View

struct DataManagementView: View {
    @ObservedObject var vpsManager: VPSManager
    @ObservedObject var deploymentService: DeploymentService
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var showingClearConfirmation = false
    
    var body: some View {
        NavigationView {
            List {
                Section("数据统计") {
                    HStack {
                        Text(.vpsInstances)
                        Spacer()
                        Text("\(vpsManager.vpsInstances.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(.deploymentTasks)
                        Spacer()
                        Text("\(deploymentService.deploymentTasks.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(.deploymentTemplates)
                        Spacer()
                        Text("\(deploymentService.templates.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("数据操作") {
                    Button("清除所有 VPS 数据") {
                        showingClearConfirmation = true
                    }
                    .foregroundColor(.red)
                    
                    Button("清除部署历史") {
                        showingDeleteConfirmation = true
                    }
                    .foregroundColor(.orange)
                }
                
                Section("说明") {
                    Text(.clearDataWarningIrreversible)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("数据管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("确认清除", isPresented: $showingClearConfirmation) {
                Button("取消", role: .cancel) { }
                Button("清除", role: .destructive) {
                    vpsManager.clearAllData()
                }
            } message: {
                Text(.clearDataWarning)
            }
            .alert("确认清除", isPresented: $showingDeleteConfirmation) {
                Button("取消", role: .cancel) { }
                Button("清除", role: .destructive) {
                    deploymentService.clearAllTasks()
                }
            } message: {
                Text(.clearDeploymentHistoryWarning)
            }
        }
    }
}

// MARK: - Security Settings View

struct SecuritySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isBiometricEnabled = false
    @State private var isPasswordEnabled = false
    @State private var showingPasswordSetup = false
    
    var body: some View {
        NavigationView {
            List {
                Section("生物识别") {
                    HStack {
                        Image(systemName: "faceid")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(.faceIDTouchID)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("使用生物识别解锁应用")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $isBiometricEnabled)
                            .labelsHidden()
                    }
                }
                
                Section("密码保护") {
                    HStack {
                        Image(systemName: "lock")
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("应用密码")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("设置应用访问密码")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $isPasswordEnabled)
                            .labelsHidden()
                    }
                    
                    if isPasswordEnabled {
                        Button("设置密码") {
                            showingPasswordSetup = true
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section("说明") {
                    Text("启用安全功能后，每次打开应用都需要验证身份。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("安全设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Theme Settings View

struct ThemeSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTheme: AppTheme = .system
    @State private var selectedAccentColor: AccentColor = .blue
    
    enum AppTheme: String, CaseIterable {
        case light = "浅色"
        case dark = "深色"
        case system = "跟随系统"
    }
    
    enum AccentColor: String, CaseIterable {
        case blue = "蓝色"
        case green = "绿色"
        case purple = "紫色"
        case orange = "橙色"
        case red = "红色"
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("主题模式") {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        HStack {
                            Text(theme.rawValue)
                            Spacer()
                            if selectedTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTheme = theme
                        }
                    }
                }
                
                Section("强调色") {
                    ForEach(AccentColor.allCases, id: \.self) { color in
                        HStack {
                            Circle()
                                .fill(accentColorFor(color))
                                .frame(width: 20, height: 20)
                            
                            Text(color.rawValue)
                            
                            Spacer()
                            
                            if selectedAccentColor == color {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedAccentColor = color
                        }
                    }
                }
            }
            .navigationTitle("主题设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func accentColorFor(_ color: AccentColor) -> Color {
        switch color {
        case .blue: return .blue
        case .green: return .green
        case .purple: return .purple
        case .orange: return .orange
        case .red: return .red
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("VPS 管理工具")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("版本 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("专业的 VPS 服务器管理工具，提供便捷的部署、监控和管理功能。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                Section("开发信息") {
                    HStack {
                        Text("开发团队")
                        Spacer()
                        Text("VPS Tools Team")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("构建版本")
                        Spacer()
                        Text("Build 1")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("发布日期")
                        Spacer()
                        Text("2025年8月")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("技术支持") {
                    HStack {
                        Text("官方网站")
                        Spacer()
                        Text("https://selfhost.vip/vpstools")
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("联系邮箱")
                        Spacer()
                        Text("clap@clap.top")
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Export Data View

struct ExportDataView: View {
    @ObservedObject var vpsManager: VPSManager
    @ObservedObject var deploymentService: DeploymentService
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportProgress = 0.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isExporting {
                    VStack(spacing: 16) {
                        ProgressView(value: exportProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text("正在导出数据...")
                            .font(.headline)
                        
                        Text("\(Int(exportProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("导出数据")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("将 VPS 配置和部署历史导出为备份文件")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("导出内容包括：")
                                .font(.headline)
                            
                            Text("• VPS 实例配置")
                            Text("• 部署任务历史")
                            Text("• 自定义部署模板")
                            Text("• 应用设置")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        
                        Button("开始导出") {
                            startExport()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("导出数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func startExport() {
        isExporting = true
        exportProgress = 0.0
        
        // 模拟导出过程
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            exportProgress += 0.02
            if exportProgress >= 1.0 {
                timer.invalidate()
                isExporting = false
                dismiss()
            }
        }
    }
}

// MARK: - Import Data View

struct ImportDataView: View {
    @ObservedObject var vpsManager: VPSManager
    @ObservedObject var deploymentService: DeploymentService
    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var importProgress = 0.0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isImporting {
                    VStack(spacing: 16) {
                        ProgressView(value: importProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        Text("正在导入数据...")
                            .font(.headline)
                        
                        Text("\(Int(importProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("导入数据")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("从备份文件恢复 VPS 配置和部署历史")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("导入说明：")
                                .font(.headline)
                            
                            Text("• 导入将覆盖现有数据")
                            Text("• 请确保备份文件完整")
                            Text("• 导入过程不可中断")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        
                        Button("选择备份文件") {
                            startImport()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("导入数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func startImport() {
        isImporting = true
        importProgress = 0.0
        
        // 模拟导入过程
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            importProgress += 0.02
            if importProgress >= 1.0 {
                timer.invalidate()
                isImporting = false
                dismiss()
            }
        }
    }
}

// MARK: - Terms View

struct TermsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("使用条款")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("欢迎使用 VPS 管理工具。请仔细阅读以下使用条款。")
                        .font(.subheadline)
                    
                    Text("1. 服务说明")
                        .font(.headline)
                    
                    Text("本应用提供 VPS 服务器管理功能，包括部署、监控、连接等操作。")
                    
                    Text("2. 用户责任")
                        .font(.headline)
                    
                    Text("用户应妥善保管 VPS 登录凭据，不得将敏感信息泄露给第三方。")
                    
                    Text("3. 服务限制")
                        .font(.headline)
                    
                    Text("本应用仅提供管理工具，不承担因 VPS 操作造成的任何损失。")
                    
                    Text("4. 隐私保护")
                        .font(.headline)
                    
                    Text("我们承诺保护用户隐私，不会收集或泄露用户的敏感信息。")
                }
                .padding()
            }
            .navigationTitle("使用条款")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Privacy View

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("隐私政策")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("我们重视您的隐私，本政策说明了我们如何收集、使用和保护您的信息。")
                        .font(.subheadline)
                    
                    Text("信息收集")
                        .font(.headline)
                    
                    Text("我们仅收集必要的应用使用数据，包括：")
                    Text("• 应用使用统计")
                    Text("• 错误报告信息")
                    Text("• 性能数据")
                    
                    Text("信息使用")
                        .font(.headline)
                    
                    Text("收集的信息仅用于：")
                    Text("• 改进应用功能")
                    Text("• 解决技术问题")
                    Text("• 提供用户支持")
                    
                    Text("信息保护")
                        .font(.headline)
                    
                    Text("我们采用行业标准的安全措施保护您的信息，包括加密存储和传输。")
                    
                    Text("信息共享")
                        .font(.headline)
                    
                    Text("我们不会向第三方出售、交易或转让您的个人信息。")
                }
                .padding()
            }
            .navigationTitle("隐私政策")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Feedback View

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var feedbackText = ""
    @State private var feedbackType: FeedbackType = .suggestion
    @State private var showingSubmitSuccess = false
    
    enum FeedbackType: String, CaseIterable {
        case suggestion = "建议"
        case bug = "问题反馈"
        case feature = "功能请求"
        case other = "其他"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("反馈类型") {
                    Picker("类型", selection: $feedbackType) {
                        ForEach(FeedbackType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("反馈内容") {
                    TextEditor(text: $feedbackText)
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                }
                
                Section("联系方式（可选）") {
                    TextField("邮箱地址", text: .constant(""))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section {
                    Button("提交反馈") {
                        submitFeedback()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(feedbackText.isEmpty)
                }
            }
            .navigationTitle("意见反馈")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .hideKeyboardOnTap()
            .alert("提交成功", isPresented: $showingSubmitSuccess) {
                Button("确定") {
                    dismiss()
                }
            } message: {
                Text("感谢您的反馈，我们会认真考虑您的建议。")
            }
        }
    }
    
    private func submitFeedback() {
        // 模拟提交反馈
        showingSubmitSuccess = true
    }
}
