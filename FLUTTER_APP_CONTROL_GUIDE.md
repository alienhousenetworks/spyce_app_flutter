# 📱 Flutter Team Guide: App Version Control (Force/Soft Update) & Maintenance Mode

This guide provides everything the Flutter mobile team needs to implement:
1. **Force Updates & Soft Updates** (with Grace Period expiration) for both iOS and Android.
2. **Scheduled Downtime Banners** (with user-dismissible 'X' action & persistence).
3. **Active Maintenance Mode** (full-screen blocking UI + automatic 503 HTTP Interception).

---

## 📑 Table of Contents
1. [Architecture & Workflow Overview](#1-architecture--workflow-overview)
2. [Backend API Contracts](#2-backend-api-contracts)
3. [Dart Models](#3-dart-models)
4. [API Service & App Control Provider](#4-api-service--app-control-provider)
5. [Dio HTTP Interceptor (Automatic 503 Maintenance Handling)](#5-dio-http-interceptor-automatic-503-maintenance-handling)
6. [UI Components](#6-ui-components)
   - [A. Force Update Dialog (Non-Dismissible)](#a-force-update-dialog-non-dismissible)
   - [B. Soft Update Dialog / Banner](#b-soft-update-dialog--banner)
   - [C. Upcoming Maintenance Warning Banner (Dismissible with 'X')](#c-upcoming-maintenance-warning-banner-dismissible-with-x)
   - [D. Fullscreen Maintenance Screen](#d-fullscreen-maintenance-screen)
7. [App Lifecycle & Splash Screen Wiring](#7-app-lifecycle--splash-screen-wiring)

---

## 1. Architecture & Workflow Overview

```mermaid
flowchart TD
    A[App Launch / Resume] --> B[Call /api/v1/app-control/config/]
    B --> C{Is Active Maintenance On?}
    C -- Yes --> D[Show Fullscreen Maintenance Screen (Block App)]
    C -- No --> E{Is Force Update Required?}
    E -- Yes --> F[Show Non-Dismissible Force Update Dialog]
    E -- No --> G{Is Soft Update Available?}
    G -- Yes --> H[Show Dismissible Soft Update Prompt]
    G -- No --> I{Is Maintenance Upcoming?}
    I -- Yes --> J[Display Top Warning Banner with Dismiss 'X']
    I -- No --> K[Proceed Normally to Main Flow]
```

### When to Check App Status:
1. **App Launch (Splash Screen):** Before letting user into auth/home screen.
2. **App Resume (`AppLifecycleState.resumed`):** When user brings app back from background to foreground.
3. **Any HTTP 503 Service Unavailable:** The Dio Interceptor automatically redirects the app to the Maintenance Screen.

---

## 2. Backend API Contracts

### Endpoint: `GET /api/v1/app-control/config/`
**Headers Recommended:**
```http
X-App-Platform: ios       # or android
X-App-Version: 2.1.0      # Client app version
X-App-Build: 45           # Client build number
```
*(Query parameters `?platform=ios&app_version=2.1.0&build_number=45` are also supported).*

### Example JSON Response:
```json
{
  "can_use_app": true,
  "version_control": {
    "update_type": "OPTIONAL",
    "is_force_update": false,
    "can_use_app": true,
    "latest_version": "2.2.0",
    "min_supported_version": "2.0.0",
    "grace_period_deadline": "2026-08-25T00:00:00Z",
    "has_grace_period_expired": false,
    "title": "New Version Available",
    "message": "We have added faster chat and new discovery features. Update now!",
    "release_notes": [
      "Brand new chat interface",
      "Performance and battery improvements",
      "Bug fixes"
    ],
    "store_url": "https://apps.apple.com/app/id123456789"
  },
  "maintenance_control": {
    "status": "SCHEDULED_UPCOMING",
    "is_under_maintenance": false,
    "can_use_app": true,
    "banner": {
      "show": true,
      "id": "e4b09c48-3195-4672-9b2f-9290135d5df2",
      "title": "Scheduled Maintenance Notice",
      "message": "We will be undergoing scheduled upgrades on Sunday from 2:00 AM to 4:00 AM UTC.",
      "start_time": "2026-08-23T02:00:00Z",
      "end_time": "2026-08-23T04:00:00Z",
      "can_dismiss": true
    },
    "maintenance_screen": {
      "is_active": false,
      "title": "",
      "message": "",
      "start_time": null,
      "estimated_end_time": null,
      "is_emergency": false
    }
  },
  "server_time": "2026-08-21T01:00:00Z"
}
```

---

## 3. Dart Models

Create `lib/core/models/app_control_model.dart`:

```dart
import 'dart:convert';

enum UpdateType {
  none,
  optional,
  forceRequired;

  static UpdateType fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'FORCE_REQUIRED':
        return UpdateType.forceRequired;
      case 'OPTIONAL':
        return UpdateType.optional;
      default:
        return UpdateType.none;
    }
  }
}

class AppControlConfig {
  final bool canUseApp;
  final VersionControlInfo versionControl;
  final MaintenanceControlInfo maintenanceControl;
  final DateTime serverTime;

  AppControlConfig({
    required this.canUseApp,
    required this.versionControl,
    required this.maintenanceControl,
    required this.serverTime,
  });

  factory AppControlConfig.fromJson(Map<String, dynamic> json) {
    return AppControlConfig(
      canUseApp: json['can_use_app'] ?? true,
      versionControl: VersionControlInfo.fromJson(json['version_control'] ?? {}),
      maintenanceControl: MaintenanceControlInfo.fromJson(json['maintenance_control'] ?? {}),
      serverTime: DateTime.tryParse(json['server_time'] ?? '') ?? DateTime.now(),
    );
  }
}

class VersionControlInfo {
  final UpdateType updateType;
  final bool isForceUpdate;
  final bool canUseApp;
  final String latestVersion;
  final String minSupportedVersion;
  final DateTime? gracePeriodDeadline;
  final bool hasGracePeriodExpired;
  final String title;
  final String message;
  final List<String> releaseNotes;
  final String storeUrl;

  VersionControlInfo({
    required this.updateType,
    required this.isForceUpdate,
    required this.canUseApp,
    required this.latestVersion,
    required this.minSupportedVersion,
    this.gracePeriodDeadline,
    required this.hasGracePeriodExpired,
    required this.title,
    required this.message,
    required this.releaseNotes,
    required this.storeUrl,
  });

  factory VersionControlInfo.fromJson(Map<String, dynamic> json) {
    return VersionControlInfo(
      updateType: UpdateType.fromString(json['update_type']),
      isForceUpdate: json['is_force_update'] ?? false,
      canUseApp: json['can_use_app'] ?? true,
      latestVersion: json['latest_version'] ?? '',
      minSupportedVersion: json['min_supported_version'] ?? '',
      gracePeriodDeadline: json['grace_period_deadline'] != null
          ? DateTime.tryParse(json['grace_period_deadline'])
          : null,
      hasGracePeriodExpired: json['has_grace_period_expired'] ?? false,
      title: json['title'] ?? 'Update Available',
      message: json['message'] ?? '',
      releaseNotes: (json['release_notes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      storeUrl: json['store_url'] ?? '',
    );
  }
}

class MaintenanceControlInfo {
  final String status;
  final bool isUnderMaintenance;
  final bool canUseApp;
  final MaintenanceBannerInfo banner;
  final MaintenanceScreenInfo screen;

  MaintenanceControlInfo({
    required this.status,
    required this.isUnderMaintenance,
    required this.canUseApp,
    required this.banner,
    required this.screen,
  });

  factory MaintenanceControlInfo.fromJson(Map<String, dynamic> json) {
    return MaintenanceControlInfo(
      status: json['status'] ?? 'NORMAL',
      isUnderMaintenance: json['is_under_maintenance'] ?? false,
      canUseApp: json['can_use_app'] ?? true,
      banner: MaintenanceBannerInfo.fromJson(json['banner'] ?? {}),
      screen: MaintenanceScreenInfo.fromJson(json['maintenance_screen'] ?? {}),
    );
  }
}

class MaintenanceBannerInfo {
  final bool show;
  final String? id;
  final String title;
  final String message;
  final DateTime? startTime;
  final DateTime? endTime;
  final bool canDismiss;

  MaintenanceBannerInfo({
    required this.show,
    this.id,
    required this.title,
    required this.message,
    this.startTime,
    this.endTime,
    required this.canDismiss,
  });

  factory MaintenanceBannerInfo.fromJson(Map<String, dynamic> json) {
    return MaintenanceBannerInfo(
      show: json['show'] ?? false,
      id: json['id'],
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      startTime: json['start_time'] != null ? DateTime.tryParse(json['start_time']) : null,
      endTime: json['end_time'] != null ? DateTime.tryParse(json['end_time']) : null,
      canDismiss: json['can_dismiss'] ?? true,
    );
  }
}

class MaintenanceScreenInfo {
  final bool isActive;
  final String title;
  final String message;
  final DateTime? startTime;
  final DateTime? estimatedEndTime;
  final bool isEmergency;

  MaintenanceScreenInfo({
    required this.isActive,
    required this.title,
    required this.message,
    this.startTime,
    this.estimatedEndTime,
    required this.isEmergency,
  });

  factory MaintenanceScreenInfo.fromJson(Map<String, dynamic> json) {
    return MaintenanceScreenInfo(
      isActive: json['is_active'] ?? false,
      title: json['title'] ?? 'Under Maintenance',
      message: json['message'] ?? 'We are undergoing maintenance. Please check back shortly.',
      startTime: json['start_time'] != null ? DateTime.tryParse(json['start_time']) : null,
      estimatedEndTime: json['estimated_end_time'] != null
          ? DateTime.tryParse(json['estimated_end_time'])
          : null,
      isEmergency: json['is_emergency'] ?? false,
    );
  }
}
```

---

## 4. API Service & App Control Provider

Create `lib/core/services/app_control_service.dart`:

```dart
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/app_control_model.dart';

class AppControlService {
  final Dio _dio;
  AppControlService(this._dio);

  Future<AppControlConfig?> fetchAppConfig() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final platform = Platform.isIOS ? 'ios' : 'android';
      final version = packageInfo.version;
      final build = packageInfo.buildNumber;

      final response = await _dio.get(
        '/api/v1/app-control/config/',
        options: Options(
          headers: {
            'X-App-Platform': platform,
            'X-App-Version': version,
            'X-App-Build': build,
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        return AppControlConfig.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('[AppControlService] Error fetching app config: $e');
    }
    return null;
  }

  /// Checks if an upcoming maintenance banner was dismissed by the user
  Future<bool> isBannerDismissed(String? bannerId) async {
    if (bannerId == null || bannerId.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('dismissed_maintenance_banner_$bannerId') ?? false;
  }

  /// Marks the maintenance banner as dismissed
  Future<void> dismissBanner(String? bannerId) async {
    if (bannerId == null || bannerId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dismissed_maintenance_banner_$bannerId', true);
  }
}
```

---

## 5. Dio HTTP Interceptor (Automatic 503 Maintenance Handling)

If the server enters maintenance mode while the user is actively using the app, backend endpoints will return `503 Service Unavailable`. This interceptor automatically catches 503 errors and routes the app to the Maintenance Screen.

Create `lib/core/network/maintenance_interceptor.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/app_control_model.dart';
import '../../features/maintenance/maintenance_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class MaintenanceInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 503) {
      final responseData = err.response?.data;
      if (responseData is Map<String, dynamic> &&
          responseData['error'] == 'MAINTENANCE_MODE') {
        final maintenanceData = responseData['maintenance'] ?? {};
        final screenInfo = MaintenanceScreenInfo.fromJson(maintenanceData);

        // Navigate to full-screen Maintenance Screen
        if (rootNavigatorKey.currentContext != null) {
          Navigator.of(rootNavigatorKey.currentContext!).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => MaintenanceScreen(maintenanceInfo: screenInfo),
            ),
            (route) => false,
          );
        }
      }
    }
    super.onError(err, handler);
  }
}
```

---

## 6. UI Components

### A. Force Update Dialog (Non-Dismissible)
Create `lib/features/app_control/widgets/force_update_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/app_control_model.dart';

class ForceUpdateDialog extends StatelessWidget {
  final VersionControlInfo versionInfo;

  const ForceUpdateDialog({Key? key, required this.versionInfo}) : super(key: key);

  Future<void> _launchStore() async {
    final uri = Uri.parse(versionInfo.storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope prevents Android back button from dismissing
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1E1E2C),
        title: Row(
          children: [
            const Icon(Icons.system_update_rounded, color: Color(0xFFFF4B6E), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                versionInfo.title.isNotEmpty ? versionInfo.title : "Update Required",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              versionInfo.message,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
            if (versionInfo.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 14),
              const Text(
                "What's New:",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 6),
              ...versionInfo.releaseNotes.map(
                (note) => Padding(
                  padding: const EdgeInsets.only(bottom: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("• ", style: TextStyle(color: Color(0xFFFF4B6E))),
                      Expanded(
                        child: Text(
                          note,
                          style: const TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _launchStore,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF4B6E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                "Update Now",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

### B. Soft Update Dialog / Banner
Create `lib/features/app_control/widgets/soft_update_dialog.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/app_control_model.dart';

class SoftUpdateDialog extends StatelessWidget {
  final VersionControlInfo versionInfo;
  final VoidCallback onDismiss;

  const SoftUpdateDialog({
    Key? key,
    required this.versionInfo,
    required this.onDismiss,
  }) : super(key: key);

  Future<void> _launchStore() async {
    final uri = Uri.parse(versionInfo.storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFF1E1E2C),
      title: Text(
        versionInfo.title.isNotEmpty ? versionInfo.title : "Update Available",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Text(
        versionInfo.message,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
      ),
      actions: [
        TextButton(
          onPressed: onDismiss,
          child: const Text("Later", style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton(
          onPressed: _launchStore,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF4B6E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text("Update", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
```

---

### C. Upcoming Maintenance Warning Banner (Dismissible with 'X')
Create `lib/features/app_control/widgets/upcoming_maintenance_banner.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/models/app_control_model.dart';

class UpcomingMaintenanceBanner extends StatelessWidget {
  final MaintenanceBannerInfo bannerInfo;
  final VoidCallback onDismiss;

  const UpcomingMaintenanceBanner({
    Key? key,
    required this.bannerInfo,
    required this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!bannerInfo.show) return const SizedBox.shrink();

    final timeFormat = DateFormat('h:mm a (MMM d)');
    final timeStr = bannerInfo.startTime != null
        ? "Starts ${timeFormat.format(bannerInfo.startTime!.toLocal())}"
        : "Starts soon";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8A2387), Color(0xFFE94057), Color(0xFFF27121)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.schedule_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  bannerInfo.title.isNotEmpty ? bannerInfo.title : "Upcoming Maintenance",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "$timeStr. ${bannerInfo.message}",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          if (bannerInfo.canDismiss) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onDismiss,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
          ]
        ],
      ),
    );
  }
}
```

---

### D. Fullscreen Maintenance Screen
Create `lib/features/maintenance/maintenance_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/app_control_model.dart';

class MaintenanceScreen extends StatelessWidget {
  final MaintenanceScreenInfo maintenanceInfo;

  const MaintenanceScreen({Key? key, required this.maintenanceInfo}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('h:mm a (MMM d)');
    final endStr = maintenanceInfo.estimatedEndTime != null
        ? dateFormat.format(maintenanceInfo.estimatedEndTime!.toLocal())
        : "shortly";

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F1A),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4B6E).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.build_circle_rounded,
                      size: 64,
                      color: Color(0xFFFF4B6E),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    maintenanceInfo.title.isNotEmpty
                        ? maintenanceInfo.title
                        : "Under Maintenance",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    maintenanceInfo.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2C),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.timer_outlined, color: Colors.white54, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "Expected back by $endStr",
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Trigger app restart or re-check
                      Navigator.of(context).pushReplacementNamed('/splash');
                    },
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    label: const Text(
                      "Check Again",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4B6E),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## 7. App Lifecycle & Splash Screen Wiring

In `lib/features/splash/splash_page.dart` (or wherever app bootstrap occurs):

```dart
Future<void> initializeApp(BuildContext context) async {
  final appControlService = AppControlService(dioInstance);
  final config = await appControlService.fetchAppConfig();

  if (config != null) {
    // 1. Check if under maintenance
    if (config.maintenanceControl.isUnderMaintenance) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MaintenanceScreen(
            maintenanceInfo: config.maintenanceControl.screen,
          ),
        ),
      );
      return;
    }

    // 2. Check Force Update
    if (config.versionControl.isForceUpdate) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => ForceUpdateDialog(versionInfo: config.versionControl),
      );
      return;
    }

    // 3. Check Soft Update
    if (config.versionControl.updateType == UpdateType.optional) {
      // Optional: show soft update dialog if not dismissed recently
      showDialog(
        context: context,
        builder: (_) => SoftUpdateDialog(
          versionInfo: config.versionControl,
          onDismiss: () => Navigator.of(context).pop(),
        ),
      );
    }
  }

  // Proceed to Auth check / Home Page
  Navigator.of(context).pushReplacementNamed('/home');
}
```
