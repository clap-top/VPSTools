import Foundation
import SwiftUI

// MARK: - Localization Manager

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @Published var currentLanguage: Language = .system {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedLanguage")
            updateLocale()
        }
    }
    
    private init() {
        // 从 UserDefaults 读取保存的语言设置
        if let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = Language(rawValue: savedLanguage) {
            currentLanguage = language
        } else {
            // 新安装的应用默认使用中文
            currentLanguage = .chinese
        }
        updateLocale()
    }
    
    private func updateLocale() {
        // 更新应用的区域设置
        if let languageCode = currentLanguage.languageCode {
            UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }
    
    func localizedString(_ key: LocalizationKey) -> String {
        return key.localizedString(for: currentLanguage)
    }
}

// MARK: - Language Enum

enum Language: String, CaseIterable {
    case system = "system"
    case chinese = "zh"
    case english = "en"
    
    var displayName: String {
        switch self {
        case .system:
            return "跟随系统"
        case .chinese:
            return "中文"
        case .english:
            return "English"
        }
    }
    
    var languageCode: String? {
        switch self {
        case .system:
            return nil
        case .chinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }
}

// MARK: - Localization Key

enum LocalizationKey: String, CaseIterable {
    // Tab Bar
    case home = "home"
    case vpsManagement = "vps_management"
    case smartDeployment = "smart_deployment"
    case monitoring = "monitoring"
    case settings = "settings"
    
    // Home View
    case welcomeBack = "welcome_back"
    case manageVPSServers = "manage_vps_servers"
    case vpsOverview = "vps_overview"
    case viewAll = "view_all"
    case recentDeployments = "recent_deployments"
    case noDeploymentRecords = "no_deployment_records"
    case quickActions = "quick_actions"
    case systemStatus = "system_status"
    case noSystemStatusData = "no_system_status_data"
    case noVPSYet = "no_vps_yet"
    case addFirstVPSServer = "add_first_vps_server"
    case services = "services"
    case memory = "memory"
    case disk = "disk"
    case systemHealth = "system_health"
    case resourceUsage = "resource_usage"
    case homeViewTitle = "home_view_title"
    case deployTo = "deploy_to"
    
    // VPS Management
    case addVPS = "add_vps"
    case editVPS = "edit_vps"
    case addFirstVPSToStart = "add_first_vps_to_start"
    case testConnection = "test_connection"
    case edit = "edit"
    case getSystemInfo = "get_system_info"
    case delete = "delete"
    case confirmDeleteVPS = "confirm_delete_vps"
    case checkingConnection = "checking_connection"
    case save = "save"
    case validatingVPSConfig = "validating_vps_config"
    case vpsViewTitle = "vps_view_title"
    
    // VPS Detail
    case connectionStatus = "connection_status"
    case needSSHConnection = "need_ssh_connection"
    case systemInfo = "system_info"
    case noSystemInfo = "no_system_info"
    case basicInfo = "basic_info"
    case tags = "tags"
    case operatingSystem = "operating_system"
    case cpuCores = "cpu_cores"
    case loadAverage = "load_average"
    case uptime = "uptime"
    case serviceList = "service_list"
    case noServices = "no_services"
    case connectionTest = "connection_test"
    case pingTest = "ping_test"
    case sshConnection = "ssh_connection"
    case error = "error"
    case noConnectionTest = "no_connection_test"
    case detecting = "detecting"
    case port = "port"
    case deployViewTitle = "deploy_view_title"
    
    // Monitoring
    case refresh = "refresh"
    case autoRefresh = "auto_refresh"
    case noMonitoringData = "no_monitoring_data"
    case addVPSInstanceToMonitor = "add_vps_instance_to_monitor"
    case systemOverview = "system_overview"
    case vpsMonitoring = "vps_monitoring"
    case timeRange = "time_range"
    case cpuUsageChart = "cpu_usage_chart"
    case currentUsage = "current_usage"
    case noData = "no_data"
    case serviceStatus = "service_status"
    case autoRefreshDescription = "auto_refresh_description"
    case monitorViewTitle = "monitor_view_title"
    case cpuUsage = "cpu_usage"
    case memoryUsage = "memory_usage"
    case toggleAutoRefresh = "toggle_auto_refresh"
    case autoRefreshInterval = "auto_refresh_interval"
    case instruction = "instruction"
    case done =  "done"
    case hour = "hour"
    case day = "day"
    case back = "back"
    
    // Deployment
    case confirmDeleteDeployment = "confirm_delete_deployment"
    
    // Common
    case cancel = "cancel"
    case confirm = "confirm"
    case ok = "ok"
    case yes = "yes"
    case no = "no"
    
    // Language Settings
    case languageSettings = "language_settings"
    case appLanguage = "app_language"
    case selectAppLanguage = "select_app_language"
    case currentLanguage = "current_language"
    
    // SingBox Install
    case installInfo = "install_info"
    case installProgress = "install_progress"
    case currentStep = "current_step"
    case installLog = "install_log"
    case installing = "installing"
    case installSuccess = "install_success"
    case singboxInstalledSuccessfully = "singbox_installed_successfully"
    case installFailed = "install_failed"
    
    // Deployment
    case templateDeployment = "template_deployment"
    case aiDeployment = "ai_deployment"
    case deploymentHistory = "deployment_history"
    case aiSmartDeployment = "ai_smart_deployment"
    case aiDeploymentDescription = "ai_deployment_description"
    case selectVPS = "select_vps"
    case noAvailableVPS = "no_available_vps"
    case describeYourNeeds = "describe_your_needs"
    case examples = "examples"
    case deploySingboxProxy = "deploy_singbox_proxy"
    case installWordPress = "install_wordpress"
    case configureDocker = "configure_docker"
    case startFirstDeployment = "start_first_deployment"
    case deploymentTask = "deployment_task"
    case startTime = "start_time"
    case completedTime = "completed_time"
    case commands = "commands"
    case configFiles = "config_files"
    case commandsToExecute = "commands_to_execute"
    case commandsDescription = "commands_description"
    case configFileContent = "config_file_content"
    case configFilesDescription = "config_files_description"
    case noConfigFiles = "no_config_files"
    case commandProgress = "command_progress"
    
