# VPSTools

A professional VPS management tool designed for iOS devices, providing an intuitive interface to manage your virtual private servers.

## 🌟 Features

### 🔧 VPS Management
- **Multi-VPS Support**: Manage multiple VPS instances
- **Connection Status Monitoring**: Real-time VPS connection status display
- **System Information**: CPU, memory, and disk usage monitoring
- **Service Management**: View and manage services on VPS

### 🚀 Smart Deployment
- **Template Deployment**: Pre-configured deployment templates
- **AI-Assisted Deployment**: Intelligent deployment suggestions and automation
- **Multi-Protocol Support**: Support for various deployment protocols
- **Deployment History**: Complete deployment records and rollback

### 📊 Monitoring Center
- **Real-time Monitoring**: Live VPS performance monitoring
- **Resource Usage**: CPU, memory, and network usage tracking
- **Service Status**: Critical service status monitoring
- **Alert Notifications**: Timely notifications for anomalies

### ⚙️ System Settings
- **SSH Connection Management**: Auto-disconnect and connection timeout settings
- **Multi-language Support**: Chinese and English interfaces
- **Theme Settings**: Personalized interface themes
- **Data Management**: Import/export VPS configurations

## 📱 Device Support

- **iPhone**: Fully optimized mobile experience
- **iPad**: Professional desktop experience with split-screen and sidebar support
- **macOS**: Native macOS application experience

## 🛠️ Technology Stack

- **SwiftUI**: Modern UI framework
- **Swift**: Native iOS development language
- **SwiftCSSH**: SSH connection library
- **SwiftLibSSH**: SSH protocol support

## 📦 Requirements

- iOS 15.0+
- Xcode 14.0+
- Swift 5.7+

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone https://github.com/your-username/VPSTools.git
cd VPSTools
```

### 2. Install Dependencies
The project uses Swift Package Manager for dependency management. Xcode will automatically resolve and download dependencies.

### 3. Build the Project
```bash
xcodebuild -project VPSTools.xcodeproj -scheme VPSTools build
```

### 4. Run the Project
Open the project in Xcode, select your target device, and click the run button.

## 📖 User Guide

### Adding a VPS
1. Open the app and navigate to the "VPS Management" page
2. Tap the "+" button in the top right corner
3. Fill in the VPS information:
   - Name: Display name for the VPS
   - Host: VPS IP address or domain
   - Port: SSH port (default 22)
   - Username: SSH username
   - Password: SSH password or key
4. Tap "Save" to complete the addition

### Smart Deployment
1. Navigate to the "Smart Deployment" page
2. Select the target VPS
3. Choose a deployment template or use AI-assisted deployment
4. Configure deployment parameters
5. Tap "Start Deployment"

### Monitoring VPS
1. Navigate to the "Monitoring" page
2. Select the VPS to monitor
3. View real-time performance data
4. Set alert thresholds

## 🏗️ Project Structure

```
VPSTools/
├── VPSTools/
│   ├── Assets.xcassets/          # App resources
│   ├── Models/                   # Data models
│   │   ├── CommonModels.swift    # Common models
│   │   └── VPSModels.swift       # VPS-related models
│   ├── Services/                 # Business services
│   │   ├── AppLifecycleManager.swift    # App lifecycle management
│   │   ├── DeploymentService.swift     # Deployment service
│   │   ├── LocalizationManager.swift   # Localization management
│   │   ├── SSHClient.swift             # SSH client
│   │   ├── VPSManager.swift            # VPS manager
│   │   └── WebViewManager.swift        # WebView management
│   ├── Views/                    # User interface
│   │   ├── HomeView.swift              # Home page
│   │   ├── VPSManagementView.swift     # VPS management
│   │   ├── DeploymentView.swift        # Deployment page
│   │   ├── MonitoringView.swift        # Monitoring page
│   │   ├── SettingsView.swift          # Settings page
│   │   └── SharedComponents.swift      # Shared components
│   ├── ContentView.swift        # Main view
│   └── VPSTools.swift           # App entry point
├── VPSTools.xcodeproj/          # Xcode project file
└── README.md                    # Project documentation
```

## 🔧 Configuration

### SSH Connection Settings
- Support for password and key authentication
- Configurable connection timeout
- Automatic reconnection mechanism

### Deployment Templates
- Support for custom deployment templates
- Template variable substitution
- Deployment script management

### Monitoring Configuration
- Configurable monitoring intervals
- Custom alert rules
- Notification settings

## 🌍 Internationalization

The app supports multiple languages:
- Chinese (Simplified)
- English

Language settings can be modified in the "Settings" page.

## 🔒 Security Features

- **SSH Encryption**: All SSH connections use encrypted transmission
- **Key Management**: Support for SSH key authentication
- **Data Encryption**: Local storage data encryption
- **Permission Control**: Principle of least privilege

## 🤝 Contributing

We welcome community contributions! Please follow these steps:

1. Fork the project
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines
- Follow Swift coding conventions
- Add appropriate comments
- Write unit tests
- Update documentation

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [SwiftCSSH](https://github.com/GitSwiftLLC/SwiftCSSH) - SSH connection library
- [SwiftLibSSH](https://github.com/GitSwiftLLC/SwiftLibSSH) - SSH protocol support

## 📞 Contact

- Project Homepage: [GitHub](https://github.com/your-username/VPSTools)
- Issue Reports: [Issues](https://github.com/your-username/VPSTools/issues)
- Feature Requests: [Discussions](https://github.com/your-username/VPSTools/discussions)

## 📈 Changelog

### v1.0.0 (2024-08-24)
- 🎉 Initial release
- ✨ Basic VPS management features
- 🚀 Smart deployment system
- 📊 Real-time monitoring functionality
- 🌍 Multi-language support
- 📱 iPad optimization support

---

**VPSTools** - Making VPS management simpler and more efficient! 🚀

---

## 📖 Multi-language Documentation

- [English](README_EN.md) - English documentation
- [中文](README.md) - Chinese documentation
