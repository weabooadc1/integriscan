# Quick Testing Guide for ANR Fixes

## Run All Tests

```powershell
# Run all tests
flutter test

# Run specific test suites
flutter test test/utils/work_manager_test.dart
flutter test test/services/compute_service_test.dart
flutter test test/utils/async_utils_test.dart
```

## Test on Device

### Profile Build (Recommended for Performance Testing)
```powershell
# Clean build
flutter clean
flutter pub get

# Run in profile mode
flutter run --profile

# Or build and install APK
flutter build apk --profile
adb install build/app/outputs/flutter-apk/app-profile.apk
```

### Release Build (For Production Testing)
```powershell
# Build release APK
flutter build apk --release

# Install on device
adb install build/app/outputs/flutter-apk/app-release.apk

# Monitor for ANR issues
adb logcat | findstr /i "ANR"
```

## Performance Monitoring

### Check UI Thread Performance
```powershell
# Enable performance overlay in app
# Settings > Developer Options > Performance Overlay

# Or use DevTools
flutter pub global activate devtools
flutter pub global run devtools
```

### Monitor Memory Usage
```powershell
adb shell dumpsys meminfo com.integriscan.app
```

### Check CPU Usage
```powershell
adb shell top | findstr com.integriscan
```

## Test Scenarios

### 1. Auto-Scan Stress Test
- Enable auto-scan
- Let it run for 5+ minutes continuously
- Monitor for ANR warnings
- Check frame rate stays above 45 FPS

### 2. Rapid Analysis Test
- Manually trigger analysis repeatedly
- Click analyze button every second for 30 seconds
- Verify no ANR or UI freezing

### 3. Background/Foreground Test
- Start auto-scan
- Send app to background (home button)
- Wait 30 seconds
- Bring app to foreground
- Verify no ANR warnings

### 4. Memory Pressure Test
- Enable auto-scan
- Open multiple other apps
- Return to IntegriScan
- Verify app recovers without ANR

## Expected Behaviors

### ✅ Good Signs
- Smooth UI animations during analysis
- Frame rate consistently above 45 FPS
- No "App not responding" dialogs
- Background tasks completing without blocking
- WorkManager queue size stays manageable (< 5)

### ❌ Warning Signs  
- Frame drops during inference
- UI freezes lasting > 100ms
- ANR warnings in logcat
- WorkManager queue growing unbounded
- Memory usage constantly increasing

## Troubleshooting

### If ANR Still Occurs

1. **Check TFLite Initialization**
   ```dart
   final modelInfo = TFLiteService.getModelInfo();
   print('Model initialized: ${modelInfo['isInitialized']}');
   ```

2. **Monitor WorkManager Queue**
   ```dart
   final status = WorkManager().getStatus();
   print('Queue size: ${status['queueSize']}');
   print('Is processing: ${status['isProcessing']}');
   ```

3. **Check Debounce Timing**
   - Increase debounce delay if needed (currently 250ms)
   - Monitor setState frequency with print statements

4. **Verify Compute Isolates**
   - Check logs for "🔬 Isolate:" messages
   - Ensure isolates are completing successfully

## Performance Benchmarks

### Target Metrics
- Frame rate: > 45 FPS consistently
- Analysis time: < 2 seconds per frame
- UI thread blocking: < 50ms per operation
- Memory growth: < 10MB per minute during auto-scan
- ANR rate: < 0.47% (Google Play requirement)

### Measuring Performance
```dart
// Add to analysis method
final stopwatch = Stopwatch()..start();
final result = await ComputeService.runInferenceInBackground(frameBytes);
stopwatch.stop();
print('⏱️ Analysis took ${stopwatch.elapsedMilliseconds}ms');
```

## Logging

### Enable Verbose Logging
All services print debug information:
- 📋 WorkManager operations
- 🔬 Isolate operations
- 💾 File I/O operations
- 🤖 AI inference
- 📸 Frame capture

### Filter Logs
```powershell
# Filter by service
adb logcat | findstr "WorkManager"
adb logcat | findstr "Isolate"
adb logcat | findstr "ComputeService"

# Filter by severity
adb logcat *:E  # Errors only
adb logcat *:W  # Warnings and above
```

## Success Criteria

The ANR fixes are working correctly if:

1. ✅ Auto-scan runs continuously for 10+ minutes without ANR
2. ✅ UI remains responsive during analysis
3. ✅ No ANR warnings in logcat during normal usage
4. ✅ Frame rate stays above 45 FPS during auto-scan
5. ✅ WorkManager tests pass (10+ of 14)
6. ✅ Memory usage stable over time
7. ✅ App recovers gracefully from background

## Contact & Support

If issues persist:
1. Check `ANR_FIX_SUMMARY.md` for detailed implementation notes
2. Review test output in `test/` directory
3. Enable verbose logging and capture logcat output
4. Test on multiple devices with different Android versions
