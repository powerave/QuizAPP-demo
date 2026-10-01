# QuizAPP

Application mobile de quiz Flutter avec Riverpod.

## Démarrage HTTPS local avec Docker

 ##*****************************************************************  
 Utiliser un autre navigateur que BRAVE pour un affichage HTTPS (sur firefox ca fonctionne parfaitement)  
 ##*******************************************************************  

Docker Compose lance PostgreSQL, Redis, le serveur WebSocket, Flutter Web et un
proxy Nginx HTTPS :

```bash
./scripts/prepare-local-demo.sh
./scripts/ensure-local-certs.sh
docker compose up --build
```

`prepare-local-demo.sh` détecte l'IPv4 LAN active du host et met à jour dans
`.env` les URLs Flutter et l'origine autorisée. Il ne modifie pas les variables
PostgreSQL ou Redis. Ouvre ensuite `https://<IP_LAN_DU_HOST>` depuis les autres
appareils du réseau, ou `https://localhost` depuis le host.

`ensure-local-certs.sh` vérifie que le certificat contient bien l'IP détectée et
le régénère avec `mkcert` si nécessaire. Sur chaque appareil client, installe
ou approuve l'autorité locale mkcert; sans cette étape, le navigateur refusera
le certificat HTTPS même si l'adresse IP est correcte.
PostgreSQL est persistant dans le volume
`quizapp_postgres` pour les profils, les pseudos et l'historique des parties.
Redis reste persistant dans `quizapp_redis` pour les métadonnées temporaires des
salons et n'est pas exposé directement aux clients Flutter.

La configuration locale est documentée dans `.env.example`. Pour l'utiliser,
copie-la vers `.env` avant Compose :

```bash
cp .env.example .env
docker compose up --build
```

`.env` est ignoré par Git. `QUIZ_SERVER_URL` est injectée dans le build Flutter
Web ; elle doit rester une adresse visible depuis le navigateur, par exemple
`wss://localhost/ws`, et jamais `ws://server:8080`.

Le script `scripts/ensure-local-certs.sh` vérifie `certs/fullchain.pem` et
`certs/privkey.pem`. S'ils sont absents, ou si l'IP de `HOST_IP` manque dans
les SAN, il exige `mkcert` et génère un certificat pour `localhost`,
`127.0.0.1`, `::1` et l'IP LAN. Il ne remplace pas un certificat incomplet
sans erreur explicite. Le dossier `certs/` est ignoré par Git.

Le serveur refuse de démarrer si Redis ou PostgreSQL n'est pas disponible. Les
tables `profiles` et `game_history` sont créées automatiquement au démarrage.
L'application demande un nom d'utilisateur et un mot de passe avant l'accès
aux salons. Lors de la création d'un compte, le nom d'affichage est enregistré
et doit être unique globalement, sans distinction entre majuscules et
minuscules.

Le serveur expose aussi `GET /health` et `GET /profile`. Cette dernière route
recharge les statistiques PostgreSQL avec le token de session conservé dans le
navigateur. Les profils, compteurs et historiques restent persistants après
une reconnexion ou un rechargement de la page.

## Démarrage manuel du serveur multijoueur

Le serveur est l'autorité de la partie : il synchronise les questions, attend
les deux réponses et calcule les scores.

```bash
cd server
/home/powerave/flutter/bin/dart pub get
/home/powerave/flutter/bin/dart run bin/server.dart
```

Le mode manuel nécessite Redis sur `127.0.0.1:6379` et PostgreSQL sur
`127.0.0.1:5432`. Les variables `REDIS_HOST`, `REDIS_PORT`,
`REDIS_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`,
`POSTGRES_USER`, `POSTGRES_PASSWORD` et `PORT` peuvent être utilisées.

Le serveur Dart reste interne à Docker. Nginx relaie `/auth`, `/profile`,
`/health` et les WebSockets sur `/ws`; les ports directs du serveur et de
Flutter Web ne sont pas publiés.

## Démarrage de l'application

```bash
flutter pub get
flutter run
```

L'application Web utilise une navigation SPA avec les routes suivantes :

- `/` : accueil ;
- `/quiz` : salons disponibles ;
- `/quiz/create` : création d'un salon ;
- `/profile` : profil et historique ;
- `/entry` : création de compte ou connexion obligatoire.

Les changements de page sont inscrits dans l'historique du navigateur. Le
bouton précédent fonctionne donc entre l'accueil, le quiz, la création de
salon et le profil.

Dans l'écran d'accueil, chaque joueur se connecte avec son compte. Ensuite les
deux joueurs saisissent la même adresse serveur et le même code de salon. Pour
deux téléphones sur un réseau local, utilisez
l'adresse IP de la machine qui héberge le serveur, par exemple
`ws://192.168.1.20:8080`. 8081 pour se connecter au host

## Organisation

- `lib/app` : configuration et composition de l'application.
- `lib/core` : briques transversales (à compléter : thème, constantes, erreurs).
- `lib/features/quiz/data` : accès aux données et repositories.
- `lib/features/quiz/domain` : modèles et règles métier.
- `lib/features/quiz/presentation` : providers Riverpod, pages et widgets UI.
- `server/bin/server.dart` : serveur WebSocket multijoueur.
- `server/bin/profile_store.dart` : accès PostgreSQL aux profils, pseudos et historiques, Redis pour les salons.
- `docker-compose.yml` : PostgreSQL, Redis, serveur et client Web Flutter.
