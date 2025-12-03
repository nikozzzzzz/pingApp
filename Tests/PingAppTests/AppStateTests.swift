import XCTest
@testable import PingApp

@MainActor
final class AppStateTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUp() {
        super.setUp()
        appState = AppState()
    }
    
    override func tearDown() {
        appState = nil
        super.tearDown()
    }
    
    // MARK: - Ping Input Tests
    
    func testPingCurrentInputWithValidHost() async throws {
        NSLog("TEST: Starting testPingCurrentInputWithValidHost")
        
        appState.pingInput = "8.8.8.8"
        XCTAssertFalse(appState.isPinging, "Should not be pinging initially")
        
        appState.pingCurrentInput()
        
        // Wait a bit for the async operation
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        XCTAssertTrue(appState.isPinging, "Should be pinging after calling pingCurrentInput")
        
        // Wait for ping to complete
        var attempts = 0
        while appState.isPinging && attempts < 50 {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            attempts += 1
        }
        
        XCTAssertFalse(appState.isPinging, "Should not be pinging after completion")
        XCTAssertNotNil(appState.currentPingResult, "Should have a ping result")
        
        if let result = appState.currentPingResult {
            NSLog("TEST: Ping result - isReachable: %d, latency: %f", 
                  result.isReachable, result.latency ?? -1)
            XCTAssertTrue(result.isReachable, "8.8.8.8 should be reachable")
        }
    }
    
    func testPingCurrentInputWithEmptyInput() {
        NSLog("TEST: Starting testPingCurrentInputWithEmptyInput")
        
        appState.pingInput = ""
        appState.pingCurrentInput()
        
        XCTAssertFalse(appState.isPinging, "Should not start pinging with empty input")
        XCTAssertNil(appState.currentPingResult, "Should not have a result")
    }
    
    // MARK: - History Tests
    
    func testAddToHistory() {
        NSLog("TEST: Starting testAddToHistory")
        
        appState.addToHistory("8.8.8.8")
        XCTAssertEqual(appState.history.count, 1)
        XCTAssertEqual(appState.history.first, "8.8.8.8")
        
        appState.addToHistory("1.1.1.1")
        XCTAssertEqual(appState.history.count, 2)
        XCTAssertEqual(appState.history.first, "1.1.1.1")
        XCTAssertEqual(appState.history[1], "8.8.8.8")
    }
    
    func testHistoryLimit() {
        NSLog("TEST: Starting testHistoryLimit")
        
        appState.addToHistory("host1")
        appState.addToHistory("host2")
        appState.addToHistory("host3")
        appState.addToHistory("host4")
        
        XCTAssertEqual(appState.history.count, 3, "History should be limited to 3 items")
        XCTAssertEqual(appState.history, ["host4", "host3", "host2"])
    }
    
    func testHistoryDuplicates() {
        NSLog("TEST: Starting testHistoryDuplicates")
        
        appState.addToHistory("8.8.8.8")
        appState.addToHistory("1.1.1.1")
        appState.addToHistory("8.8.8.8")
        
        XCTAssertEqual(appState.history.count, 2)
        XCTAssertEqual(appState.history.first, "8.8.8.8")
    }
    
    // MARK: - Monitoring Tests
    
    func testAddMonitoredHost() {
        NSLog("TEST: Starting testAddMonitoredHost")
        
        appState.addMonitoredHost(host: "8.8.8.8", interval: 5.0)
        
        XCTAssertEqual(appState.monitoredHosts.count, 1)
        XCTAssertEqual(appState.monitoredHosts.first?.host, "8.8.8.8")
        XCTAssertEqual(appState.monitoredHosts.first?.interval, 5.0)
    }
    
    func testRemoveMonitoredHost() {
        NSLog("TEST: Starting testRemoveMonitoredHost")
        
        appState.addMonitoredHost(host: "8.8.8.8", interval: 5.0)
        appState.addMonitoredHost(host: "1.1.1.1", interval: 10.0)
        
        XCTAssertEqual(appState.monitoredHosts.count, 2)
        
        appState.removeMonitoredHost(at: IndexSet(integer: 0))
        
        XCTAssertEqual(appState.monitoredHosts.count, 1)
        XCTAssertEqual(appState.monitoredHosts.first?.host, "1.1.1.1")
    }
}
