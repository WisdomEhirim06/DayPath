import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
//import 'package:hive_flutter/hive_flutter.dart';
import 'package:daypath/screens/home_screen.dart';
import 'package:daypath/screens/onboarding_screen.dart';
import 'package:daypath/themes/theme.dart';
import 'package:daypath/services/storage_service.dart';
import 'package:daypath/services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize storage
  final storageService = StorageService();
  await storageService.init();
  
  // check if this is the first launch
  final isFirstLaunch = storageService.isFirstLaunch();

  runApp(MyApp(
    storageService: storageService,
    isFirstLaunch: isFirstLaunch,
  ));
}

class MyApp extends StatelessWidget {
  final StorageService storageService;
  final bool isFirstLaunch;
  
  const MyApp({
    required this.storageService,
    required this.isFirstLaunch,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<StorageService>.value(value: storageService),
        ChangeNotifierProxyProvider<StorageService, LocationService>(
          create: (context) => LocationService(storageService),
          update: (context, storage, previous) => previous ?? LocationService(storage),
        ),
      ],
      child: MaterialApp(
        title: 'DayPath',
        theme: DayPathTheme.getLightTheme(),
        darkTheme: DayPathTheme.getDarkTheme(),
        themeMode: ThemeMode.system,
        home: isFirstLaunch ? const OnboardingScreen() : const HomeScreen(),
      ),
    );
  }
}