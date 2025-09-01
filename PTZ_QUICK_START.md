# PTZ Control - Quick Start Guide

## 🚀 Quick Implementation Summary

Your IntegriScan app now has **full PTZ (Pan-Tilt-Zoom) control** integrated with the damage analysis workflow! Here's what was implemented:

### ✅ What's New

1. **PTZ Service** (`lib/services/ptz_service.dart`)
   - HTTP-based camera control for AMCREST cameras
   - Automatic credential extraction from RTSP URLs
   - Multiple movement directions and scan patterns
   - Error handling and timeout management

2. **Integrated Workflow** (in `rtsp_stream_screen.dart`)
   - **Analysis → Pan → Wait → Next Analysis**
   - Prevents duplicate frame analysis
   - Automatic movement after each AI analysis
   - Configurable scan patterns

3. **UI Controls**
   - Auto-scan toggle with status indicator
   - Manual PTZ controls (Up, Down, Left, Right)
   - Scan pattern selection (Horizontal, Vertical, Grid)
   - Real-time movement feedback

## 🎯 How It Works

### Your Requested Workflow
```
1. AI analyzes current frame for damage
2. After analysis completes → Camera pans to new angle
3. System waits 3 seconds for movement completion
4. AI analyzes the NEW frame (different angle)
5. Process repeats automatically
```

This ensures **no duplicate analysis** and **complete coverage**!

## 🎮 How to Use

### Step 1: Connect Your AMCREST Camera
```
rtsp://admin:password@192.168.1.100:554/cam/realmonitor?channel=1&subtype=0
```

### Step 2: Start Analysis with PTZ
1. Open RTSP stream
2. Wait for **"PTZ Control detected!"** message
3. Enable **"AI Analysis"**
4. Enable **"PTZ Auto-Scan"**
5. Select scan pattern (Horizontal/Vertical/Grid)

### Step 3: Monitor Progress
- Watch real-time analysis results
- Monitor PTZ movement counter
- View detection history
- Generate comprehensive reports

## 🛠️ Technical Features

### Automatic Scanning Patterns
```dart
// Horizontal: Left-Right coverage
PTZScanPattern.horizontalScan

// Vertical: Up-Down coverage  
PTZScanPattern.verticalScan

// Grid: Complete area coverage
PTZScanPattern.gridScan
```

### Manual Controls
- **Individual direction buttons** for precise positioning
- **Movement status indicators** during operation
- **Disabled state** during automatic scanning
- **Error handling** for failed movements

### Smart Integration
```dart
// After AI analysis completes:
if (_ptzEnabled && _ptzSupported) {
  await _performPTZMovement(); // Move camera
  // Wait for movement completion before next analysis
}
```

## 🔧 Configuration

### Camera Requirements
- **AMCREST ProHD** camera with PTZ support
- **HTTP API enabled** (port 80)
- **Same credentials** as RTSP stream
- **Network connectivity** to camera IP

### Adjustable Settings
- **Analysis interval**: 3-30 seconds (includes movement time)
- **Movement steps**: 1-5 steps per direction
- **Scan patterns**: Choose based on inspection area
- **Movement timeout**: 10 seconds per command

## 🧪 Testing

Run the included tests to verify functionality:
```bash
flutter test test/ptz_service_test.dart
```

All tests should pass ✅

## 📋 Usage Examples

### Example 1: Basic Auto-Scan
1. Start RTSP stream
2. Enable AI Analysis (5-second interval)
3. Enable PTZ Auto-Scan (Horizontal pattern)
4. System automatically analyzes → pans → analyzes → pans...

### Example 2: Manual Inspection
1. Use directional buttons to position camera
2. Enable AI Analysis for that specific view
3. Manual control for detailed inspection
4. Switch back to auto-scan for coverage

### Example 3: Report Generation
1. Complete auto-scan cycle (multiple movements)
2. Generate comprehensive report
3. Report includes images from all angles
4. Engineers review complete structural assessment

## 🎯 Benefits for Your Workflow

### Complete Coverage
- **No missed areas**: Systematic scanning ensures full coverage
- **No duplicate analysis**: Movement delays prevent same-frame analysis
- **Efficient inspection**: Automated process reduces manual work

### Quality Assurance
- **Consistent results**: Each analysis on different structural areas
- **Comprehensive reports**: Multiple angles in single session
- **Professional output**: Engineer-ready documentation

### Time Savings
- **Automated scanning**: Set it up and let it run
- **Faster inspections**: Cover more area in less time
- **Reduced site visits**: Remote operation capability

## 🚨 Important Notes

### Camera Compatibility
- Designed for **AMCREST ProHD** cameras
- Uses standard **AMCREST HTTP API**
- **Automatic detection** if PTZ is supported
- **Graceful fallback** if PTZ unavailable

### Network Requirements
- **Stable connection** to camera
- **Low latency** for responsive control
- **Port 80 access** for HTTP commands
- **Same network** as RTSP stream

Your app now provides **professional-grade automated structural inspection** with comprehensive PTZ control! 🎉

## 📞 Support

If you encounter any issues:
1. Check camera HTTP API accessibility
2. Verify RTSP credentials match HTTP credentials
3. Test manual movement before auto-scan
4. Review network connectivity to camera

The implementation is robust and handles most edge cases automatically.
