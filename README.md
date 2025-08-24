# VPSTools

一个专为iOS设备设计的VPS管理工具，提供直观的界面来管理您的虚拟私有服务器。

## 🌟 功能特性

### 🔧 VPS管理
- **多VPS支持**: 管理多个VPS实例
- **连接状态监控**: 实时显示VPS连接状态
- **系统信息查看**: CPU、内存、磁盘使用率监控
- **服务管理**: 查看和管理VPS上的服务

### 🚀 智能部署
- **模板部署**: 预配置的部署模板
- **AI辅助部署**: 智能部署建议和自动化
- **多协议支持**: 支持多种部署协议
- **部署历史**: 完整的部署记录和回滚

### 📊 监控中心
- **实时监控**: VPS性能实时监控
- **资源使用率**: CPU、内存、网络使用情况
- **服务状态**: 关键服务运行状态监控
- **告警通知**: 异常情况及时通知

### ⚙️ 系统设置
- **SSH连接管理**: 自动断开和连接超时设置
- **多语言支持**: 中文和英文界面
- **主题设置**: 个性化界面主题
- **数据管理**: 导入导出VPS配置

## 📱 设备支持

- **iPhone**: 完全优化的移动端体验
- **iPad**: 专业级桌面体验，支持分屏和侧边栏
- **macOS**: 原生macOS应用体验

## 🛠️ 技术栈

- **SwiftUI**: 现代化的UI框架
- **Swift**: 原生iOS开发语言
- **SwiftCSSH**: SSH连接库
- **SwiftLibSSH**: SSH协议支持

## 📦 安装要求

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+

## 🚀 快速开始

### 1. 克隆项目
```bash
git clone https://github.com/your-username/VPSTools.git
cd VPSTools
```

### 2. 安装依赖
项目使用Swift Package Manager管理依赖，Xcode会自动解析和下载依赖包。

### 3. 构建项目
```bash
xcodebuild -project VPSTools.xcodeproj -scheme VPSTools build
```

### 4. 运行项目
在Xcode中打开项目，选择目标设备，点击运行按钮。

## 📖 使用指南

### 添加VPS
1. 打开应用，进入"VPS管理"页面
2. 点击右上角的"+"按钮
3. 填写VPS信息：
   - 名称：VPS的显示名称
   - 主机：VPS的IP地址或域名
   - 端口：SSH端口（默认22）
   - 用户名：SSH用户名
   - 密码：SSH密码或密钥
4. 点击"保存"完成添加

### 智能部署
1. 进入"智能部署"页面
2. 选择要部署的VPS
3. 选择部署模板或使用AI辅助部署
4. 配置部署参数
5. 点击"开始部署"

### 监控VPS
1. 进入"监控"页面
2. 选择要监控的VPS
3. 查看实时性能数据
4. 设置告警阈值

## 🏗️ 项目结构

```
VPSTools/
├── VPSTools/
│   ├── Assets.xcassets/          # 应用资源
│   ├── Models/                   # 数据模型
│   │   ├── CommonModels.swift    # 通用模型
│   │   └── VPSModels.swift       # VPS相关模型
│   ├── Services/                 # 业务服务
│   │   ├── AppLifecycleManager.swift    # 应用生命周期管理
│   │   ├── DeploymentService.swift     # 部署服务
│   │   ├── LocalizationManager.swift   # 本地化管理
│   │   ├── SSHClient.swift             # SSH客户端
│   │   ├── VPSManager.swift            # VPS管理器
│   │   └── WebViewManager.swift        # WebView管理
│   ├── Views/                    # 用户界面
│   │   ├── HomeView.swift              # 首页
│   │   ├── VPSManagementView.swift     # VPS管理
│   │   ├── DeploymentView.swift        # 部署页面
│   │   ├── MonitoringView.swift        # 监控页面
│   │   ├── SettingsView.swift          # 设置页面
│   │   └── SharedComponents.swift      # 共享组件
│   ├── ContentView.swift        # 主视图
│   └── VPSTools.swift           # 应用入口
├── VPSTools.xcodeproj/          # Xcode项目文件
└── README.md                    # 项目说明
```

## 🔧 配置说明

### SSH连接配置
- 支持密码和密钥认证
- 可配置连接超时时间
- 自动重连机制

### 部署模板
- 支持自定义部署模板
- 模板变量替换
- 部署脚本管理

### 监控配置
- 可配置监控间隔
- 自定义告警规则
- 通知设置

## 🌍 国际化

应用支持多语言：
- 中文（简体）
- English

语言设置可在"设置"页面中修改。

## 🔒 安全特性

- **SSH加密**: 所有SSH连接使用加密传输
- **密钥管理**: 支持SSH密钥认证
- **数据加密**: 本地存储数据加密
- **权限控制**: 最小权限原则

## 🤝 贡献指南

我们欢迎社区贡献！请遵循以下步骤：

1. Fork项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 打开Pull Request

### 开发规范
- 遵循Swift编码规范
- 添加适当的注释
- 编写单元测试
- 更新文档

## 📄 许可证

本项目采用MIT许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- [SwiftCSSH](https://github.com/GitSwiftLLC/SwiftCSSH) - SSH连接库
- [SwiftLibSSH](https://github.com/GitSwiftLLC/SwiftLibSSH) - SSH协议支持

## 📞 联系我们

- 项目主页: [GitHub](https://github.com/your-username/VPSTools)
- 问题反馈: [Issues](https://github.com/your-username/VPSTools/issues)
- 功能建议: [Discussions](https://github.com/your-username/VPSTools/discussions)

## 📈 更新日志

### v1.0.0 (2024-08-24)
- 🎉 初始版本发布
- ✨ 基础VPS管理功能
- 🚀 智能部署系统
- 📊 实时监控功能
- 🌍 多语言支持
- 📱 iPad优化支持

---

**VPSTools** - 让VPS管理更简单、更高效！ 🚀

---

## 📖 多语言文档

- [English](README_EN.md) - English documentation
- [中文](README.md) - 中文文档
