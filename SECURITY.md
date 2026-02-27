# Politique de sécurité

## Versions supportées

| Version       | Supportée          |
|---------------|-------------------|
| 1.0.x-beta    | :white_check_mark: |
| < 1.0.0-beta  | :x:                |

## Signaler une vulnérabilité

**Ne publiez PAS de vulnérabilité via les issues publiques GitHub.**

Kita traite des données sensibles (caméra, voix, localisation, données personnelles) et prend la sécurité très au sérieux.

Pour signaler une vulnérabilité, envoyez un email à :

**kita-security@proton.me**

Incluez dans votre rapport :

- Description détaillée de la vulnérabilité
- Étapes de reproduction
- Impact potentiel
- Suggestions de correction (si applicable)

## Délais de réponse

| Étape                          | Délai visé        |
|--------------------------------|-------------------|
| Accusé de réception            | 48 heures         |
| Évaluation initiale            | 7 jours           |
| Correctif (critique/haute)     | 30 jours          |
| Correctif (moyenne/basse)      | 90 jours          |

## Périmètre

Les vulnérabilités suivantes sont dans le périmètre :

- Fuite de données personnelles (PII) via les logs ou le réseau
- Contournement du sandbox des plugins
- Accès non autorisé à la base de données chiffrée (Drift + SQLCipher)
- Exfiltration de données via les providers IA (contexte envoyé aux API cloud)
- Contournement des permissions caméra/micro/localisation
- Injection de commandes via le système vocal ou les plugins

## Bonnes pratiques

- **Clés API** : ne jamais commiter de clés API ou tokens dans le dépôt. Utiliser des variables d'environnement ou `flutter_secure_storage`.
- **Logs** : aucune donnée personnelle (PII) ne doit apparaître dans les logs (coordonnées GPS, noms, emails, etc.).
- **Base de données** : toutes les données utilisateur sont chiffrées via SQLCipher (AES-256).
- **Sandbox plugins** : les plugins tiers s'exécutent dans un environnement sandboxé avec permissions explicites.

## Divulgation responsable

Nous suivons le principe de divulgation coordonnée. Nous vous demandons de :

1. Nous accorder un délai raisonnable pour corriger la vulnérabilité avant toute publication
2. Ne pas exploiter la vulnérabilité au-delà de ce qui est nécessaire pour la démontrer
3. Ne pas accéder ni modifier les données d'autres utilisateurs

Nous nous engageons à :

1. Vous tenir informé de l'avancement du correctif
2. Vous créditer dans les notes de version (sauf si vous préférez l'anonymat)
3. Ne pas engager de poursuites contre les chercheurs en sécurité agissant de bonne foi
