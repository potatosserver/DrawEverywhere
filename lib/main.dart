import 'package:flutter/material.dart';
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
      // Handle permission denied
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('需要懸浮視窗權限才能運行')));
      }
      return;
    }

    // Check foreground service permission (Android 14+)
    if (await Permission.notification.request().isGranted) {
      // Start service and overlay
      await _startService();
      await FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        flag: OverlayFlag.clickThrough,
        alignment: OverlayAlignment.center,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.right, // Use a valid gravity
        height: WindowSize.matchParent,
        width: WindowSize.matchParent,
      );

      // Close the main activity since user doesn't want a home screen
      // SystemNavigator.pop(); // This might kill the app, let's just minimize or show a simple UI
    }
  }

  Future<void> _startService() async {
    ft.FlutterForegroundTask.init(
      androidNotificationOptions: ft.AndroidNotificationOptions(
        channelId: 'notification_channel_id',
        channelName: 'Foreground Service Notification',
        channelDescription:
            'This notification appears when the foreground service is running.',
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
      notificationText: '點擊以開啟工具欄',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text('正在啟動螢幕畫筆...'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _checkPermissionsAndStart,
              child: const Text('重新授權並啟動'),
            ),
          ],
        ),
      ),
    );
  }
}
