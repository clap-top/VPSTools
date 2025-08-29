import SwiftUI

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    let isSensitive: Bool
    
    init(label: String, value: String, isSensitive: Bool = false) {
        self.label = label
        self.value = value
        self.isSensitive = isSensitive
    }
    
    @State private var showSensitiveValue = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            
            if isSensitive {
                HStack(spacing: 4) {
                    if showSensitiveValue {
                        Text(value)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    } else {
                        Text(String(repeating: "•", count: min(value.count, 8)))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        showSensitiveValue.toggle()
                    }) {
                        Image(systemName: showSensitiveValue ? "eye.slash" : "eye")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
            } else {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Log Row View

struct LogRowView: View {
    let log: DeploymentLog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(log.level.rawValue.uppercased())
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(log.level.color.opacity(0.2))
                    .foregroundColor(log.level.color)
                    .cornerRadius(4)
            }
            
            Text(log.message)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - User Friendly Log Row View

struct UserFriendlyLogRowView: View {
    let log: DeploymentLog
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 状态图标
            Image(systemName: getStatusIcon())
                .font(.caption)
                .foregroundColor(getStatusColor())
                .frame(width: 16, height: 16)
            
            // 用户友好的消息
            VStack(alignment: .leading, spacing: 2) {
                Text(getUserFriendlyMessage())
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Text(log.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func getStatusIcon() -> String {
        switch log.level {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    private func getStatusColor() -> Color {
        switch log.level {
        case .success:
            return .green
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }
    
    private func getUserFriendlyMessage() -> String {
        let message = log.message
        
        // 将技术性消息转换为用户友好的消息
        if message.contains("正在连接 SSH") {
            return "正在连接到服务器..."
        } else if message.contains("SSH 连接成功") {
            return "✅ 服务器连接成功"
        } else if message.contains("正在检测系统环境") {
            return "正在检测服务器环境..."
        } else if message.contains("系统检测:") {
            return "✅ 服务器环境检测完成"
        } else if message.contains("开始部署") {
            return "🚀 开始部署服务"
        } else if message.contains("正在处理模板变量") {
            return "正在准备配置参数..."
        } else if message.contains("准备执行") {
            return "正在准备执行命令..."
        } else if message.contains("开始执行") {
            return "正在执行部署命令..."
        } else if message.contains("指令组") && message.contains("执行成功") {
            return "✅ 部署步骤执行成功"
        } else if message.contains("正在生成服务文件") {
            return "正在创建服务文件..."
        } else if message.contains("服务文件生成完成") {
            return "✅ 服务文件创建完成"
        } else if message.contains("正在启动服务") {
            return "正在启动服务..."
        } else if message.contains("服务启动完成") {
            return "✅ 服务启动成功"
        } else if message.contains("正在生成配置文件") {
            return "正在创建配置文件..."
        } else if message.contains("配置文件生成完成") {
            return "✅ 配置文件创建完成"
        } else if message.contains("部署完成") {
            return "🎉 部署完成！服务已成功启动"
        } else if message.contains("部署失败") {
            return "❌ 部署失败"
        } else if message.contains("端口检查") {
            return "正在检查端口可用性..."
        } else if message.contains("端口可用") {
            return "✅ 端口检查通过"
        } else if message.contains("端口已被占用") {
            return "❌ 端口被占用，请选择其他端口"
        }
        
        return message
    }
}

// MARK: - Keyboard Hide Modifier

struct KeyboardHideModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hideKeyboard()
                    }
            )
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Enhanced Keyboard Hide Modifier

struct EnhancedKeyboardHideModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        hideKeyboard()
                    }
            )
            .onTapGesture {
                hideKeyboard()
            }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - View Extension

extension View {
    /// 添加点击隐藏键盘功能
    func hideKeyboardOnTap() -> some View {
        self.modifier(KeyboardHideModifier())
    }
    
    /// 添加增强的点击隐藏键盘功能（适用于复杂布局）
    func hideKeyboardOnTapEnhanced() -> some View {
        self.modifier(EnhancedKeyboardHideModifier())
    }
}
