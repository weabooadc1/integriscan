# PTZ (Pan-Tilt-Zoom) Control Implementation

## Overview
This implementation adds PTZ control functionality to your IntegriScan app, specifically designed for AMCREST ProHD cameras. The PTZ system integrates seamlessly with the existing damage analysis workflow.

## How It Works

### 1. Workflow Integration
- **Analysis First**: The app performs AI damage analysis on the current camera frame
- **Automatic Pan**: After analysis is complete, the camera automatically pans to a new angle
- **Wait for Movement**: The system waits for the camera movement to complete (3 seconds delay)
- **New Frame Analysis**: Only after movement is complete, the system analyzes the new frame

This ensures that:
- ✅ Each analysis is performed on a different area
- ✅ No duplicate analysis of the same frame
- ✅ Complete coverage of the inspection area

### 2. PTZ Features

#### Automatic Scanning Patterns
- **Horizontal Scan**: Left-right movement pattern
- **Vertical Scan**: Up-down movement pattern  
- **Grid Scan**: Comprehensive grid coverage

#### Manual Controls
- Individual direction controls (Up, Down, Left, Right)
- Real-time movement feedback
- Movement status indicators

#### Smart Integration
- PTZ availability detection on startup
- Only activates if camera supports PTZ
- Graceful fallback if PTZ is not available

## Setup Instructions

### 1. Camera Requirements
- AMCREST ProHD camera with PTZ support
- HTTP API enabled (usually port 80)
- Same credentials as RTSP stream

### 2. RTSP URL Format
```
rtsp://username:password@camera_ip:554/cam/realmonitor?channel=1&subtype=0
```

The PTZ system automatically extracts:
- Username and password for HTTP authentication
- Camera IP address for PTZ commands
- Maintains secure credential handling

### 3. Using PTZ Controls

#### Enable Auto-Scan
1. Start your RTSP stream normally
2. Wait for "PTZ Control detected!" message
3. Enable "AI Analysis" 
4. Enable "PTZ Auto-Scan"
5. Select your preferred scan pattern

#### Manual Control
- Use the directional buttons for manual movement
- Movement is disabled during automatic scanning
- Real-time feedback shows movement status

### 4. Configuration Options

#### Analysis Interval
- Adjustable from 3-30 seconds
- Includes time for PTZ movement
- Optimized for thorough coverage

#### Scan Patterns
- **Horizontal**: 6-step left-right pattern
- **Vertical**: 6-step up-down pattern
- **Grid**: 9-step comprehensive coverage

## Technical Implementation

### PTZ Service (`ptz_service.dart`)
- HTTP-based communication with AMCREST cameras
- Automatic credential extraction from RTSP URL
- Error handling and timeout management
- Movement completion verification

### Integration Points
- `_processAnalysisResult()`: Triggers PTZ after analysis
- `_performPTZMovement()`: Executes movement with delays
- UI Controls: Real-time status and manual override

### Error Handling
- Network connectivity issues
- Camera response timeouts
- Invalid credentials
- Unsupported cameras

## Benefits

### For Structural Analysis
1. **Complete Coverage**: Systematic scanning ensures no areas are missed
2. **No Frame Duplication**: Movement delays prevent analyzing identical frames
3. **Consistent Quality**: Each analysis focuses on a different structural area
4. **Time Efficient**: Automated scanning reduces manual intervention

### User Experience
1. **Simple Setup**: Works with existing RTSP configuration
2. **Visual Feedback**: Clear status indicators and movement confirmation
3. **Manual Override**: Full manual control when needed
4. **Safe Operation**: Automatic error handling and recovery

## Camera Compatibility

### Tested With
- AMCREST ProHD Series
- Standard AMCREST HTTP API (port 80)

### API Commands Used
```
GET http://camera_ip:80/cgi-bin/ptz.cgi?action=start&channel=0&code=Left&arg1=0&arg2=3&arg3=0
GET http://camera_ip:80/cgi-bin/ptz.cgi?action=start&channel=0&code=Right&arg1=0&arg2=3&arg3=0
GET http://camera_ip:80/cgi-bin/ptz.cgi?action=start&channel=0&code=Up&arg1=0&arg2=3&arg3=0
GET http://camera_ip:80/cgi-bin/ptz.cgi?action=start&channel=0&code=Down&arg1=0&arg2=3&arg3=0
```

## Troubleshooting

### PTZ Not Detected
1. Verify camera supports PTZ
2. Check HTTP port accessibility (usually 80)
3. Confirm credentials match RTSP URL
4. Test manual camera web interface

### Movement Issues
1. Check network connectivity
2. Verify camera isn't at movement limits
3. Ensure no physical obstructions
4. Try manual movement first

### Analysis Issues
1. Verify AI analysis works without PTZ
2. Check movement timing (may need adjustment)
3. Ensure proper lighting after movement
4. Review scan pattern for your area

## Future Enhancements

### Possible Improvements
- **Preset Positions**: Save/recall specific camera positions
- **Zone-based Scanning**: Define specific areas for analysis
- **Smart Focusing**: Zoom control based on detected damage
- **Custom Patterns**: User-defined movement sequences
- **Advanced Timing**: Dynamic delays based on movement distance

This PTZ implementation provides a robust foundation for automated structural inspection while maintaining the flexibility for manual control when needed.
