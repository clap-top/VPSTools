import SwiftUI

struct ContentView: View {
    @StateObject private var vpsManager = VPSManager()
    @StateObject private var deploymentService: DeploymentService
    @EnvironmentObject var appLifecycleManager: AppLifecycleManager
    
    init() {
        let vpsManager = VPSManager()
        self._vpsManager = StateObject(wrappedValue: vpsManager)
        self._deploymentService = StateObject(wrappedValue: DeploymentService(vpsManager: vpsManager))
    }
    
    var body: some View {
        TabView {
            // 首页 - VPS 概览
            HomeView(vpsManager: vpsManager, deploymentService: deploymentService)
                .tabItem {
                    Image(systemName: "house")
                    Text(.home)
                }
            
            // VPS 管理
            VPSManagementView(vpsManager: vpsManager)
                .tabItem {
                    Image(systemName: "server.rack")
                    Text(.vpsManagement)
                }
            
            // 智能部署
            DeploymentView(vpsManager: vpsManager, deploymentService: deploymentService)
                .tabItem {
                    Image(systemName: "brain")
                    Text(.smartDeployment)
                }
            
            // 监控中心
            MonitoringView(vpsManager: vpsManager)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text(.monitoring)
                }
            
            // 设置
            SettingsView(vpsManager: vpsManager, deploymentService: deploymentService)
                .tabItem {
                    Image(systemName: "gear")
                    Text(.settings)
                }
        }
        .accentColor(.blue)
        .onAppear {
            // 配置应用生命周期管理器
//            appLifecycleManager.setServices(vpsManager: vpsManager, deploymentService: deploymentService)
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
