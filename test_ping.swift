#!/usr/bin/env swift

import Foundation

// Import the ICMPPing library path
#if canImport(ICMPPing)
import ICMPPing
#endif

print("=== PingApp Standalone Test Runner ===\n")

// Test 1: DNS Resolution
print("Test 1: DNS Resolution for google.com")
var hints = addrinfo(
    ai_flags: AI_ADDRCONFIG,
    ai_family: AF_INET,
    ai_socktype: SOCK_STREAM,
    ai_protocol: IPPROTO_TCP,
    ai_addrlen: 0,
    ai_canonname: nil,
    ai_addr: nil,
    ai_next: nil
)

var info: UnsafeMutablePointer<addrinfo>?
let resolveResult = getaddrinfo("google.com", nil, &hints, &info)

if resolveResult == 0 {
    defer { freeaddrinfo(info) }
    
    if let info = info {
        var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        if let addr = info.pointee.ai_addr {
            let sinAddr = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
            var addrCopy = sinAddr
            inet_ntop(AF_INET, &addrCopy, &ipBuffer, socklen_t(INET_ADDRSTRLEN))
            let ipString = String(cString: ipBuffer)
            print("✅ PASS: Resolved google.com to \(ipString)")
        } else {
            print("❌ FAIL: Could not get address from addrinfo")
        }
    } else {
        print("❌ FAIL: addrinfo is nil")
    }
} else {
    print("❌ FAIL: DNS resolution failed with error code: \(resolveResult)")
}

// Test 2: ICMP Ping Test
print("\nTest 2: ICMP Ping to 8.8.8.8")

#if canImport(ICMPPing)
do {
    let address = try ICMPPing.IPAddress("8.8.8.8", type: .ipv4)
    print("✅ PASS: Created IPAddress object")
    
    let result = try ICMPPing.ping(address: address, timeout: 2)
    print("Result: responseType=\(result.responseType), interval=\(result.interval)ms")
    
    if result.responseType == .success {
        print("✅ PASS: Ping successful with latency \(result.interval)ms")
    } else {
        print("⚠️  WARN: Ping returned non-success response type: \(result.responseType)")
    }
} catch {
    print("❌ FAIL: ICMP Ping failed with error: \(error)")
    print("Error details: \(error.localizedDescription)")
}
#else
print("⚠️  SKIP: ICMPPing module not available")
#endif

// Test 3: Check if running with proper permissions
print("\nTest 3: Permission Check")
let uid = getuid()
print("Running as UID: \(uid)")
if uid == 0 {
    print("✅ Running as root (has ICMP permissions)")
} else {
    print("⚠️  Running as non-root user (may need special permissions for ICMP)")
}

print("\n=== Test Summary ===")
print("Tests completed. Check results above.")
print("\nNote: ICMP ping typically requires root privileges or special entitlements.")
print("If ping tests fail, this may be the cause.")
