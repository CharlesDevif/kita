---
story_id: "10.2"
title: "Background Service — iOS Background Audio + Location"
epic: "E10 — Kita veille — Mode Passif & Background"
phase: "4"
status: ready-for-dev
priority: critical
estimated_complexity: XL
depends_on: []
blocks: ["10.3", "10.4"]
---

# Story 10.2 : Background Service — iOS Background Audio + Location

## User Story

**En tant que** utilisateur de Kita sur iOS,
**je veux** que Kita reste active en arriere-plan malgre les restrictions iOS,
**afin que** les alertes fonctionnent en continu.

## Acceptance Criteria

- **AC1:** `BackgroundAudioService.swift` utilise Background Audio pour maintenir l'app active
- **AC2:** Location Updates en background sont configures pour les situations de navigation
- **AC3:** `Info.plist` contient les justifications pour `UIBackgroundModes` (audio, location)
- **AC4:** Le `BackgroundChannel.swift` communique l'etat au code Flutter
- **AC5:** Les tests verifient la persistance du service

## Technical Intelligence

### Strategie iOS : Background Audio (plus fiable pour "always-on")

iOS n'a PAS de foreground service equivalent a Android. La strategie pour maintenir l'app active :

1. **Background Audio** — Configure `AVAudioSession` avec category `.playback` + `.mixWithOthers`. L'app reste active tant que la session audio est active (meme silencieuse).

2. **Background Location** — `CLLocationManager` avec `always` authorization. Active l'app a chaque changement de position significatif.

3. **Combinaison** — Audio pour le keepalive continu + Location pour les alertes de navigation.

### AppDelegate.swift — Configuration Background Audio

```swift
import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    configureAudioSession()
    setupBackgroundChannel()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
      // .playback garde l'app active en background
      // .mixWithOthers ne coupe pas la musique de l'utilisateur
      try session.setCategory(.playback, options: [.mixWithOthers])
      try session.setActive(true)
    } catch {
      print("[Kita] AVAudioSession config failed: \(error)")
    }
  }
}
```

### Info.plist — UIBackgroundModes et permissions

```xml
<!-- Background modes -->
<key>UIBackgroundModes</key>
<array>
  <string>audio</string>
  <string>location</string>
  <string>fetch</string>
  <string>processing</string>
</array>

<!-- Permission descriptions -->
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Kita utilise votre position pour detecter votre environnement et vous alerter des obstacles.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Kita utilise votre position pour adapter les alertes a votre environnement.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Kita utilise le micro pour ecouter vos commandes vocales.</string>
<key>NSCameraUsageDescription</key>
<string>Kita utilise la camera pour decrire votre environnement et detecter les obstacles.</string>
<key>NSMotionUsageDescription</key>
<string>Kita utilise le mouvement pour adapter l assistance selon votre activite.</string>
```

### BackgroundChannel.swift — Platform Channel

```swift
import Flutter

class BackgroundChannel {
  static let channelName = "com.kita/background"
  private let channel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    eventChannel = FlutterEventChannel(name: "com.kita/service_state", binaryMessenger: messenger)

    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "startService":
        self?.startService()
        result(nil)
      case "stopService":
        self?.stopService()
        result(nil)
      case "isRunning":
        result(self?.isRunning ?? false)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    eventChannel.setStreamHandler(ServiceStateStreamHandler(channel: self))
  }

  private func startService() { /* configure audio + location */ }
  private func stopService() { /* deactivate audio session */ }
  var isRunning: Bool { /* check audio session active */ }
}
```

### BGTaskScheduler — Pour taches periodiques (PAS pour keepalive continu)

```swift
// BGTaskScheduler donne 30s d'execution a intervalles de ~15min minimum
// Utile pour : sync modeles IA, nettoyage cache, check updates
// PAS utile pour : surveillance continue capteurs
BGTaskScheduler.shared.register(
  forTaskWithIdentifier: "com.kita.refresh",
  using: nil
) { task in
  self.handleRefresh(task: task as! BGAppRefreshTask)
}
```

### Package audio_session (Dart wrapper)

`audio_session` (pub.dev) wrape `AVAudioSession` en Dart si on prefere ne pas ecrire de Swift. Mais pour le controle fin dont Kita a besoin, le code Swift natif est recommande.

## Pitfalls & Gotchas

