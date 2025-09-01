import 'lib/services/ptz_service.dart';

void main() async {
  print('🎯 Testing PTZ Authentication Pattern');
  
  final rtspUrl = 'rtsp://admin:admin123@192.168.1.14:554/cam/realmonitor?channel=1&subtype=0';
  
  // Test the commands that worked before
  final testCommands = [
    {'name': 'Pan Right (2600)', 'command': 'action=start&channel=0&code=PositionABS&arg1=2600&arg2=900&arg3=0'},
    {'name': 'Pan Left (1000)', 'command': 'action=start&channel=0&code=PositionABS&arg1=1000&arg2=900&arg3=0'},
    {'name': 'Pan Center (1800)', 'command': 'action=start&channel=0&code=PositionABS&arg1=1800&arg2=900&arg3=0'},
    {'name': 'Pan Right Again (2600)', 'command': 'action=start&channel=0&code=PositionABS&arg1=2600&arg2=900&arg3=0'},
  ];
  
  for (int i = 0; i < testCommands.length; i++) {
    final test = testCommands[i];
    print('\n${i + 1}. Testing: ${test['name']}');
    
    // Direct call to the internal command method
    final success = await PTZService.testCommand(rtspUrl, test['command']!);
    
    if (success) {
      print('   ✅ SUCCESS');
    } else {
      print('   ❌ FAILED');
    }
    
    // Wait between commands
    if (i < testCommands.length - 1) {
      await Future.delayed(Duration(seconds: 2));
    }
  }
  
  print('\n🎯 Test Complete!');
}
