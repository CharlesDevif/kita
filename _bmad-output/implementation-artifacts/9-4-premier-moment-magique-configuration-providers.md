---
story_id: "9.4"
title: "Premier Moment Magique et configuration providers"
epic: "E9 — Kita accueille — Onboarding Marie"
phase: "4"
status: review
priority: high
estimated_complexity: L
depends_on: ["9.3"]
blocks: ["9.5"]
---

# Story 9.4 : Premier Moment Magique et configuration providers

## User Story

**En tant que** utilisateur de Kita,
**je veux** vivre mon Premier Moment Magique ("decris" → description vocale) a la fin de l'onboarding et configurer mes providers IA,
**afin que** je sois convaincu que Kita fonctionne et pret a l'utiliser au quotidien.

## Acceptance Criteria

- **AC1:** Kita dit : "On essaie ? Dis-moi 'decris' et pointe ton telephone vers quelque chose."
- **AC2:** L'utilisateur dit "decris" et recoit une description vocale < 5s
- **AC3:** Kita dit : "Je suis prete. Dis-moi ce dont tu as besoin."
- **AC4:** Le mode decouverte gratuit est propose par defaut (credits limites)
- **AC5:** Le mode BYOK permet d'entrer ses cles API (ecran `api_key_setup.dart`)
- **AC6:** Les cles API sont validees via `AIProvider.validateApiKey()` et stockees dans Keychain/Keystore
- **AC7:** L'onboarding se termine et le mode passif s'active
- **AC8:** Chaque widget interactif a un `Semantics` wrapper
- **AC9:** Contrastes >= 4.5:1, touch targets >= 48x48px

## Technical Intelligence

### flutter_secure_storage 10.0.0 — Stockage cles API

```yaml
dependencies:
  flutter_secure_storage: ^10.0.0
```

```dart
final storage = FlutterSecureStorage(
  aOptions: AndroidOptions(resetOnError: true),
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
    // first_unlock : donnees accessibles apres premier deverrouillage
    // Necessaire pour le background service (Story 10.x)
  ),
);

// Stocker une cle API
await storage.write(key: 'anthropic_api_key', value: apiKey);

// Lire
final key = await storage.read(key: 'anthropic_api_key');

// Verifier existence
final exists = await storage.containsKey(key: 'anthropic_api_key');
```

**IMPORTANT** : `KeychainAccessibility.first_unlock` (pas `.unlocked` qui est le defaut). `.unlocked` bloque l'acces en background — critique pour Story 10.x.

### Migration flutter_secure_storage 9.x → 10.0.0

