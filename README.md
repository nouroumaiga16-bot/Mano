# Mano

Application de gestion pour les petits commerçants du Burkina Faso :
stock, ventes et factures, fichier clients. Fonctionne 100 % hors ligne.
Montants en FCFA.

**Version de test (iPhone, Safari) : https://nouroumaiga16-bot.github.io/Mano/**

## Avancement

- [x] Étape 1 : module Stock (produits, prix, quantités, alerte stock bas, historique)
- [x] Étape 2 : ventes et factures PDF (partage WhatsApp), remises, 4 modes de paiement
- [x] Produits : couleur, taille, catégorie, photo ; téléphones affichés par paires
- [x] Étape 3 : fichier clients (téléphone, quartier, note), ventes à crédit, remboursements, rappel WhatsApp
- [x] Étape 4 : bilan du jour, du mois et de l'année (chiffre d'affaires, bénéfice, argent reçu, graphique, meilleurs produits)
- [ ] Plus tard : synchronisation en ligne (Supabase)

## Organisation du code

| Dossier | Contenu |
|---|---|
| `lib/data/database.dart` | Base de données SQLite (tables et opérations du stock) |
| `lib/data/sales_queries.dart` | Opérations des ventes et réglages |
| `lib/stock/` | Écrans du module Stock |
| `lib/sales/` | Ventes, panier, facture et PDF |
| `lib/settings/` | Informations de la boutique |
| `lib/customers/` | Fichier clients, dettes et remboursements |
| `lib/dashboard/` | Bilan et graphique |
| `lib/data/report_queries.dart` | Calculs du bilan |
| `lib/data/customers_queries.dart` | Opérations des clients et paiements |
| `lib/utils/format.dart` | Affichage des montants FCFA et des dates |
| `assets/fonts/` | Police Roboto pour les factures PDF (licence Apache 2.0) |
| `test/` | Tests automatiques |
| `web/` | Version web (test sur iPhone) : moteur SQLite, service worker hors ligne |
| `tool/build_web.sh` | Fabrique la version web |

## Commandes utiles

```bash
dart run build_runner build   # après une modification des tables
flutter test                  # lance les tests
tool/build_web.sh             # fabrique la version web dans build/web
flutter build apk             # fabrique l'app Android
```

La version web est publiée automatiquement sur GitHub Pages à chaque envoi
sur `main` (voir `.github/workflows/web.yml`).
