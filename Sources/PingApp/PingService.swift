import Foundation
import ICMPPing

struct PingResult: Identifiable, Codable {
    var id = UUID()
    let host: String
    let latency: Double? // nil if unreachable
    let isReachable: Bool
    let timestamp: Date
}

class PingService {
    static let shared = PingService()
    
    private init() {}
    
    func ping(host: String, count: Int = 1) async -> PingResult {
        // Resolve hostname to IP first
        NSLog("DEBUG: Resolving host: %@", host)
        guard let ipString = resolve(host: host) else {
            NSLog("DEBUG: Failed to resolve host: %@", host)
            return PingResult(host: host, latency: nil, isReachable: false, timestamp: Date())
        }
        NSLog("DEBUG: Resolved %@ to %@", host, ipString)
        
        return await Task.detached {
            var latencies: [Double] = []
            var receivedCount = 0
            
            for _ in 0..<count {
                do {
                    let address = try ICMPPing.IPAddress(ipString, type: .ipv4)
                    NSLog("DEBUG: Attempting to ping %@", ipString)
                    let result = try ICMPPing.ping(address: address, timeout: 2)
                    NSLog("DEBUG: Ping result - type: \(result.responseType), interval: %f", result.interval)
                    
                    if result.responseType == .success {
                        // interval is in milliseconds according to docs/usage?
                        // Quick Start says: interval: 23.011
                        // Let's assume milliseconds as is standard for ping
                        latencies.append(result.interval)
                        receivedCount += 1
                    }
                } catch {
                    // Ping failed
                    NSLog("DEBUG: Ping failed with error: %@", error.localizedDescription)
                }
                
                // Small delay between pings if count > 1
                if count > 1 {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                }
            }
            
            if receivedCount > 0 {
                let avgLatency = latencies.reduce(0.0, +) / Double(latencies.count)
                return PingResult(host: host, latency: avgLatency, isReachable: true, timestamp: Date())
            } else {
                return PingResult(host: host, latency: nil, isReachable: false, timestamp: Date())
            }
        }.value
    }
    
    private func resolve(host: String) -> String? {
        // Check if it's already an IP address
        var sin = sockaddr_in()
        if host.withCString({ inet_pton(AF_INET, $0, &sin.sin_addr) }) == 1 {
            return host
        }
        
        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_INET, // IPv4 for now
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        
        var info: UnsafeMutablePointer<addrinfo>?
        
        guard getaddrinfo(host, nil, &hints, &info) == 0 else {
            return nil
        }
        defer { freeaddrinfo(info) }
        
        guard let info = info else { return nil }
        
        var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        guard let addr = info.pointee.ai_addr else { return nil }
        
        // Cast sockaddr to sockaddr_in to get sin_addr
        let sinAddr = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
        
        // Convert to string
        var addrCopy = sinAddr
        inet_ntop(AF_INET, &addrCopy, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
        
        return String(cString: ipBuffer)
    }
}
