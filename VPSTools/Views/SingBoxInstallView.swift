import SwiftUI

// MARK: - SingBox Install View

struct SingBoxInstallView: View {
    let vps: VPSInstance
    @StateObject private var installService = SingBoxInstallService()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 安装信息
                installInfoSection
                
                // 进度显示
                progressSection
                
                // 日志输出
                logsSection
                
                Spacer()
                
                // 操作按钮
                actionButtonsSection
            }
            .padding()
            .navigationTitle("SingBox 安装")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                    .disabled(installService.isInstalling)
                }
            }
        }
    }
    
    // MARK: - Install Info Section
    
    private var installInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.installInfo)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(label: "VPS", value: vps.displayName)
                InfoRow(label: "IP地址", value: vps.host)
                InfoRow(label: "操作系统", value: vps.systemInfo?.osName ?? "未知")
                InfoRow(label: "状态", value: installService.currentStep.rawValue)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.installProgress)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // 进度条
                ProgressView(value: installService.progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                // 当前步骤
                HStack {
                    Text(.currentStep)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(installService.currentStep.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(installService.currentStep == .failed ? .red : .primary)
                }
                
                // 步骤列表
                VStack(spacing: 8) {
                    ForEach(SingBoxInstallService.SingBoxInstallStep.allCases, id: \.self) { step in
                        HStack {
                            // 状态图标
                            Image(systemName: stepIcon(for: step))
                                .foregroundColor(stepColor(for: step))
                                .frame(width: 20)
                            
                            // 步骤名称
                            Text(step.rawValue)
                                .font(.caption)
                                .foregroundColor(stepColor(for: step))
                            
                            Spacer()
                            
                            // 进度百分比
                            if step.progress > 0 {
                                Text("\(Int(step.progress * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Logs Section
    
    private var logsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(.installLog)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("清空") {
                    installService.installLogs.removeAll()
                }
                .font(.caption)
                .disabled(installService.installLogs.isEmpty)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(installService.installLogs, id: \.self) { log in
                        Text(log)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxHeight: 200)
            .padding(8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 1)
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            if installService.isInstalling {
                // 安装中
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(.installing)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
                
            } else if installService.currentStep == .completed {
                // 安装完成
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                    
                    Text(.installSuccess)
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text(.singboxInstalledSuccessfully)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGreen).opacity(0.1))
                .cornerRadius(8)
                
            } else if installService.currentStep == .failed {
                // 安装失败
                VStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                    
                    Text(.installFailed)
                        .font(.headline)
                        .foregroundColor(.red)
                    
                    if let error = installService.lastError {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemRed).opacity(0.1))
                .cornerRadius(8)
                
                // 重试按钮
                Button("重新安装") {
                    startInstallation()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
            } else {
                // 开始安装
                Button("开始安装") {
                    startInstallation()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(installService.isInstalling)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func startInstallation() {
        Task {
            do {
                try await installService.installSingBox(to: vps)
            } catch {
                print("安装失败: \(error.localizedDescription)")
            }
        }
    }
    
    private func stepIcon(for step: SingBoxInstallService.SingBoxInstallStep) -> String {
        switch step {
        case .idle:
            return "circle"
        case .detectingArchitecture, .fetchingLatestVersion, .downloadingSingBox, .installingSingBox, .configuringService, .startingService, .verifyingInstallation:
            if installService.currentStep == step {
                return "arrow.clockwise"
            } else if installService.progress >= step.progress {
                return "checkmark.circle.fill"
            } else {
                return "circle"
            }
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        }
    }
    
    private func stepColor(for step: SingBoxInstallService.SingBoxInstallStep) -> Color {
        switch step {
        case .idle:
            return .secondary
        case .detectingArchitecture, .fetchingLatestVersion, .downloadingSingBox, .installingSingBox, .configuringService, .startingService, .verifyingInstallation:
            if installService.currentStep == step {
                return .blue
            } else if installService.progress >= step.progress {
                return .green
            } else {
                return .secondary
            }
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}



// MARK: - Preview

struct SingBoxInstallView_Previews: PreviewProvider {
    static var previews: some View {
        SingBoxInstallView(vps: VPSInstance(
            name: "测试 VPS",
            host: "192.168.1.100",
            username: "root"
        ))
    }
}
