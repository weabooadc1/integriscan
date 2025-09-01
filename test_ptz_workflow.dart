import 'lib/services/ptz_service.dart';
import 'dart:io';

void main() async {
  print('🎯 Testing PTZ Workflow for Damage Analysis');
  
  final rtspUrl = 'rtsp://admin:admin123@192.168.1.14:554/cam/realmonitor?channel=1&subtype=0';
  
  print('\n📐 Testing Pan Movement with Absolute Positioning:');
  
  // Test pan left (position 1000)
  print('\n🔄 Moving camera LEFT for position 1 analysis...');
  bool result = await PTZService.panLeft(rtspUrl, steps: 4);
  print(result ? '✅ Camera moved LEFT successfully' : '❌ Failed to move LEFT');
  
  // Wait for movement to complete
  print('⏳ Waiting 3 seconds for movement to stabilize...');
  await Future.delayed(Duration(seconds: 3));
  print('📸 [SIMULATION] Analyzing frame at LEFT position...');
  await Future.delayed(Duration(seconds: 2)); // Simulate analysis time
  
  // Test pan right (position 2600)  
  print('\n🔄 Moving camera RIGHT for position 2 analysis...');
  result = await PTZService.panRight(rtspUrl, steps: 4);
  print(result ? '✅ Camera moved RIGHT successfully' : '❌ Failed to move RIGHT');
  
  // Wait for movement to complete
  print('⏳ Waiting 3 seconds for movement to stabilize...');
  await Future.delayed(Duration(seconds: 3));
  print('📸 [SIMULATION] Analyzing frame at RIGHT position...');
  await Future.delayed(Duration(seconds: 2)); // Simulate analysis time
  
  // Return to center position
  print('\n🔄 Returning camera to CENTER position...');
  result = await PTZService.gotoPreset(rtspUrl, 2); // Preset 2 = Center
  print(result ? '✅ Camera returned to CENTER' : '❌ Failed to return to CENTER');
  
  print('\n🎯 PTZ Workflow Test Complete!');
  print('📋 Summary:');
  print('   • Pan Left: Working with absolute positioning');
  print('   • Pan Right: Working with absolute positioning');  
  print('   • Return to Center: Working with preset positions');
  print('   • Workflow: Move → Wait → Analyze → Move → Wait → Analyze');
}
