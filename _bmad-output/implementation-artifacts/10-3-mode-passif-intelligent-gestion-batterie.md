---
story_id: "10.3"
title: "Mode passif intelligent et gestion batterie"
epic: "E10 — Kita veille — Mode Passif & Background"
phase: "4"
status: ready-for-dev
priority: high
estimated_complexity: XL
depends_on: ["10.1", "10.2"]
blocks: ["10.4"]
---

# Story 10.3 : Mode passif intelligent et gestion batterie

## User Story

**En tant que** utilisateur de Kita,
**je veux** que le mode passif maintienne les capteurs essentiels actifs tout en preservant ma batterie (< 5%/h),
**afin que** Kita veille sur moi toute la journee sans vider ma batterie.

## Acceptance Criteria

- **AC1:** Les capteurs minimaux (micro ambient, accelerometre) restent actifs en permanence
- **AC2:** La camera s'active sur mouvement detecte (marche/course) pour la detection d'obstacles
- **AC3:** La camera se desactive si l'utilisateur est immobile > 30s
- **AC4:** Le FPS camera s'adapte au mouvement : immobile = OFF, marche = 15 FPS, course = 30 FPS
- **AC5:** La consommation batterie en mode passif est < 5% par heure
- **AC6:** Une alerte vocale est declenchee quand la batterie passe sous 20%
- **AC7:** La RAM en mode passif reste < 200 MB
- **AC8:** Les tests verifient l'adaptation du FPS et la liberation des ressources

## Technical Intelligence

### sensors_plus 7.0.0 — Detection mouvement

```yaml
dependencies:
  sensors_plus: ^7.0.0
```

**Breaking changes 7.0.0** : Requiert Kotlin 2.2.0, AGP >= 8.12.1, Gradle wrapper >= 8.13.

**Breaking change 6.0.0** : `NSMotionUsageDescription` OBLIGATOIRE dans Info.plist (crash sans).

```dart
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math';

// Accelerometre filtre (sans gravite) — meilleur pour detection mouvement
userAccelerometerEventStream(
  samplingPeriod: SensorInterval.normalInterval, // 200ms / 5Hz
).listen((UserAccelerometerEvent e) {
  final magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
  // magnitude ~0 au repos, ~1.5 en marchant, ~4.0 en courant
});
```

### SensorInterval valeurs

| Constante | Periode | Frequence |
|-----------|---------|-----------|
| `fastestInterval` | min hardware | max Hz |
| `gameInterval` | ~20ms | 50Hz |
| `uiInterval` | ~66ms | 15Hz |
| `normalInterval` | ~200ms | 5Hz |

### Classification mouvement

```dart
enum MotionState { stationary, walking, running }

MotionState classify(UserAccelerometerEvent e) {
  final magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
  if (magnitude < 0.3) return MotionState.stationary;
  if (magnitude < 2.0) return MotionState.walking;
  return MotionState.running;
}
```

### camera 0.11.4 — Streaming bas FPS

```yaml
dependencies:
  camera: ^0.11.4
```

**Breaking change 0.11.0** : Android utilise CameraX par defaut (plus Camera2).

Le package `camera` ne permet pas de configurer le FPS du stream directement sur CameraX. Utiliser un gate temporel :

```dart
int _lastFrameMs = 0;
int _targetIntervalMs = 1000 ~/ 15; // 15 FPS par defaut

void _onImageAvailable(CameraImage image) {
  final now = DateTime.now().millisecondsSinceEpoch;
  if (now - _lastFrameMs < _targetIntervalMs) return; // skip frame
  _lastFrameMs = now;

  if (_processing) return; // guard concurrent
  _processing = true;
  _processFrame(image).whenComplete(() => _processing = false);
}

void adaptFps(MotionState motion) {
  switch (motion) {
    case MotionState.stationary:
      _stopCamera(); // OFF
    case MotionState.walking:
      _targetIntervalMs = 1000 ~/ 15; // 15 FPS
      _startCameraIfNeeded();
    case MotionState.running:
      _targetIntervalMs = 1000 ~/ 30; // 30 FPS
      _startCameraIfNeeded();
  }
}
```

### battery_plus 7.0.0 — Monitoring batterie

```yaml
dependencies:
  battery_plus: ^7.0.0
```

**Breaking change 7.0.0** : Requiert Kotlin 2.2.0, AGP >= 8.12.1.

```dart
import 'package:battery_plus/battery_plus.dart';

final battery = Battery();

// Niveau courant
final level = await battery.batteryLevel; // 0-100

// Stream d'etat
battery.onBatteryStateChanged.listen((BatteryState state) {
  // charging, discharging, full, connectedNotCharging, unknown
});

// Mode economie d'energie
final isLowPower = await battery.isInBatterySaveMode;
```

### Strategie adaptive pour < 5%/h

| Contexte | Accelerometre | Camera | Location | Estimation drain |
|----------|--------------|--------|----------|-----------------|
| Immobile | 5Hz (normalInterval) | OFF | OFF | ~1%/h |
| Marche | 15Hz (uiInterval) | 15 FPS low-res | ON (100m filter) | ~3%/h |
| Course | 50Hz (gameInterval) | 30 FPS low-res | ON (10m filter) | ~5%/h |
| Low battery (<20%) | 5Hz | OFF | OFF | ~0.5%/h |

### Camera en background — Limitations

