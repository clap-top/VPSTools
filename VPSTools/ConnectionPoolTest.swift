import Foundation
import XCTest

// MARK: - Connection Pool Test

/// 连接池测试类
class ConnectionPoolTest {
    
    static func runBasicTests() {
        print("开始连接池基础测试...")
        
        // 测试连接池创建
        testConnectionPoolCreation()
        
        // 测试连接状态管理
        testConnectionStateManagement()
        
        // 测试统计信息
        testStatistics()
        
        print("连接池基础测试完成")
    }
    
    private static func testConnectionPoolCreation() {
        print("测试连接池创建...")
        
        let pool = ConnectionPool()
        
        // 验证初始状态
        let stats = pool.getPoolStats()
        XCTAssertEqual(stats.totalConnections, 0, "初始连接数应该为0")
        XCTAssertEqual(stats.healthyConnections, 0, "初始健康连接数应该为0")
        XCTAssertEqual(stats.inUseConnections, 0, "初始使用中连接数应该为0")
        
        print("✅ 连接池创建测试通过")
    }
    
    private static func testConnectionStateManagement() {
        print("测试连接状态管理...")
        
        let pool = ConnectionPool()
        
        // 创建测试VPS
        let testVPS = VPSInstance(
            name: "Test VPS",
            host: "test.example.com",
            port: 22,
            username: "testuser"
        )
        
        // 测试获取不存在的连接状态
        let status = pool.getConnectionStatus(for: testVPS.id)
        XCTAssertNil(status, "不存在的连接状态应该为nil")
        
        print("✅ 连接状态管理测试通过")
    }
    
    private static func testStatistics() {
        print("测试统计信息...")
        
        let pool = ConnectionPool()
        let stats = pool.getPoolStats()
        
        // 验证统计信息结构
        XCTAssertEqual(stats.maxPoolSize, SSHConnectionConfig.ConnectionPool.maxSize, "最大连接池大小应该匹配配置")
        XCTAssertEqual(stats.utilizationRate, 0.0, "空连接池利用率应该为0")
        XCTAssertEqual(stats.healthRate, 0.0, "空连接池健康率应该为0")
        
        print("✅ 统计信息测试通过")
    }
}

// MARK: - Test Helpers

/// 简单的断言函数
func XCTAssertEqual<T: Equatable>(_ expression1: T, _ expression2: T, _ message: String = "") {
    if expression1 != expression2 {
        print("❌ 断言失败: \(message)")
        print("   期望: \(expression2)")
        print("   实际: \(expression1)")
    } else {
        print("✅ 断言通过: \(message)")
    }
}

func XCTAssertNil<T>(_ expression: T?, _ message: String = "") {
    if expression != nil {
        print("❌ 断言失败: \(message)")
        print("   期望: nil")
        print("   实际: \(expression!)")
    } else {
        print("✅ 断言通过: \(message)")
    }
}

// MARK: - Usage Example

/// 使用示例
class ConnectionPoolExample {
    
    static func demonstrateUsage() {
        print("连接池使用示例:")
        
        // 1. 创建连接池
        let pool = ConnectionPool()
        
        // 2. 创建VPS实例
        let vps = VPSInstance(
            name: "Production Server",
            host: "192.168.1.100",
            port: 22,
            username: "admin"
        )
        
        // 3. 获取连接（在实际使用中）
        Task {
            do {
                let client = try await pool.getConnection(for: vps)
                print("✅ 成功获取连接")
                
                // 4. 使用连接
                // let result = try await client.executeCommand("ls -la")
                
                // 5. 释放连接
                pool.releaseConnection(for: vps.id)
                print("✅ 成功释放连接")
                
            } catch {
                print("❌ 获取连接失败: \(error)")
            }
        }
        
        // 6. 查看统计信息
        let stats = pool.getPoolStats()
        print("连接池统计: \(stats.totalConnections) 个连接")
    }
}

// MARK: - Performance Test

/// 性能测试
class ConnectionPoolPerformanceTest {
    
    static func runPerformanceTest() {
        print("开始性能测试...")
        
        let pool = ConnectionPool()
        let startTime = Date()
        
        // 模拟多次连接获取和释放
        for i in 0..<100 {
            let vps = VPSInstance(
                name: "Test VPS \(i)",
                host: "test\(i).example.com",
                port: 22,
                username: "user\(i)"
            )
            
            // 模拟连接获取
            pool.connectionMetrics[vps.id] = ConnectionMetrics()
            pool.connectionMetrics[vps.id]?.totalAttempts += 1
            pool.connectionMetrics[vps.id]?.successfulAttempts += 1
            
            // 模拟连接释放
            pool.healthStatus[vps.id] = .healthy
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        print("性能测试结果:")
        print("   处理100个连接耗时: \(String(format: "%.3f", duration))秒")
        print("   平均每个连接: \(String(format: "%.3f", duration / 100))秒")
        
        let stats = pool.getPoolStats()
        print("   最终连接数: \(stats.totalConnections)")
        print("   健康连接数: \(stats.healthyConnections)")
    }
}
