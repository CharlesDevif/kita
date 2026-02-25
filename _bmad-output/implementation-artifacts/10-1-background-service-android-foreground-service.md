---
story_id: "10.1"
title: "Background Service — Android Foreground Service"
epic: "E10 — Kita veille — Mode Passif & Background"
phase: "4"
status: ready-for-dev
priority: critical
estimated_complexity: XL
depends_on: []
blocks: ["10.3", "10.4"]
---

# Story 10.1 : Background Service — Android Foreground Service

## User Story

**En tant que** utilisateur de Kita sur Android,
**je veux** que Kita reste active en arriere-plan sans etre tuee par le systeme,
**afin que** les alertes d'obstacles fonctionnent meme quand l'app n'est pas au premier plan.

## Acceptance Criteria

- **AC1:** `KitaForegroundService` cree un Foreground Service avec notification permanente
- **AC2:** Le service maintient les capteurs minimaux actifs (micro ambient, accelerometre)
- **AC3:** La camera et le GPS sont actives uniquement sur commande vocale ou mouvement detecte
- **AC4:** Le service survit au passage en arriere-plan de l'app
- **AC5:** Le `BackgroundChannel` communique l'etat du service au code Flutter
- **AC6:** Les tests verifient que le service reste actif apres `onPause()`

## Technical Intelligence

### Approche recommandee : flutter_foreground_task 9.2.0

```yaml
dependencies:
  flutter_foreground_task: ^9.2.0
```

Ce package est le plus fiable pour Android 12+ (API 31). Il gere :
- True foreground service avec notification permanente
- Dart isolate pour execution en background
- `allowAutoRestart: true` (nouveau en 9.2.0) — le service redemarre apres kill par l'OS
- Support explicite des `foregroundServiceType` requis par Android 14+

### AndroidManifest.xml — Permissions requises

```xml
<!-- Foreground Service -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CAMERA" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />

<!-- Wake Lock pour garder le CPU actif -->
<uses-permission android:name="android.permission.WAKE_LOCK" />

<!-- Exemption batterie (justifier dans Privacy Policy) -->
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />

<!-- Dans <application> -->
<service
  android:name="com.pravera.flutter_foreground_task.service.ForegroundService"
  android:foregroundServiceType="camera|microphone|location"
  android:exported="false" />
```

### Dart — Demarrage du service

```dart
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// DOIT etre une fonction top-level
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(KitaTaskHandler());
}

class KitaTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Initialiser capteurs minimaux : accelerometre + micro ambient
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Poll accelerometre, check mouvement
    FlutterForegroundTask.updateService(
      notificationTitle: 'Kita actif',
      notificationText: 'Surveillance en cours',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Cleanup capteurs
    // isTimeout = true si Android 15 depasse la limite 6h dataSync
  }
}

Future<void> startKitaService() async {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'kita_service',
      channelName: 'Kita Service',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      isSticky: true, // notification ne peut pas etre dismissee
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.repeat(5000), // toutes les 5s
      autoRunOnBoot: true,
      allowWakeLock: true,
      allowAutoRestart: true, // 9.2.0 — redemarre apres kill OS
    ),
  );

  await FlutterForegroundTask.startService(
    serviceId: 1001,
    notificationTitle: 'Kita',
    notificationText: 'Compagnon actif',
    callback: startCallback,
    serviceTypes: [
      ForegroundServiceTypes.camera,
      ForegroundServiceTypes.microphone,
      ForegroundServiceTypes.location,
    ],
  );
}
```

### Communication service → Flutter via EventChannel

```dart
// Dart side
class KitaServiceChannel {
  static const _methodChannel = MethodChannel('com.kita/background');
  static const _eventChannel = EventChannel('com.kita/service_state');

  Future<void> start() => _methodChannel.invokeMethod('startService');
  Future<void> stop() => _methodChannel.invokeMethod('stopService');

  Stream<ServiceState> get stateStream =>
    _eventChannel.receiveBroadcastStream()
      .map((event) => ServiceState.fromMap(event as Map));
}
```

### Exemption batterie

```dart
// Verifier si deja exempte
final ignored = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
if (!ignored) {
  // Ouvre le dialogue systeme Android
  await FlutterForegroundTask.requestIgnoreBatteryOptimization();
}
```

## Pitfalls & Gotchas

1. **Android 12 (API 31) — `ForegroundServiceStartNotAllowedException`** — Impossible de lancer un foreground service depuis le background. Doit etre lance pendant que l'app est au foreground OU via une exemption (battery optimization, FCM high priority, etc.). Lancer le service pendant l'onboarding ou au retour au foreground.

2. **Android 14 (API 34) — `foregroundServiceType` OBLIGATOIRE** — Si le type n'est pas declare dans le manifest ET dans `startService()`, → `SecurityException` au runtime. Declarer `camera|microphone|location` dans les deux endroits.