    // Quick Deploy
    case deploymentTarget = "deployment_target"
    case selectDeploymentMethod = "select_deployment_method"
    case recommendedTemplates = "recommended_templates"
    case noRecommendedTemplates = "no_recommended_templates"
    case downloads = "downloads"
    case official = "official"
    case officialTemplate = "official_template"
    case selectDeploymentTarget = "select_deployment_target"
    case pleaseAddVPSFirst = "please_add_vps_first"
    case configParameters = "config_parameters"
    case previewCommands = "preview_commands"
    case deploymentCommands = "deployment_commands"
    case pleaseSelectVPS = "please_select_vps"
    case shadowsocksProxy = "shadowsocks_proxy"
    case installNginxReverseProxy = "install_nginx_reverse_proxy"
    
    // AI Analysis
    case aiAnalysis = "ai_analysis"
    case aiGeneratedPlan = "ai_generated_plan"
    case aiAnalyzing = "ai_analyzing"
    case aiAnalyzingNeeds = "ai_analyzing_needs"
    case aiGeneratedCommands = "ai_generated_commands"
    case aiWillAnalyze = "ai_will_analyze"
    
    // System Info
    case cpu = "cpu"
    case targetVPS = "target_vps"
    case vpsNotExists = "vps_not_exists"
    case logs = "logs"
    
    // Settings
    case manageVPSData = "manage_vps_data"
    case exportVPSConfig = "export_vps_config"
    case vpsStatusNotification = "vps_status_notification"
    case autoDisconnectBackground = "auto_disconnect_background"
    case sshTimeout = "ssh_timeout"
    case manageSSHKeys = "manage_ssh_keys"
    case iosVersion = "ios_version"
    case appVersion = "app_version"
    case vpsInstances = "vps_instances"
    case clearAllData = "clear_all_data"
    case clearDataWarning = "clear_data_warning"
    case faceIDTouchID = "face_id_touch_id"
    case vpsManagementTool = "vps_management_tool"
    case appDescription = "app_description"
    case vpsToolsTeam = "vps_tools_team"
    case build = "build"
    case website = "website"
    case email = "email"
    case exportProgress = "export_progress"
    case exportDescription = "export_description"
    case vpsInstanceConfig = "vps_instance_config"
    case importProgress = "import_progress"
    case importDescription = "import_description"
    case termsOfService = "terms_of_service"
    case termsDescription1 = "terms_description_1"
    case termsDescription2 = "terms_description_2"
    case termsDescription3 = "terms_description_3"
    case termsDescription4 = "terms_description_4"
    case settingViewTitle = "setting_view_title"
    case userPolicy = "user_policy"
    case privacyPolicy = "privacy_policy"
    case systemInfoSection = "system_info_section"
    case supportAndFeedback = "support_and_feedback"
    case aboutSection = "about_section"
    case dataStatistics = "data_statistics"
    case dataOperations = "data_operations"
    case clearAllVPSData = "clear_all_vps_data"
    case clearDeploymentHistory = "clear_deployment_history"
    case instructions = "instructions"
    case securityInstructions = "security_instructions"
    case securityInstructionsText = "security_instructions_text"
    case confirmClear = "confirm_clear"
    case clear = "clear"
    case biometricAuthentication = "biometric_authentication"
    case useBiometricToUnlock = "use_biometric_to_unlock"
    case passwordProtection = "password_protection"
    case appPassword = "app_password"
    case setAppAccessPassword = "set_app_access_password"
    case setPassword = "set_password"
    case themeMode = "theme_mode"
    case accentColor = "accent_color"
    case version = "version"
    case developmentInfo = "development_info"
    case developmentTeam = "development_team"
    case buildVersion = "build_version"
    case releaseDate = "release_date"
    case technicalSupport = "technical_support"
    case officialWebsite = "official_website"
    case contactEmail = "contact_email"
    case exportingData = "exporting_data"
    case exportDataTitle = "export_data_title"
    case exportDataDescription = "export_data_description"
    case exportContent = "export_content"
    case deploymentTaskHistory = "deployment_task_history"
    case customDeploymentTemplates = "custom_deployment_templates"
    case appSettings = "app_settings"
    case startExport = "start_export"
    case importingData = "importing_data"
    case importDataTitle = "import_data_title"
    case importDataDescription = "import_data_description"
    case importInstructions = "import_instructions"
    case importWillOverwrite = "import_will_overwrite"
    case ensureBackupComplete = "ensure_backup_complete"
    case importProcessUninterruptible = "import_process_uninterruptible"
    case selectBackupFile = "select_backup_file"
    case termsOfServiceTitle = "terms_of_service_title"
    case termsOfServiceDescription = "terms_of_service_description"
    case serviceDescription = "service_description"
    case userResponsibility = "user_responsibility"
    case userResponsibilityText = "user_responsibility_text"
    case serviceLimitations = "service_limitations"
    case serviceLimitationsText = "service_limitations_text"
    case privacyProtection = "privacy_protection"
    case privacyProtectionText = "privacy_protection_text"
    case privacyPolicyTitle = "privacy_policy_title"
    case privacyPolicyDescription = "privacy_policy_description"
    case informationCollection = "information_collection"
    case informationCollectionDescription = "information_collection_description"
    case appUsageStatistics = "app_usage_statistics"
    case errorReportInformation = "error_report_information"
    case performanceData = "performance_data"
    case informationUsage = "information_usage"
    case informationUsageDescription = "information_usage_description"
    case improveAppFunctionality = "improve_app_functionality"
    case resolveTechnicalIssues = "resolve_technical_issues"
    case provideUserSupport = "provide_user_support"
    case informationProtection = "information_protection"
    case informationProtectionText = "information_protection_text"
    case informationSharing = "information_sharing"
    case informationSharingText = "information_sharing_text"
    case feedbackType = "feedback_type"
    case feedbackTypePicker = "feedback_type_picker"
    case feedbackContent = "feedback_content"
    case contactInfoOptional = "contact_info_optional"
    case emailAddress = "email_address"
    case submitFeedback = "submit_feedback"
    case feedbackTitle = "feedback_title"
    case submitSuccess = "submit_success"
    case submitSuccessMessage = "submit_success_message"
    case feedbackSuggestion = "feedback_suggestion"
    case feedbackBug = "feedback_bug"
    case feedbackFeature = "feedback_feature"
    case feedbackOther = "feedback_other"
    case themeLight = "theme_light"
    case themeDark = "theme_dark"
    case themeSystem = "theme_system"
    case colorBlue = "color_blue"
    case colorGreen = "color_green"
    case colorPurple = "color_purple"
    case colorOrange = "color_orange"
    case colorRed = "color_red"
    case releaseDateValue = "release_date_value"
    case connectionTimeoutValue = "connection_timeout_value"
    case appStatusSection = "app_status_section"
    
