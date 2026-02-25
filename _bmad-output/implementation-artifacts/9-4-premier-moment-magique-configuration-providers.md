---
story_id: "9.4"
title: "Premier Moment Magique et configuration providers"
epic: "E9 — Kita accueille — Onboarding Marie"
phase: "4"
status: ready-for-dev
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

Creer `lib/features/onboarding/presentation/magic_moment_screen.dart` :
- [ ] Kita dit "On essaie ? Dis-moi 'decris'" (TTS)
- [ ] Ecoute STT pour "decris"
- [ ] Lance `KitaOrchestrator.handleInput(RawInput.voice("decris"))` via le vrai pipeline
- [ ] Affiche feedback pendant le traitement (KitaOrb en mode processing)
- [ ] Apres description reussie, Kita dit "Je suis prete"
- [ ] Gestion du cas d'echec (camera fail, AI fail) avec message d'encouragement
- [ ] `Semantics` wrapper sur tous les elements

### Task 2 : ApiKeySetupScreen (presentation)

Creer `lib/features/onboarding/presentation/api_key_setup.dart` :
- [ ] Choix : "Decouverte gratuite" (defaut) vs "J'ai mes propres cles"
- [ ] Si BYOK : champ de saisie pour cle API (Anthropic, OpenAI)
- [ ] Validation en temps reel via `AIProvider.validateApiKey()`
- [ ] Feedback visuel + vocal : "Cle valide" ou "Cle invalide"
- [ ] Stockage dans `flutter_secure_storage` avec `KeychainAccessibility.first_unlock`
- [ ] `Semantics` wrapper, touch targets >= 48x48px

### Task 3 : OnboardingCompletion (data)

Creer `lib/features/onboarding/data/onboarding_completion.dart` :
- [ ] `Future<void> completeOnboarding(String userName, AccessibilityProfile profile)`
- [ ] Persiste le profil dans `user_profiles_table` (E4)
- [ ] Marque l'onboarding comme complete (SharedPreferences ou secure_storage)
- [ ] Active le mode passif
- [ ] Invalide le `onboardingCompleteProvider` pour declencher le redirect go_router

### Task 4 : Tests

- [ ] `test/features/onboarding/presentation/magic_moment_screen_test.dart`
  - Test : flow complet "decris" → description vocale
  - Test : echec camera → message d'encouragement
  - Test : echec AI → fallback message
- [ ] `test/features/onboarding/presentation/api_key_setup_test.dart`
  - Test : choix decouverte gratuite (defaut)
  - Test : BYOK cle valide → stockage
  - Test : BYOK cle invalide → message erreur
- [ ] `test/features/onboarding/data/onboarding_completion_test.dart`
  - Test : completion persiste le profil
  - Test : redirect go_router apres completion

## Accessibility Tax

- [ ] `Semantics` wrapper sur boutons "Decouverte" et "J'ai mes cles"
- [ ] `Semantics` wrapper sur champ de saisie cle API
- [ ] Feedback vocal a chaque etape
- [ ] Contrastes >= 4.5:1
- [ ] Touch targets >= 48x48px

## Definition of Done

- [ ] Premier Moment Magique fonctionne via le vrai pipeline orchestrateur
- [ ] Ecran BYOK avec validation et stockage securise
- [ ] Mode decouverte gratuit par defaut
- [ ] Onboarding completion persiste et redirige
- [ ] Accessibility Tax verifie
- [ ] 8+ tests passent
- [ ] `dart analyze --fatal-infos` clean
- [ ] `flutter test` passe
- [ ] Zero PII dans les logs (PAS de cle API dans les logs)
- [ ] sprint-status.yaml mis a jour

---

## Dev Agent Record

**Agent Model:**
**Date:**

### Completion Notes

_(A remplir par l'agent de developpement)_

### Files Modified

_(A remplir par l'agent de developpement)_