1. **Camera en background : IMPOSSIBLE sur iOS** — Le hardware camera est verrouille a l'app foreground. La session camera est terminee par l'OS immediatement au passage en background. La detection d'obstacles par camera ne fonctionne qu'au foreground. En background, seuls l'accelerometre et la location sont disponibles.

2. **Accelerometre en background** — Fonctionne SEULEMENT si l'app est maintenue active via audio ou location background mode. Sans keepalive, l'OS suspend l'app et les streams capteurs s'arretent.

3. **Silent audio trick** — L'audio session `.playback` + `.mixWithOthers` garde l'app active meme sans jouer de son audible. C'est une technique utilisee par les apps de navigation et fitness. Apple la tolere si l'app a une raison legitime (accessibilite = raison legitime).

4. **Location always authorization** — iOS demande d'abord `whenInUse`, puis l'app peut demander `always`. L'utilisateur recoit une notification systeme quelques jours plus tard demandant confirmation. Si l'utilisateur refuse → fallback sur `whenInUse` + perte du background location.

5. **Battery drain** — Location `always` + audio session active = drain batterie important. Optimiser avec `desiredAccuracy: kCLLocationAccuracyHundredMeters` et `distanceFilter: 10` (metres) pour reduire les updates location.

6. **App Store Review** — Apple peut rejeter l'app si les `UIBackgroundModes` ne sont pas justifies par l'usage reel. L'accessibilite est un cas d'usage accepte. Documenter clairement dans les metadata App Store.

7. **sensors_plus 7.0.0** — Requiert `NSMotionUsageDescription` dans Info.plist. Sans cette cle, l'app crash au premier acces accelerometre sur iOS.

## Architecture References

- `lib/platform/ios_bridge.dart` — Implementation iOS channels
- `ios/Runner/AppDelegate.swift` — Configuration audio session
- `ios/Runner/Info.plist` — Permissions et background modes
- `lib/features/io/domain/background_service.dart` — Interface (Story 10.1)
- `lib/features/io/domain/location_service.dart` — LocationService (E3)

## Implementation Tasks

### Task 1 : IOSBackgroundServiceImpl (data)

Creer `lib/features/io/data/ios_background_service_impl.dart` :
- [ ] Implements `KitaBackgroundService` (interface de Story 10.1)
- [ ] `start()` → active audio session + location background via MethodChannel
- [ ] `stop()` → desactive audio session
- [ ] `stateStream` → EventChannel depuis Swift
- [ ] `isRunning` → check via MethodChannel

### Task 2 : BackgroundChannel.swift (natif iOS)

Creer `ios/Runner/Channels/BackgroundChannel.swift` :
- [ ] MethodChannel `com.kita/background` : startService, stopService, isRunning
- [ ] EventChannel `com.kita/service_state` : stream d'etat
- [ ] Configure `AVAudioSession` category `.playback` + `.mixWithOthers`
- [ ] Gestion du lifecycle `applicationDidEnterBackground` / `willEnterForeground`

### Task 3 : Info.plist permissions

Modifier `ios/Runner/Info.plist` :
- [ ] `UIBackgroundModes` : audio, location, fetch, processing
- [ ] `NSLocationAlwaysAndWhenInUseUsageDescription`
- [ ] `NSLocationWhenInUseUsageDescription`
- [ ] `NSMotionUsageDescription`
- [ ] Toutes les descriptions en francais

### Task 4 : Platform-conditional Provider

Modifier `lib/features/io/di/` :
- [ ] `backgroundServiceProvider` retourne `AndroidBackgroundServiceImpl` ou `IOSBackgroundServiceImpl` selon la plateforme
- [ ] `Platform.isAndroid` / `Platform.isIOS` pour la selection

### Task 5 : Tests

- [ ] `test/features/io/data/ios_background_service_impl_test.dart`
  - Test : start() appelle le MethodChannel correct
  - Test : stop() appelle le MethodChannel correct
  - Test : stateStream decode les events
  - Test : isRunning retourne le bon etat
- [ ] Mock MethodChannel pour simuler les reponses iOS

## Definition of Done

- [ ] IOSBackgroundServiceImpl creee
- [ ] BackgroundChannel.swift fonctionnel
- [ ] Info.plist avec tous les background modes et permissions
- [ ] Provider platform-conditional
- [ ] 6+ tests passent
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
