import SwiftUI

// MARK: - Edit VPS View

struct EditVPSView: View {
    let vps: VPSInstance
    @ObservedObject var vpsManager: VPSManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String
    @State private var host: String
    @State private var port: String
    @State private var username: String
    @State private var password: String
    @State private var privateKey: String
    @State private var privateKeyPhrase: String
    @State private var group: String
    @State private var tags: String
    @State private var authMethod: AuthMethod
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    init(vps: VPSInstance, vpsManager: VPSManager) {
        self.vps = vps
        self.vpsManager = vpsManager
        
        _name = State(initialValue: vps.name)
        _host = State(initialValue: vps.host)
        _port = State(initialValue: String(vps.port))
        _username = State(initialValue: vps.username)
        _password = State(initialValue: vps.password ?? "")
        _privateKey = State(initialValue: vps.privateKey ?? "")
        _privateKeyPhrase = State(initialValue: vps.privateKeyPhrase ?? "")
        _group = State(initialValue: vps.group)
        _tags = State(initialValue: vps.tags.joined(separator: ", "))
        _authMethod = State(initialValue: vps.password != nil ? .password : .privateKey)
    }
    
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
                        TextField(LocalizationManager.shared.localizedString(.privateKey), text: $privateKey)
                        TextField(LocalizationManager.shared.localizedString(.privateKeyPhrase), text: $privateKeyPhrase)
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
            .navigationTitle(LocalizationManager.shared.localizedString(.editVPS))
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
                            await updateVPS()
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
        (authMethod == .password ? !password.isEmpty : !privateKey.isEmpty)
    }
    
    private func updateVPS() async {
        isLoading = true
        errorMessage = ""
        
        do {
            var updatedVPS = vps
            updatedVPS.name = name
            updatedVPS.host = host
            updatedVPS.port = Int(port) ?? 22
            updatedVPS.username = username
            updatedVPS.password = authMethod == .password ? password : nil
            updatedVPS.privateKey = authMethod != .password ? privateKey : nil
            updatedVPS.group = group
            updatedVPS.tags = tags.isEmpty ? [] : tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            
            try await vpsManager.updateVPS(updatedVPS)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Auth Method

enum AuthMethod: String, CaseIterable {
    case password = "password"
    case privateKey = "privateKey"
    
    var displayName: String {
        switch self {
        case .password:
            return LocalizationManager.shared.localizedString(.password)
        case .privateKey:
            return LocalizationManager.shared.localizedString(.privateKey)
        }
    }
}

// MARK: - Preview

struct EditVPSView_Previews: PreviewProvider {
    static var previews: some View {
        EditVPSView(
            vps: VPSInstance(
                name: "测试 VPS",
                host: "192.168.1.100",
                username: "root"
            ),
            vpsManager: VPSManager()
        )
    }
}
