import SwiftUI

// MARK: - VPS Management View

struct VPSManagementView: View {
    @ObservedObject var vpsManager: VPSManager
    @State private var showingAddVPS = false
    @State private var selectedVPS: VPSInstance?
    @State private var searchText = ""
    @State private var selectedGroup = LocalizationManager.shared.localizedString(.all)
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // VPS 列表
                if vpsManager.vpsInstances.isEmpty {
                    emptyStateView
                } else {
                    vpsListView
                }
            }
            .navigationTitle(Text(.vpsManagement))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddVPS = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { Task { await vpsManager.testAllConnections() } }) {
                        if vpsManager.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(vpsManager.isLoading)
                }
            }
            .sheet(isPresented: $showingAddVPS) {
                AddVPSView(vpsManager: vpsManager)
            }
            .sheet(item: $selectedVPS) { vps in
                VPSDetailView(vps: vps, vpsManager: vpsManager)
            }
            .onAppear {
                // 只在需要时进行初始连接检测
                if vpsManager.needsInitialConnectionTest() {
                    Task {
                        await vpsManager.testAllConnections()
                    }
                }
            }
        }
    }
    
    // MARK: - Search and Filter Bar
    
    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // 搜索框
//            HStack {
//                Image(systemName: "magnifyingglass")
//                    .foregroundColor(.secondary)
//                
//                TextField("搜索 VPS...", text: $searchText)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//            }
//            .padding(.horizontal)
            
            // 分组筛选
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(groups, id: \.self) { group in
                        Button(action: { selectedGroup = group }) {
                            Text(group)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedGroup == group ? Color.accentColor : Color.secondary.opacity(0.2))
                                .foregroundColor(selectedGroup == group ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - VPS List View
    
    private var vpsListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredVPSInstances) { vps in
                    VPSCardView(vps: vps, vpsManager: vpsManager) {
                        selectedVPS = vps
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "server.rack")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(.noVPSYet)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(.addFirstVPSToStart)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button(action: { showingAddVPS = true }) {
                HStack {
                    Image(systemName: "plus")
                    Text(.addVPS)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Computed Properties
    
    private var groups: [String] {
        let allGroups = Set(vpsManager.vpsInstances.map { $0.group })
        return [LocalizationManager.shared.localizedString(.all)] + Array(allGroups).sorted()
    }
    
    private var filteredVPSInstances: [VPSInstance] {
        var filtered = vpsManager.vpsInstances
        
        // 按分组筛选
        if selectedGroup != LocalizationManager.shared.localizedString(.all) {
            filtered = filtered.filter { $0.group == selectedGroup }
        }
        
        // 按搜索文本筛选
        if !searchText.isEmpty {
            filtered = filtered.filter { vps in
                vps.name.localizedCaseInsensitiveContains(searchText) ||
                vps.host.localizedCaseInsensitiveContains(searchText) ||
                vps.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        return filtered
    }
}

// MARK: - VPS Card View

struct VPSCardView: View {
    let vps: VPSInstance
    let vpsManager: VPSManager
    let onTap: () -> Void
    
    @State private var showingActionSheet = false
    @State private var showingEditVPS = false
    @State private var showingDeleteConfirmation = false
    
    private var connectionStatusColor: Color {
        // 优先使用连接测试结果
        if let testResult = vpsManager.connectionTestResults[vps.id] {
            if testResult.sshSuccess {
                return .green
            } else {
                return .red
            }
        }
        
        // 如果没有测试结果，使用最后连接时间
        if let lastConnected = vps.lastConnected {
            let timeSinceLastConnection = Date().timeIntervalSince(lastConnected)
            if timeSinceLastConnection < 300 { // 5 minutes
                return .green
            } else if timeSinceLastConnection < 3600 { // 1 hour
                return .orange
            } else {
                return .red
            }
        }
        
        return .gray
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 头部信息
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vps.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(vps.connectionString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 状态指示器
                HStack(spacing: 8) {
                    if vpsManager.isConnectionTesting(for: vps) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    } else {
                        Circle()
                            .fill(connectionStatusColor)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            
            // 标签
            if !vps.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vps.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .cornerRadius(4)
                        }
                    }
                }
            }
            
            // 系统信息
            if let systemInfo = vps.systemInfo {
                HStack(spacing: 16) {
                    SystemInfoItem(
                        icon: "cpu",
                        title: String(.cpu),
                        value: "\(systemInfo.cpuCores) \(String(.cpuCores))"
                    )
                    
                    SystemInfoItem(
                        icon: "memorychip",
                        title: String(.memory),
                        value: "\(Int(systemInfo.memoryUsage))%"
                    )
                    
                    SystemInfoItem(
                        icon: "externaldrive",
                        title: String(.disk),
                        value: "\(Int(systemInfo.diskUsage))%"
                    )
                }
            }
            
            // 服务列表
            if !vps.services.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                                            Text(.services)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                        ForEach(vps.services.prefix(4)) { service in
                            ServiceChipView(service: service)
                        }
                    }
                    
                    if vps.services.count > 4 {
                                            Text(.moreServices, arguments: String(vps.services.count - 4))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            
            // 操作按钮
            HStack {
                Button(action: {
                    Task {
                        await vpsManager.testConnection(for: vps)
                    }
                }) {
                    HStack {
                        Image(systemName: "network")
                        Text(.testConnection)
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                }
                
                Spacer()
                
                Button(action: { showingActionSheet = true }) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text(vps.displayName),
                buttons: [
                    .default(Text(.edit)) { showingEditVPS = true },
                    .default(Text(.testConnection)) {
                        Task {
                            await vpsManager.testConnection(for: vps)
                        }
                    },
                    .default(Text(.getSystemInfo)) {
                        Task {
                            try? await vpsManager.getSystemInfo(for: vps)
                        }
                    },
                    .destructive(Text(.delete)) {
                        showingDeleteConfirmation = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showingEditVPS) {
            EditVPSView(vps: vps, vpsManager: vpsManager)
        }
        .alert("Confirm Delete", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await vpsManager.deleteVPS(vps)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(String(.confirmDeleteVPS, arguments: vps.name))
        }
    }
}

// MARK: - System Info Item

struct SystemInfoItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Service Chip View

struct ServiceChipView: View {
    let service: VPSService
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: service.type.icon)
                .font(.caption)
            
            Text(service.displayName)
                .font(.caption)
                .lineLimit(1)
            
            Circle()
                .fill(service.status.color)
                .frame(width: 6, height: 6)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(6)
    }
}

// MARK: - Add VPS View

struct AddVPSView: View {
    @ObservedObject var vpsManager: VPSManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var host = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var password = ""
    @State private var sshKeyPath = ""
    @State private var group = LocalizationManager.shared.localizedString(.defaultGroup)
    @State private var tags = ""
    @State private var authMethod: AuthMethod = .password
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(LocalizationManager.shared.localizedString(.basicInfo)) {
                    TextField(LocalizationManager.shared.localizedString(.vpsName), text: $name)
                    TextField(LocalizationManager.shared.localizedString(.hostAddress), text: $host)
                    TextField(LocalizationManager.shared.localizedString(.port), text: $port)
                        .keyboardType(.numberPad)
                    TextField(LocalizationManager.shared.localizedString(.username), text: $username)
                }
                
                Section(LocalizationManager.shared.localizedString(.authMethod)) {
                    Picker(LocalizationManager.shared.localizedString(.authMethod), selection: $authMethod) {
                        ForEach(AuthMethod.allCases, id: \.self) { method in
                            Text(method.displayName).tag(method)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if authMethod == .password {
                        SecureField(LocalizationManager.shared.localizedString(.password), text: $password)
                    } else {
                        TextField(LocalizationManager.shared.localizedString(.sshKeyPath), text: $sshKeyPath)
                    }
                }
                
                Section(LocalizationManager.shared.localizedString(.groupAndTags)) {
                    TextField(LocalizationManager.shared.localizedString(.group), text: $group)
                    TextField(LocalizationManager.shared.localizedString(.tagsCommaSeparated), text: $tags)
                }
                
                if !errorMessage.isEmpty {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Add VPS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationManager.shared.localizedString(.cancel)) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await saveVPS()
                        }
                    }) {
                        if isLoading {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                Text(.checkingConnection)
                                    .font(.subheadline)
                            }
                        } else {
                            Text(.save)
                        }
                    }
                    .disabled(isLoading || !isValid)
                }
            }
            .disabled(isLoading)
            .overlay(
                Group {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            
                            VStack(spacing: 8) {
                                Text(.checkingConnection)
                                    .font(.headline)
                                    .fontWeight(.medium)
                                
                                Text(.validatingVPSConfig)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(32)
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                }
            )
            .hideKeyboardOnTap()
        }
    }
    
    private var isValid: Bool {
        !name.isEmpty && !host.isEmpty && !username.isEmpty && !port.isEmpty &&
        (authMethod == .password ? !password.isEmpty : !sshKeyPath.isEmpty)
    }
    
    private func saveVPS() async {
        isLoading = true
        errorMessage = ""
        
        do {
            // 创建 VPS 实例
            let vps = VPSInstance(
                name: name,
                host: host,
                port: Int(port) ?? 22,
                username: username,
                password: authMethod == .password ? password : nil,
                sshKeyPath: authMethod != .password ? sshKeyPath : nil,
                tags: tags.isEmpty ? [] : tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                group: group
            )
            
            // 添加 VPS（这会自动测试连接）
            try await vpsManager.addVPS(vps)
            
            // 成功添加后关闭页面
            dismiss()
            
        } catch VPSManagerError.connectionFailed(let message) {
            errorMessage = String(format: LocalizationManager.shared.localizedString(.connectionFailed), message)
        } catch VPSManagerError.invalidConfiguration(let message) {
            errorMessage = String(format: LocalizationManager.shared.localizedString(.configError), message)
        } catch {
            errorMessage = String(format: LocalizationManager.shared.localizedString(.saveFailed), error.localizedDescription)
        }
        
        isLoading = false
    }
}

