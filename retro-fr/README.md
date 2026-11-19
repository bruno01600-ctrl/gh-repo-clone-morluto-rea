# Rétro FR

Une application Android pour jouer aux jeux de consoles rétro sur un téléphone, avec une interface
en français. Elle est indépendante de dumbtv : tout se trouve dans ce dossier.

L'application ne contient aucun jeu commercial. Vous ajoutez vos propres fichiers de jeu, comme des
copies de vos cartouches et CD ou des jeux gratuits distribués par leurs auteurs. Ils restent dans le
téléphone : rien n'est envoyé sur Internet.

## Consoles

| Marque | Consoles |
|---|---|
| Nintendo | NES, Super Nintendo, Nintendo 64, Game Boy / Color, Game Boy Advance, Nintendo DS, Virtual Boy |
| Sega | Master System, Mega Drive, Game Gear, 32X, Mega-CD |
| Sony | PlayStation |
| Autres | PC Engine, Neo Geo Pocket, WonderSwan, Atari Lynx, Atari 2600, Atari 7800 |

L'émulation est assurée par [EmulatorJS](https://emulatorjs.org) (GPL-3.0) et les cœurs libretro qu'il
fournit. Mega-CD et PlayStation peuvent demander un BIOS selon le jeu. Les autres consoles n'en ont pas besoin.

## Installer sur le téléphone

1. Sur GitHub, ouvrez l'onglet **Actions**, puis le workflow **retro-fr**, puis la dernière exécution
   réussie. Téléchargez l'artefact **retro-fr-apk**, qui est un .zip contenant `retro-fr.apk`.
2. Copiez `retro-fr.apk` sur le téléphone et ouvrez-le. Android demande d'autoriser l'installation
   d'applications de cette source (le navigateur ou le gestionnaire de fichiers) : acceptez.
3. Ouvrez **Rétro FR**, touchez **＋ Ajouter des jeux** et choisissez vos fichiers.

Il faut Android 7 ou plus récent. La Nintendo 64 et la Nintendo DS demandent un téléphone assez puissant.

## Utilisation

- La console est reconnue d'après l'extension du fichier (.nes, .sfc, .gba, .md…). Pour .zip, .bin,
  .iso ou .chd, l'application demande de quelle console il s'agit.
- Les trois points sous un jeu permettent de le renommer, de changer sa console ou de le supprimer.
- En jeu, une manette tactile s'affiche. Une manette Bluetooth fonctionne aussi. Le menu de
  l'émulateur permet de sauvegarder et de charger une partie à tout moment.
- Le bouton retour du téléphone ramène à la bibliothèque.

## Développer

```sh
./fetch-emulator.sh                  # télécharge EmulatorJS et ses cœurs depuis npm dans web/emulator/
python3 -m http.server -d web 8000   # puis http://localhost:8000 dans un navigateur
./android/build.sh                   # APK, avec un SDK Android (platforms;android-34, build-tools)
```

- `web/` contient l'application elle-même : HTML, CSS et JavaScript, sans dépendance ni étape de build.
- `android/` contient une WebView plein écran qui sert `web/` depuis les assets de l'APK.
- `web/emulator/` n'est pas versionné : `fetch-emulator.sh` le recrée.

Pour que chaque nouvelle version s'installe par-dessus l'ancienne, ajoutez au dépôt le secret
`RETROFR_KEYSTORE_B64`, qui contient une clé PKCS12 encodée en base64. Ajoutez aussi
`RETROFR_KEYPASS` si son mot de passe n'est pas `retrofr`. Sans ces secrets, chaque compilation
utilise une clé jetable, et il faut désinstaller l'ancienne version avant d'installer la nouvelle.
