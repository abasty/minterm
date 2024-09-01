# minterm

Un nouvel émulateur Minitel en Flutter & Dart.

## Moteur d'émulation

ACU

## Rendering

ACU

## Caractères

* Les jeux de caractères G0 et G2 sont générés au format PNG  depuis
  `Minitel.ttf` de [Frédéric Bisson](https://zigazou.dev/)
  ([git](https://github.com/Zigazou)). Certains caractères sont redessinés (`Ç`,
  barres verticales gauche et droite, barre haut, pavé plein). `ttf2minterm.py`
  utilise `PIL` (_Pillow_) pour construire l'image RGBA correspondante et la
  sauvegarder dans `g0g2.png`. Les 31 caractères du jeu G2 (caractères accentués
  et spéciaux) sont placés dans les 2 premières colones de l'image.

  ![Jeux G0 et G2](assets/g0g2.png)

* Le jeu de caractères G1 est généré depuis la fonte _bitmap_ `g18x10.bdf` de
  [Pierre Ficheux](http://pficheux.free.fr/) et de son émulateur
  [Xtel](http://pficheux.free.fr/xtel/). `xtel2minterm.py` utilise `bdfparser`
  et `PIL` (_Pillow_) pour construire l'image RGBA correspondante et la
  sauvegarder dans `g1.png`.

  ![Jeux G1](assets/g1.png)
