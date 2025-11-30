# PingApp

A lightweight macOS menu bar application for network ping monitoring and diagnostics.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

## Features

- **Quick Ping**: Instantly ping any host directly from the menu bar
- **Continuous Monitoring**: Monitor multiple hosts with configurable ping intervals (1+ seconds)
- **Visual Feedback**: Color-coded latency indicators for quick status assessment
  - Green: Excellent (< 50ms)
  - Yellow: Good (50-100ms)
  - Orange: Fair (100-200ms)
  - Red: Poor (> 200ms)
  - Gray: Unreachable
- **Recent History**: Quick access to your last 3 pinged hosts
- **Persistent State**: Monitoring continues across app restarts
- **Enable/Disable Hosts**: Toggle monitoring for individual hosts without removing them

## Requirements

- macOS 13.0 (Ventura) or later
- Swift 5.9 or later

## Installation

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/nikozzzzzz/pingApp.git
cd pingApp
```

2. Build using Swift Package Manager:
```bash
swift build -c release
```

3. Run the application:
```bash
.build/release/PingApp
```

### Building with Xcode

1. Open `PingApp.xcodeproj` in Xcode
2. Select the PingApp scheme
3. Build and run (⌘R)

Alternatively, use the provided build script:
```bash
./bundle_app.sh
```

## Usage

1. **Launch the app**: PingApp appears in your menu bar with a network icon
2. **Quick Ping**: 
   - Click the menu bar icon
   - Enter a hostname or IP address
   - Click "Ping" to get instant latency results
3. **Monitor Hosts**:
   - Navigate to "Monitoring" tab
   - Add hosts with custom ping intervals
   - View real-time latency updates
   - Enable/disable monitoring per host
4. **View History**: Access recently pinged hosts from the "History" tab

## Architecture

### Core Components

- **PingService**: Handles network ping operations using the system `ping` command
  - Async/await based API
  - Configurable timeout (5 seconds default)
  - Regex-based latency parsing
  
- **AppState**: Central state management using SwiftUI's `@Published` properties
  - Persistent storage via UserDefaults
  - Automatic monitoring timer management
  - History tracking (last 3 hosts)

- **MenuBarManager**: Manages the macOS menu bar interface
  - SwiftUI-based popover UI
  - Native menu bar integration

### Views

- **ContentView**: Main tabbed interface
- **PingInputView**: Quick ping input and results
- **MonitoringView**: Continuous host monitoring dashboard
- **HistoryView**: Recent ping history
- **SettingsView**: Host monitoring configuration

## Entitlements

The app uses App Sandbox with the following entitlements:
- Outgoing network connections (for ping functionality)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Author

nikozzzzzz
