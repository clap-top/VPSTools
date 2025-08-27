import Foundation
import SwiftUI
import Combine

// MARK: - App Lifecycle Manager

/// 应用生命周期管理器
/// 负责监听应用状态变化，在应用进入后台时自动断开 SSH 连接
@MainActor
class AppLifecycleManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAppActive: Bool = true
    @Published var lastBackgroundTime: Date?
    @Published var lastForegroundTime: Date?
    @Published var backgroundDuration: TimeInterval = 0
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var backgroundStartTime: Date?
    
    // 服务引用
    private weak var vpsManager: VPSManager?
    private weak var deploymentService: DeploymentService?
    
    // 配置
    private let autoDisconnectOnBackground: Bool = true
    private let backgroundDisconnectDelay: TimeInterval = 1.0 // 1秒后断开连接
    
    // MARK: - Initialization
    
    init() {
        setupNotificationObservers()
        print("AppLifecycleManager initialized")
    }
    
    deinit {
        // 在 deinit 中不能调用异步方法，所以只清理通知观察者
        cancellables.removeAll()
        print("AppLifecycleManager deinitialized")
    }
    
    // MARK: - Public Methods
    
    /// 设置服务引用
    func setServices(vpsManager: VPSManager, deploymentService: DeploymentService) {
        self.vpsManager = vpsManager
        self.deploymentService = deploymentService
        print("AppLifecycleManager: Services configured")
    }
    
    /// 手动断开所有 SSH 连接
    func disconnectAllSSHConnections() async {
        print("AppLifecycleManager: Manually disconnecting all SSH connections")
        
        // 断开 VPSManager 中的 SSH 连接
        if let vpsManager = vpsManager {
            await vpsManager.disconnectAllSSHClients()
        }
        
        // 断开 DeploymentService 中的 SSH 连接
        if let deploymentService = deploymentService {
            await deploymentService.disconnectSSH()
        }
    }
    
    /// 获取应用状态信息
    func getAppStatusInfo() -> AppStatusInfo {
        return AppStatusInfo(
            isActive: isAppActive,
            lastBackgroundTime: lastBackgroundTime,
            lastForegroundTime: lastForegroundTime,
            backgroundDuration: backgroundDuration,
            autoDisconnectEnabled: autoDisconnectOnBackground
        )
    }
    
    // MARK: - Private Methods
    
    /// 设置通知观察者
    private func setupNotificationObservers() {
        // 应用进入后台
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppDidEnterBackground()
                }
            }
            .store(in: &cancellables)
        
        // 应用进入前台
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppWillEnterForeground()
                }
            }
            .store(in: &cancellables)
        
        // 应用即将终止
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppWillTerminate()
                }
            }
            .store(in: &cancellables)
        
        // 应用内存警告
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.handleAppDidReceiveMemoryWarning()
                }
            }
            .store(in: &cancellables)
        
        print("AppLifecycleManager: Notification observers setup completed")
    }
    
    /// 移除通知观察者
    private func removeNotificationObservers() {
        cancellables.removeAll()
        print("AppLifecycleManager: Notification observers removed")
    }
    
    /// 处理应用进入后台
    private func handleAppDidEnterBackground() async {
        print("AppLifecycleManager: App did enter background")
        
        isAppActive = false
        backgroundStartTime = Date()
        lastBackgroundTime = Date()
        
        // 如果启用了自动断开连接
        if autoDisconnectOnBackground {
            // 延迟断开连接，给用户一些时间快速切换回应用
            Task {
                try? await Task.sleep(nanoseconds: UInt64(backgroundDisconnectDelay * 1_000_000_000))
                
                // 再次检查应用是否仍在后台
                if !isAppActive {
                    print("AppLifecycleManager: Auto-disconnecting SSH connections after background delay")
                    vpsManager?.stopAllMonitoring()
                    await disconnectAllSSHConnections()
                }
            }
        }
    }
    
    /// 处理应用进入前台
    private func handleAppWillEnterForeground() async {
        print("AppLifecycleManager: App will enter foreground")
        
        isAppActive = true
        lastForegroundTime = Date()
        
        // 计算后台持续时间
        if let startTime = backgroundStartTime {
            backgroundDuration = Date().timeIntervalSince(startTime)
            backgroundStartTime = nil
        }
        
        print("AppLifecycleManager: App was in background for \(String(format: "%.1f", backgroundDuration)) seconds")
        
        // 如果后台时间超过30秒，重新初始化连接状态
        if backgroundDuration > 30 {
            print("AppLifecycleManager: Background duration > 30s, reinitializing connection state")
            await reinitializeConnectionState()
        }
    }
    
    /// 处理应用即将终止
    private func handleAppWillTerminate() async {
        print("AppLifecycleManager: App will terminate")
        
        // 立即断开所有 SSH 连接
        await disconnectAllSSHConnections()
    }
    
    /// 处理应用内存警告
    private func handleAppDidReceiveMemoryWarning() async {
        print("AppLifecycleManager: App did receive memory warning")
        
        // 在内存警告时也断开 SSH 连接以释放资源
        if !isAppActive {
            await disconnectAllSSHConnections()
        }
    }
    
    /// 重新初始化连接状态
    private func reinitializeConnectionState() async {
        print("AppLifecycleManager: Reinitializing connection state")
        
        // 确保所有连接都已断开
        await disconnectAllSSHConnections()
        
        // 等待一小段时间确保清理完成
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
        
        // 重新初始化VPSManager状态
        if let vpsManager = vpsManager {
            // 重置连接状态
            await vpsManager.resetConnectionStates()
        }
        
        print("AppLifecycleManager: Connection state reinitialized")
    }
}

// MARK: - Supporting Types

/// 应用状态信息
struct AppStatusInfo {
    let isActive: Bool
    let lastBackgroundTime: Date?
    let lastForegroundTime: Date?
    let backgroundDuration: TimeInterval
    let autoDisconnectEnabled: Bool
    
    /// 获取格式化的后台持续时间
    var formattedBackgroundDuration: String {
        if backgroundDuration < 60 {
            return String(format: "%.0f秒", backgroundDuration)
        } else if backgroundDuration < 3600 {
            let minutes = Int(backgroundDuration) / 60
            let seconds = Int(backgroundDuration) % 60
            return "\(minutes)分\(seconds)秒"
        } else {
            let hours = Int(backgroundDuration) / 3600
            let minutes = Int(backgroundDuration) % 3600 / 60
            return "\(hours)小时\(minutes)分"
        }
    }
    
    /// 获取状态描述
    var statusDescription: String {
        if isActive {
            return "应用处于前台"
        } else {
            return "应用处于后台"
        }
    }
}

// MARK: - Extensions

extension DeploymentService {
    /// 断开 SSH 连接
    func disconnectSSH() async {
        print("DeploymentService: Disconnecting SSH")
        
        // DeploymentService 通过 vpsManager 管理 SSH 连接
        // 这里不需要额外的断开操作，因为 vpsManager 已经处理了
        // 如果需要，可以在这里添加 DeploymentService 特定的清理逻辑
        
        print("DeploymentService: SSH disconnected")
    }
}
