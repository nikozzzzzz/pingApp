import XCTest
@testable import PingApp

final class PingServiceTests: XCTestCase {
    
    var pingService: PingService!
    
    override func setUp() {
        super.setUp()
        pingService = PingService.shared
    }
    
    // MARK: - Basic Ping Tests
    
    func testPingGoogleDNS() async throws {
        NSLog("TEST: Starting testPingGoogleDNS")
        let result = await pingService.ping(host: "8.8.8.8")
        
        NSLog("TEST: Ping result - host: %@, isReachable: %d, latency: %f", 
              result.host, result.isReachable, result.latency ?? -1)
        
        XCTAssertEqual(result.host, "8.8.8.8", "Host should match input")
        XCTAssertTrue(result.isReachable, "Google DNS should be reachable")
        XCTAssertNotNil(result.latency, "Latency should not be nil for successful ping")
        XCTAssertGreaterThan(result.latency ?? 0, 0, "Latency should be positive")
    }
    
    func testPingCloudflareDNS() async throws {
        NSLog("TEST: Starting testPingCloudflareDNS")
        let result = await pingService.ping(host: "1.1.1.1")
        
        NSLog("TEST: Ping result - host: %@, isReachable: %d, latency: %f",
              result.host, result.isReachable, result.latency ?? -1)
        
        XCTAssertEqual(result.host, "1.1.1.1")
        XCTAssertTrue(result.isReachable, "Cloudflare DNS should be reachable")
        XCTAssertNotNil(result.latency)
    }
    
    func testPingWithHostname() async throws {
        NSLog("TEST: Starting testPingWithHostname")
        let result = await pingService.ping(host: "google.com")
        
        NSLog("TEST: Ping result - host: %@, isReachable: %d, latency: %f",
              result.host, result.isReachable, result.latency ?? -1)
        
        XCTAssertEqual(result.host, "google.com")
        XCTAssertTrue(result.isReachable, "google.com should be reachable")
        XCTAssertNotNil(result.latency)
    }
    
    func testPingInvalidHost() async throws {
        NSLog("TEST: Starting testPingInvalidHost")
        let result = await pingService.ping(host: "invalid.host.that.does.not.exist.test")
        
        NSLog("TEST: Ping result - host: %@, isReachable: %d",
              result.host, result.isReachable)
        
        XCTAssertEqual(result.host, "invalid.host.that.does.not.exist.test")
        XCTAssertFalse(result.isReachable, "Invalid host should not be reachable")
        XCTAssertNil(result.latency, "Latency should be nil for unreachable host")
    }
    
    func testPingMultipleCount() async throws {
        NSLog("TEST: Starting testPingMultipleCount")
        let result = await pingService.ping(host: "8.8.8.8", count: 3)
        
        NSLog("TEST: Ping result - host: %@, isReachable: %d, latency: %f",
              result.host, result.isReachable, result.latency ?? -1)
        
        XCTAssertTrue(result.isReachable)
        XCTAssertNotNil(result.latency)
    }
    
    // MARK: - DNS Resolution Tests
    
    func testDNSResolutionIPv4() async throws {
        NSLog("TEST: Starting testDNSResolutionIPv4")
        // Test that IP addresses are passed through
        let result = await pingService.ping(host: "8.8.8.8")
        XCTAssertTrue(result.isReachable, "Direct IP should work")
    }
    
    func testDNSResolutionHostname() async throws {
        NSLog("TEST: Starting testDNSResolutionHostname")
        // Test that hostnames are resolved
        let result = await pingService.ping(host: "cloudflare.com")
        XCTAssertTrue(result.isReachable, "Hostname resolution should work")
    }
    
    // MARK: - Performance Tests
    
    func testPingPerformance() throws {
        NSLog("TEST: Starting testPingPerformance")
        measure {
            let expectation = self.expectation(description: "Ping completes")
            
            Task {
                _ = await pingService.ping(host: "8.8.8.8")
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
    }
}