- **Android** : Camera possible en FGS avec `FOREGROUND_SERVICE_CAMERA` (Story 10.1)
- **iOS** : Camera IMPOSSIBLE en background. Detection obstacles uniquement au foreground. En background, seuls accelerometre + location sont disponibles.

## Pitfalls & Gotchas

1. **`samplingPeriod` est un hint, pas une garantie** — Android ne garantit pas la frequence demandee. Le taux reel peut varier. Utiliser un buffer/moyenne glissante pour la classification mouvement.

2. **Camera low-res obligatoire** — `ResolutionPreset.low` (480p) pour minimiser le drain batterie. `ResolutionPreset.low` sur CameraX peut monter a 480p (pas 240p comme documente — 240p tombe silencieusement a 480p).

3. **iOS : pas de camera en background** — La camera est hardware-locked au foreground. Le mode passif iOS ne peut detecter les obstacles que via accelerometre + location. Pas de YOLO/TFLite en background sur iOS.

4. **Guard `_processing` obligatoire** — Les callbacks camera haute frequence (15-30 FPS) necessitent un flag `_processing` pour eviter les appels concurrents a l'inference ML.

5. **Timer immobile > 30s** — Utiliser `Clock.delayed(Duration(seconds: 30))` (injectable) pour le timer d'inactivite. Si aucun mouvement detecte pendant 30s → camera OFF.

6. **battery_plus + sensors_plus** — Les deux requierent Kotlin 2.2.0 et AGP >= 8.12.1. Verifier la compatibilite avec le setup Gradle actuel du projet.

7. **RAM < 200 MB** — Les images camera en YUV420 prennent ~1.5MB chacune. Ne JAMAIS accumuler les frames — traiter et liberer immediatement. Utiliser `Isolate.run` pour l'inference ML hors main isolate.

## Architecture References

- `lib/features/io/domain/background_service.dart` — Interface (Story 10.1)
- `lib/features/io/domain/camera_service.dart` — CameraService (E3)
- `lib/features/io/domain/motion_service.dart` — MotionService (E3)
- `lib/features/io/domain/location_service.dart` — LocationService (E3)
- `lib/features/plugins/built_in/alert/kita_alert_plugin.dart` — AlertAgent (E7)
- `lib/features/orchestration/data/output_coordinator.dart` — OutputCoordinator (E12)

## Implementation Tasks

### Task 1 : PassiveModeManager (domain)

Creer `lib/features/io/domain/passive_mode.dart` :
- [ ] `abstract class PassiveModeManager`
- [ ] `Future<void> activate()` — active le mode passif
- [ ] `Future<void> deactivate()` — desactive
- [ ] `Stream<PassiveModeState> get stateStream`
- [ ] `enum PassiveModeState { idle, monitoring, alerting, lowBattery }`
- [ ] `enum MotionState { stationary, walking, running }`

### Task 2 : PassiveModeManagerImpl (data)

Creer `lib/features/io/data/passive_mode_impl.dart` :
- [ ] Implements `PassiveModeManager`
- [ ] Souscrit a `userAccelerometerEventStream` pour classification mouvement
- [ ] Adapte le FPS camera selon `MotionState`
- [ ] Timer 30s inactivite → camera OFF (via `Clock.delayed`)
- [ ] Souscrit a `battery.onBatteryStateChanged`
- [ ] Si batterie < 20% → mode low battery (camera OFF, accel 5Hz)
- [ ] Alerte vocale batterie < 20% via OutputCoordinator
- [ ] Dispose propre de toutes les subscriptions

### Task 3 : AdaptiveSensorController (data)

Creer `lib/features/io/data/adaptive_sensor_controller.dart` :
- [ ] Gere les transitions accelerometre (changement `samplingPeriod`)
- [ ] Gere les transitions camera (start/stop stream, changement FPS gate)
- [ ] Guard `_processing` sur les callbacks camera
- [ ] `ResolutionPreset.low` obligatoire
- [ ] `ImageFormatGroup.yuv420` pour ML Kit/TFLite

### Task 4 : Battery monitor integration

- [ ] Provider `batteryLevelProvider` — StreamProvider depuis `battery_plus`
- [ ] Provider `isLowBatteryProvider` — derived, `< 20%`
- [ ] Alerte vocale via `OutputCoordinator` quand `isLowBattery` passe a true
- [ ] Cooldown sur l'alerte batterie (pas de spam toutes les minutes)

### Task 5 : Tests

- [ ] `test/features/io/data/passive_mode_impl_test.dart`
  - Test : immobile → camera OFF
  - Test : marche → camera 15 FPS
  - Test : course → camera 30 FPS
  - Test : immobile > 30s → camera OFF (avec FakeClock)
  - Test : batterie < 20% → mode low battery
  - Test : batterie < 20% → alerte vocale (une seule fois)
  - Test : dispose nettoie toutes les subscriptions
- [ ] `test/features/io/data/adaptive_sensor_controller_test.dart`
  - Test : guard `_processing` empeche les appels concurrents
  - Test : changement FPS effectif
- [ ] Au moins 1 test d'integration avec mocks capteurs

## Definition of Done

- [ ] PassiveModeManager avec adaptation FPS
- [ ] Camera OFF si immobile > 30s
- [ ] FPS adapte : OFF / 15 / 30 selon mouvement
- [ ] Alerte batterie < 20%
- [ ] Mode low battery (camera OFF, accel reduit)
- [ ] Guard concurrent sur callbacks camera
- [ ] 10+ tests passent
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
