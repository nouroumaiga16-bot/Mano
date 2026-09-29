# Mano

Application de gestion pour les petits commerçants du Burkina Faso :
stock, ventes et factures, fichier clients. Fonctionne 100 % hors ligne.
Montants en FCFA.

**Version de test (iPhone, Safari) : https://nouroumaiga16-bot.github.io/Mano/**

## Avancement

- [x] Étape 1 : module Stock (produits, prix, quantités, alerte stock bas, historique)
- [ ] Étape 2 : ventes et factures PDF (partage WhatsApp)
- [ ] Étape 3 : fichier clients et ventes à crédit
- [ ] Étape 4 : tableau de bord du jour
- [ ] Plus tard : synchronisation en ligne (Supabase)

## Organisation du code

| Dossier | Contenu |
|---|---|
| `lib/data/database.dart` | Base de données SQLite (tables et opérations) |
| `lib/stock/` | Écrans du module Stock |
| `lib/utils/format.dart` | Affichage des montants FCFA et des dates |
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