    // Additional Settings
    case appStatus = "app_status"
    case lastBackgroundTime = "last_background_time"
    case lastForegroundTime = "last_foreground_time"
    case backgroundDuration = "background_duration"
    case dataManagement = "data_management"
    case exportData = "export_data"
    case importData = "import_data"
    case monitoringSettings = "monitoring_settings"
    case monitoringNotification = "monitoring_notification"
    case sshConnectionManagement = "ssh_connection_management"
    case autoDisconnect = "auto_disconnect"
    case connectionTimeout = "connection_timeout"
    case securitySettings = "security_settings"
    case themeSettings = "theme_settings"
    case fontSize = "font_size"
    case standard = "standard"
    case deviceModel = "device_model"
    case deploymentTasks = "deployment_tasks"
    case deploymentTemplates = "deployment_templates"
    case clearDataWarningIrreversible = "clear_data_warning_irreversible"
    case clearDeploymentHistoryWarning = "clear_deployment_history_warning"
    
    // Time Units
    case seconds = "seconds"
    case minutes = "minutes"
    case secondsShort = "seconds_short"
    case minutesShort = "minutes_short"
    
    // Additional VPS Detail
    case moreServices = "more_services"
    
    // Additional Deployment
    case deploymentInfo = "deployment_info"
    case executionStatus = "execution_status"
    case latestCommandResult = "latest_command_result"
    case preparing = "preparing"
    case executionLog = "execution_log"
    case customDeployment = "custom_deployment"
    case customDeploymentDescription = "custom_deployment_description"
    case environmentVariables = "environment_variables"
    case startDeployment = "start_deployment"
    case customDeploymentExecution = "custom_deployment_execution"
    case executingCustomCommands = "executing_custom_commands"
    case command = "command"
    
    // Home View Status
    case vpsTotal = "vps_total"
    case onlineVPS = "online_vps"
    case customDeploymentStatus = "custom_deployment_status"
    case unknownVPS = "unknown_vps"
    case waiting = "waiting"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    case online = "online"
    case offline = "offline"
    case unknown = "unknown"
    
    // VPS Management
    case all = "all"
    case searchVPS = "search_vps"
    case vpsName = "vps_name"
    case hostAddress = "host_address"
    case username = "username"
    case authMethod = "auth_method"
    case password = "password"
    case privateKey = "private_key"
    case privateKeyPhrase = "private_key_phrase"
    case groupAndTags = "group_and_tags"
    case group = "group"
    case tagsCommaSeparated = "tags_comma_separated"
    case defaultGroup = "default_group"
    case connectionFailed = "connection_failed"
    case connectionFailedCheck = "connection_failed_check"
    case configError = "config_error"
    case saveFailed = "save_failed"
    
    // Additional AI Deployment
    case willExecuteFollowingCommands = "will_execute_following_commands"
    
