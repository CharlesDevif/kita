# Kita — Data Safety Section (Google Play)

Ce document sert de **référence interne** pour remplir la section Data Safety dans la Google Play Console.
Il documente les réponses exactes à fournir et les justifications associées.

**Application :** Kita — Compagnon IA d'assistance au handicap
**Package :** `com.kita.kita`
**Version :** 1.0.0-beta.1

---

## Comment remplir la Data Safety dans Play Console

1. Aller dans Play Console → [Votre app] → Politique → Data safety
2. Répondre aux questions dans l'ordre ci-dessous
3. Sauvegarder et soumettre pour vérification

---

## Section 1 : Collecte et partage de données

### Q: Votre application collecte-t-elle ou partage-t-elle des données utilisateur ?

**Réponse : Oui (partage limité uniquement)**

**Justification :**
- Kita est **local-first** : aucune donnée personnelle n'est collectée sur des serveurs.
- Cependant, lorsque l'utilisateur utilise les fonctionnalités IA, le **contenu de la requête** (texte ou description de scène) est transmis aux providers IA (Anthropic Claude, OpenAI). Ce contenu ne contient aucune donnée d'identification personnelle (PII).

---

## Section 2 : Types de données

### Données collectées par l'application

**Réponse : Aucune collecte sur serveur**

Kita ne collecte aucune donnée utilisateur sur ses propres serveurs. Toutes les données sont stockées localement sur l'appareil.

### Données partagées avec des tiers

| Type de donnée | Partagé avec | Finalité | Obligatoire ? |
|----------------|-------------|----------|---------------|
| Contenu des requêtes (texte/audio transcrit) | Anthropic (Claude) | Génération de réponses IA | Optionnel (fonctionnalité IA) |
| Contenu des requêtes (texte/audio transcrit) | OpenAI (GPT) | Génération de réponses IA | Optionnel (fonctionnalité IA) |

**Important :** Le contenu des requêtes ne contient **jamais** :
- Nom ou prénom de l'utilisateur
- Localisation GPS précise
- Profil d'accessibilité (données de santé Art. 9 RGPD)
- Clés API ou tokens d'authentification
- Données de contact

---

## Section 3 : Pratiques de sécurité

### Q: Les données sont-elles chiffrées en transit ?

**Réponse : Oui**

Toutes les communications avec des services externes (providers IA) utilisent **HTTPS/TLS**. Aucune donnée n'est transmise en clair.

### Q: Les données sont-elles chiffrées au repos ?

**Réponse : Oui**

La base de données locale est chiffrée avec **SQLCipher (AES-256)**. La clé de chiffrement est stockée dans le **Android Keystore** (zone matériellement sécurisée).

### Q: L'utilisateur peut-il demander la suppression de ses données ?

**Réponse : Oui**

Kita intègre une fonctionnalité native **"Tout oublier"** (Paramètres → Confidentialité → Tout oublier) qui supprime irréversiblement toutes les données locales. La suppression est immédiate.

---

## Section 4 : APIs tierces et leurs pratiques

### Anthropic (Claude API)

- **Site :** https://www.anthropic.com/privacy
- **Données transmises :** Contenu des requêtes textuelles uniquement
- **Rétention :** Selon la politique Anthropic (consulter leur documentation)
- **Note :** Le champ `context` interne de Kita (métadonnées) n'est **jamais** transmis à Anthropic

### OpenAI (GPT API)

- **Site :** https://openai.com/privacy
- **Données transmises :** Contenu des requêtes textuelles uniquement
- **Rétention :** Selon la politique OpenAI (consulter leur documentation)
- **Note :** Les données soumises via API ne sont pas utilisées pour entraîner les modèles (à vérifier selon le plan API)

---

## Section 5 : Formulaire Play Console — Réponses ligne par ligne

| Question Play Console | Réponse | Notes |
|----------------------|---------|-------|
| Cette app collecte-t-elle des données ? | **Non** (collecte serveur) | Données uniquement locales |
| Cette app partage-t-elle des données ? | **Oui** (contenu requêtes IA) | Limité au contenu des requêtes |
| Quels types de données sont partagés ? | **Contenu utilisateur** (requêtes) | Pas de PII |
| Les données partagées sont-elles chiffrées en transit ? | **Oui** | HTTPS/TLS |
| Les données au repos sont-elles chiffrées ? | **Oui** | SQLCipher AES-256 |
| L'utilisateur peut-il demander la suppression ? | **Oui** | Fonctionnalité "Tout oublier" intégrée |
| Y a-t-il une politique de confidentialité ? | **Oui** | URL : voir docs/privacy-policy-url.txt |

---

## Section 6 : Catégories de données (Play Console)

Dans la section "Data types", sélectionner :

- [ ] **App activity** → App interactions : NON (pas de tracking)
- [ ] **App info and performance** → Crash logs : NON (pas de Sentry en MVP)
- [ ] **Device or other IDs** : NON (pas d'Android ID utilisé)
- [x] **Messages** → Other in-app messages : OUI (contenu requêtes IA, non permanent)

**Finalité pour le contenu des requêtes IA :**
- [ ] Analytics : NON
- [ ] Developer communications : NON
- [x] App functionality : OUI (les requêtes sont nécessaires au fonctionnement de l'IA)
- [ ] Fraud prevention : NON
- [ ] Personalization : NON
- [ ] Account management : NON

---

## Section 7 : Notes pour la soumission

1. **Politique de confidentialité :** Héberger `docs/privacy-policy.md` et renseigner l'URL dans Play Console avant soumission.
2. **Vérification annuelle :** Revoir cette section à chaque ajout d'un nouveau provider IA ou d'une nouvelle fonctionnalité collectant des données.
3. **Accessibility Nutrition Labels :** Play Store propose également une section accessibilité — déclarer le support TalkBack, Dynamic Text, et réduction d'animations.
