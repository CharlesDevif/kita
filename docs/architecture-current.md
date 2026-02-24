# Kita — Architecture actuelle (Phase 3)

## Vue d'ensemble

```mermaid
graph TB
    subgraph ENTRY["Initialisation"]
        main["main.dart"] --> sl["ServiceLocator.init()"]
        sl --> app["KitaApp<br/>ProviderScope + MixTheme"]
        app --> router["go_router"]
    end

    subgraph NAV["Navigation"]
        router --> home["/ → KitaShell"]
        router --> onboard["/onboarding → Placeholder ⬜"]
        router --> settings["/settings → Placeholder ⬜"]
    end

    subgraph SHELL["Shell UI (E8) ✅"]
        home --> shell["KitaShell<br/>Scaffold 3 zones"]
        shell --> header["Header"]
        shell --> vp["PluginViewport"]
        shell --> input_zone["KitaInput"]

        header --> orb["KitaOrb<br/>6 animations"]
        header --> status["StatusIndicator<br/>online/offline"]

        input_zone --> mic["Micro 56x56"]
        input_zone --> text["Champ texte"]
    end

    subgraph PLUGINS["Plugin System (E5) ✅"]
        registry["PluginRegistry<br/>register/activate/deactivate"]
        registry --> describe["KitaDescribePlugin"]
        registry --> alert["KitaAlertPlugin"]
    end

    subgraph SANDBOX["Sandboxes"]
        sensor["SensorAccess<br/>camera, location, motion"]
        ai_sandbox["AIAccess<br/>vision, complete"]
        mem_sandbox["MemoryAccess<br/>query, store"]
    end

    subgraph AI["AI Router (E2) ✅"]
        ai_router["AIRouter"] --> classifier["RequestClassifier<br/>4 priorities"]
        classifier --> fallback["FallbackChain"]
        fallback --> claude["Claude Provider"]
        fallback --> openai["OpenAI Provider"]
        fallback --> local["Local Provider<br/>ML Kit / CoreML"]
        ai_router --> cache["ResponseCache"]
    end

    subgraph IO["Capteurs (E3) ✅"]
        camera["CameraService<br/>photo + stream"]
        tts["TTSService<br/>speak + priorities"]
        stt["STTService<br/>transcription"]
        haptic["HapticService<br/>warning/danger"]
        loc["LocationService"]
        motion["MotionService"]
        voice["VoiceCommandHandler<br/>7 commandes"]
    end

    subgraph MEMORY["Mémoire (E4) ✅"]
        vault["MemoryVault<br/>SQLCipher AES-256"]
        vault --> episode_dao["EpisodeDao"]
        vault --> person_dao["PersonDao"]
        vault --> consent_dao["ConsentDao"]
        vault --> pref_dao["PreferenceDao"]
        cleanup["AutoCleanupService<br/>30j retention"]
        secure["SecureKeyVault<br/>Keychain/Keystore"]
    end

    subgraph MULTIMODAL["Multi-Modal (E8) ✅"]
        profile["ProfileAdapter"]
        profile --> p_blind["Profil aveugle<br/>vocal + haptic"]
        profile --> p_deaf["Profil sourd<br/>visual + haptic"]
        profile --> p_std["Profil standard<br/>tous canaux"]
    end

    %% Connexions Plugin → Sandboxes
    describe --> sensor
    describe --> ai_sandbox
    alert --> sensor
    alert --> ai_sandbox

    %% Sandboxes → Services
    sensor --> camera
    sensor --> loc
    sensor --> motion
    ai_sandbox --> ai_router

    %% Alert → Output direct
    alert --> tts
    alert --> haptic
    alert --> profile

    %% Viewport display
    describe -.-> vp
    alert -.-> vp

    %% Input → Voice
    mic --> stt
    stt --> voice
    voice -.-> registry
```

## Flow Describe (E6) ✅