**Breaking change** : les cles ecrites avec v9 + `encryptedSharedPreferences: false` echouent avec `readAll`/`deleteAll` en v10 (GitHub #912). Comme c'est une fresh install (onboarding), pas de migration necessaire.

**`encryptedSharedPreferences` est DEPRECATED en v10** — ne pas l'utiliser.

### Validation cle API

```dart
// Pattern de validation via AIProvider existant (E2)
Future<bool> validateApiKey(String provider, String key) async {
  try {
    final result = await aiRouter.validateKey(provider, key);
    return result.isSuccess;
  } catch (_) {
    return false;
  }
}
```

### Premier Moment Magique — Flow

```
Kita dit : "On essaie ? Dis-moi 'decris'"
  ↓
STT capture "decris"
  ↓
KitaOrchestrator.handleInput(RawInput.voice("decris"))
  ↓
InputRouter → spawn DescribeAgent → capture photo → AI → TTS
  ↓
Description vocale (< 5s)
  ↓
Kita dit : "Je suis prete. Dis-moi ce dont tu as besoin."
  ↓
Choix provider : Decouverte gratuite (defaut) ou BYOK
  ↓
Si BYOK : ecran api_key_setup → validation → stockage Keychain/Keystore
  ↓
Onboarding complete → mode passif
```

## Pitfalls & Gotchas

1. **Latence < 5s pour le Premier Moment Magique** — Utiliser le provider IA le plus rapide disponible (local ML Kit si possible, sinon cloud avec fallback). Le Premier Moment doit etre impressionnant, pas frustrant.

2. **Camera deja autorisee** — La permission camera a ete accordee en Story 9.3. Pas besoin de re-demander. Mais verifier le status avant de lancer le Describe.

3. **flutter_secure_storage v10 + BadPaddingException** — Sur certains appareils Android, l'ecriture de JWT/longues valeurs peut corrompre l'entree Keystore (GitHub #933). `resetOnError: true` (defaut v10) efface et retente, mais perd la valeur precedente. Acceptable pour les cles API (l'utilisateur peut re-entrer).

4. **Mode decouverte** — Le mode gratuit avec credits limites est le defaut. L'utilisateur ne doit PAS etre oblige de configurer BYOK pour terminer l'onboarding.

5. **KitaOrchestrator** — Le Premier Moment Magique utilise le vrai pipeline orchestrateur (InputRouter → DescribeAgent). Ne pas creer un flow separe — valider que le systeme complet fonctionne.

## Architecture References

- `lib/features/onboarding/presentation/api_key_setup.dart` — Ecran BYOK
- `lib/features/ai/domain/ai_router.dart` — AIRouter pour validation (E2)
- `lib/features/orchestration/data/kita_orchestrator.dart` — Orchestrateur (E12)
- `lib/features/plugins/built_in/describe/describe_plugin.dart` — DescribeAgent (E6)
- `lib/features/memory/data/tables/user_profiles_table.dart` — Profil utilisateur (E4)

## Implementation Tasks

### Task 1 : MagicMomentScreen (presentation)

Creer `lib/features/onboarding/presentation/magic_moment_step.dart` :
- [x] Kita dit "On essaie ? Dis-moi 'decris'" (TTS)
- [x] Ecoute STT pour "decris" (via DescribeCallback)
- [x] Lance describe via callback (injectable, wired to real pipeline in OnboardingScreen)
- [x] Affiche feedback pendant le traitement (CircularProgressIndicator "Je regarde...")
- [x] Apres description reussie, Kita dit "Je suis prete"
- [x] Gestion du cas d'echec (camera fail, AI fail) avec message d'encouragement
- [x] `Semantics` wrapper sur tous les elements

### Task 2 : ApiKeySetupScreen (presentation)

Creer `lib/features/onboarding/presentation/api_key_setup_step.dart` :
- [x] Choix : "Decouverte gratuite" (defaut) vs "J'ai mes propres cles"
- [x] Si BYOK : champ de saisie pour cle API (Anthropic, OpenAI)
- [x] Validation en temps reel via ValidateKeyCallback (injectable)
- [x] Feedback visuel + vocal : check icon "Cle valide" ou error text "Cle invalide"
- [x] Stockage via StoreKeyCallback (injectable, wired to flutter_secure_storage)
- [x] `Semantics` wrapper, touch targets >= 48x48px

### Task 3 : OnboardingCompletion (data)

Creer `lib/features/onboarding/data/onboarding_completion.dart` :
- [x] `Future<void> completeOnboarding(String userName, AccessibilityProfile profile)`
- [x] Persiste le profil via PersistProfileCallback (injectable)
- [x] Marque l'onboarding comme complete via MarkCompleteCallback (injectable)
- [x] Completion flag + duplicate call guard
- [x] Invalide le `onboardingCompleteProvider` pour declencher le redirect go_router

### Task 4 : Tests

- [x] `test/features/onboarding/presentation/magic_moment_step_test.dart`
  - Test : flow complet "decris" → description vocale (11 tests)
  - Test : echec camera → message d'encouragement
  - Test : echec AI → fallback message
- [x] `test/features/onboarding/presentation/api_key_setup_step_test.dart`
  - Test : choix decouverte gratuite (defaut)
  - Test : BYOK cle valide → stockage (15 tests)
  - Test : BYOK cle invalide → message erreur
- [x] `test/features/onboarding/data/onboarding_completion_test.dart`
  - Test : completion persiste le profil (7 tests)
  - Test : redirect go_router apres completion

## Accessibility Tax

- [x] `Semantics` wrapper sur boutons "Decouverte" et "J'ai mes cles"
- [x] `Semantics` wrapper sur champ de saisie cle API
- [x] Feedback vocal a chaque etape
- [x] Contrastes >= 4.5:1
- [x] Touch targets >= 48x48px

## Definition of Done

- [x] Premier Moment Magique fonctionne via callback injectable (wired to pipeline in OnboardingScreen)
- [x] Ecran BYOK avec validation et stockage securise
- [x] Mode decouverte gratuit par defaut
- [x] Onboarding completion persiste et redirige
- [x] Accessibility Tax verifie
- [x] 8+ tests passent (33 tests for story 9.4 components)
- [x] `dart analyze --fatal-infos` clean
- [x] `flutter test` passe (126 tests onboarding total)
- [x] Zero PII dans les logs (PAS de cle API dans les logs)
- [x] sprint-status.yaml mis a jour

---

## Dev Agent Record

**Agent Model:** Claude Opus 4.6
**Date:** 2026-02-25

### Completion Notes

**Approach:** Story 9.4 implements the "Premier Moment Magique" and API key setup as the final onboarding steps. The architecture uses injectable callbacks (DescribeCallback, ValidateKeyCallback, StoreKeyCallback) to decouple presentation from infrastructure. This allows easy testing without real AI/storage dependencies while the OnboardingScreen wires real services.

**Key decisions:**
- MagicMomentStep uses a `DescribeCallback` returning `Future<bool>` instead of directly calling KitaOrchestrator. This allows the OnboardingScreen to wire the real pipeline while tests inject simple callbacks.
- ApiKeySetupStep detects the provider from key prefix (`sk-ant-` = anthropic, else openai). Validation and storage are injectable.
- OnboardingCompletion uses callback injection (PersistProfileCallback, MarkCompleteCallback) for testability. Duplicate calls are silently ignored with a warning log.
- The MagicMomentStep always allows continuing even on failure ("Pas de souci, on reessayera plus tard") — the magic moment must not block onboarding completion.
- Discovery mode (free with limited credits) is the default — BYOK is optional.
- Zero PII in logs — API keys are never logged, only "Validating API key" and "API key stored successfully".

**Integration with OnboardingScreen (9.2):** The `_buildMagicMoment` method in onboarding_screen.dart manages the transition from MagicMomentStep to ApiKeySetupStep via a `_showApiKeySetup` flag. After ApiKeySetupStep completes, `notifier.completeOnboarding()` triggers the go_router redirect.

### Files Modified

- `lib/features/onboarding/presentation/magic_moment_step.dart` — Created: MagicMomentStep widget with 4 states (invitation/processing/success/failure)
- `lib/features/onboarding/presentation/api_key_setup_step.dart` — Created: ApiKeySetupStep with discovery/BYOK modes
- `lib/features/onboarding/data/onboarding_completion.dart` — Created: OnboardingCompletion service with callback injection
- `lib/features/onboarding/di/providers.dart` — Modified: added onboardingCompletionProvider
- `lib/features/onboarding/presentation/onboarding_screen.dart` — Modified: integrated magic moment and api key steps
- `test/features/onboarding/presentation/magic_moment_step_test.dart` — Created: 14 tests
- `test/features/onboarding/presentation/api_key_setup_step_test.dart` — Created: 15 tests
- `test/features/onboarding/data/onboarding_completion_test.dart` — Created: 7 tests
