import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart' as ft;
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'overlay_main.dart' as overlay;

void main() {
  runApp(const MyApp());
}

@pragma('vm:entry-point')
void overlayMain() {
  overlay.main();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Draw Everywhere',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const InitializationScreen(),
    );
  }
}

class InitializationScreen extends StatefulWidget {
  const InitializationScreen({super.key});

  @override
  State<InitializationScreen> createState() => _InitializationScreenState();
}

class _InitializationScreenState extends State<InitializationScreen> {
  @override
  void initState() {
    super.initState();
    _checkPermissionsAndStart();
  }

  Future<void> _checkPermissionsAndStart() async {
    // Check overlay permission
    bool status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      status = await FlutterOverlayWindow.requestPermission() ?? false;
    }

    if (!status) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('需要懸浮視窗權限才能運行')),
        );
      }
      return;
    }

    // Check notification permission (for foreground service)
    if (await Permission.notification.request().isGranted) {
       await _startService();
       
       // Show overlay - ensure it is NOT click-through by default so we can draw
       await FlutterOverlayWindow.showOverlay(
         enableDrag: false,
         flag: OverlayFlag.defaultFlag, // Allow touches for drawing
         alignment: OverlayAlignment.topLeft,
         visibility: NotificationVisibility.visibilityPublic,
         positionGravity: PositionGravity.right,
         height: WindowSize.matchParent,
         width: WindowSize.matchParent,
       );
       
       // Hide the main activity to fulfill "no main screen" requirement
       if (mounted) {
         try {
           const MethodChannel('flutter.native/helper').invokeMethod('moveTaskToBack');
         } catch (e) {
           SystemNavigator.pop();
         }
       }
    }
  }

  Future<void> _startService() async {
    ft.FlutterForegroundTask.init(
      androidNotificationOptions: ft.AndroidNotificationOptions(
        channelId: 'draw_service',
        channelName: '螢幕畫筆服務',
        channelDescription: '維持螢幕畫筆在背景運行',
        channelImportance: ft.NotificationChannelImportance.LOW,
        priority: ft.NotificationPriority.LOW,
        iconData: const ft.NotificationIconData(
          resType: ft.ResourceType.mipmap,
          resPrefix: ft.ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const ft.IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ft.ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    
    await ft.FlutterForegroundTask.startService(
      notificationTitle: '螢幕畫筆運行中',
      notificationText: '可以直接在螢幕上繪圖',
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
