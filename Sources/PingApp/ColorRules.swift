import SwiftUI

struct ColorRules {
    static func color(for result: PingResult) -> Color {
        guard result.isReachable, let latency = result.latency else { return .gray }
        
        switch latency {
        case 0..<100: return .green
        case 100..<250: return .yellow
        case 250..<500: return .orange
        case 500..<2500: return .red
        default: return .purple // Extremely high latency (>= 2500ms)
        }
    }
}
