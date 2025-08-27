import Foundation
import SwiftUI

/// 连接池测试类
/// 用于验证 ConnectionPool 和 VPSManager 的清理机制
class ConnectionPoolTest {
    
    static func runCleanupTest() {
        print("=== 开始连接池清理测试 ===")
        
        // 测试 1: 创建和销毁 ConnectionPool
        testConnectionPoolCleanup()
        
        // 测试 2: 创建和销毁 VPSManager
        testVPSManagerCleanup()
        
        // 测试 3: 测试应用生命周期管理
        testAppLifecycleCleanup()
        
        print("=== 连接池清理测试完成 ===")
    }
    
    private static func testConnectionPoolCleanup() {
        print("测试 1: ConnectionPool 清理")
        
        // 创建 ConnectionPool 实例
        let connectionPool = ConnectionPool()
        print("ConnectionPool 已创建")
        
        // 模拟一些操作
        connectionPool.poolStatus = .active
        connectionPool.activeConnections = 2
        
        // 手动调用清理方法（在实际使用中，这会在 deinit 中自动调用）
        print("ConnectionPool 即将销毁...")
        
        // 在这里，connectionPool 会超出作用域并被销毁
        // deinit 方法会被自动调用
    }
    
    private static func testVPSManagerCleanup() {
        print("测试 2: VPSManager 清理")
        
        // 创建 VPSManager 实例
        let vpsManager = VPSManager()
        print("VPSManager 已创建")
        
        // 模拟一些操作
        vpsManager.isLoading = true
        vpsManager.lastError = "测试错误"
        
        // 手动调用清理方法
        Task {
            await vpsManager.prepareForDeallocation()
        }
        
        print("VPSManager 即将销毁...")
        
        // 在这里，vpsManager 会超出作用域并被销毁
        // deinit 方法会被自动调用
    }
    
    private static func testAppLifecycleCleanup() {
        print("测试 3: 应用生命周期清理")
        
        // 创建 AppLifecycleManager 实例
        let lifecycleManager = AppLifecycleManager()
        print("AppLifecycleManager 已创建")
        
        // 创建 VPSManager 和 DeploymentService
        let vpsManager = VPSManager()
        let deploymentService = DeploymentService(vpsManager: vpsManager)
        
        // 设置服务
        lifecycleManager.setServices(vpsManager: vpsManager, deploymentService: deploymentService)
        
        // 模拟应用进入后台
        Task {
            await lifecycleManager.handleAppDidEnterBackground()
        }
        
        // 模拟应用即将终止
        Task {
            await lifecycleManager.handleAppWillTerminate()
        }
        
        print("AppLifecycleManager 即将销毁...")
        
        // 在这里，所有对象会超出作用域并被销毁
    }
}

/// 测试视图
struct ConnectionPoolTestView: View {
    @State private var testResults: [String] = []
    
    var body: some View {
        VStack {
            Text("连接池清理测试")
                .font(.title)
                .padding()
            
            Button("运行测试") {
                runTest()
            }
            .padding()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(testResults, id: \.self) { result in
                        Text(result)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal)
                    }
                }
            }
        }
        .onAppear {
            // 重定向控制台输出到测试结果
            setupConsoleCapture()
        }
    }
    
    private func runTest() {
        testResults.removeAll()
        ConnectionPoolTest.runCleanupTest()
    }
    
    private func setupConsoleCapture() {
        // 这里可以添加控制台输出捕获逻辑
        // 在实际应用中，可能需要更复杂的日志捕获机制
    }
}

// MARK: - Preview

struct ConnectionPoolTestView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectionPoolTestView()
    }
}
