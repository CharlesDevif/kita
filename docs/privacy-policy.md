# Politique de confidentialité — Kita

**Version :** 1.0.0-beta.1
**Date d'entrée en vigueur :** 2026-03-01
**Dernière mise à jour :** 2026-02-25

---

## 1. Introduction

Kita est une application mobile d'assistance au handicap visuel, auditif et cognitif. Elle est conçue selon le principe **local-first** : toutes vos données personnelles restent sur votre appareil et ne sont jamais transmises à des serveurs tiers sans votre consentement explicite.

La présente politique de confidentialité décrit comment Kita traite vos données personnelles, conformément au **Règlement Général sur la Protection des Données (RGPD — Règlement UE 2016/679)**.

---

## 2. Responsable du traitement

**Nom :** Charles (développeur indépendant)
**Contact RGPD :** privacy@kita.app *(adresse à configurer avant publication)*
**Adresse :** *(à compléter avant publication)*

---

## 3. Données collectées et traitées

### 3.1 Données stockées localement sur votre appareil

Kita stocke les données suivantes **exclusivement sur votre appareil**, chiffrées avec AES-256 (SQLCipher) :

| Type de donnée | Finalité | Base légale RGPD |
|----------------|----------|-----------------|
| Profil d'accessibilité (aveugle, malvoyant, sourd, etc.) | Adapter l'interface et les alertes | Consentement explicite (Art. 6.1.a + Art. 9.2.a) |
| Historique des interactions vocales | Améliorer la contextualisation des réponses | Consentement explicite (Art. 6.1.a) |
| Préférences utilisateur | Personnalisation de l'application | Intérêt légitime (Art. 6.1.f) |
| Clés API personnelles (Claude, OpenAI) | Permettre les fonctionnalités IA | Nécessité contractuelle (Art. 6.1.b) |

### 3.2 Données transmises à des services tiers

Lorsque vous utilisez les fonctionnalités d'intelligence artificielle, **le contenu de votre requête** (texte ou description de scène) est transmis au fournisseur IA configuré (Anthropic Claude ou OpenAI). **Aucune donnée d'identification personnelle** (nom, localisation précise, profil d'accessibilité) n'est incluse dans ces requêtes.

| Service | Données transmises | Données NON transmises |
|---------|--------------------|----------------------|
| Anthropic Claude | Contenu de la requête vocale/textuelle | Nom, localisation, profil handicap |
| OpenAI | Contenu de la requête vocale/textuelle | Nom, localisation, profil handicap |

Les requêtes sont transmises via HTTPS (chiffrement en transit). Les politiques de confidentialité des fournisseurs IA s'appliquent à ces données.

### 3.3 Données jamais collectées

Kita ne collecte **jamais** :
- Données de localisation précise transmises à des serveurs
- Identifiants publicitaires ou de tracking
- Données biométriques
- Données de navigation ou d'utilisation à des fins analytiques
- Listes de contacts ou données du répertoire

---

## 4. Données sensibles — Article 9 RGPD

Votre **profil d'accessibilité** (par exemple : aveugle, malvoyant, sourd, trouble cognitif) est une **donnée de santé au sens de l'Article 9 du RGPD**. Ces données sont classées comme données sensibles et bénéficient d'une protection renforcée :

- Stockées **exclusivement sur votre appareil**
- Chiffrées avec AES-256 (SQLCipher)
- Jamais transmises à des tiers
- Accessibles uniquement avec votre consentement explicite donné lors de l'onboarding
- Supprimables à tout moment via la fonctionnalité "Tout oublier"

La base légale pour ce traitement est votre **consentement explicite** (Art. 9.2.a RGPD).

---

## 5. Chiffrement et sécurité

### 5.1 Données au repos

Toutes les données stockées par Kita sont chiffrées avec **AES-256 via SQLCipher**, une bibliothèque de chiffrement open source reconnue. La clé de chiffrement est stockée dans le **Keychain iOS** ou le **Keystore Android**, des zones sécurisées matériellement isolées du reste du système.

### 5.2 Données en transit

Toutes les communications avec des services externes (providers IA) utilisent **HTTPS/TLS 1.3**. Aucune donnée n'est transmise en clair.

### 5.3 Clés API

Vos clés API personnelles (Claude, OpenAI) sont stockées dans le **Keychain iOS** ou le **Keystore Android**. Elles ne sont jamais transmises à des tiers, n'apparaissent jamais dans les logs, et ne sont jamais incluses dans les rapports d'erreur.

---

## 6. Droit à l'oubli — "Forget Everything"

Kita intègre une fonctionnalité native de **droit à l'oubli** accessible depuis les paramètres :

**Procédure in-app :**
1. Ouvrez les Paramètres
2. Sélectionnez "Confidentialité"
3. Appuyez sur "Tout oublier"
4. Confirmez la suppression

**Données supprimées :**
- Historique des interactions
- Profil utilisateur
- Préférences
- Données des plugins
- Données de consentement

**Délai :** La suppression est **immédiate et irréversible** pour les données locales. Les données déjà transmises aux providers IA lors de requêtes précédentes sont soumises aux politiques de rétention de ces fournisseurs.

**Demande de suppression externe :** Pour demander la suppression de données éventuellement détenues par des tiers, contactez privacy@kita.app. Nous vous accompagnerons dans les démarches auprès des fournisseurs concernés dans un délai de **30 jours**.

---

## 7. Vos droits RGPD

Conformément aux Articles 15 à 22 du RGPD, vous disposez des droits suivants :

| Droit | Description | Comment l'exercer |
|-------|-------------|-------------------|
| **Accès** (Art. 15) | Connaître les données traitées | Paramètres → "Mes données" |
| **Rectification** (Art. 16) | Corriger des données inexactes | Paramètres → Profil |
| **Effacement** (Art. 17) | Supprimer toutes vos données | Paramètres → "Tout oublier" |
| **Limitation** (Art. 18) | Restreindre certains traitements | Paramètres → Consentements |
| **Portabilité** (Art. 20) | Exporter vos données | À implémenter — contactez-nous |
| **Opposition** (Art. 21) | S'opposer à un traitement | Paramètres → Consentements |
| **Réclamation** | Saisir la CNIL | [www.cnil.fr](https://www.cnil.fr) |

**Contact pour exercer vos droits :** privacy@kita.app *(à configurer avant publication)*

---

## 8. Conservation des données

| Type de donnée | Durée de conservation |
|----------------|----------------------|
| Historique des interactions | Jusqu'à suppression par l'utilisateur (max. 90 jours par défaut) |
| Profil d'accessibilité | Jusqu'à suppression par l'utilisateur |
| Préférences | Jusqu'à désinstallation ou suppression |
| Consentements | Jusqu'à révocation explicite |

---

## 9. Modifications de la politique

Toute modification substantielle de cette politique sera notifiée via une notification in-app au moins **30 jours avant** son entrée en vigueur. Votre consentement sera re-demandé si les modifications affectent des données sensibles (Art. 9 RGPD).

---

## 10. Contact

**Email RGPD :** privacy@kita.app *(à configurer avant publication)*
**Autorité de contrôle :** Commission Nationale de l'Informatique et des Libertés (CNIL) — [www.cnil.fr](https://www.cnil.fr)

---

*Cette politique de confidentialité a été rédigée en français, langue de l'application. En cas de traduction, la version française fait foi.*
