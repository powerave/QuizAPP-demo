# QuizAPP

Application de quiz Flutter avec salons multijoueurs.

> **Important : Brave n'affiche pas correctement le HTTPS local de cette démo.**
> Utilisez Firefox ou un autre navigateur pour accéder à l'application.

## Démarrage rapide

Prérequis : Docker, `mkcert` et `openssl`.

```bash
cp .env.example .env
./scripts/prepare-local-demo.sh
./scripts/ensure-local-certs.sh
docker compose up --build
```

`prepare-local-demo.sh` détecte l'adresse IP LAN du host et met à jour `.env`.
Il configure l'URL WebSocket, l'URL HTTPS et les origines autorisées sans
modifier les paramètres PostgreSQL ou Redis.

Depuis le host, ouvrez :

```text
https://localhost
```

Depuis un autre appareil du réseau, utilisez l'adresse `HOST_IP` affichée dans
`.env` :

```text
https://<HOST_IP>
```

Le certificat est généré pour `localhost`, `127.0.0.1`, `::1` et `HOST_IP`.
Sur les autres appareils, l'autorité locale `mkcert` doit être approuvée pour
que le navigateur accepte le HTTPS. Le dossier `certs/` est ignoré par Git.

## Données persistantes

PostgreSQL conserve les comptes, les statistiques et l'historique des parties
dans le volume Docker `quizapp_postgres`. Redis conserve les métadonnées des
salons dans `quizapp_redis`.

Les données sont conservées après un redémarrage de l'application ou des
conteneurs. Pour supprimer volontairement toutes les données :

```bash
docker compose down -v
```

## Fonctionnement réseau

- Nginx est le seul point d'entrée public et expose les ports `80` et `443`.
- Flutter utilise `wss://<HOST_IP>/ws` pour les WebSockets.
- L'authentification et le profil passent par `https://<HOST_IP>/auth` et
  `https://<HOST_IP>/profile`.
- Le serveur Dart, PostgreSQL et Redis restent internes au réseau Docker.

## Arrêt

```bash
docker compose down
```

Les volumes PostgreSQL et Redis ne sont pas supprimés par cette commande.
