import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header / Ping Input
            PingInputView()
                .padding()
            
            Divider()
            
            // History
            if !appState.history.isEmpty {
                HistoryView()
                    .padding(.horizontal)
                    .padding(.top, 8)
            }
            
            Divider()
                .padding(.vertical, 8)
            
            // Monitoring
            MonitoringView()
                .padding(.horizontal)
            
            Spacer()
            
            // Footer / Settings Button
            HStack {
                Spacer()
                Menu {
                    Button("Settings") {
                        showSettings = true
                    }
                    Divider()
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .padding()
            }
        }
        .frame(width: 320, height: 450)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}
