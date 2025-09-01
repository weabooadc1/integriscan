import 'dart:io';
import 'lib/services/ptz_service.dart';

void main() async {
  print('🔧 PTZ Manual Commands Debug Test');
  print('=================================');
  
  // Use your camera's RTSP URL
  final rtspUrl = 'rtsp://admin:admin123@192.168.1.14:554/cam/realmonitor?channel=1&subtype=0';
  
  print('📡 Testing individual PTZ commands on AMCREST IP2M-841B...');
  print('Note: This will test the authentication and command structure');
  
  // Test 1: Simple pan right with small steps
  print('\n🔄 Test 1: Pan Right (2 steps)');
  bool success = await PTZService.panRight(rtspUrl, steps: 2);
  print(success ? '✅ Pan Right: SUCCESS' : '❌ Pan Right: FAILED');
  
  if (success) {
    await Future.delayed(Duration(seconds: 2));
    
    // Test 2: Pan back left
    print('\n🔄 Test 2: Pan Left (2 steps)');
    success = await PTZService.panLeft(rtspUrl, steps: 2);
    print(success ? '✅ Pan Left: SUCCESS' : '❌ Pan Left: FAILED');
    
    await Future.delayed(Duration(seconds: 2));
    
    // Test 3: Tilt up
    print('\n🔄 Test 3: Tilt Up (1 step)');
    success = await PTZService.tiltUp(rtspUrl, steps: 1);
    print(success ? '✅ Tilt Up: SUCCESS' : '❌ Tilt Up: FAILED');
    
    await Future.delayed(Duration(seconds: 2));
    
    // Test 4: Tilt down  
    print('\n🔄 Test 4: Tilt Down (1 step)');
    success = await PTZService.tiltDown(rtspUrl, steps: 1);
    print(success ? '✅ Tilt Down: SUCCESS' : '❌ Tilt Down: FAILED');
    
  } else {
    print('\n❌ First command failed - likely authentication issue');
    print('� Check camera IP, credentials, and network connection');
  }
  
  print('\n🎯 Manual PTZ Commands Test Complete!');
  print('=====================================');
  print('');
  print('📋 Summary:');
  print('• Port 80 authentication implemented');
  print('• Rate limiting: 800ms between commands');
  print('• Fresh HTTP client per request');
  print('• No-cache headers to prevent stale auth');
  print('');
  print('If commands still fail, the issue may be:');
  print('1. Camera credentials incorrect');  
  print('2. Camera IP address changed');
  print('3. Network connectivity issue');
  print('4. Camera firmware incompatibility');
}
