//
//  QuickDeployView.swift
//  SwiftUIApp
//
//  Created by Song.Wang on 2025/8/23.
//


import SwiftUI

struct QuickDeployView: View {
    let vps: VPSInstance
    @ObservedObject var vpsManager: VPSManager
    @ObservedObject var deploymentService: DeploymentService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTemplate: DeploymentTemplate?
    @State private var showingTemplateSelection = false
    @State private var showingAIDeployment = false
    @State private var showingCustomDeployment = false
    @State private var showingRecentDeployments = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // VPS 信息卡片
                    vpsInfoCard
                    
                    // 最近部署
                    if !recentDeployments.isEmpty {
                        recentDeploymentsSection
                    }
                    
                    // 快速部署选项
//                    quickDeployOptionsSection
                    
                    // 推荐模板
                    recommendedTemplatesSection
                }
                .padding()
            }
            .navigationTitle("快速部署")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("刷新") {
                            checkConnectionStatus()
                        }
                        
                        Button("查看部署历史") {
                            showingRecentDeployments = true
                        }
                        
                        Button("连接测试") {
                            Task {
                                await testConnection()
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingTemplateSelection) {
                TemplateSelectionView(vps: vps, vpsManager: vpsManager, deploymentService: deploymentService)
            }
            .sheet(isPresented: $showingAIDeployment) {
                AIDeploymentView(vps: vps, deploymentService: deploymentService)
            }
            .sheet(isPresented: $showingCustomDeployment) {
                CustomDeploymentView(vps: vps, deploymentService: deploymentService)
            }
            .sheet(isPresented: $showingRecentDeployments) {
                RecentDeploymentsView(vps: vps, deploymentService: deploymentService)
            }
            .alert("错误", isPresented: $showingErrorAlert) {
                Button("确定") { }
            } message: {
                Text(errorMessage)
            }
            .alert("成功", isPresented: $showingSuccessAlert) {
                Button("确定") { }
            } message: {
                Text(successMessage)
            }
            .onAppear {
                initializeData()
            }
        }
    }
    
    // MARK: - VPS Info Card
    
    private var vpsInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(.deploymentTarget)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(vps.displayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(vps.host)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    // 连接状态指示器
                    HStack(spacing: 6) {
                        Circle()
                            .fill(vps.statusColor)
                            .frame(width: 8, height: 8)
                        
                        Text(vps.statusColor == .green ? "在线" : "离线")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // 系统信息（如果有）
                    if let systemInfo = vps.systemInfo {
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 8) {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(.memory)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(Int(systemInfo.memoryUsage))%")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(memoryUsageColor(systemInfo.memoryUsage))
                                }
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(.disk)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Text("\(Int(systemInfo.diskUsage))%")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(diskUsageColor(systemInfo.diskUsage))
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Recent Deployments Section
    
    private var recentDeploymentsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(.recentDeployments)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("查看全部") {
                    showingRecentDeployments = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if recentDeployments.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text(.noDeploymentRecords)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("开始部署") {
                        showingTemplateSelection = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(recentDeployments.prefix(3)) { task in
                            RecentDeploymentCard(task: task, deploymentService: deploymentService)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    // MARK: - Quick Deploy Options Section
    
    private var quickDeployOptionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(.selectDeploymentMethod)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                QuickDeployOption(
                    title: "使用模板",
                    subtitle: "选择预配置的部署模板",
                    icon: "doc.text",
                    color: .blue,
                    badge: "推荐"
                ) {
                    showingTemplateSelection = true
                }
                
                QuickDeployOption(
                    title: "AI 部署",
                    subtitle: "用自然语言描述需求",
                    icon: "brain.head.profile",
                    color: .purple,
                    badge: "智能"
                ) {
                    showingAIDeployment = true
                }
                
//                QuickDeployOption(
//                    title: "自定义部署",
//                    subtitle: "手动配置部署参数",
//                    icon: "gearshape",
//                    color: .orange
//                ) {
//                    showingCustomDeployment = true
//                }
//                
//                QuickDeployOption(
//                    title: "快速部署",
//                    subtitle: "一键部署常用服务",
//                    icon: "bolt",
//                    color: .green,
//                    badge: "快速"
//                ) {
//                    // TODO: 实现快速部署功能
//                    showSuccessMessage("快速部署功能开发中...")
//                }
            }
        }
    }
    
    // MARK: - Recommended Templates Section
    
    private var recommendedTemplatesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(.recommendedTemplates)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("查看全部") {
                    showingTemplateSelection = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if recommendedTemplates.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text(.noRecommendedTemplates)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button("浏览模板") {
                        showingTemplateSelection = true
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(recommendedTemplates.prefix(4)) { template in
                        RecommendedTemplateCard(template: template) {
                            selectedTemplate = template
                            showingTemplateSelection = true
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var recentDeployments: [DeploymentTask] {
        return deploymentService.deploymentTasks
            .filter { $0.vpsId == vps.id }
            .sorted { ($0.startedAt ?? Date.distantPast) > ($1.startedAt ?? Date.distantPast) }
    }
    
    private var recommendedTemplates: [DeploymentTemplate] {
        return deploymentService.templates
            .filter { $0.isOfficial && $0.rating >= 4.0 }
            .sorted { $0.rating > $1.rating }
    }
    
    // MARK: - Private Methods
    
    private func checkConnectionStatus() {
        Task {
            await testConnection()
        }
    }
    
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showingSuccessAlert = true
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
    }
    
    private func testConnection() async {
        do {
            let testResult = await vpsManager.testConnection(for: vps)
            if !testResult.isConnected {
                let errorMessage = testResult.sshError ?? LocalizationManager.shared.localizedString(.unknownError)
                throw VPSManagerError.connectionFailed(errorMessage)
            }
        } catch {
            
        }
    }
    
    private func memoryUsageColor(_ usage: Double) -> Color {
        if usage >= 90 {
            return .red
        } else if usage >= 70 {
            return .orange
        } else {
            return .green
        }
    }
    
    private func diskUsageColor(_ usage: Double) -> Color {
        if usage >= 90 {
            return .red
        } else if usage >= 70 {
            return .orange
        } else {
            return .green
        }
    }
    
    private func initializeData() {
        // 初始化数据
        checkConnectionStatus()
        
        // 检查是否有推荐模板
        if recommendedTemplates.isEmpty {
            // 可以在这里加载默认模板
        }
        
        // 检查最近部署记录
        if recentDeployments.isEmpty {
            // 可以在这里显示欢迎信息
        }
    }
}

// MARK: - Quick Deploy Option

struct QuickDeployOption: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let badge: String?
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        badge: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.badge = badge
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let badge = badge {
                            Text(badge)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(color.opacity(0.2))
                                .foregroundColor(color)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recent Deployment Card

struct RecentDeploymentCard: View {
    let task: DeploymentTask
    let deploymentService: DeploymentService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: task.status.icon)
                    .foregroundColor(task.status.color)
                    .font(.caption)
                
                Spacer()
                
                if let startedAt = task.startedAt {
                    Text(startedAt.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(taskName)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(task.status.displayName)
                .font(.caption)
                .foregroundColor(task.status.color)
        }
        .padding()
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
        .frame(width: 120)
    }
    
    private var taskName: String {
        if let templateId = task.templateId,
           let template = deploymentService.getTemplate(by: templateId.uuidString) {
            return template.name
        } else {
            return LocalizationManager.shared.localizedString(.customDeployment)
        }
    }
}

// MARK: - Recommended Template Card

struct RecommendedTemplateCard: View {
    let template: DeploymentTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: template.serviceType.icon)
                        .foregroundColor(template.serviceType.color)
                        .font(.title3)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.yellow)
                        
                        Text(String(format: "%.1f", template.rating))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Text(template.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                Text(template.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Text(template.serviceType.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(template.serviceType.color.opacity(0.1))
                        .foregroundColor(template.serviceType.color)
                        .cornerRadius(4)
                    
                    Spacer()
                    
                    Text("\(template.downloads)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Template Selection View

struct TemplateSelectionView: View {
    let vps: VPSInstance
    @ObservedObject var vpsManager: VPSManager
    @ObservedObject var deploymentService: DeploymentService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedCategory: ServiceCategory = .proxy
    @State private var searchText = ""
    @State private var showingTemplateDetail: DeploymentTemplate?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 搜索栏
                searchBar
                
                // 分类选择
                categorySelector
                
                // 模板列表
                templateList
            }
            .navigationTitle("选择模板")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationManager.shared.localizedString(.back)) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("管理") {
                        // TODO: 导航到模板管理
                    }
                }
            }
            .sheet(item: $showingTemplateDetail) { template in
                TemplateDetailView(
                    template: template, 
                    vps: vps, 
                    vpsManager: vpsManager, 
                    deploymentService: deploymentService
                )
            }
        }
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("搜索模板...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button("清除") {
                    searchText = ""
                }
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top)
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
        .padding(.vertical)
    }
    
    // MARK: - Template List
    
    private var templateList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredTemplates) { template in
                    TemplateCardView(template: template) {
                        showingTemplateDetail = template
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
            templates = deploymentService.searchTemplates(query: searchText)
                .filter { $0.category == selectedCategory }
        }
        
        return templates.sorted { $0.rating > $1.rating }
    }
}