    func localizedString(for language: Language) -> String {
        let bundle = Bundle.main
        let tableName = language == .chinese ? "Localizable" : "Localizable"
        
        // 根据语言选择不同的本地化字符串
        switch language {
        case .system:
            // 使用系统语言
            return NSLocalizedString(self.rawValue, tableName: tableName, bundle: bundle, comment: "")
        case .chinese:
            return LocalizationKey.chineseStrings[self] ?? self.rawValue
        case .english:
            return LocalizationKey.englishStrings[self] ?? self.rawValue
        }
    }
}

// MARK: - Localization Strings

extension LocalizationKey {
    // 中文字符串
    static var chineseStrings: [LocalizationKey: String] {
        return [
            // Tab Bar
            .home: "首页",
            .vpsManagement: "VPS 管理",
            .smartDeployment: "智能部署",
            .monitoring: "监控",
            .settings: "设置",
            
            // Home View
            .welcomeBack: "欢迎回来",
            .manageVPSServers: "管理您的 VPS 服务器和部署服务",
            .vpsOverview: "VPS 概览",
            .viewAll: "查看全部",
            .recentDeployments: "最近部署",
            .noDeploymentRecords: "暂无部署记录",
            .quickActions: "快速操作",
            .systemStatus: "系统状态",
            .noSystemStatusData: "暂无系统状态数据",
            .noVPSYet: "还没有 VPS",
            .addFirstVPSServer: "添加您的第一个 VPS 服务器",
            .services: "服务",
            .memory: "内存",
            .disk: "磁盘",
            .systemHealth: "系统健康度",
            .resourceUsage: "资源使用",
            .homeViewTitle: "智能 VPS 管理",
            .deployTo: "部署到",
            
            // VPS Management
            .addVPS: "添加 VPS",
            .editVPS: "编辑 VPS",
            .addFirstVPSToStart: "添加您的第一个 VPS 服务器开始管理",
            .testConnection: "测试连接",
            .edit: "编辑",
            .getSystemInfo: "获取系统信息",
            .delete: "删除",
            .confirmDeleteVPS: "确定要删除 VPS \"%@\" 吗？此操作无法撤销。",
            .checkingConnection: "检查连接...",
            .save: "保存",
            .validatingVPSConfig: "正在验证 VPS 配置并测试 SSH 连接",
            .vpsViewTitle: "VPS 管理",
            
            // VPS Detail
            .connectionStatus: "连接状态",
            .needSSHConnection: "需要建立 SSH 连接以获取系统信息",
            .systemInfo: "系统信息",
            .noSystemInfo: "暂无系统信息",
            .basicInfo: "基本信息",
            .tags: "标签",
            .operatingSystem: "操作系统",
            .cpuCores: "核",
            .loadAverage: "负载平均值",
            .uptime: "运行时间",
            .serviceList: "服务列表",
            .noServices: "暂无服务",
            .connectionTest: "连接测试",
            .pingTest: "Ping 测试",
            .sshConnection: "SSH 连接",
            .error: "错误: %@",
            .noConnectionTest: "未进行连接测试",
            .detecting: "检测中...",
            .port: "端口",
            .deployViewTitle: "智能部署",
            
            // Monitoring
            .refresh: "刷新",
            .autoRefresh: "自动刷新",
            .noMonitoringData: "暂无监控数据",
            .addVPSInstanceToMonitor: "添加 VPS 实例后即可开始监控",
            .systemOverview: "系统概览",
            .vpsMonitoring: "VPS 监控",
            .timeRange: "时间范围",
            .cpuUsageChart: "CPU 使用率图表",
            .currentUsage: "当前使用率",
            .noData: "暂无数据",
            .serviceStatus: "服务状态",
            .autoRefreshDescription: "自动刷新会定期更新 VPS 状态和系统信息，可能会消耗一定的网络流量。",
            .monitorViewTitle: "监控中心",
            .cpuUsage: "平均 CPU",
            .memoryUsage: "平均内存",
            .toggleAutoRefresh: "启用自动刷新",
            .autoRefreshInterval: "刷新间隔",
            .instruction: "说明",
            .done: "完成",
            .hour: "小时",
            .day: "天",
            .back: "返回",
            
            // Deployment
            .confirmDeleteDeployment: "确定要删除这个部署任务吗？此操作无法撤销。",
            
            // Common
            .cancel: "取消",
            .confirm: "确认",
            .ok: "确定",
            .yes: "是",
            .no: "否",
            
            // Language Settings
            .languageSettings: "语言设置",
            .appLanguage: "应用语言",
            .selectAppLanguage: "选择应用显示语言",
            .currentLanguage: "当前语言",
            
            // SingBox Install
            .installInfo: "安装信息",
            .installProgress: "安装进度",
            .currentStep: "当前步骤:",
            .installLog: "安装日志",
            .installing: "正在安装...",
            .installSuccess: "安装成功",
            .singboxInstalledSuccessfully: "SingBox已成功安装并启动",
            .installFailed: "安装失败",
            
            // Deployment
            .templateDeployment: "模板部署",
            .aiDeployment: "AI 部署",
            .deploymentHistory: "部署历史",
            .aiSmartDeployment: "AI 智能部署",
            .aiDeploymentDescription: "用自然语言描述您的需求，AI 将自动生成部署方案",
            .selectVPS: "选择 VPS",
            .noAvailableVPS: "没有可用的 VPS",
            .describeYourNeeds: "描述您的需求",
            .examples: "示例",
            .deploySingboxProxy: "• 部署一个 sing-box 代理服务器",
            .installWordPress: "• 安装 WordPress 博客系统",
            .configureDocker: "• 配置 Docker 环境",
            .startFirstDeployment: "开始您的第一次部署",
            .deploymentTask: "部署任务 #%@",
            .startTime: "开始时间: ",
            .completedTime: "完成时间: ",
            .commands: "命令",
            .configFiles: "配置文件",
            .commandsToExecute: "将要执行的命令",
            .commandsDescription: "以下命令将在目标 VPS 上按顺序执行",
            .configFileContent: "配置文件内容",
            .configFilesDescription: "以下配置文件将被生成并部署到目标 VPS",
            .noConfigFiles: "无配置文件",
            .commandProgress: "命令 %@/%@",
            
            // Quick Deploy
            .deploymentTarget: "部署目标",
            .selectDeploymentMethod: "选择部署方式",
            .recommendedTemplates: "推荐模板",
            .noRecommendedTemplates: "暂无推荐模板",
            .downloads: "次下载",
            .official: "官方",
            .officialTemplate: "官方模板",
            .selectDeploymentTarget: "选择部署目标",
            .pleaseAddVPSFirst: "请先添加 VPS 实例才能进行部署",
            .configParameters: "配置参数",
            .previewCommands: "预览命令",
            .deploymentCommands: "部署命令",
            .pleaseSelectVPS: "请先选择一个 VPS 实例",
            .shadowsocksProxy: "• 部署一个 Shadowsocks 代理服务器",
            .installNginxReverseProxy: "• 安装 Nginx 并配置反向代理",
            
            // AI Analysis
            .aiAnalysis: "AI 智能分析",
            .aiGeneratedPlan: "AI 生成的部署计划",
            .aiAnalyzing: "AI 正在分析需求...",
            .aiAnalyzingNeeds: "AI 正在分析您的需求...",
            .aiGeneratedCommands: "AI 生成的命令",
            .aiWillAnalyze: "AI 将分析您的需求并生成部署命令",
            
            // System Info
            .cpu: "CPU",
            .targetVPS: "目标 VPS",
            .vpsNotExists: "VPS 不存在或已被删除",
            .logs: "条",
            
            // Settings
            .manageVPSData: "管理 VPS 实例和部署数据",
            .exportVPSConfig: "导出 VPS 配置和部署历史",
            .vpsStatusNotification: "VPS 状态变化时发送通知",
            .autoDisconnectBackground: "应用进入后台时自动断开 SSH 连接",
            .sshTimeout: "SSH 连接超时时间",
            .manageSSHKeys: "管理 SSH 密钥",
            .iosVersion: "iOS 版本",
            .appVersion: "1.0.0 (Build 1)",
            .vpsInstances: "VPS 实例",
            .clearAllData: "清除所有数据",
            .clearDataWarning: "这将清除所有 VPS 实例数据，此操作不可恢复。",
            .faceIDTouchID: "Face ID / Touch ID",
            .vpsManagementTool: "VPS 管理工具",
            .appDescription: "专业的 VPS 服务器管理工具，提供便捷的部署、监控和管理功能。",
            .vpsToolsTeam: "VPS Tools Team",
            .build: "Build 1",
            .website: "https://selfhost.vip/vpstools",
            .email: "clap@clap.top",
            .exportProgress: "导出进度: %@%%",
            .exportDescription: "将 VPS 配置和部署历史导出为备份文件",
            .vpsInstanceConfig: "• VPS 实例配置",
            .importProgress: "导入进度: %@%%",
            .importDescription: "从备份文件恢复 VPS 配置和部署历史",
            .termsOfService: "欢迎使用 VPS 管理工具。请仔细阅读以下使用条款。",
            .termsDescription1: "本应用提供 VPS 服务器管理功能，包括部署、监控、连接等操作。",
            .termsDescription2: "用户应妥善保管 VPS 登录凭据，不得将敏感信息泄露给第三方。",
            .termsDescription3: "本应用仅提供管理工具，不承担因 VPS 操作造成的任何损失。",
            .termsDescription4: "使用本应用即表示同意以上条款。",
            .settingViewTitle: "设置",
            .userPolicy: "使用条款",
            .privacyPolicy: "隐私政策",
            .systemInfoSection: "系统信息",
            .supportAndFeedback: "支持与反馈",
            .aboutSection: "关于",
            .dataStatistics: "数据统计",
            .dataOperations: "数据操作",
            .clearAllVPSData: "清除所有 VPS 数据",
            .clearDeploymentHistory: "清除部署历史",
            .instructions: "说明",
            .securityInstructions: "说明",
            .securityInstructionsText: "启用安全功能后，每次打开应用都需要验证身份。",
            .confirmClear: "确认清除",
            .clear: "清除",
            .biometricAuthentication: "生物识别",
            .useBiometricToUnlock: "使用生物识别解锁应用",
            .passwordProtection: "密码保护",
            .appPassword: "应用密码",
            .setAppAccessPassword: "设置应用访问密码",
            .setPassword: "设置密码",
            .themeMode: "主题模式",
            .accentColor: "强调色",
            .version: "版本 1.0.0",
            .developmentInfo: "开发信息",
            .developmentTeam: "开发团队",
            .buildVersion: "构建版本",
            .releaseDate: "发布日期",
            .technicalSupport: "技术支持",
            .officialWebsite: "官方网站",
            .contactEmail: "联系邮箱",
            .exportingData: "正在导出数据...",
            .exportDataTitle: "导出数据",
            .exportDataDescription: "将 VPS 配置和部署历史导出为备份文件",
            .exportContent: "导出内容包括：",
            .deploymentTaskHistory: "• 部署任务历史",
            .customDeploymentTemplates: "• 自定义部署模板",
            .appSettings: "• 应用设置",
            .startExport: "开始导出",
            .importingData: "正在导入数据...",
            .importDataTitle: "导入数据",
            .importDataDescription: "从备份文件恢复 VPS 配置和部署历史",
            .importInstructions: "导入说明：",
            .importWillOverwrite: "• 导入将覆盖现有数据",
            .ensureBackupComplete: "• 请确保备份文件完整",
            .importProcessUninterruptible: "• 导入过程不可中断",
            .selectBackupFile: "选择备份文件",
            .termsOfServiceTitle: "使用条款",
            .termsOfServiceDescription: "欢迎使用 VPS 管理工具。请仔细阅读以下使用条款。",
            .serviceDescription: "1. 服务说明",
            .userResponsibility: "2. 用户责任",
            .userResponsibilityText: "用户应妥善保管 VPS 登录凭据，不得将敏感信息泄露给第三方。",
            .serviceLimitations: "3. 服务限制",
            .serviceLimitationsText: "本应用仅提供管理工具，不承担因 VPS 操作造成的任何损失。",
            .privacyProtection: "4. 隐私保护",
            .privacyProtectionText: "我们承诺保护用户隐私，不会收集或泄露用户的敏感信息。",
            .privacyPolicyTitle: "隐私政策",
            .privacyPolicyDescription: "我们重视您的隐私，本政策说明了我们如何收集、使用和保护您的信息。",
            .informationCollection: "信息收集",
            .informationCollectionDescription: "我们仅收集必要的应用使用数据，包括：",
            .appUsageStatistics: "• 应用使用统计",
            .errorReportInformation: "• 错误报告信息",
            .performanceData: "• 性能数据",
            .informationUsage: "信息使用",
            .informationUsageDescription: "收集的信息仅用于：",
            .improveAppFunctionality: "• 改进应用功能",
            .resolveTechnicalIssues: "• 解决技术问题",
            .provideUserSupport: "• 提供用户支持",
            .informationProtection: "信息保护",
            .informationProtectionText: "我们采用行业标准的安全措施保护您的信息，包括加密存储和传输。",
            .informationSharing: "信息共享",
            .informationSharingText: "我们不会向第三方出售、交易或转让您的个人信息。",
            .feedbackType: "反馈类型",
            .feedbackTypePicker: "类型",
            .feedbackContent: "反馈内容",
            .contactInfoOptional: "联系方式（可选）",
            .emailAddress: "邮箱地址",
            .submitFeedback: "提交反馈",
            .feedbackTitle: "意见反馈",
            .submitSuccess: "提交成功",
            .submitSuccessMessage: "感谢您的反馈，我们会认真考虑您的建议。",
            .feedbackSuggestion: "建议",
            .feedbackBug: "问题反馈",
            .feedbackFeature: "功能请求",
            .feedbackOther: "其他",
            .themeLight: "浅色",
            .themeDark: "深色",
            .themeSystem: "跟随系统",
            .colorBlue: "蓝色",
            .colorGreen: "绿色",
            .colorPurple: "紫色",
            .colorOrange: "橙色",
            .colorRed: "红色",
            .releaseDateValue: "2025年8月",
            .connectionTimeoutValue: "30秒",
            .appStatusSection: "应用状态",
            
            // Additional Settings
            .appStatus: "应用状态",
            .lastBackgroundTime: "最后进入后台",
            .lastForegroundTime: "最后进入前台",
            .backgroundDuration: "后台持续时间",
            .dataManagement: "数据管理",
            .exportData: "导出数据",
            .importData: "导入数据",
            .monitoringSettings: "监控设置",
            .monitoringNotification: "监控通知",
            .sshConnectionManagement: "SSH 连接管理",
            .autoDisconnect: "自动断开连接",
            .connectionTimeout: "连接超时",
            .securitySettings: "安全设置",
            .themeSettings: "主题设置",
            .fontSize: "字体大小",
            .standard: "标准",
            .deviceModel: "设备型号",
            .deploymentTasks: "部署任务",
            .deploymentTemplates: "部署模板",
            .clearDataWarningIrreversible: "清除数据操作不可恢复，请谨慎操作。",
            .clearDeploymentHistoryWarning: "这将清除所有部署历史记录，此操作不可恢复。",
            
            // Time Units
            .seconds: "秒",
            .minutes: "分钟",
            .secondsShort: "秒",
            .minutesShort: "分钟",
            
            // Additional VPS Detail
            .moreServices: "还有 %@ 个服务...",
            
            // Additional Deployment
            .deploymentInfo: "部署信息",
            .executionStatus: "执行状态",
            .latestCommandResult: "最新命令结果:",
            .preparing: "准备中...",
            .executionLog: "执行日志",
            .customDeployment: "自定义部署",
            .customDeploymentDescription: "手动配置部署命令和参数",
            .environmentVariables: "环境变量",
            .startDeployment: "开始部署",
            .customDeploymentExecution: "自定义部署执行",
            .executingCustomCommands: "正在执行自定义命令...",
            .command: "命令:",
            
            // Additional AI Deployment
            .willExecuteFollowingCommands: "将执行以下命令：",
            
            // Home View Status
            .vpsTotal: "VPS 总数",
            .onlineVPS: "在线 VPS",
            .customDeploymentStatus: "自定义部署",
            .unknownVPS: "未知 VPS",
            .waiting: "等待中",
            .running: "运行中",
            .completed: "已完成",
            .failed: "失败",
            .cancelled: "已取消",
            .online: "在线",
            .offline: "离线",
            .unknown: "未知",
            
            // VPS Management
            .all: "全部",
            .searchVPS: "搜索 VPS...",
            .vpsName: "VPS 名称",
            .hostAddress: "主机地址",
            .username: "用户名",
            .authMethod: "认证方式",
            .password: "密码",
            .privateKey: "SSH 密钥",
            .privateKeyPhrase: "密钥密码(可选)",
            .groupAndTags: "分组和标签",
            .group: "分组",
            .tagsCommaSeparated: "标签（用逗号分隔）",
            .defaultGroup: "默认分组",
            .connectionFailed: "连接失败：%@\n\n请检查：\n• 主机地址是否正确\n• 端口是否开放\n• 用户名和密码是否正确\n• 网络连接是否正常",
            .connectionFailedCheck: "连接失败：%@\n\n请检查：\n• 主机地址是否正确\n• 端口是否开放\n• 用户名和密码是否正确\n• 网络连接是否正常",
            .configError: "配置错误：%@",
            .saveFailed: "保存失败：%@"
        ]
    }
    