3. **Android 14 — Pas de FGS camera/micro depuis le background** — Meme avec exemption battery, les apps en background ne peuvent PAS creer un FGS qui demande camera ou microphone. La camera et le micro doivent etre ouverts PENDANT que l'app est au foreground, et le service maintient l'acces.

4. **Android 15 (API 35) — Limite 6h pour `dataSync`** — `camera` et `microphone` FGS ne sont PAS soumis a cette limite, mais `dataSync` oui. Kita utilise `camera|microphone|location`, donc pas de probleme.

5. **Android 15 — Pas de FGS camera/micro depuis BOOT_COMPLETED** — Apres un reboot, le service ne peut pas demarrer avec camera/micro. Il faut attendre que l'utilisateur ouvre l'app. `autoRunOnBoot` avec `allowAutoRestart` redemarre le service, mais sans camera/micro jusqu'au retour au foreground.

6. **Notification permanente** — `isSticky: true` + `NotificationChannelImportance.LOW` = notification discrete qui ne peut pas etre dismissee. L'utilisateur peut la cacher via les parametres de notification Android.

7. **Pigeon 26.1.7** — Pour les APIs complexes natif ↔ Dart, preferer Pigeon a MethodChannel brut. Genere du code type-safe en Kotlin + Swift + Dart. Mais pour cette story, flutter_foreground_task gere deja la communication.

## Architecture References

- `lib/platform/android_bridge.dart` — Implementation Android channels
- `lib/features/io/domain/motion_service.dart` — MotionService (E3)
- `lib/features/io/domain/audio_service.dart` — AudioService (E3)
- `lib/features/io/domain/camera_service.dart` — CameraService (E3)
- `android/app/src/main/AndroidManifest.xml` — Permissions

## Implementation Tasks

### Task 1 : KitaBackgroundService interface (domain)

Creer `lib/features/io/domain/background_service.dart` :
- [ ] `abstract class KitaBackgroundService`
- [ ] `Future<void> start()` — demarre le service
- [ ] `Future<void> stop()` — arrete le service
- [ ] `Stream<BackgroundServiceState> get stateStream` — etat courant
- [ ] `Future<bool> get isRunning`
- [ ] `enum BackgroundServiceState { idle, starting, running, stopped, error }`

### Task 2 : AndroidBackgroundServiceImpl (data)

Creer `lib/features/io/data/android_background_service_impl.dart` :
- [ ] Implements `KitaBackgroundService`
- [ ] Utilise `flutter_foreground_task` pour le FGS
- [ ] Configure notification permanente (LOW importance)
- [ ] Declare `serviceTypes` : camera, microphone, location
- [ ] `KitaTaskHandler` avec `onStart`/`onRepeatEvent`/`onDestroy`
- [ ] Communication etat via MethodChannel/EventChannel

### Task 3 : Battery optimization request

Ajouter dans le flow d'onboarding ou au premier lancement :
- [ ] Verifier `isIgnoringBatteryOptimizations`
- [ ] Si non → `requestIgnoreBatteryOptimization()` avec explication vocale
- [ ] Logger le resultat (pas le nom de l'utilisateur)

### Task 4 : AndroidManifest.xml permissions

Modifier `android/app/src/main/AndroidManifest.xml` :
- [ ] Ajouter `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CAMERA`, `FOREGROUND_SERVICE_MICROPHONE`, `FOREGROUND_SERVICE_LOCATION`
- [ ] Ajouter `WAKE_LOCK`, `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
- [ ] Ajouter `<service>` declaration avec `foregroundServiceType`

### Task 5 : Riverpod Provider

Creer dans `lib/features/io/di/` :
- [ ] `backgroundServiceProvider` — Platform-conditional (Android vs iOS)
- [ ] `ref.onDispose()` pour stop le service proprement

### Task 6 : Tests

- [ ] `test/features/io/data/android_background_service_impl_test.dart`
  - Test : start() initialise le service
  - Test : stop() arrete le service
  - Test : stateStream emet les bons etats
  - Test : isRunning retourne le bon etat
- [ ] Test platform channel mock (pas de vrai FGS en test)
- [ ] Au moins 1 test d'integration avec mock MethodChannel

## Definition of Done

- [ ] KitaBackgroundService interface creee
- [ ] AndroidBackgroundServiceImpl avec flutter_foreground_task
- [ ] Notification permanente fonctionnelle
- [ ] Battery optimization request integre
- [ ] AndroidManifest.xml permissions correctes
- [ ] 8+ tests passent
- [ ] `dart analyze --fatal-infos` clean
- [ ] `flutter test` passe
- [ ] Zero PII dans les logs
- [ ] sprint-status.yaml mis a jour

---

## Dev Agent Record

**Agent Model:**
**Date:**

### Completion Notes

_(A remplir par l'agent de developpement)_

### Files Modified

_(A remplir par l'agent de developpement)_
