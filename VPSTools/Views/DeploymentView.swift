import SwiftUI
import Combine

// MARK: - Deployment View

struct DeploymentView: View {
    @ObservedObject var vpsManager: VPSManager
    @ObservedObject var deploymentService: DeploymentService
    @State private var selectedTab = 0
    @State private var showingNaturalLanguageDeployment = false
    @State private var selectedVPS: VPSInstance?
    
    // 新增：支持从外部传入预选的 VPS
    let preSelectedVPS: VPSInstance?
    
    init(vpsManager: VPSManager, deploymentService: DeploymentService, preSelectedVPS: VPSInstance? = nil) {
        self.vpsManager = vpsManager
        self.deploymentService = deploymentService
        self.preSelectedVPS = preSelectedVPS
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 顶部操作栏
//                topActionBar
                
                // 标签页
                Picker("部署方式", selection: $selectedTab) {
                                    Text(.templateDeployment).tag(0)
                Text(.aiDeployment).tag(1)
                Text(.deploymentHistory).tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // 内容区域
                TabView(selection: $selectedTab) {
                    TemplateDeploymentView(
                        vpsManager: vpsManager,
                        deploymentService: deploymentService,
                        preSelectedVPS: preSelectedVPS
                    )
                    .tag(0)
                    
                    NaturalLanguageDeploymentView(
                        vpsManager: vpsManager,
                        deploymentService: deploymentService
                    )
                    .tag(1)
                    
                    DeploymentHistoryView(
                        vpsManager: vpsManager,
                        deploymentService: deploymentService
                    )
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle(Text(.deployViewTitle))
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Top Action Bar
    
    private var topActionBar: some View {
        HStack {
            Button(action: { showingNaturalLanguageDeployment = true }) {
                HStack {
                    Image(systemName: "brain")
                    Text("AI 部署")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            Spacer()
            
            Button(action: { selectedTab = 2 }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("历史记录")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.2))
                .foregroundColor(.primary)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Template Deployment View

struct TemplateDeploymentView: View {
    @ObservedObject var vpsManager: VPSManager
    @ObservedObject var deploymentService: DeploymentService
    @State private var selectedCategory: ServiceCategory = .devops
    @State private var searchText = ""
    @State private var showingTemplateDetail = false
    @State private var selectedTemplate: DeploymentTemplate?
    @State private var selectedVPS: VPSInstance?
    
    // 新增：支持从外部传入预选的 VPS
    let preSelectedVPS: VPSInstance?
    
    init(vpsManager: VPSManager, deploymentService: DeploymentService, preSelectedVPS: VPSInstance? = nil) {
        self.vpsManager = vpsManager
        self.deploymentService = deploymentService
        self.preSelectedVPS = preSelectedVPS
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // 分类选择
            categorySelector
            
            // 模板列表
            templateList
        }
        .onAppear {
            // 如果有预选VPS，直接使用
            if let preSelectedVPS = preSelectedVPS {
                selectedVPS = preSelectedVPS
            }
        }
        .sheet(item: $selectedTemplate) { template in
            TemplateDetailView(
                template: template,
                vps: nil,
                vpsManager: vpsManager,
                deploymentService: deploymentService
            )
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索模板...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
    }
    
    // MARK: - Category Selector
    
    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ServiceCategory.allCases, id: \.self) { category in
                    Button(action: { selectedCategory = category }) {
                        HStack {
                            Image(systemName: category.icon)
                            Text(category.rawValue)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedCategory == category ? Color.accentColor : Color.secondary.opacity(0.2))
                        .foregroundColor(selectedCategory == category ? .white : .primary)
                        .cornerRadius(20)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom)
    }
    
    // MARK: - Template List
    
    private var templateList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredTemplates) { template in
                    TemplateCardView(template: template) {
                        selectedTemplate = template
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredTemplates: [DeploymentTemplate] {
        var templates = deploymentService.getTemplatesByCategory(selectedCategory)
        
        if !searchText.isEmpty {
            templates = templates.filter { template in
                template.name.localizedCaseInsensitiveContains(searchText) ||
                template.description.localizedCaseInsensitiveContains(searchText) ||
                template.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        return templates
    }
}

// MARK: - VPS Selection Card

struct VPSSelectionCard: View {
    let vps: VPSInstance
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vps.displayName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(vps.host)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(Color.accentColor, lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .foregroundColor(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
            }
            
            if let systemInfo = vps.systemInfo {
                HStack(spacing: 12) {
                    Text(.cpu, arguments: String(systemInfo.cpuCores))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("内存: \(Int(systemInfo.memoryUsage))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            onTap()
        }
    }
}



// MARK: - Natural Language Deployment View

struct NaturalLanguageDeploymentView: View {
    @ObservedObject var vpsManager: VPSManager
    @ObservedObject var deploymentService: DeploymentService
    @State private var description = ""
    @State private var selectedVPS: VPSInstance?
    @State private var showingDeployment = false
    @State private var showingCommandPreview = false
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 说明
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "brain")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor)
                        Text(.aiSmartDeployment)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Text(.aiDeploymentDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            
                // VPS 选择
                VStack(alignment: .leading, spacing: 12) {
                    Text(.selectVPS)
                        .font(.headline)
                    
                    if vpsManager.vpsInstances.isEmpty {
                        VStack(spacing: 12) {
                            Text(.noAvailableVPS)
                                .foregroundColor(.secondary)
                            
                            Button("添加 VPS") {
                                // 导航到 VPS 管理
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(vpsManager.vpsInstances) { vps in
                                    VPSSelectionCard(
                                        vps: vps,
                                        isSelected: selectedVPS?.id == vps.id
                                    ) {
                                        selectedVPS = vps
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // 需求描述
                VStack(alignment: .leading, spacing: 12) {
                    Text(.describeYourNeeds)
                        .font(.headline)
                    
                    TextEditor(text: $description)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                }
                .padding(.horizontal)
                
                // 操作按钮
                VStack(spacing: 12) {
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    HStack(spacing: 12) {
                        Button("生成部署方案") {
                            showingCommandPreview = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(selectedVPS == nil || description.isEmpty || isLoading)
                    }
                }
                .padding()
                
                // 底部间距，确保内容不被遮挡
                Spacer(minLength: 50)
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
        .sheet(isPresented: $showingDeployment) {
            if let vps = selectedVPS {
                NaturalLanguageDeploymentExecutionView(
                    vps: vps,
                    description: description,
                    deploymentService: deploymentService,
                    preGeneratedPlan: nil
                )
            }
        }
        .sheet(isPresented: $showingCommandPreview) {
            if let vps = selectedVPS {
                NaturalLanguageCommandPreviewView(
                    vps: vps,
                    description: description,
                    deploymentService: deploymentService,
                    preGeneratedPlan: nil
                )
            }
        }
        .hideKeyboardOnTapEnhanced()
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func generateDeploymentPlan() async {
        guard let vps = selectedVPS else { return }
        
        isLoading = true
        errorMessage = ""
        
        do {
            _ = try await deploymentService.createDeploymentFromNaturalLanguage(
                vpsId: vps.id,
                description: description
            )
            
            showingDeployment = true
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Deployment History View

struct DeploymentHistoryView: View {
    @ObservedObject var vpsManager: VPSManager
    @ObservedObject var deploymentService: DeploymentService
    @State private var selectedTask: DeploymentTask?
    
    var body: some View {
        VStack {
            if deploymentService.deploymentTasks.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text(.noDeploymentRecords)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(.startFirstDeployment)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(deploymentService.deploymentTasks.sorted(by: { task1, task2 in
                        let date1 = task1.completedAt ?? task1.startedAt ?? Date.distantPast
                        let date2 = task2.completedAt ?? task2.startedAt ?? Date.distantPast
                        return date1 > date2
                    })) { task in
                        DeploymentHistoryTaskRow(task: task) {
                            selectedTask = task
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedTask) { task in
            DeploymentTaskDetailView(task: task, vpsManager: vpsManager, deploymentService: deploymentService)
        }
    }
}

// MARK: - Deployment History Task Row

struct DeploymentHistoryTaskRow: View {
    let task: DeploymentTask
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(.deploymentTask, arguments: String(task.id.uuidString.prefix(8)))
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let completedAt = task.completedAt {
                        Text("\(String(.completedTime))\(completedAt, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let startedAt = task.startedAt {
                        Text("\(String(.startTime))\(startedAt, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(task.status.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(task.status.color.opacity(0.2))
                        .foregroundColor(task.status.color)
                        .cornerRadius(4)
                    
                    if task.status == .running {
                        ProgressView(value: task.progress)
                            .frame(width: 60)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Command Preview View

struct CommandPreviewView: View {
    let template: DeploymentTemplate
    let variables: [String: String]
    @ObservedObject var deploymentService: DeploymentService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 标签页选择器
                Picker("预览内容", selection: $selectedTab) {
                    Text("命令").tag(0)
                    if !template.configTemplate.isEmpty {
                        Text("配置文件").tag(1)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // 内容区域
                TabView(selection: $selectedTab) {
                    commandsPreview
                        .tag(0)
                    
                    if !template.configTemplate.isEmpty {
                        configPreview
                            .tag(1)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("命令预览")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Commands Preview
    
    private var commandsPreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 预览信息
                VStack(alignment: .leading, spacing: 8) {
                    Text(.commandsToExecute)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(.commandsDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // 命令列表
                LazyVStack(spacing: 12) {
                    let commands = deploymentService.previewDeploymentCommands(
                        template: template,
                        variables: variables
                    )
                    
                    ForEach(Array(commands.enumerated()), id: \.offset) { index, command in
                        CommandRowView(
                            index: index + 1,
                            command: command,
                            total: commands.count
                        )
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
    
    // MARK: - Config Preview
    
    private var configPreview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 预览信息
                VStack(alignment: .leading, spacing: 8) {
                    Text(.configFileContent)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(.configFilesDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // 配置文件内容
                VStack(alignment: .leading, spacing: 8) {
                    let configContent = deploymentService.previewConfigurationFile(
                        template: template,
                        variables: variables
                    )
                    
                    if configContent.isEmpty {
                        Text(.noConfigFiles)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        Text(configContent)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Command Row View

struct CommandRowView: View {
    let index: Int
    let command: String
    let total: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(.commandProgress, arguments: String(index), String(total))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // 命令类型指示器
                HStack(spacing: 4) {
                    Circle()
                        .fill(commandTypeColor)
                        .frame(width: 6, height: 6)
                    
                    Text(commandTypeText)
                        .font(.caption2)
                        .foregroundColor(commandTypeColor)
                }
            }
            
            Text(command)
                .font(.system(.body, design: .monospaced))
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .textSelection(.enabled)
        }
    }
    
    private var commandTypeColor: Color {
        if command.hasPrefix("sudo") {
            return .red
        } else if command.contains("install") || command.contains("apt") || command.contains("yum") {
            return .blue
        } else if command.contains("systemctl") || command.contains("service") {
            return .green
        } else if command.contains("echo") || command.contains("cat") {
            return .orange
        } else {
            return .gray
        }
    }
    
    private var commandTypeText: String {
        if command.hasPrefix("sudo") {
            return "特权命令"
        } else if command.contains("install") || command.contains("apt") || command.contains("yum") {
            return "安装命令"
        } else if command.contains("systemctl") || command.contains("service") {
            return "服务管理"
        } else if command.contains("echo") || command.contains("cat") {
            return "信息查看"
        } else {
            return "普通命令"
        }
    }
}