```mermaid
sequenceDiagram
    participant M as Marie (voix)
    participant STT as STTService
    participant VC as VoiceCommand
    participant PR as PluginRegistry
    participant DP as DescribePlugin
    participant CAM as CameraService
    participant AI as AIRouter
    participant TTS as TTSService
    participant PA as ProfileAdapter

    M->>STT: "Décris"
    STT->>VC: transcription
    VC->>PR: command 'decris'
    PR->>DP: handleRequest('decris')
    DP->>CAM: capturePhoto()
    CAM-->>DP: ImageData (EXIF stripped)
    DP->>AI: vision(image, prompt)
    AI-->>DP: "Un passage piéton avec..."
    DP-->>PR: PluginResponse(text)
    PR-->>PA: feedback(vocal + haptic)
    PA->>TTS: speak("Un passage piéton...")

    Note over DP: Timer 5s silence

    M->>STT: "Plus de détails"
    STT->>VC: transcription
    VC->>PR: command 'moreDetails'
    PR->>DP: handleRequest('moreDetails')
    DP->>AI: vision(same image, detailed prompt)
    AI-->>DP: "Plus précisément..."
    DP-->>PR: PluginResponse(text)
    PA->>TTS: speak("Plus précisément...")

    Note over DP: 5s silence → retour passif
```

## Flow Alert (E7) ✅

```mermaid
sequenceDiagram
    participant CAM as CameraService
    participant OD as ObstacleDetector
    participant FP as FramePreprocessor
    participant YOLO as TFLite/YOLO
    participant DP as DetectionPostprocessor
    participant AP as KitaAlertPlugin
    participant PA as ProfileAdapter
    participant TTS as TTSService
    participant HAP as HapticService
    participant UI as AlertViewport

    CAM->>FP: frame (YUV420)
    FP->>FP: RGB → resize 640x640 → normalize
    FP->>YOLO: Float32 tensor
    YOLO-->>DP: raw predictions
    DP->>DP: transpose + filter > 0.80 + NMS
    DP-->>OD: List<Detection>

    OD->>AP: handleRequest('obstacle_detected')
    AP->>AP: classify urgency (distance)

    alt Immédiat (< 2m)
        AP->>PA: feedback(vocal + haptic)
        PA->>TTS: "Attention! Poteau à 1 mètre"
        PA->>HAP: danger()
        AP->>UI: AlertViewport(critical)
    else Préventif (2-5m)
        AP->>PA: feedback(vocal + haptic léger)
        PA->>TTS: "Vélo à 3 mètres"
        PA->>HAP: warning()
    end

    Note over AP: Auto-dismiss 5s

    Note over AP: Marie: "C'est quoi?"
    AP->>AP: lookup last detection (< 10s)
    AP-->>PA: description détaillée
```

## État du câblage

| Composant | Code | Câblé | Phase |
|-----------|------|-------|-------|
| KitaShell (3 zones) | ✅ | ⚠️ partiel | E8 |
| KitaOrb (animations) | ✅ | ✅ | E8 |
| KitaInput (mic+texte) | ✅ | ⚠️ callbacks définis, pas branchés | E8 |
| PluginRegistry | ✅ | ✅ | E5 |
| Describe Plugin | ✅ | ✅ via sandboxes | E6 |
| Alert Plugin | ✅ | ✅ via sandboxes | E7 |
| AI Router + Fallback | ✅ | ⚠️ pas de provider Riverpod public | E2 |
| Camera/TTS/STT/Haptic | ✅ | ⚠️ services dispo, intégration Shell partielle | E3 |
| Memory (SQLCipher) | ✅ | ❌ infrastructure prête, pas utilisée | E4 |
| ProfileAdapter | ✅ | ✅ Alert l'utilise | E8 |
| Onboarding | ❌ placeholder | ❌ | E9 |
| Background service | ❌ pas commencé | ❌ | E10 |
| Settings/Forget | ❌ placeholder | ❌ | E10 |

## Ce qui manque pour le MVP

1. **Phase 4 — E9** : Onboarding vocal (Marie ouvre l'app pour la 1ère fois)
2. **Phase 4 — E10** : Background service (détection continue quand l'app est en arrière-plan)
3. **Phase 5 — E11** : Tests E2E, CI/CD, build signé, déploiement stores
4. **Câblage Shell ↔ Plugins** : KitaInput → VoiceCommand → PluginRegistry (partiellement fait)
5. **Câblage Shell ↔ AI** : Requêtes texte → AIRouter (pas encore fait)
6. **Memory utilisée** : Les plugins ne stockent pas encore d'épisodes en mémoire
