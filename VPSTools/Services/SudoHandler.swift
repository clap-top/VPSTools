import Foundation

// MARK: - Sudo Handler

/// 专门处理sudo相关问题的工具类
class SudoHandler {
    
    // MARK: - Sudo Problem Types
    
    enum SudoProblem: String, CaseIterable {
        case notInstalled = "sudo未安装"
        case noPrivileges = "无sudo权限"
        case configurationError = "sudo配置错误"
        case rootUser = "已是root用户"
        case unknown = "未知问题"
        
        var description: String {
            switch self {
            case .notInstalled:
                return "系统中没有安装sudo命令"
            case .noPrivileges:
                return "当前用户没有sudo权限"
            case .configurationError:
                return "sudo配置文件存在问题"
            case .rootUser:
                return "当前已是root用户，无需sudo"
            case .unknown:
                return "sudo问题类型未知"
            }
        }
    }
    
    // MARK: - Sudo Solutions
    
    struct SudoSolution {
        let problem: SudoProblem
        let description: String
        let commands: [String]
        let manualSteps: [String]
        let requiresReboot: Bool
        
        var isAutomatic: Bool {
            return !commands.isEmpty
        }
    }
    
    // MARK: - Public Methods
    
    /// 诊断sudo问题
    static func diagnoseSudoProblem(systemInfo: SystemEnvironmentInfo) -> SudoProblem {
        if systemInfo.isRoot {
            return .rootUser
        }
        
        if !systemInfo.hasSudo {
            return .notInstalled
        }
        
        if !systemInfo.hasSudoPrivileges {
            return .noPrivileges
        }
        
        return .unknown
    }
    
    /// 生成sudo解决方案
    static func generateSolution(for problem: SudoProblem, systemInfo: SystemEnvironmentInfo) -> SudoSolution {
        switch problem {
        case .rootUser:
            return SudoSolution(
                problem: .rootUser,
                description: "当前已是root用户，无需sudo权限",
                commands: [],
                manualSteps: ["继续使用root用户执行命令"],
                requiresReboot: false
            )
            
        case .notInstalled:
            return generateInstallSolution(systemInfo: systemInfo)
            
        case .noPrivileges:
            return generatePrivilegeSolution(systemInfo: systemInfo)
            
        case .configurationError:
            return generateConfigurationSolution(systemInfo: systemInfo)
            
        case .unknown:
            return SudoSolution(
                problem: .unknown,
                description: "sudo问题类型未知，需要手动检查",
                commands: [],
                manualSteps: [
                    "检查sudo是否已安装: which sudo",
                    "检查当前用户: whoami",
                    "检查sudo权限: sudo -l",
                    "检查sudoers文件: cat /etc/sudoers"
                ],
                requiresReboot: false
            )
        }
    }
    
    /// 生成安装sudo的解决方案
    private static func generateInstallSolution(systemInfo: SystemEnvironmentInfo) -> SudoSolution {
        let commands: [String]
        let manualSteps: [String]
        
        switch systemInfo.packageManager {
        case .apt:
            commands = [
                "apt update",
                "apt install -y sudo"
            ]
            manualSteps = [
                "更新包列表: apt update",
                "安装sudo: apt install -y sudo",
                "配置sudo权限: usermod -aG sudo \(systemInfo.currentUser)",
                "重新登录或运行: newgrp sudo"
            ]
            
        case .yum:
            commands = [
                "yum install -y sudo"
            ]
            manualSteps = [
                "安装sudo: yum install -y sudo",
                "配置sudo权限: usermod -aG wheel \(systemInfo.currentUser)",
                "重新登录或运行: newgrp wheel"
            ]
            
        case .dnf:
            commands = [
                "dnf install -y sudo"
            ]
            manualSteps = [
                "安装sudo: dnf install -y sudo",
                "配置sudo权限: usermod -aG wheel \(systemInfo.currentUser)",
                "重新登录或运行: newgrp wheel"
            ]
            
        case .unknown:
            commands = []
            manualSteps = [
                "手动安装sudo包",
                "配置sudo权限",
                "重新登录以生效"
            ]
        }
        
        return SudoSolution(
            problem: .notInstalled,
            description: "系统中没有安装sudo，需要先安装sudo包",
            commands: commands,
            manualSteps: manualSteps,
            requiresReboot: false
        )
    }
    