    // 英文字符串
    static var englishStrings: [LocalizationKey: String] {
        return [
            // Tab Bar
            .home: "Home",
            .vpsManagement: "VPS Management",
            .smartDeployment: "Smart Deployment",
            .monitoring: "Monitoring",
            .settings: "Settings",
            
            
            // Home View
            .welcomeBack: "Welcome Back",
            .manageVPSServers: "Manage your VPS servers and deployment services",
            .vpsOverview: "VPS Overview",
            .viewAll: "View All",
            .recentDeployments: "Recent Deployments",
            .noDeploymentRecords: "No deployment records",
            .quickActions: "Quick Actions",
            .systemStatus: "System Status",
            .noSystemStatusData: "No system status data",
            .noVPSYet: "No VPS yet",
            .addFirstVPSServer: "Add your first VPS server",
            .services: "Services",
            .memory: "Memory",
            .disk: "Disk",
            .systemHealth: "System Health",
            .resourceUsage: "Resource Usage",
            .homeViewTitle: "Smart VPS Management",
            .deployTo: "Deploy to",
            
            // VPS Management
            .addVPS: "Add VPS",
            .editVPS: "Edit VPS",
            .addFirstVPSToStart: "Add your first VPS server to start managing",
            .testConnection: "Test Connection",
            .edit: "Edit",
            .getSystemInfo: "Get System Info",
            .delete: "Delete",
            .confirmDeleteVPS: "Are you sure you want to delete VPS \"%@\"? This action cannot be undone.",
            .checkingConnection: "Checking connection...",
            .save: "Save",
            .validatingVPSConfig: "Validating VPS configuration and testing SSH connection",
            .vpsViewTitle: "VPS Management",
            
            // VPS Detail
            .connectionStatus: "Connection Status",
            .needSSHConnection: "SSH connection needed to get system information",
            .systemInfo: "System Information",
            .noSystemInfo: "No system information",
            .basicInfo: "Basic Information",
            .tags: "Tags",
            .operatingSystem: "Operating System",
            .cpuCores: "cores",
            .loadAverage: "Load Average",
            .uptime: "Uptime",
            .serviceList: "Service List",
            .noServices: "No services",
            .connectionTest: "Connection Test",
            .pingTest: "Ping Test",
            .sshConnection: "SSH Connection",
            .error: "Error: %@",
            .noConnectionTest: "No connection test performed",
            .detecting: "Detecting...",
            .port: "Port",
            .deployViewTitle: "Smart Deployment",
            
            // Monitoring
            .refresh: "Refresh",
            .autoRefresh: "Auto Refresh",
            .noMonitoringData: "No monitoring data",
            .addVPSInstanceToMonitor: "Add VPS instances to start monitoring",
            .systemOverview: "System Overview",
            .vpsMonitoring: "VPS Monitoring",
            .timeRange: "Time Range",
            .cpuUsageChart: "CPU Usage Chart",
            .currentUsage: "Current Usage",
            .noData: "No data",
            .serviceStatus: "Service Status",
            .autoRefreshDescription: "Auto refresh will periodically update VPS status and system information, which may consume some network traffic.",
            .monitorViewTitle: "Monitoring Center",
            .cpuUsage: "CPU Usage",
            .memoryUsage: "Memory Usage",
            .toggleAutoRefresh: "Enable Auto Refresh",
            .autoRefreshInterval: "Refresh Interval",
            .instruction: "Instruction",
            .done: "Done",
            .hour: "Hours",
            .day: "Days",
            .back: "Back",
            
            // Deployment
            .confirmDeleteDeployment: "Are you sure you want to delete this deployment task? This action cannot be undone.",
            
            // Common
            .cancel: "Cancel",
            .confirm: "Confirm",
            .feedbackSuggestion: "Suggestion",
            .feedbackBug: "Bug Report",
            .feedbackFeature: "Feature Request",
            .feedbackOther: "Other",
            .themeLight: "Light",
            .themeDark: "Dark",
            .themeSystem: "System",
            .colorBlue: "Blue",
            .colorGreen: "Green",
            .colorPurple: "Purple",
            .colorOrange: "Orange",
            .colorRed: "Red",
            .releaseDateValue: "August 2025",
            .connectionTimeoutValue: "30s",
            .appStatusSection: "App Status",
            .ok: "OK",
            .yes: "Yes",
            .no: "No",
            
            // Language Settings
            .languageSettings: "Language Settings",
            .appLanguage: "App Language",
            .selectAppLanguage: "Select app display language",
            .currentLanguage: "Current Language",
            
            // SingBox Install
            .installInfo: "Installation Info",
            .installProgress: "Installation Progress",
            .currentStep: "Current Step:",
            .installLog: "Installation Log",
            .installing: "Installing...",
            .installSuccess: "Installation Successful",
            .singboxInstalledSuccessfully: "SingBox has been successfully installed and started",
            .installFailed: "Installation Failed",
            
            // Deployment
            .templateDeployment: "Template",
            .aiDeployment: "AI Deployment",
            .deploymentHistory: "Deployment History",
            .aiSmartDeployment: "AI Smart Deployment",
            .aiDeploymentDescription: "Describe your requirements in natural language, AI will automatically generate deployment plans",
            .selectVPS: "Select VPS",
            .noAvailableVPS: "No available VPS",
            .describeYourNeeds: "Describe your needs",
            .examples: "Examples",
            .deploySingboxProxy: "• Deploy a sing-box proxy server",
            .installWordPress: "• Install WordPress blog system",
            .configureDocker: "• Configure Docker environment",
            .startFirstDeployment: "Start your first deployment",
            .deploymentTask: "Deployment Task #%@",
            .startTime: "Start Time: ",
            .completedTime: "Completed Time: ",
            .commands: "Commands",
            .configFiles: "Config Files",
            .commandsToExecute: "Commands to execute",
            .commandsDescription: "The following commands will be executed sequentially on the target VPS",
            .configFileContent: "Config file content",
            .configFilesDescription: "The following config files will be generated and deployed to the target VPS",
            .noConfigFiles: "No config files",
            .commandProgress: "Command %@/%@",
            
            // Quick Deploy
            .deploymentTarget: "Deployment Target",
            .selectDeploymentMethod: "Select Deployment Method",
            .recommendedTemplates: "Recommended Templates",
            .noRecommendedTemplates: "No recommended templates",
            .downloads: "downloads",
            .official: "Official",
            .officialTemplate: "Official Template",
            .selectDeploymentTarget: "Select Deployment Target",
            .pleaseAddVPSFirst: "Please add VPS instances first to deploy",
            .configParameters: "Config Parameters",
            .previewCommands: "Preview Commands",
            .deploymentCommands: "Deployment Commands",
            .pleaseSelectVPS: "Please select a VPS instance first",
            .shadowsocksProxy: "• Deploy a Shadowsocks proxy server",
            .installNginxReverseProxy: "• Install Nginx and configure reverse proxy",
            
            // AI Analysis
            .aiAnalysis: "AI Analysis",
            .aiGeneratedPlan: "AI Generated Plan",
            .aiAnalyzing: "AI is analyzing requirements...",
            .aiAnalyzingNeeds: "AI is analyzing your needs...",
            .aiGeneratedCommands: "AI Generated Commands",
            .aiWillAnalyze: "AI will analyze your needs and generate deployment commands",
            
            // System Info
            .cpu: "CPU",
            .targetVPS: "Target VPS",
            .vpsNotExists: "VPS does not exist or has been deleted",
            .logs: "logs",
            
            // Settings
            .manageVPSData: "Manage VPS instances and deployment data",
            .exportVPSConfig: "Export VPS configuration and deployment history",
            .vpsStatusNotification: "Send notifications when VPS status changes",
            .autoDisconnectBackground: "Automatically disconnect SSH connections when app goes to background",
            .sshTimeout: "SSH connection timeout",
            .manageSSHKeys: "Manage SSH Keys",
            .iosVersion: "iOS Version",
            .appVersion: "1.0.0 (Build 1)",
            .vpsInstances: "VPS Instances",
            .clearAllData: "Clear All Data",
            .clearDataWarning: "This will clear all VPS instance data. This action cannot be undone.",
            .faceIDTouchID: "Face ID / Touch ID",
            .vpsManagementTool: "VPS Management Tool",
            .appDescription: "Professional VPS server management tool providing convenient deployment, monitoring and management features.",
            .vpsToolsTeam: "VPS Tools Team",
            .build: "Build 1",
            .website: "https://selfhost.vip/vpstools",
            .email: "clap@clap.top",
            .exportProgress: "Export Progress: %@%%",
            .exportDescription: "Export VPS configuration and deployment history as backup file",
            .vpsInstanceConfig: "• VPS instance configuration",
            .importProgress: "Import Progress: %@%%",
            .importDescription: "Restore VPS configuration and deployment history from backup file",
            .termsOfService: "Welcome to VPS Management Tool. Please read the following terms of service carefully.",
            .termsDescription1: "This app provides VPS server management features including deployment, monitoring, connection and other operations.",
            .termsDescription2: "Users should properly keep VPS login credentials and not disclose sensitive information to third parties.",
            .termsDescription3: "This app only provides management tools and does not bear any losses caused by VPS operations.",
            .termsDescription4: "Using this app indicates agreement to the above terms.",
            .settingViewTitle: "Settings",
            .userPolicy: "User Policy",
            .privacyPolicy: "Privacy Policy",
            .systemInfoSection: "System Information",
            .supportAndFeedback: "Support & Feedback",
            .aboutSection: "About",
            .dataStatistics: "Data Statistics",
            .dataOperations: "Data Operations",
            .clearAllVPSData: "Clear All VPS Data",
            .clearDeploymentHistory: "Clear Deployment History",
            .instructions: "Instructions",
            .securityInstructions: "Instructions",
            .securityInstructionsText: "After enabling security features, identity verification will be required each time the app is opened.",
            .confirmClear: "Confirm Clear",
            .clear: "Clear",
            .biometricAuthentication: "Biometric Authentication",
            .useBiometricToUnlock: "Use biometric authentication to unlock the app",
            .passwordProtection: "Password Protection",
            .appPassword: "App Password",
            .setAppAccessPassword: "Set app access password",
            .setPassword: "Set Password",
            .themeMode: "Theme Mode",
            .accentColor: "Accent Color",
            .version: "Version 1.0.0",
            .developmentInfo: "Development Info",
            .developmentTeam: "Development Team",
            .buildVersion: "Build Version",
            .releaseDate: "Release Date",
            .technicalSupport: "Technical Support",
            .officialWebsite: "Official Website",
            .contactEmail: "Contact Email",
            .exportingData: "Exporting data...",
            .exportDataTitle: "Export Data",
            .exportDataDescription: "Export VPS configuration and deployment history as backup file",
            .exportContent: "Export content includes:",
            .deploymentTaskHistory: "• Deployment task history",
            .customDeploymentTemplates: "• Custom deployment templates",
            .appSettings: "• App settings",
            .startExport: "Start Export",
            .importingData: "Importing data...",
            .importDataTitle: "Import Data",
            .importDataDescription: "Restore VPS configuration and deployment history from backup file",
            .importInstructions: "Import instructions:",
            .importWillOverwrite: "• Import will overwrite existing data",
            .ensureBackupComplete: "• Please ensure backup file is complete",
            .importProcessUninterruptible: "• Import process cannot be interrupted",
            .selectBackupFile: "Select Backup File",
            .termsOfServiceTitle: "Terms of Service",
            .termsOfServiceDescription: "Welcome to VPS Management Tool. Please read the following terms of service carefully.",
            .serviceDescription: "1. Service Description",
            .userResponsibility: "2. User Responsibility",
            .userResponsibilityText: "Users should properly keep VPS login credentials and not disclose sensitive information to third parties.",
            .serviceLimitations: "3. Service Limitations",
            .serviceLimitationsText: "This app only provides management tools and does not bear any losses caused by VPS operations.",
            .privacyProtection: "4. Privacy Protection",
            .privacyProtectionText: "We commit to protecting user privacy and will not collect or disclose users' sensitive information.",
            .privacyPolicyTitle: "Privacy Policy",
            .privacyPolicyDescription: "We value your privacy. This policy explains how we collect, use, and protect your information.",
            .informationCollection: "Information Collection",
            .informationCollectionDescription: "We only collect necessary app usage data, including:",
            .appUsageStatistics: "• App usage statistics",
            .errorReportInformation: "• Error report information",
            .performanceData: "• Performance data",
            .informationUsage: "Information Usage",
            .informationUsageDescription: "Collected information is only used for:",
            .improveAppFunctionality: "• Improving app functionality",
            .resolveTechnicalIssues: "• Resolving technical issues",
            .provideUserSupport: "• Providing user support",
            .informationProtection: "Information Protection",
            .informationProtectionText: "We use industry-standard security measures to protect your information, including encrypted storage and transmission.",
            .informationSharing: "Information Sharing",
            .informationSharingText: "We will not sell, trade, or transfer your personal information to third parties.",
            .feedbackType: "Feedback Type",
            .feedbackTypePicker: "Type",
            .feedbackContent: "Feedback Content",
            .contactInfoOptional: "Contact Info (Optional)",
            .emailAddress: "Email Address",
            .submitFeedback: "Submit Feedback",
            .feedbackTitle: "Feedback",
            .submitSuccess: "Submit Success",
            .submitSuccessMessage: "Thank you for your feedback. We will carefully consider your suggestions.",
            
            // Additional Settings
            .appStatus: "App Status",
            .lastBackgroundTime: "Last Background Time",
            .lastForegroundTime: "Last Foreground Time",
            .backgroundDuration: "Background Duration",
            .dataManagement: "Data Management",
            .exportData: "Export Data",
            .importData: "Import Data",
            .monitoringSettings: "Monitoring Settings",
            .monitoringNotification: "Monitoring Notification",
            .sshConnectionManagement: "SSH Connection Management",
            .autoDisconnect: "Auto Disconnect",
            .connectionTimeout: "Connection Timeout",
            .securitySettings: "Security Settings",
            .themeSettings: "Theme Settings",
            .fontSize: "Font Size",
            .standard: "Standard",
            .deviceModel: "Device Model",
            .deploymentTasks: "Deployment Tasks",
            .deploymentTemplates: "Deployment Templates",
            .clearDataWarningIrreversible: "Clear data operation is irreversible, please proceed with caution.",
            .clearDeploymentHistoryWarning: "This will clear all deployment history records. This action cannot be undone.",
            
            // Time Units
            .seconds: "seconds",
            .minutes: "minutes",
            .secondsShort: "s",
            .minutesShort: "m",
            
            // Additional VPS Detail
            .moreServices: "%@ more services...",
            
            // Additional Deployment
            .deploymentInfo: "Deployment Info",
            .executionStatus: "Execution Status",
            .latestCommandResult: "Latest command result:",
            .preparing: "Preparing...",
            .executionLog: "Execution Log",
            .customDeployment: "Custom Deployment",
            .customDeploymentDescription: "Manually configure deployment commands and parameters",
            .environmentVariables: "Environment Variables",
            .startDeployment: "Start Deployment",
            .customDeploymentExecution: "Custom Deployment Execution",
            .executingCustomCommands: "Executing custom commands...",
            .command: "Command:",
            
            // Additional AI Deployment
            .willExecuteFollowingCommands: "Will execute the following commands:",
            
            // Home View Status
            .vpsTotal: "Total VPS",
            .onlineVPS: "Online VPS",
            .customDeploymentStatus: "Custom Deployment",
            .unknownVPS: "Unknown VPS",
            .waiting: "Waiting",
            .running: "Running",
            .completed: "Completed",
            .failed: "Failed",
            .cancelled: "Cancelled",
            .online:  "Online",
            .offline: "Offline",
            .unknown: "Unknown",
            
            // VPS Management
            .all: "All",
            .searchVPS: "Search VPS...",
            .vpsName: "VPS Name",
            .hostAddress: "Host Address",
            .username: "Username",
            .authMethod: "Auth Method",
            .password: "Password",
            .privateKey: "SSH Key",
            .privateKeyPhrase: "SSH Key Password(Optional)",
            .groupAndTags: "Group & Tags",
            .group: "Group",
            .tagsCommaSeparated: "Tags (comma separated)",
            .defaultGroup: "Default Group",
            .connectionFailed: "Connection failed: %@\n\nPlease check:\n• Host address is correct\n• Port is open\n• Username and password are correct\n• Network connection is normal",
            .connectionFailedCheck: "Connection failed: %@\n\nPlease check:\n• Host address is correct\n• Port is open\n• Username and password are correct\n• Network connection is normal",
            .configError: "Configuration error: %@",
            .saveFailed: "Save failed: %@"
        ]
    }
}

// MARK: - Localized Text Extension

extension Text {
    init(_ key: LocalizationKey) {
        self.init(LocalizationManager.shared.localizedString(key))
    }
    
    init(_ key: LocalizationKey, arguments: CVarArg...) {
        let format = LocalizationManager.shared.localizedString(key)
        self.init(String(format: format, arguments: arguments))
    }
}

// MARK: - Localized String Extension

extension String {
    init(_ key: LocalizationKey) {
        self = LocalizationManager.shared.localizedString(key)
    }
    
    init(_ key: LocalizationKey, arguments: CVarArg...) {
        let format = LocalizationManager.shared.localizedString(key)
        self = String(format: format, arguments: arguments)
    }
}
