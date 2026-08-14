# Sudoku

Sudokus aléatoires **4×4 et 9×9**, affichés en **chiffres ou en couleurs** (changeable à tout moment, autant de fois qu'on veut).

Fonctionnalités de jeu : **timer**, **statistiques** (parties, réussite, meilleurs temps), **mode notes** (crayon avec nettoyage automatique), **bouton indice**, **animations de victoire** (confettis) et écran **« reprendre une partie »** multi-sauvegardes (la partie en cours est mise de côté automatiquement quand on en lance une autre).

- **`web/`** — Site React (Vite + TypeScript), **mobile-first**, trilingue **FR / ES / EN**, **PWA installable** (service worker, hors-ligne, icônes). **12 thèmes de fond** (dont 3 clairs) changeables à tout moment. La partie en cours et les préférences sont persistées en **localStorage** : le dyno Heroku peut redémarrer, rien n'est perdu côté joueur.
- **`backend/`** — API **Rust + Axum + SeaORM + SQLite** : génération de grilles (solution unique garantie) et sauvegarde des parties (iOS ou web). Sert aussi le build du site.
- **`ios/`** — Application **native iOS (SwiftUI)**, localisée FR / ES / EN, générateur embarqué + synchronisation avec l'API.

## API

| Méthode | Route | Description |
|---|---|---|
| `GET` | `/api/health` | État du serveur |
| `GET` | `/api/puzzle?size=4\|9&difficulty=easy\|medium\|hard` | Grille aléatoire (solution unique) |
| `POST` | `/api/games` | Créer / mettre à jour une sauvegarde (`{id?, device_id, size, difficulty, state}`) |
| `GET` | `/api/games?device_id=…` | Lister les sauvegardes d'un appareil |
| `GET` | `/api/games/:id` | Lire une sauvegarde |
| `DELETE` | `/api/games/:id?device_id=…` | Supprimer une sauvegarde |

## Développement local

```bash
# Backend (port 8080)
cargo run --release

# Web (port 5173, proxy /api -> 8080)
cd web && npm install && npm run dev
```

Tests du générateur : `cargo test`.

## Déploiement Heroku

Le buildpack Node compile le site React (`web/dist`), puis le buildpack Rust compile le serveur qui sert le tout (`Procfile`).

```bash
heroku create mon-sudoku
heroku buildpacks:add heroku/nodejs
heroku buildpacks:add emk/rust
git push heroku main
```

> ⚠️ Le système de fichiers d'un dyno est **éphémère** : le SQLite serveur est réinitialisé à chaque redémarrage. C'est assumé — le web s'appuie sur **localStorage** et l'app iOS sur **UserDefaults** ; la sauvegarde serveur n'est qu'un miroir best-effort (l'API régénère la ligne si elle a disparu).

## Application iOS

Le projet Xcode est généré avec [XcodeGen](https://github.com/yonaskolb/XcodeGen) :

```bash
cd ios
xcodegen generate
open Sudoku.xcodeproj
```

Pointez le client API vers votre app Heroku : variable d'environnement `SUDOKU_API_URL` dans le scheme Xcode, ou éditez `baseURL` dans `ios/Sudoku/Models/APIClient.swift`. Sans réseau, l'app génère les grilles en local.