    /// 生成配置sudo权限的解决方案
    private static func generatePrivilegeSolution(systemInfo: SystemEnvironmentInfo) -> SudoSolution {
        let commands: [String]
        let manualSteps: [String]
        
        switch systemInfo.packageManager {
        case .apt:
            commands = [
                "usermod -aG sudo \(systemInfo.currentUser)",
                "echo '\(systemInfo.currentUser) ALL=(ALL:ALL) NOPASSWD:ALL' | tee /etc/sudoers.d/\(systemInfo.currentUser)"
            ]
            manualSteps = [
                "将用户添加到sudo组: usermod -aG sudo \(systemInfo.currentUser)",
                "配置sudoers文件: echo '\(systemInfo.currentUser) ALL=(ALL:ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/\(systemInfo.currentUser)",
                "重新登录或运行: newgrp sudo"
            ]
            
        case .yum, .dnf:
            commands = [
                "usermod -aG wheel \(systemInfo.currentUser)",
                "echo '\(systemInfo.currentUser) ALL=(ALL:ALL) NOPASSWD:ALL' | tee /etc/sudoers.d/\(systemInfo.currentUser)"
            ]
            manualSteps = [
                "将用户添加到wheel组: usermod -aG wheel \(systemInfo.currentUser)",
                "配置sudoers文件: echo '\(systemInfo.currentUser) ALL=(ALL:ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/\(systemInfo.currentUser)",
                "重新登录或运行: newgrp wheel"
            ]
            
        case .unknown:
            commands = []
            manualSteps = [
                "将用户添加到sudo组: usermod -aG sudo \(systemInfo.currentUser)",
                "配置sudoers文件",
                "重新登录以生效"
            ]
        }
        
        return SudoSolution(
            problem: .noPrivileges,
            description: "当前用户没有sudo权限，需要配置sudo权限",
            commands: commands,
            manualSteps: manualSteps,
            requiresReboot: false
        )
    }
    
    /// 生成修复sudo配置的解决方案
    private static func generateConfigurationSolution(systemInfo: SystemEnvironmentInfo) -> SudoSolution {
        let commands: [String]
        let manualSteps: [String]
        
        switch systemInfo.packageManager {
        case .apt:
            commands = [
                "chmod 440 /etc/sudoers",
                "chmod 440 /etc/sudoers.d/*",
                "visudo -c"
            ]
            manualSteps = [
                "检查sudoers文件权限: ls -la /etc/sudoers*",
                "修复权限: chmod 440 /etc/sudoers",
                "验证配置: visudo -c",
                "重新配置用户权限"
            ]
            
        case .yum, .dnf:
            commands = [
                "chmod 440 /etc/sudoers",
                "chmod 440 /etc/sudoers.d/*",
                "visudo -c"
            ]
            manualSteps = [
                "检查sudoers文件权限: ls -la /etc/sudoers*",
                "修复权限: chmod 440 /etc/sudoers",
                "验证配置: visudo -c",
                "重新配置用户权限"
            ]
            
        case .unknown:
            commands = []
            manualSteps = [
                "检查sudoers文件",
                "修复文件权限",
                "验证配置",
                "重新配置用户权限"
            ]
        }
        
        return SudoSolution(
            problem: .configurationError,
            description: "sudo配置文件存在问题，需要修复配置",
            commands: commands,
            manualSteps: manualSteps,
            requiresReboot: false
        )
    }
    
    /// 生成系统特定的sudo安装脚本
    static func generateSudoInstallScript(for systemInfo: SystemEnvironmentInfo) -> String {
        switch systemInfo.packageManager {
        case .apt:
            return generateDebianSudoScript()
        case .yum, .dnf:
            return generateCentOSSudoScript()
        case .unknown:
            return generateGenericSudoScript()
        }
    }
    
