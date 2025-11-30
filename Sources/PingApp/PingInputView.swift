import SwiftUI

struct PingInputView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ping Address")
                .font(.headline)
            
            HStack {
                TextField("Enter IP or Domain", text: $appState.pingInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit {
                        appState.pingInput = appState.pingInput.trimmingCharacters(in: .whitespaces)
                        appState.pingCurrentInput()
                    }
                
                Button(action: {
                    appState.pingInput = appState.pingInput.trimmingCharacters(in: .whitespaces)
                    appState.pingCurrentInput()
                }) {
                    Image(systemName: "arrow.right")
                }
                .disabled(appState.pingInput.isEmpty || appState.isPinging)
                
                // Result indicator inline
                if appState.isPinging {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 20, height: 20)
                } else if let result = appState.currentPingResult {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(ColorRules.color(for: result))
                            .frame(width: 12, height: 12)
                        
                        if let latency = result.latency {
                            Text("\(Int(latency)) ms")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }
}
