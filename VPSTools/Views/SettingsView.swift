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
        Section(String(.appStatusSection)) {
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
                    
                    Text(String(.connectionTimeoutValue))
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
        Section(String(.systemInfoSection)) {
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
        Section(String(.supportAndFeedback)) {
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
        Section(String(.aboutSection)) {
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
                Section(String(.dataStatistics)) {
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
                
                Section(String(.dataOperations)) {
                    Button(String(.clearAllVPSData)) {
                        showingClearConfirmation = true
                    }
                    .foregroundColor(.red)
                    
                    Button(String(.clearDeploymentHistory)) {
                        showingDeleteConfirmation = true
                    }
                    .foregroundColor(.orange)
                }
                
                Section(String(.instructions)) {
                    Text(.clearDataWarningIrreversible)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(String(.dataManagement))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(.done)) {
                        dismiss()
                    }
                }
            }
            .alert(String(.confirmClear), isPresented: $showingClearConfirmation) {
                Button(String(.cancel), role: .cancel) { }
                Button(String(.clear), role: .destructive) {
                    vpsManager.clearAllData()
                }
            } message: {
                Text(.clearDataWarning)
            }
            .alert(String(.confirmClear), isPresented: $showingDeleteConfirmation) {
                Button(String(.cancel), role: .cancel) { }
                Button(String(.clear), role: .destructive) {
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
                Section(String(.biometricAuthentication)) {
                    HStack {
                        Image(systemName: "faceid")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(.faceIDTouchID)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(String(.useBiometricToUnlock))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $isBiometricEnabled)
                            .labelsHidden()
                    }
                }
                
                Section(String(.passwordProtection)) {
                    HStack {
                        Image(systemName: "lock")
                            .foregroundColor(.red)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(.appPassword))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(String(.setAppAccessPassword))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $isPasswordEnabled)
                            .labelsHidden()
                    }
                    
                    if isPasswordEnabled {
                        Button(String(.setPassword)) {
                            showingPasswordSetup = true
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Section(String(.securityInstructions)) {
                    Text(String(.securityInstructionsText))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle(String(.securitySettings))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(.done)) {
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
        case light = "light"
        case dark = "dark"
        case system = "system"
    }
    
    enum AccentColor: String, CaseIterable {
        case blue = "blue"
        case green = "green"
        case purple = "purple"
        case orange = "orange"
        case red = "red"
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(String(.themeMode)) {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        HStack {
                            Text(themeDisplayName(theme))
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
                
                Section(String(.accentColor)) {
                    ForEach(AccentColor.allCases, id: \.self) { color in
                        HStack {
                            Circle()
                                .fill(accentColorFor(color))
                                .frame(width: 20, height: 20)
                            
                            Text(colorDisplayName(color))
                            
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
            .navigationTitle(String(.themeSettings))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(.done)) {
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
    
    private func themeDisplayName(_ theme: AppTheme) -> String {
        switch theme {
        case .light:
            return String(.themeLight)
        case .dark:
            return String(.themeDark)
        case .system:
            return String(.themeSystem)
        }
    }
    
    private func colorDisplayName(_ color: AccentColor) -> String {
        switch color {
        case .blue:
            return String(.colorBlue)
        case .green:
            return String(.colorGreen)
        case .purple:
            return String(.colorPurple)
        case .orange:
            return String(.colorOrange)
        case .red:
            return String(.colorRed)
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
                        
                        Text(String(.vpsManagementTool))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(String(.version))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(String(.appDescription))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                }
                
                Section(String(.developmentInfo)) {
                    HStack {
                        Text(String(.developmentTeam))
                        Spacer()
                        Text(String(.vpsToolsTeam))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(String(.buildVersion))
                        Spacer()
                        Text(String(.build))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(String(.releaseDate))
                        Spacer()
                        Text(String(.releaseDateValue))
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(String(.technicalSupport)) {
                    HStack {
                        Text(String(.officialWebsite))
                        Spacer()
                        Text(String(.website))
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text(String(.contactEmail))
                        Spacer()
                        Text(String(.email))
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle(String(.aboutSection))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(.done)) {
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
                        
                        Text(String(.exportingData))
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
                        
                        Text(String(.exportDataTitle))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(String(.exportDataDescription))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(.exportContent))
                                .font(.headline)
                            
                            Text(String(.vpsInstanceConfig))
                            Text(String(.deploymentTaskHistory))
                            Text(String(.customDeploymentTemplates))
                            Text(String(.appSettings))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        
                        Button(String(.startExport)) {
                            startExport()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle(String(.exportData))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(.cancel)) {
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
                        
                        Text(String(.importingData))
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
                        
                        Text(String(.importDataTitle))
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(String(.importDataDescription))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(.importInstructions))
                                .font(.headline)
                            
                            Text(String(.importWillOverwrite))
                            Text(String(.ensureBackupComplete))
                            Text(String(.importProcessUninterruptible))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        
                        Button(String(.selectBackupFile)) {
                            startImport()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle(String(.importData))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(.cancel)) {
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
                    Text(String(.termsOfServiceTitle))
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(String(.termsOfServiceDescription))
                        .font(.subheadline)
                    
                    Text(String(.serviceDescription))
                        .font(.headline)
                    
                    Text(String(.termsDescription1))
                    
                    Text(String(.userResponsibility))
                        .font(.headline)
                    
                    Text(String(.userResponsibilityText))
                    
                    Text(String(.serviceLimitations))
                        .font(.headline)
                    
                    Text(String(.serviceLimitationsText))
                    
                    Text(String(.privacyProtection))
                        .font(.headline)
                    
                    Text(String(.privacyProtectionText))
                }
                .padding()
            }
            .navigationTitle(String(.userPolicy))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(.done)) {
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
                    Text(String(.privacyPolicyTitle))
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(String(.privacyPolicyDescription))
                        .font(.subheadline)
                    
                    Text(String(.informationCollection))
                        .font(.headline)
                    
                    Text(String(.informationCollectionDescription))
                    Text(String(.appUsageStatistics))
                    Text(String(.errorReportInformation))
                    Text(String(.performanceData))
                    
                    Text(String(.informationUsage))
                        .font(.headline)
                    
                    Text(String(.informationUsageDescription))
                    Text(String(.improveAppFunctionality))
                    Text(String(.resolveTechnicalIssues))
                    Text(String(.provideUserSupport))
                    
                    Text(String(.informationProtection))
                        .font(.headline)
                    
                    Text(String(.informationProtectionText))
                    
                    Text(String(.informationSharing))
                        .font(.headline)
                    
                    Text(String(.informationSharingText))
                }
                .padding()
            }
            .navigationTitle(String(.privacyPolicy))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(.done)) {
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
        case suggestion = "suggestion"
        case bug = "bug"
        case feature = "feature"
        case other = "other"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(String(.feedbackType)) {
                    Picker(String(.feedbackTypePicker), selection: $feedbackType) {
                        ForEach(FeedbackType.allCases, id: \.self) { type in
                            Text(feedbackTypeDisplayName(type)).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(String(.feedbackContent)) {
                    TextEditor(text: $feedbackText)
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                }
                
                Section(String(.contactInfoOptional)) {
                    TextField(String(.emailAddress), text: .constant(""))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section {
                    Button(String(.submitFeedback)) {
                        submitFeedback()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(feedbackText.isEmpty)
                }
            }
            .navigationTitle(String(.feedbackTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(String(.cancel)) {
                        dismiss()
                    }
                }
            }
            .hideKeyboardOnTap()
            .alert(String(.submitSuccess), isPresented: $showingSubmitSuccess) {
                Button(String(.confirm)) {
                    dismiss()
                }
            } message: {
                Text(String(.submitSuccessMessage))
            }
        }
    }
    
    private func submitFeedback() {
        // 模拟提交反馈
        showingSubmitSuccess = true
    }
    
    private func feedbackTypeDisplayName(_ type: FeedbackType) -> String {
        switch type {
        case .suggestion:
            return String(.feedbackSuggestion)
        case .bug:
            return String(.feedbackBug)
        case .feature:
            return String(.feedbackFeature)
        case .other:
            return String(.feedbackOther)
        }
    }
}
