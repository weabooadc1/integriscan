import 'package:flutter/material.dart';
import 'package:integriscan/screens/welcome/welcome_screen.dart';
import 'package:integriscan/constant.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:integriscan/providers/auth_provider.dart';
import 'package:integriscan/screens/home/home_screen.dart';
import 'package:integriscan/utils/logger.dart';
import 'package:integriscan/database/database_helper.dart';
import 'package:integriscan/services/connectivity_service.dart';
import 'package:integriscan/services/report_service.dart';
import 'firebase_options.dart';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Run database migration for verification status terminology
  final dbHelper = DatabaseHelper();
  await dbHelper.migrateVerificationStatusTerminology();
  
  // Initialize connectivity service
  final connectivityService = ConnectivityService();
  await connectivityService.initialize();
  
  // Set up background sync when connectivity is restored
  connectivityService.setConnectivityRestoredCallback(() async {
    try {
      await ReportService.syncAllUnsyncedReportsStatic();
      Logger.info('Background sync completed after connectivity restoration');
    } catch (e) {
      Logger.error('Error during background sync', e);
    }
  });
  
  runApp(const IndexPage());
}



class IndexPage extends StatelessWidget {
  const IndexPage({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'IntegriScan',
        theme: ThemeData(
          primaryColor: kPrimaryColor,
          scaffoldBackgroundColor: Colors.white,
        ),        home: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            // Show loading indicator while checking authentication state
            if (authProvider.isLoading) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
              // Debug print to check auth state
            Logger.info('Auth state: ${authProvider.isAuthenticated ? 'Authenticated' : 'Not Authenticated'}');
            if (authProvider.isAuthenticated) {
              Logger.secureLog('User', authProvider.user?.email ?? 'unknown');
            }
            
            // Navigate based on authentication state
            return authProvider.isAuthenticated
                ? const HomeScreen()
                : const WelcomeScreen();
          },
        ),
      ),
    );
  }
}