    /// 生成Debian系统的sudo安装脚本
    private static func generateDebianSudoScript() -> String {
        return """
        #!/bin/bash
        
        set -e
        
        # 检测是否为root用户
        if [ "$EUID" -eq 0 ]; then
            exit 0
        fi
        
        CURRENT_USER=$(whoami)
        
        # 检测sudo是否已安装
        if command -v sudo &> /dev/null; then
            # 检测sudo权限
            if sudo -n true 2>/dev/null; then
                exit 0
            fi
        else
            # 更新包列表
            apt update
            
            # 安装sudo
            apt install -y sudo
            
            if ! command -v sudo &> /dev/null; then
                exit 1
            fi
        fi
        
        # 将用户添加到sudo组
        usermod -aG sudo $CURRENT_USER
        
        # 创建sudoers.d文件
        SUDOERS_FILE="/etc/sudoers.d/$CURRENT_USER"
        if [ ! -f "$SUDOERS_FILE" ]; then
            echo "$CURRENT_USER ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee "$SUDOERS_FILE"
            chmod 440 "$SUDOERS_FILE"
        fi
        
        # 验证配置
        if ! visudo -c &> /dev/null; then
            exit 1
        fi
        """
    }
    
    /// 生成CentOS/RHEL系统的sudo安装脚本
    private static func generateCentOSSudoScript() -> String {
        return """
        #!/bin/bash
        
        set -e
        
        # 检测是否为root用户
        if [ "$EUID" -eq 0 ]; then
            exit 0
        fi
        
        CURRENT_USER=$(whoami)
        
        # 检测包管理器
        if command -v dnf &> /dev/null; then
            PKG_MANAGER="dnf"
        elif command -v yum &> /dev/null; then
            PKG_MANAGER="yum"
        else
            exit 1
        fi
        
        # 检测sudo是否已安装
        if command -v sudo &> /dev/null; then
            # 检测sudo权限
            if sudo -n true 2>/dev/null; then
                exit 0
            fi
        else
            # 安装sudo
            $PKG_MANAGER install -y sudo
            
            if ! command -v sudo &> /dev/null; then
                exit 1
            fi
        fi
        
        # 将用户添加到wheel组
        usermod -aG wheel $CURRENT_USER
        
        # 创建sudoers.d文件
        SUDOERS_FILE="/etc/sudoers.d/$CURRENT_USER"
        if [ ! -f "$SUDOERS_FILE" ]; then
            echo "$CURRENT_USER ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee "$SUDOERS_FILE"
            chmod 440 "$SUDOERS_FILE"
        fi
        
        # 验证配置
        if ! visudo -c &> /dev/null; then
            exit 1
        fi
        """
    }
    
    /// 生成通用sudo安装脚本
    private static func generateGenericSudoScript() -> String {
        return """
        #!/bin/bash
        
        set -e
        
        # 检测是否为root用户
        if [ "$EUID" -eq 0 ]; then
            exit 0
        fi
        
        CURRENT_USER=$(whoami)
        
        # 检测包管理器
        if command -v apt &> /dev/null; then
            PKG_MANAGER="apt"
            SUDO_GROUP="sudo"
        elif command -v dnf &> /dev/null; then
            PKG_MANAGER="dnf"
            SUDO_GROUP="wheel"
        elif command -v yum &> /dev/null; then
            PKG_MANAGER="yum"
            SUDO_GROUP="wheel"
        else
            exit 1
        fi
        
        # 检测sudo是否已安装
        if command -v sudo &> /dev/null; then
            # 检测sudo权限
            if sudo -n true 2>/dev/null; then
                exit 0
            fi
        else
            # 安装sudo
            if [ "$PKG_MANAGER" = "apt" ]; then
                apt update
                apt install -y sudo
            else
                $PKG_MANAGER install -y sudo
            fi
            
            if ! command -v sudo &> /dev/null; then
                exit 1
            fi
        fi
        
        # 将用户添加到sudo组
        usermod -aG $SUDO_GROUP $CURRENT_USER
        
        # 创建sudoers.d文件
        SUDOERS_FILE="/etc/sudoers.d/$CURRENT_USER"
        if [ ! -f "$SUDOERS_FILE" ]; then
            echo "$CURRENT_USER ALL=(ALL:ALL) NOPASSWD:ALL" | sudo tee "$SUDOERS_FILE"
            chmod 440 "$SUDOERS_FILE"
        fi
        
        # 验证配置
        if ! visudo -c &> /dev/null; then
            exit 1
        fi
        """
    }
}
