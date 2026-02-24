# Spec : RequestOrchestrator — Gestion des requêtes concurrentes

**Décision :** Option C — Hybride (interruption + FIFO avec priorités)
**Phase :** 4 (E9/E10)
**Validé par :** Charles, 2026-02-24

## Contexte

Marie est aveugle. Elle ne peut pas voir d'indicateur de chargement ni lire une queue de notifications. Chaque output est vocal ou haptique. La gestion des requêtes concurrentes doit être invisible et intuitive.

## Architecture

```
            Voix / Texte / Capteurs
                     │
                ┌────▼────┐
                │  Input   │  STT, texte, détections
                └────┬────┘
                     │
              ┌──────▼──────┐
              │ RequestRouter│  classifie la priorité
              └──────┬──────┘
                     │
        ┌────────────┼────────────┐
        │            │            │
  ┌─────▼─────┐ ┌───▼───┐ ┌─────▼─────┐
  │ CRITICAL  │ │URGENT │ │ STANDARD  │
  │ interrupt │ │ wait  │ │   FIFO    │
  └─────┬─────┘ └───┬───┘ └─────┬─────┘
        │            │           │
        └────────────┼───────────┘
                     │
              ┌──────▼──────┐
              │  Executor   │  plugin actif + TTS control
              └─────────────┘
```

## Niveaux de priorité

| Niveau | Déclencheur | Comportement TTS | Exemple |
|--------|-------------|-------------------|---------|
| **CANCEL** | "stop", "annule" | Coupe TTS + vide la queue + reset plugin | Marie dit "stop" |
| **CRITICAL** | Obstacle < 2m | Coupe TTS immédiatement, parle | "Attention ! Poteau à 1m" |
| **URGENT** | Obstacle 2-5m | Attend fin de phrase (~2s max), puis parle | "Vélo à 3 mètres" |
| **STANDARD** | "décris", "plus de détails", mémoire | FIFO, attend son tour | Description de scène |

## Règles de comportement

### Interruption et queue

1. **CANCEL coupe tout** — `TTS.stop()`, vide la queue, reset le plugin actif, feedback vocal "OK"
2. **CRITICAL interrompt** — `TTS.stop()`, insère en tête de queue, exécute immédiatement
3. **URGENT attend la phrase** — TTS continue jusqu'à la prochaine pause naturelle (~2s max), puis insère en tête
4. **STANDARD s'enqueue** — FIFO, exécuté quand rien de plus prioritaire
5. **Même plugin** — une nouvelle commande du même plugin remplace la précédente (pas d'accumulation de "décris" x5)
6. **Timeout** — une requête en queue depuis > 10s est silencieusement droppée (le contexte spatial a changé)

### Queue

- **Taille** : illimitée (le timeout de 10s fait office de nettoyage naturel)
- **Feedback CANCEL** : Kita confirme "OK" (sonore) avant de se taire

### Cooldown alertes (anti-spam)

Pour éviter que Marie entende "poteau... poteau... poteau..." en marchant le long d'une rue :

- **1ère détection** d'un type d'obstacle → alerte complète (TTS + haptic + visual)
- **Détections suivantes dans les 15s** → silencieuses
- **Exception rapprochement** : si la distance diminue de > 30% (ex: 3m → 1.5m) → nouvelle alerte même pendant le cooldown
- **Après 15s** → cooldown expire, prochaine détection = nouvelle alerte
- **Clé de cooldown** : `{label}_{zone}` (même type + même zone approximative)

### Retour au contexte après interruption

- Après une alerte qui interrompt une description, Kita **ne reprend PAS** automatiquement
- Marie doit re-demander ("décris" ou "continue")
- Raison : le contexte spatial a changé (Marie a bougé), reprendre une description obsolète serait confusant

## Composants à implémenter

| Composant | Responsabilité | Fichier prévu |
|-----------|---------------|---------------|
| `RequestRouter` | Classifie priorité, route vers queue | `lib/core/orchestration/request_router.dart` |
| `RequestQueue` | FIFO avec priorités, timeout, dedup | `lib/core/orchestration/request_queue.dart` |
| `RequestExecutor` | Exécute la requête via plugin + gère TTS | `lib/core/orchestration/request_executor.dart` |
| `AlertCooldown` | Cooldown 15s par obstacle, exception rapprochement | `lib/features/plugins/built_in/alert/alert_cooldown.dart` |
| `TTSController` | Interruption immédiate vs attente phrase | Extension de `lib/features/io/data/tts_service.dart` |

## Dépendances

- `PluginRegistry` (E5) — déjà implémenté
- `TTSService` avec priorities (E3) — déjà implémenté, à étendre avec `waitForPhrase()`
- `ObstacleDetector` (E7) — déjà implémenté
- `VoiceCommandHandler` (E3) — déjà implémenté, à étendre avec CANCEL

## Tests requis

- [ ] CANCEL coupe le TTS et vide la queue
- [ ] CRITICAL interrompt une description en cours
- [ ] URGENT attend la fin de phrase avant de parler
- [ ] STANDARD en FIFO (2 requêtes, exécutées dans l'ordre)
- [ ] Même plugin : nouvelle commande remplace l'ancienne
- [ ] Timeout 10s : requête droppée silencieusement
- [ ] Cooldown 15s : même obstacle pas ré-alerté
- [ ] Exception rapprochement : re-alerte si distance -30%
- [ ] Après interruption, pas de reprise auto