// MARK: - Template Card View

struct TemplateCardView: View {
    let template: DeploymentTemplate
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(template.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            
                            Text(String(format: "%.1f", template.rating))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Text("\(template.downloads) 次下载")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack {
                    Text(template.serviceType.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(template.serviceType.color.opacity(0.1))
                        .foregroundColor(template.serviceType.color)
                        .cornerRadius(6)
                    
                    if template.isOfficial {
                        Text("官方")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Template Detail View

struct TemplateDetailView: View {
    let template: DeploymentTemplate
    @ObservedObject var vpsManager: VPSManager
    @ObservedObject var deploymentService: DeploymentService
    @Environment(\.dismiss) private var dismiss
    
    // 支持预选的 VPS，如果没有则需要在页面中选择
    let preSelectedVPS: VPSInstance?
    
    @State private var variables: [String: String] = [:]
    @State private var showingDeployment = false
    @State private var isDeploying = false
    @State private var showingPreview = false
    @State private var selectedVPS: VPSInstance?
    @State private var showingAddVPS = false
    
    init(template: DeploymentTemplate, vps: VPSInstance? = nil, vpsManager: VPSManager, deploymentService: DeploymentService) {
        self.template = template
        self.preSelectedVPS = vps
        self.vpsManager = vpsManager
        self.deploymentService = deploymentService
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 模板信息
                    templateInfoSection
                    
                    // VPS 选择区域
                    vpsSelectionSection
                    
                    // 变量配置
                    variablesSection
                    
                    // 预览
                    previewSection
                    
                    // 操作按钮
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("模板详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                initializeVariables()
                // 如果有预选VPS，直接使用
                if let preSelectedVPS = preSelectedVPS {
                    selectedVPS = preSelectedVPS
                }
            }
            .sheet(isPresented: $showingDeployment) {
                if let selectedVPS = selectedVPS {
                    DeploymentExecutionView(
                        vps: selectedVPS,
                        template: template,
                        variables: variables,
                        deploymentService: deploymentService
                    )
                }
            }
            .sheet(isPresented: $showingAddVPS) {
                AddVPSView(vpsManager: vpsManager)
            }
        }
    }
    
    // MARK: - Template Info Section
    
    private var templateInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(template.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        
                        Text(String(format: "%.1f", template.rating))
                            .fontWeight(.medium)
                    }
                    
                    Text("\(template.downloads) 次下载")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                Text(template.serviceType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(template.serviceType.color.opacity(0.1))
                    .foregroundColor(template.serviceType.color)
                    .cornerRadius(6)
                
                if template.isOfficial {
                    Text("官方模板")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                
                Spacer()
            }
            
            if !template.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(template.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.1))
                                .foregroundColor(.secondary)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - VPS Selection Section
    
    private var vpsSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(.selectDeploymentTarget)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("添加 VPS") {
                    showingAddVPS = true
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
            
            if vpsManager.vpsInstances.isEmpty {
                emptyVPSState
            } else {
                vpsList
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    private var emptyVPSState: some View {
        VStack(spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            
            Text(.noAvailableVPS)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(.pleaseAddVPSFirst)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("添加 VPS") {
                showingAddVPS = true
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
    
    private var vpsList: some View {
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
            .padding(.horizontal)
        }
    }
    
    // MARK: - Variables Section
    
    private var variablesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(.configParameters)
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(template.variables, id: \.name) { variable in
                    if template.serviceType == .singbox && variable.name == "protocol" {
                        // 协议选择器
                        VariableInputView(
                            variable: variable,
                            value: Binding(
                                get: { variables[variable.name] ?? variable.defaultValue ?? "" },
                                set: { variables[variable.name] = $0 }
                            )
                        )
                    } else if template.serviceType == .singbox && shouldShowVariable(variable) {
                        // 协议相关参数
                        ProtocolAwareVariableInputView(
                            variable: variable,
                            protocol: variables["protocol"] ?? "shadowsocks",
                            value: Binding(
                                get: { variables[variable.name] ?? variable.defaultValue ?? "" },
                                set: { variables[variable.name] = $0 }
                            )
                        )
                    } else if template.serviceType != .singbox {
                        // 非sing-box模板的普通变量
                        VariableInputView(
                            variable: variable,
                            value: Binding(
                                get: { variables[variable.name] ?? variable.defaultValue ?? "" },
                                set: { variables[variable.name] = $0 }
                            )
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Methods
    
    private func shouldShowVariable(_ variable: TemplateVariable) -> Bool {
        let selectedProtocol = variables["protocol"] ?? "shadowsocks"
        
        // 通用参数始终显示
        if ["port", "password", "log_level"].contains(variable.name) {
            return true
        }
        
        // 通用 TLS 参数 - 对于支持 TLS 的协议显示
        let tlsSupportedProtocols = ["vmess", "trojan", "vless", "hysteria", "shadowtls", "tuic", "hysteria2", "anytls"]
        if tlsSupportedProtocols.contains(selectedProtocol) {
            // TLS 开关始终显示
            if variable.name == "tls_enabled" {
                return true
            }
            
            // 检查 TLS 是否启用
            let tlsEnabled = variables["tls_enabled"] ?? "false"
            if tlsEnabled == "true" {
                // 基础 TLS 参数始终显示
                let basicTlsParams = [
                    "tls_server_name", "tls_insecure", "tls_alpn", 
                    "tls_min_version", "tls_max_version", "tls_certificate_path", "tls_key_path"
                ]
                if basicTlsParams.contains(variable.name) {
                    return true
                }
                
                // ACME 相关参数 - 只在 ACME 启用时显示
                if variable.name == "tls_acme_enabled" {
                    return true
                }
                let acmeEnabled = variables["tls_acme_enabled"] ?? "false"
                if acmeEnabled == "true" {
                    let acmeParams = ["tls_acme_domain", "tls_acme_email", "tls_acme_provider"]
                    if acmeParams.contains(variable.name) {
                        return true
                    }
                }
                
                // ECH 相关参数 - 只在 ECH 启用时显示
                if variable.name == "tls_ech_enabled" {
                    return true
                }
                let echEnabled = variables["tls_ech_enabled"] ?? "false"
                if echEnabled == "true" {
                    let echParams = ["tls_ech_key_path", "tls_ech_config_path"]
                    if echParams.contains(variable.name) {
                        return true
                    }
                }
                
                // Reality 相关参数 - 只在 Reality 启用时显示
                if variable.name == "tls_reality_enabled" {
                    return true
                }
                let realityEnabled = variables["tls_reality_enabled"] ?? "false"
                if realityEnabled == "true" {
                    let realityParams = [
                        "tls_reality_private_key", "tls_reality_public_key",
                        "tls_reality_handshake_server", "tls_reality_handshake_port", "tls_reality_short_id"
                    ]
                    if realityParams.contains(variable.name) {
                        return true
                    }
                }
                
                // uTLS 相关参数 - 只在 uTLS 启用时显示 (仅客户端)
                if variable.name == "tls_utls_enabled" {
                    return true
                }
                let utlsEnabled = variables["tls_utls_enabled"] ?? "false"
                if utlsEnabled == "true" {
                    let utlsParams = ["tls_utls_fingerprint"]
                    if utlsParams.contains(variable.name) {
                        return true
                    }
                }
                
                // TLS 分片相关参数 - 只在分片启用时显示 (仅客户端)
                if variable.name == "tls_fragment_enabled" {
                    return true
                }
                let fragmentEnabled = variables["tls_fragment_enabled"] ?? "false"
                if fragmentEnabled == "true" {
                    let fragmentParams = ["tls_record_fragment_enabled"]
                    if fragmentParams.contains(variable.name) {
                        return true
                    }
                }
            }
        }
        
        // 根据协议显示相应参数
        switch selectedProtocol {
        case "direct", "mixed":
            return false // 这些协议不需要额外参数
        case "socks":
            return ["socks_username", "socks_password"].contains(variable.name)
        case "http":
            return ["http_username", "http_password"].contains(variable.name)
        case "shadowsocks":
            return ["method"].contains(variable.name)
        case "vmess":
            return ["vmess_uuid", "vmess_alter_id"].contains(variable.name)
        case "trojan":
            return ["trojan_uuid"].contains(variable.name)
        case "naive":
            return ["naive_username", "naive_password"].contains(variable.name)
        case "hysteria":
            // Hysteria 基础参数始终显示
            if variable.name == "hysteria_password" {
                return true
            }
            
            // 带宽参数 - 可选显示
            let bandwidthParams = ["hysteria_up_mbps", "hysteria_down_mbps"]
            if bandwidthParams.contains(variable.name) {
                return true
            }
            
            return false
        case "shadowtls":
            return ["shadowtls_password", "shadowtls_server"].contains(variable.name)
        case "tuic":
            // TUIC 基础参数始终显示
            let basicTUICParams = ["tuic_uuid", "tuic_password"]
            if basicTUICParams.contains(variable.name) {
                return true
            }
            
            // TUIC 高级参数 - 可选显示
            let advancedTUICParams = ["tuic_congestion_control", "tuic_udp_relay_mode", "tuic_max_datagram_size"]
            if advancedTUICParams.contains(variable.name) {
                return true
            }
            
            return false
        case "hysteria2":
            return ["hysteria2_password"].contains(variable.name)
        case "vless":
            // VLESS 基础参数始终显示
            let basicVlessParams = ["vless_uuid", "vless_flow", "vless_transport_type"]
            if basicVlessParams.contains(variable.name) {
                return true
            }
            
            // 传输相关参数 - 根据传输类型动态显示
            let transportType = variables["vless_transport_type"] ?? "tcp"
            
            // TCP 传输不需要额外参数
            if transportType == "tcp" {
                // 只显示基础参数
            } else {
                // WebSocket 传输参数
                if transportType == "ws" {
                    let wsParams = ["vless_transport_path", "vless_transport_host", "vless_transport_headers", "vless_transport_max_early_data", "vless_transport_use_browser_forwarding"]
                    if wsParams.contains(variable.name) {
                        return true
                    }
                }
                
                // gRPC 传输参数
                if transportType == "grpc" {
                    let grpcParams = ["vless_transport_service_name", "vless_transport_idle_timeout", "vless_transport_ping_timeout", "vless_transport_permit_without_stream"]
                    if grpcParams.contains(variable.name) {
                        return true
                    }
                }
                
                // QUIC 传输参数 (目前 QUIC 不需要额外参数)
                if transportType == "quic" {
                    // QUIC 目前不需要额外参数
                }
            }
            
            // 多路复用相关参数 - 只在多路复用启用时显示
            if variable.name == "vless_multiplex_enabled" {
                return true
            }
            let multiplexEnabled = variables["vless_multiplex_enabled"] ?? "false"
            if multiplexEnabled == "true" {
                // 基础多路复用参数
                let basicMultiplexParams = ["vless_multiplex_padding", "vless_multiplex_protocol", "vless_multiplex_max_connections", "vless_multiplex_min_streams", "vless_multiplex_max_streams"]
                if basicMultiplexParams.contains(variable.name) {
                    return true
                }
                
                // Brutal 相关参数 - 只在 Brutal 启用时显示
                if variable.name == "vless_multiplex_brutal_enabled" {
                    return true
                }
                let brutalEnabled = variables["vless_multiplex_brutal_enabled"] ?? "false"
                if brutalEnabled == "true" {
                    let brutalParams = ["vless_multiplex_brutal_up_mbps", "vless_multiplex_brutal_down_mbps"]
                    if brutalParams.contains(variable.name) {
                        return true
                    }
                }
            }
            
            return false
        case "anytls":
            return ["anytls_uuid", "anytls_server"].contains(variable.name)
        case "tun":
            return ["tun_interface_name", "tun_mtu", "tun_auto_route"].contains(variable.name)
        case "redirect":
            return ["redirect_to"].contains(variable.name)
        case "tproxy":
            return ["tproxy_mode", "tproxy_network"].contains(variable.name)
        default:
            return false
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(.previewCommands)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingPreview.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(showingPreview ? "隐藏" : "查看")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Image(systemName: showingPreview ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if showingPreview {
                VStack(alignment: .leading, spacing: 8) {
                    Text(.deploymentCommands)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(deploymentService.previewDeploymentCommands(template: template, variables: variables), id: \.self) { command in
                        Text(command)
                            .font(.caption)
                            .padding()
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(6)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            
            // 部署按钮
            Button(action: {
                showingDeployment = true
            }) {
                HStack {
                    if isDeploying {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "play.circle.fill")
                    }
                    
                    Text(isDeploying ? "部署中..." : "开始部署")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedVPS != nil ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isDeploying || selectedVPS == nil)
            
            // VPS 选择提示
            if selectedVPS == nil {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(.pleaseSelectVPS)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeVariables() {
        for variable in template.variables {
            variables[variable.name] = variable.defaultValue
        }
    }
}

// MARK: - Variable Input View

struct VariableInputView: View {
    let variable: TemplateVariable
    @Binding var value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(variable.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if variable.required {
                    Text("*")
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                if !variable.description.isEmpty {
                    Button(action: {
                        // TODO: 显示帮助信息
                    }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 根据变量类型渲染不同的输入控件
            switch variable.type {
            case .select:
                if let options = variable.options, !options.isEmpty {
                    Picker(variable.name, selection: $value) {
                        ForEach(options, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    TextField("输入 \(variable.name)", text: $value)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            case .password:
                SecureField("输入 \(variable.name)", text: $value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            case .number:
                TextField("输入 \(variable.name)", text: $value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            case .boolean:
                Toggle(variable.name, isOn: Binding(
                    get: { value.lowercased() == "true" },
                    set: { value = $0 ? "true" : "false" }
                ))
                .toggleStyle(SwitchToggleStyle())
            default:
                TextField("输入 \(variable.name)", text: $value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            if !variable.description.isEmpty {
                Text(variable.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Protocol Aware Variable Input View

struct ProtocolAwareVariableInputView: View {
    let variable: TemplateVariable
    let `protocol`: String
    @Binding var value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(variable.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if variable.required {
                    Text("*")
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                // 显示协议标识
                Text("(\(`protocol`))")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                if !variable.description.isEmpty {
                    Button(action: {
                        // TODO: 显示帮助信息
                    }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 根据变量类型渲染不同的输入控件
            switch variable.type {
            case .select:
                if let options = variable.options, !options.isEmpty {
                    Picker(variable.name, selection: $value) {
                        ForEach(options, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                } else {
                    TextField("输入 \(variable.name)", text: $value)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            case .password:
                SecureField("输入 \(variable.name)", text: $value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            case .number:
                TextField("输入 \(variable.name)", text: $value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            case .boolean:
                Toggle(variable.name, isOn: Binding(
                    get: { value.lowercased() == "true" },
                    set: { value = $0 ? "true" : "false" }
                ))
                .toggleStyle(SwitchToggleStyle())
            default:
                TextField("输入 \(variable.name)", text: $value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            
            if !variable.description.isEmpty {
                Text(variable.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - AI Deployment View

struct AIDeploymentView: View {
    let vps: VPSInstance
    @ObservedObject var deploymentService: DeploymentService
    @Environment(\.dismiss) private var dismiss
    
    @State private var description = ""
    @State private var isGenerating = false
    @State private var showingDeployment = false
    @State private var deploymentPlan: DeploymentPlan?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 说明
                VStack(alignment: .leading, spacing: 8) {
                    Text(.aiSmartDeployment)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(.aiDeploymentDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // 输入区域
                VStack(alignment: .leading, spacing: 12) {
                    Text(.describeYourNeeds)
                        .font(.headline)
                    
                    TextEditor(text: $description)
                        .frame(minHeight: 120)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                
                // 示例
                VStack(alignment: .leading, spacing: 8) {
                    Text(.examples)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• 部署一个 Shadowsocks 代理服务器")
                        Text("• 安装 Nginx 并配置反向代理")
                        Text("• 搭建一个 WordPress 网站")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // 生成按钮
                Button(action: generateDeploymentPlan) {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "brain.head.profile")
                        }
                        
                        Text(isGenerating ? "AI 分析中..." : "生成部署方案")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(description.isEmpty ? Color.gray : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(description.isEmpty || isGenerating)
            }
            .padding()
            .navigationTitle("AI 部署")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .hideKeyboardOnTap()
            .sheet(isPresented: $showingDeployment) {
                if let plan = deploymentPlan {
                    NaturalLanguageDeploymentExecutionView(
                        vps: vps,
                        description: description,
                        deploymentService: deploymentService,
                        preGeneratedPlan: plan
                    )
                }
            }
        }
    }
    
    private func generateDeploymentPlan() {
        guard !description.isEmpty else { return }
        
        isGenerating = true
        
        Task {
            do {
                let plan = try await deploymentService.previewNaturalLanguageDeployment(
                    description: description,
                    vps: vps
                )
                
                await MainActor.run {
                    deploymentPlan = plan
                    showingDeployment = true
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    // TODO: 显示错误信息
                }
            }
        }
    }
}

// MARK: - Custom Deployment View

struct CustomDeploymentView: View {
    let vps: VPSInstance
    @ObservedObject var deploymentService: DeploymentService
    @Environment(\.dismiss) private var dismiss
    
    @State private var commands: [String] = [""]
    @State private var variables: [String: String] = [:]
    @State private var showingDeployment = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 说明
                    VStack(alignment: .leading, spacing: 8) {
                        Text(.customDeployment)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(.customDeploymentDescription)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // 命令列表
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(.deploymentCommands)
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("添加命令") {
                                commands.append("")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        ForEach(commands.indices, id: \.self) { index in
                            HStack {
                                TextField("输入命令...", text: $commands[index])
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                if commands.count > 1 {
                                    Button(action: {
                                        commands.remove(at: index)
                                    }) {
                                        Image(systemName: "minus.circle")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    }
                    
                    // 变量配置
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(.environmentVariables)
                                .font(.headline)
                            
                            Spacer()
                            
                            Button("添加变量") {
                                // TODO: 添加变量输入
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        // TODO: 实现变量输入界面
                    }
                    
                    Spacer()
                    
                    // 部署按钮
                    Button(action: {
                        showingDeployment = true
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text(.startDeployment)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(commands.allSatisfy { $0.isEmpty })
                }
                .padding()
            }
            .navigationTitle("自定义部署")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
            .hideKeyboardOnTap()
            .sheet(isPresented: $showingDeployment) {
                CustomDeploymentExecutionView(
                    vps: vps,
                    deploymentService: deploymentService,
                    commands: commands.filter { !$0.isEmpty },
                    variables: variables
                )
            }
        }
    }
}

// MARK: - Custom Deployment Execution View

struct CustomDeploymentExecutionView: View {
    let vps: VPSInstance
    @ObservedObject var deploymentService: DeploymentService
    let commands: [String]
    let variables: [String: String]
    @Environment(\.dismiss) private var dismiss
    
    @State private var isExecuting = false
    @State private var currentTask: DeploymentTask?
    @State private var showingLogs = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 部署信息
                VStack(alignment: .leading, spacing: 12) {
                    Text(.customDeploymentExecution)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(.executingCustomCommands)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(.command)
                        ForEach(commands, id: \.self) { command in
                            Text("• \(command)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                Spacer()
                
                // 操作按钮
                VStack(spacing: 12) {
                    Button("开始执行") {
                        startDeployment()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isExecuting)
                    
                    Button("关闭") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("自定义部署")
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
    
    private func startDeployment() {
        // TODO: 实现自定义部署逻辑
        isExecuting = true
        
        // 模拟部署过程
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isExecuting = false
            dismiss()
        }
    }
}

// MARK: - Recent Deployments View

struct RecentDeploymentsView: View {
    let vps: VPSInstance
    @ObservedObject var deploymentService: DeploymentService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(recentDeployments) { task in
                    DeploymentTaskRow(
                        task: task,
                        vpsManager: VPSManager(), // TODO: 传入正确的 vpsManager
                        deploymentService: deploymentService
                    ) {
                        // 显示任务详情
                    }
                }
            }
            .navigationTitle("部署历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("返回") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var recentDeployments: [DeploymentTask] {
        return deploymentService.deploymentTasks
            .filter { $0.vpsId == vps.id }
            .sorted { ($0.startedAt ?? Date.distantPast) > ($1.startedAt ?? Date.distantPast) }
    }
}



// MARK: - Preview

struct QuickDeployView_Previews: PreviewProvider {
    static var previews: some View {
        QuickDeployView(
            vps: VPSInstance(
                name: "测试 VPS",
                host: "192.168.1.100",
                port: 22,
                username: "root",
                password: "password"
            ),
            vpsManager: VPSManager(),
            deploymentService: DeploymentService(vpsManager: VPSManager())
        )
    }
}
