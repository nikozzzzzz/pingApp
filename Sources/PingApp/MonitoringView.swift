import SwiftUI

struct MonitoringView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Monitoring")
                .font(.headline)
            
            if appState.monitoredHosts.isEmpty {
                Text("No monitored hosts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                List {
                    ForEach(appState.monitoredHosts) { host in
                        HStack {
                            Text(host.host)
                            Spacer()
                            
                            if let result = host.lastResult {
                                if let latency = result.latency {
                                    Text("\(Int(latency)) ms")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Circle()
                                    .fill(ColorRules.color(for: result))
                                    .frame(width: 8, height: 8)
                            } else {
                                Circle()
                                    .fill(Color.gray)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .frame(height: 150)
            }
        }
    }
}
