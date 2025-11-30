import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var newHost = ""
    @State private var newInterval = "60"
    @State private var launchAtLogin = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Monitoring List
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Monitored Hosts")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                        ForEach(appState.monitoredHosts) { host in
                            HStack {
                                Text(host.host)
                                Spacer()
                                Text("\(Int(host.interval))s")
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    if let index = appState.monitoredHosts.firstIndex(where: { $0.id == host.id }) {
                                        appState.removeMonitoredHost(at: IndexSet(integer: index))
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 8)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                            .padding(.bottom, 4)
                        }
                        
                        if appState.monitoredHosts.isEmpty {
                            Text("No monitored hosts")
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    }
                    
                    // Add Host Section
                    HStack {
                        TextField("IP or hostname", text: $newHost)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("Sec", text: $newInterval)
                            .frame(width: 60)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button("Add") {
                            // Validate and add host
                            guard !newHost.isEmpty else { return }
                            guard let interval = Double(newInterval), interval >= 1 else {
                                errorMessage = "Interval must be at least 1 second"
                                showError = true
                                return
                            }
                            appState.addMonitoredHost(host: newHost, interval: interval)
                            newHost = ""
                            newInterval = "60"
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // General Section
                    HStack {
                        Toggle("Launch at Login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { newValue in
                                toggleLaunchAtLogin(newValue)
                            }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("PingApp v1.0")
                                .font(.headline)
                            Text("Developed by Nikos Papadopulos")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .padding(.horizontal, 20)
            }
            
            Divider()
            
            HStack {
                Spacer()
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
        }
        .frame(width: 450, height: 600)
        .onAppear {
            checkLaunchAtLogin()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func toggleLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert toggle state and show error
            launchAtLogin = !enabled
            errorMessage = "Failed to update launch at login: \(error.localizedDescription)"
            showError = true
        }
    }
    
    private func checkLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
