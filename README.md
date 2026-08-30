# minterm

Encore un émulateur Minitel ! En Flutter & Dart.

📖 [Manuel d'utilisation](docs/EMULATOR-MANUAL-fr.md)

⚠️ Le mode **Téléinformatique (80 colonnes)** est expérimental : il reste à
confronter à un émulateur matériel ou à un vrai Minitel 1B pour valider son
comportement.

## Build/launch Linux en release

```
$ flutter build linux
$ build/linux/x64/release/bundle/minterm
```

L'icône de la fenêtre/barre des tâches est chargée automatiquement depuis
`build/linux/x64/release/bundle/data/icon.png` (voir `linux/my_application.cc`
et `linux/resources/icon.png`), aucune action supplémentaire n'est nécessaire.

Pour ajouter une entrée dans le menu des applications du bureau (Gnome, KDE,
etc.), il faut installer manuellement l'icône et le fichier `.desktop` :

```
$ cp linux/resources/icon.png ~/.local/share/icons/hicolor/512x512/apps/minterm.png
$ cp linux/resources/minterm.desktop ~/.local/share/applications/
```

Puis éditer `~/.local/share/applications/minterm.desktop` pour que `Exec=`
pointe vers le chemin réel du binaire (par exemple le chemin absolu de
`build/linux/x64/release/bundle/minterm`, ou un lien symbolique dans le
`PATH`).

## Build Android

Il faut que les options développeur et le mode _Debug USB_ soit activé sur le
_device_. Il apparait alors dans la liste avec `flutter devices`.

Pour téléphone et tablette arm64, on peut ne construire que l'APK approprié :

```
$ flutter build apk --split-per-abi
...
✓ Built build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk (7.3MB)
✓ Built build/app/outputs/flutter-apk/app-arm64-v8a-release.apk (7.8MB)
✓ Built build/app/outputs/flutter-apk/app-x86_64-release.apk (7.9MB)
```

On installe avec `flutter install`. On peut créer un lien vers le bon APK ou
utiliser `--use-application-binary` :

```
$ flutter install --use-application-binary=./build/app/outputs/apk/release/app-arm64-v8a-release.apk
Installing app-arm64-v8a-release.apk to ABR NX1...
Uninstalling old version...
Installing build/app/outputs/apk/release/app-arm64-v8a-release.apk...         5.6s
```

## Build/launch Web en local

```
$ flutter build web
$ cd build/web
$ python3 -m http.server 8000
```

Puis ouvrir <http://localhost:8000> dans le navigateur. Ne pas ouvrir
`index.html` directement (`file://`) : le chargement des assets échoue sans
serveur HTTP.

En web, seules les connexions WebSocket sont disponibles (pas de TCP direct
ni de port série), en clair (`ws://`) ou chiffrées (`wss://`).

⚠️ Si l'app web est servie en HTTPS (ex. GitHub Pages), le navigateur bloque
par sécurité (*mixed content*) toute connexion `ws://` non chiffrée : seuls
les serveurs exposant du `wss://` restent alors accessibles. La version
locale (`http://localhost`, voir ci-dessus) n'est pas concernée par cette
restriction.

## Bugs

* [x] **Série : Ajouter configuration par défaut (1200)**
* [x] **Série : mode 1200 et 4800 (comme sur minitel), du coup MinSettings au max**
* [x] Sortir de la ligne 0 sur \r\n (à vérifier sur Minitel)
* [ ] DRCS : certains dessins téléchargés s'affichent en carrés noirs — à
  fixer en comparant avec la séquence Vidéotex telle que téléchargée par le
  service 6212\*DRCS et le rendu obtenu sur une autre implémentation
  (émulateur hardware ou JS)
* [ ] DRCS : téléchargement de plusieurs glyphes en rafale (sans délai entre
  eux, contrairement à une vraie ligne série) peut faire courir les
  décodages d'image asynchrones et laisser l'atlas de police dans un état
  incohérent (voir `MinSettings.updateDrcsGlyph`)

## TODO

* [ ] En mode 80 cols, il faut supporter le jeu de caractère approprié
* [ ] Vitesse en mode web non respectée
* Penser à Ctrl+X pour CX/Fin
* [ ] Bug rendu des caractères disjoints (en x2.5 et x3.5 pas en x3 ou x4).
  Éventuellement voir code JS ici (clip avant de dessiner):
  <https://github.com/Zigazou/miedit/blob/fad284ce2b3a91fbf03d6aebcb94107f64de3bf3/library/minitel/font-sprite.js#L181>
* [ ] Bug scrolling up qui déborde sur ligne 0 en cas de caractères double
  hauteur (à voir ce que ça fait sur un vrai Minitel)
* [ ] Voir ce que font insl, dell, insc, delc en ligne 0 sur un M1B et corriger
  l'émulateur
* [ ] Support touches Ctrl + A-Z
* [ ] Connexion to Minitel (output)
* [ ] Ajouter BASTOS
* [ ] Mode vidéo inverse (bof, pour BASTOS / VP100)
* [ ] Implémenter clavier zx81 étendu
* [x] Répondre à demande vitesse (PRO1 74 (t))
* [x] Touches de direction : génère un ESC + 2 caractères ([Touches en mode
  clavier étendu](#touches-en-mode-clavier-%C3%A9tendu))
  * [x] Implémenter dans minterm (clavier virtuel et physique)
  * [x] Implémenter dans `os_get_key()`
  * [x] Touches Enter + Ctrl et Shift (CLS, HOME)
  * [x] Touche flèche gauche + Ctrl (DEL)
  * [x] En mode local (sans connexion à BASTOS) les touches de direction ne
    marchent pas dans l'émulateur : à voir comment ça fait sur un Minitel avec
    clavier en mode étendu => les touches de direction fonctionnent sans cx à
    BASTOS si clavier en mode étendu
  * [x] En mode clavier étendu (mode unique de l'émulateur), les touches doivent
    faire des déplacements attendus : Ajouter support à l'émulateur
  * [x] Touches de direction + Shift (SUPL: 1b5b4d, INSL: 1b5b4c, SUPC: 1b5b50)
  * [x] Support pour SUPL, INSL, SUPC : Même codes que les touches
  * [x] Touches de direction + Shift (INSC_ON: 1b5b3468, INSC_OFF: 1b5b346c)
    supporter au niveau de l'émulateur
* [x] LIST : il faut print les caractères graphiques et envoyer G0 / G1 à
  l'écran
* [x] Mode minuscules/majuscules : support au niveau proto dans l'émulateur
* [x] Émulation mode 80 colonnes et mode mixte
* [x] Implémenter blink et cursor blinking
* [x] Support ws et tcp
* [x] Clavier minitel 1b
* [x] Version Android
* [x] Ajouter websockets et services connus
* [x] `_MinPainter.drawChar()` : Utilise un `TMinitelChar`
* [x] `TMinitel.putChar()` : Traduire depuis la version assembleur
* [x] `_MinPainter.paint()` : Utilise un `TMinitel`, teste `kRedrawFlag` pour
  repeindre uniquement les caractères impactés

## Caractères

* Les jeux de caractères G0 et G2 sont générés au format PNG depuis
  `Minitel.ttf` de [Frédéric Bisson](https://zigazou.dev/)
  ([git](https://github.com/Zigazou)). Certains caractères sont redessinés (`Ç`,
  barres verticales gauche et droite, barre haut, pavé plein). `ttf2minterm.py`
  utilise `PIL` (_Pillow_) pour construire l'image RGBA correspondante et la
  sauvegarder dans `g0g2.png`. Les 31 caractères du jeu G2 (caractères accentués
  et spéciaux) sont placés dans les 2 premières colones de l'image.

  ![Jeux G0 et G2](assets/g0g2.png)

* Le jeu de caractères G1 est généré depuis la fonte _bitmap_ `g18x10.bdf` de
  [Pierre Ficheux](http://pficheux.free.fr/) et de son émulateur
  [Xtel](http://pficheux.free.fr/xtel/). Le caractère #0 est redéfinit comme le
  masque à appliquer pour les graphiques disjoints. `xtel2minterm.py` utilise
  `bdfparser` et `PIL` (_Pillow_) pour construire l'image RGBA correspondante et
  la sauvegarder dans `g1.png`.

  ![Jeux G1](assets/g1.png)

* Le Minitel supporte aussi les **caractères redéfinissables (DRCS)** :
  certains services téléchargent leurs propres glyphes 8×10 pour les jeux
  G'0/G'1 (désignation `ESC 2/8` / `ESC 2/9`), affichés dès leur réception
  sans action de l'utilisateur. Support récent, encore expérimental (voir
  [Bugs](#bugs)).

## Clavier

![alt text](clavier.png)

# Liens

* <https://fr.wikipedia.org/wiki/Micro-serveur_Minitel>
* <https://archive.org/details/minitel-stum1b/page/n39/mode/1up?view=theater>

# URLs

* 3611 : `ws:3611.re:80:/ws`
* 3615 : `wss://3615co.de/ws`
* hacker : `ws:mntl.joher.com:2018:/?echo`
* minipavi : `tcp:go.minipavi.fr:516`
* retrocampus : `tcp:bbs.retrocampus.com:1651`
