import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Recent")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ForEach(appState.history, id: \.self) { host in
                Button(action: {
                    appState.pingInput = host
                    appState.pingCurrentInput()
                }) {
                    HStack {
                        Text(host)
                        Spacer()
                        Image(systemName: "arrow.up.left")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 2)
            }
        }
    }
}
