import SwiftUI

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
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
