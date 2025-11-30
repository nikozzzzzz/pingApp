import Foundation
import Combine

struct MonitoredHost: Identifiable, Codable {
    var id = UUID()
    var host: String
    var interval: TimeInterval
    var lastResult: PingResult?
    var isEnabled: Bool = true
}

@MainActor
class AppState: ObservableObject {
    @Published var history: [String] = [] {
        didSet {
            saveHistory()
        }
    }
    
    @Published var monitoredHosts: [MonitoredHost] = [] {
        didSet {
            if !isSuppressingUpdates {
                saveMonitoredHosts()
            }
        }
    }
    
    @Published var currentPingResult: PingResult?
    @Published var isPinging: Bool = false
    @Published var pingInput: String = ""
    
    private let historyKey = "pingAppHistory"
    private let monitoringKey = "pingAppMonitoring"
    private var monitoringTimers: [UUID: Timer] = [:]
    private var isSuppressingUpdates = false
    
    init() {
        loadHistory()
        loadMonitoredHosts()
        rescheduleMonitoring()
    }
    
    // MARK: - History
    
    func addToHistory(_ host: String) {
        if let index = history.firstIndex(of: host) {
            history.remove(at: index)
        }
        history.insert(host, at: 0)
        if history.count > 3 {
            history = Array(history.prefix(3))
        }
    }
    
    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let loaded = try? JSONDecoder().decode([String].self, from: data) {
            history = loaded
        }
    }
    
    // MARK: - Monitoring
    
    func addMonitoredHost(host: String, interval: TimeInterval) {
        // Validate interval (minimum 1 second)
        guard interval >= 1.0 else { return }
        let newHost = MonitoredHost(host: host, interval: interval, lastResult: nil)
        monitoredHosts.append(newHost)
        rescheduleMonitoring()
    }
    
    func removeMonitoredHost(at offsets: IndexSet) {
        monitoredHosts.remove(atOffsets: offsets)
        rescheduleMonitoring()
    }
    
    func updateMonitoredHost(_ host: MonitoredHost) {
        if let index = monitoredHosts.firstIndex(where: { $0.id == host.id }) {
            monitoredHosts[index] = host
            rescheduleMonitoring()
        }
    }
    
    private func saveMonitoredHosts() {
        if let data = try? JSONEncoder().encode(monitoredHosts) {
            UserDefaults.standard.set(data, forKey: monitoringKey)
        }
    }
    
    private func loadMonitoredHosts() {
        if let data = UserDefaults.standard.data(forKey: monitoringKey),
           let loaded = try? JSONDecoder().decode([MonitoredHost].self, from: data) {
            monitoredHosts = loaded
        }
    }
    
    private func rescheduleMonitoring() {
        // Invalidate all existing timers
        monitoringTimers.values.forEach { $0.invalidate() }
        monitoringTimers.removeAll()
        
        // Schedule new timers
        for host in monitoredHosts where host.isEnabled {
            let hostId = host.id
            let timer = Timer.scheduledTimer(withTimeInterval: host.interval, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.pingMonitoredHost(id: hostId)
                }
            }
            monitoringTimers[hostId] = timer
        }
    }
    
    private func pingMonitoredHost(id: UUID) async {
        // Get host info once to avoid TOCTOU race condition
        guard let host = monitoredHosts.first(where: { $0.id == id }) else { return }
        
        let result = await PingService.shared.ping(host: host.host)
        
        // Update result without triggering didSet save (optimization)
        if let index = monitoredHosts.firstIndex(where: { $0.id == id }) {
            isSuppressingUpdates = true
            monitoredHosts[index].lastResult = result
            isSuppressingUpdates = false
        }
    }
    
    // MARK: - Actions
    
    func pingCurrentInput() {
        NSLog("DEBUG: pingCurrentInput called with input: %@", pingInput)
        guard !pingInput.isEmpty else {
            NSLog("DEBUG: pingInput is empty, returning")
            return
        }
        let host = pingInput
        isPinging = true
        addToHistory(host)
        
        NSLog("DEBUG: Starting ping task for host: %@", host)
        Task {
            let result = await PingService.shared.ping(host: host)
            NSLog("DEBUG: Ping completed - isReachable: %d, latency: %f", result.isReachable, result.latency ?? -1)
            self.currentPingResult = result
            self.isPinging = false
        }
    }
}
