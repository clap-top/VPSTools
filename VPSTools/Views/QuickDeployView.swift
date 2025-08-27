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
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
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
            
            TextField("输入 \(variable.name)", text: $value)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            
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
