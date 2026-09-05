# Séquences standard Minitel

Transcription exhaustive des séquences de contrôle **standard** (normalisées
CNET/CCETT/Télétel : STUM 1, STUM 1B, STUM 2, STUM 10, STUM 12, STURM Réseau
Minitel, S.T.U.P.A.V., S.T.U.C.A.M., S.T.U.T.E.L.) du protocole
Vidéotex/Télétel, couvrant les deux modes gérés par Minterm — **Vidéotex 40
colonnes** et **Téléinformatique 80 colonnes** — ainsi que les protocoles
périphériques documentés par les mêmes sources (téléphonie, carte à mémoire,
réseau X25/PAD) pour référence complète.

Il sert de référence avant l'étude des séquences **non standard** (extensions
propriétaires, comportements spécifiques à certains services ou matériels).

Sources : <https://millevaches.hydraule.org/info/minitel/specs/index.htm>,
qui reprend elle-même deux compilations plus anciennes :
- « La norme Videotex » (Alexandre MONTARON, 1992, v1.02a) — <http://canal.chez.com/videotex.htm>
- « Table des codes de programmation du Minitel » (forum developpez.net)

Voir [Références](#références) pour le détail des documents CNET/CCETT
d'origine.

## Sommaire

- [Conventions de notation](#conventions-de-notation)
- [1. Codes de contrôle C0](#1-codes-de-contrôle-c0)
- [2. Codes US](#2-codes-us)
- [3. Séparateurs (SEP)](#3-séparateurs-sep)
- [4. ISO 2022, première partie (réseau, PAVI, messagerie)](#4-iso-2022-première-partie-réseau-pavi-messagerie)
- [5. ISO 2022, deuxième partie (adressage périphériques)](#5-iso-2022-deuxième-partie-adressage-périphériques)
- [6. Codes escape généraux](#6-codes-escape-généraux)
- [7. Attributs vidéotex (couleurs, effets)](#7-attributs-vidéotex-couleurs-effets)
- [8. Dispositifs auxiliaires](#8-dispositifs-auxiliaires)
- [9. Positionnement du curseur](#9-positionnement-du-curseur)
- [10. Jeu semi-graphique G1 (mosaïque)](#10-jeu-semi-graphique-g1-mosaïque)
- [11. Caractères spéciaux G2 (accents, symboles)](#11-caractères-spéciaux-g2-accents-symboles)
- [12. Téléchargement DRCS et numéros de téléphone](#12-téléchargement-drcs-et-numéros-de-téléphone)
- [13. Commandes protocole PRO1 / PRO2 / PRO3](#13-commandes-protocole-pro1--pro2--pro3)
- [14. Clavier](#14-clavier)
- [15. Matériel (prise péri-informatique)](#15-matériel-prise-péri-informatique)
- [16. Mode Téléinformatique 80 colonnes](#16-mode-téléinformatique-80-colonnes)
- [17. Codes TRANSPAC (PAD X.3)](#17-codes-transpac-pad-x3)
- [18. Lecteur de carte à mémoire (LECAM)](#18-lecteur-de-carte-à-mémoire-lecam)
- [Références](#références)

## Conventions de notation

- Les codes sont donnés en hexadécimal (parfois complétés du décimal quand la
  source le précise).
- `ESC` = `1B`, `CSI` = `ESC 5B` (`ESC [`), `SS2` = `19` (Ctrl-Y), `SS3` = `1D`
  (Ctrl-]), `SEP` = `13` (Ctrl-S), `US` = `1F` (Ctrl-_), `DLE` = `10`
  (Ctrl-P).
- `Pn`, `Ps`, `Pl`, `Pc` : paramètres numériques ANSI/ISO 6429 (nombre,
  sélecteur, ligne, colonne), codés en chiffres ASCII décimaux.
- Une valeur telle que `Pl+64` (ou `Pl+40` en hexadécimal) signifie « valeur
  ajoutée à `0x40` », méthode de codage systématique du Minitel pour
  transmettre un nombre sur un octet imprimable.
- Annotations de modèle : **M1** = Minitel 1, **M1B** = Minitel 1B,
  **M2** = Minitel 2, **M5** = Minitel 5, **M10/M10B** = Minitel 10/10B,
  **M12** = Minitel 12.

## 1. Codes de contrôle C0

Codes `00`-`1F`, valables en mode Vidéotex 40 colonnes.

| Code | Ctrl | Nom | Fonction |
|------|------|-----|----------|
| `00` | Ctrl-@ | NUL | Filtré. Caractère de bourrage. |
| `01` | Ctrl-A | SOH | Filtré. Début de ROM/RAM. |
| `02` | Ctrl-B | — | Filtré. |
| `03` | Ctrl-C | — | Filtré. |
| `04` | Ctrl-D | EOT | Filtré. Fin de ROM/RAM. |
| `05` | Ctrl-E | ENQ | Renvoie le contenu de la RAM 1 (M1). |
| `06` | Ctrl-F | — | Filtré. |
| `07` | Ctrl-G | BEL | Signal sonore (bip). |
| `08` | Ctrl-H | BS  | Curseur gauche. |
| `09` | Ctrl-I | HT  | Curseur droite (tabulation). |
| `0A` | Ctrl-J | LF  | Curseur bas. |
| `0B` | Ctrl-K | VT  | Curseur haut. |
| `0C` | Ctrl-L | FF  | Effacement écran + retour en position d'origine (Home). |
| `0D` | Ctrl-M | CR  | Retour chariot (colonne 1, même ligne). |
| `0E` | Ctrl-N | SO  | Bascule vers le jeu semi-graphique G1. |
| `0F` | Ctrl-O | SI  | Retour au jeu alphanumérique G0. |
| `10` | Ctrl-P | DLE | Filtré. Caractère de transparence (M10). |
| `11` | Ctrl-Q | Con | Curseur visible (allumé). |
| `12` | Ctrl-R | Rep | Répétition du dernier caractère : `12 (n+40)`, répète `n` fois (max. 64). |
| `13` | Ctrl-S | Sep | Filtre aussi le caractère suivant (préfixe touches/commandes — voir [§3](#3-séparateurs-sep)). |
| `14` | Ctrl-T | Coff | Curseur invisible (éteint). |
| `15` | Ctrl-U | NACK | Filtré. |
| `16` | Ctrl-V | SYN | Non documenté, idem `19` (Ctrl-Y). |
| `17` | Ctrl-W | — | Filtré. |
| `18` | Ctrl-X | CAN | Effacement jusqu'en fin de ligne. |
| `19` | Ctrl-Y | SS2 | Introduit un caractère du jeu G2 (accents, symboles) — voir [§11](#11-caractères-spéciaux-g2-accents-symboles). |
| `1A` | Ctrl-Z | SUB | Caractère d'erreur (`?` inversé si M1/M10, `DEL` sinon). |
| `1B` | Ctrl-[ | ESC | Introduit une séquence d'échappement. |
| `1C` | Ctrl-\\ | — | Filtré. |
| `1D` | Ctrl-] | SS3 | Filtre aussi le caractère suivant (M1B). |
| `1E` | Ctrl-^ | RS  | Home : curseur en ligne 1, colonne 1. |
| `1F` | Ctrl-_ | US  | Positionnement direct du curseur : `Pl+64 Pc+64`, ou `Pl` sur 2 chiffres — voir [§9](#9-positionnement-du-curseur). |

## 2. Codes US

Préfixe `US` (`1F`). Portée générale (au-delà du positionnement de base) :

| Code | Car. | Fonction |
|------|------|----------|
| `23` | `#` | Téléchargement des jeux DRCS (M2) |
| `30` | `0` | Positionnement du curseur en début de ligne |
| `31` | `1` | `US 31 3X 3Y` ⇒ curseur en ligne `XY` (décimal), colonne inchangée |
| `32` | `2` | Séquence obsolète, ne doit plus être utilisée |
| `3C` | `<` | Voir S.T.U.C.A.M. (lecteur de carte à mémoire, [§18](#18-lecteur-de-carte-à-mémoire-lecam)) |
| `3E` | `>` | Voir S.T.U.T.E.L. (protocole M12, ci-dessous) |
| `40`-`58` | `@`-`X` | `US XX+64 YY+64` ⇒ ligne `XX`, colonne `YY`. `58` est aussi utilisé en 80 colonnes pour l'accès à la ligne 0 |

### Téléchargement des jeux DRCS (M2)

```
US 23 20 20 20 42 49   en-tête de téléchargement du jeu G'0
US 23 20 20 20 43 49   en-tête de téléchargement du jeu G'1
US 23 YY 30 <14 octets> 30     télécharge le caractère YY et les suivants...
US XX YY                       sort du téléchargement, sauf accès ligne 0
```

### Éléments S.T.U.T.E.L. utilisés par le Minitel 12

```
US 3E 44 .. 0D                 Établissement d'association
US 3E 50 32 0D                 Acquittement T-Transfert positif
US 3E 50 33 0D                 Acquittement T-Transfert négatif
US 3E 50 37 0D                 Demande de répétition du message
US 3E 54 2F L TLV message 0D   Transfert de données
US 3E 39 0D                    Rupture d'association
```

## 3. Séparateurs (SEP)

Préfixe `SEP` (`13`, Ctrl-S). Émis par le clavier vers le serveur pour les
touches de fonction et les acquittements protocole.

| Séquence | Fonction | Modèle |
|----------|----------|--------|
| `SEP 11` (XON) | Demande de reprise du flux | M12 |
| `SEP 15` (NACK) | Demande d'arrêt du flux | M12 |
| `SEP 41` | Touche ENVOI | — |
| `SEP 42` | Touche RÉPÉTITION | — |
| `SEP 43` | Touche RETOUR | — |
| `SEP 44` | Touche GUIDE | — |
| `SEP 45` | Touche ANNULATION | — |
| `SEP 46` | Touche SOMMAIRE | — |
| `SEP 47` | Touche CORRECTION | — |
| `SEP 48` | Touche SUITE | — |
| `SEP 49` | Touche CONNEXION-FIN | — |
| `SEP 4A` | Demande de mise en route de la PCE (TS+RÉPÉTITION sur M1/M10) | — |
| `SEP 4B` | Demande d'arrêt de la PCE | — |
| `SEP 4C` | Demande de retournement du modem (1200→75 Bd) | — |
| `SEP 4D` | Demande de retournement inverse (75→1200 Bd) | — |
| `SEP 4E`-`4F` | *(réservé, non documenté)* | — |
| `SEP 50` | Changement d'état à la connexion | — |
| `SEP 51` | Changement de vitesse du modem | — |
| `SEP 52` | Connexion ou déconnexion d'un module téléphonique | — |
| `SEP 53` | Connexion ou déconnexion du modem | — |
| `SEP 54` | Changement d'état du fil PT | — |
| `SEP 55` | Connexion ou déconnexion de modules logiciels supplémentaires | — |
| `SEP 56` | Changement d'état du status mode de fonctionnement | — |
| `SEP 57` | Acquittement de la mise en transparence | — |
| `SEP 58` | Début et fin de retournement | — |
| `SEP 59` | Phase de connexion-déconnexion | — |
| `SEP 5A` | Changement d'état de la fonction MEM | M10 uniquement |
| `SEP 5B` | Changement d'état du courant de ligne | M10 |
| `SEP 5C` | Début et fin de recopie d'écran | M1B |
| `SEP 5D` | *(réservé)* | — |
| `SEP 5E` | Reset | M1B |
| `SEP 5F`-`60` | *(réservé)* | — |
| `SEP 61` | Touche CC (Coupure Calibrée) | M10 |
| `SEP 62` | Touche HP+ | M10 |
| `SEP 63` | Touche HP- | M10 |
| `SEP 64` | Touche BIS | M10 |
| `SEP 65` | Touche RT (Répertoire) | M10 |
| `SEP 66` | *(réservé)* | — |
| `SEP 67` | Touche Spéciale + MEM | M10 |
| `SEP 68` | Touche Spéciale + BIS | M10 |
| `SEP 69`-`6B` | *(réservé)* | — |
| `SEP 6C` | Détecteur de sonnerie intégré | M12 / M2 |
| `SEP 6D` | Acquittement status modem | M12 |
| `SEP 6E`-`6F` | *(réservé)* | — |
| `SEP 70` | Passage au mode Mixte | M1B |
| `SEP 71` | Passage au mode Videotex | M1B |
| `SEP 72` | Changement d'état de la veille | M12 / M2 |
| `SEP 73` | *(réservé)* | — |
| `SEP 74` | Inhibition de la réception STUTEL | M12 |

## 4. ISO 2022, première partie (réseau, PAVI, messagerie)

### Commandes utilisées par le PAVI (commande `30`)

```
ESC 20 2X 30       Invitation À Numéroter (IAN). X = numéro du groupe de taxation.
ESC 21 2X 2Y 30    XY = représentation décimale du niveau de taxation utilisé.
ESC 22 30          Indication d'échec de connexion.
```

### Commandes utilisées par la messagerie 40 colonnes (commande `31`)

| Séquence | Fonction |
|----------|----------|
| `ESC 20 20 31` | Début de message |
| `ESC 20 21 31` | Début du champ expéditeur |
| `ESC 20 22 31` | Début du champ nom |
| `ESC 20 23 31` | Début du champ numéro de téléphone |
| `ESC 20 24 31` | Début du champ destinataire |
| `ESC 20 25 31` | Début du champ objet |
| `ESC 20 26 31` | Début du champ corps |
| `ESC 21 20 31` | Fin de message ou de champ |

### Mode compatible PAD-X3 (commandes `34` à `37`)

En mode compatible PAD-X3, toute séquence `SEP XY` devient `ESC 2Y 3X 0D`
(sauf pour `Y=5`, qui devient `F`).

Exemples : `SEP 41` (ENVOI) devient `ESC 21 34` ; `SEP 53` (acquittement)
devient `ESC 23 35` ; `SEP 65` (touche Minitel 10) devient `ESC 2F 36` ;
`SEP 70` devient `ESC 20 37`.

### Commandes utilisées par le réseau Minitel (commandes `38` à `3C`)

| Séquence | Sigle | Fonction |
|----------|-------|----------|
| `ESC A 38` `[CR]` | DC | Demande de Connexion |
| `ESC 2F 38` `[CR]` | DID | Demande d'IDentification |
| `ESC A 39 CR` | AC | Acquittement de Connexion |
| `ESC A 3A` `[CR]` | ILC | Indication de Libération de Connexion |
| `ESC 2F 3A` `[CR]` | ILC générale | Indication de Libération de Connexion (générale) |
| `ESC A 3B` | J | Jeton |
| `ESC 2F 3B` | DLC | Demande de Libération de Connexion |
| `ESC 20 p 3C` `[CR]` | — | Demande de Modification des Caractéristiques de Transmission |
| `ESC 21 3C` `[CR]` | DT | Début de Transparence (DMCT) |
| `ESC 22 P 3C` `[CR]` | CDG | Commande de Déconnexion Générale |
| `ESC 23 A 3C` `[CR]` | IRD | Indication de Ressource Disponible |
| `ESC 24 A 3C` `[CR]` | IRND | Indication de Ressource Non-Disponible |
| `ESC 28 3C` `[CR]` | FT | Fin de Transparence |

### Commandes du système d'échange utilisées par les Minitel 1B

```
ESC 21 38            Demande d'identification d'une imprimante.
ESC 21 2D 38         Demande d'identification d'une imprimante et du bout de chaîne.
ESC 2D 21 2C 26 38   Idem pour Minitel 12 et 2.
ESC 2D 3A            Indication de Libération de Connexion du bout de chaîne.
ESC 21 3A            Indication de Libération de Connexion d'une imprimante.
ESC 2F 3B            Demande de Libération de Connexion.
```

## 5. ISO 2022, deuxième partie (adressage périphériques)

### Codes d'adressage

| Code | Car. | Périphérique |
|------|------|--------------|
| `20` | ` ` | Écran vidéotex |
| `21` | `!` | Imprimante |
| `22` | `"` | Lecteur de cassettes |
| `23` | `#` | Lecteur de cartes |
| `24` | `$` | Numéroteur |
| `25` | `%` | Interdit (indique le sous-adressage) |
| `26` | `&` | Vidéodisque |
| `27` | `'` | Calculateur domestique ou personnel |
| `28` | `(` | Clavier auxiliaire |
| `29` | `)` | Adaptateur pour handicapés |
| `2A` | `*` | Coffret d'adaptation vidéotex pour réseau RV1G |
| `2B` | `+` | Lecteur de codes barre |
| `2C` | `,` | Réservé pour extensions |
| `2D` | `-` | Périphérique en bout de chaîne |
| `2E` | `.` | Base de données distante |
| `2F` | `/` | Tous les périphériques |

Adressages combinés : `20 2C 21` (Messagerie 40), `21 2C 26` (Imprimante...).

### Paramètres pour la CDG (Commande de Déconnexion Générale)

| Code | Car. | Signification |
|------|------|----------------|
| `20` | ` ` | Déconnexion de service par le serveur |
| `21` | `!` | Déconnexion de service par l'usager |
| `22` | `"` | Déconnexion sur incident TRANSPAC |
| `2F` | `/` | Défaillance application |

### Codage des C0 en transparence

`DLE` suivi du C0 dont le bit 6 est forcé à 1.

## 6. Codes escape généraux

| Séquence | Fonction |
|----------|----------|
| `ESC 23 20 58` | Masquage plein écran |
| `ESC 23 20 5F` | Démasquage plein écran |
| `ESC 23 21 XX` | Filtré. Attributs pleine rangée (`3F<XX<60`) |
| `ESC 25` | Transparence écran |
| `ESC 25 40` | Fin de transparence écran, M1B — **à ne pas utiliser** |
| `ESC 28 40` | G0 : jeu de base alphanumérique (M2) |
| `ESC 28 20 42` | G'0 : jeu DRCS alphanumérique (M2) |
| `ESC 29 63` | G1 : jeu de base semi-graphique (M2) |
| `ESC 29 20 43` | G'1 : jeu DRCS semi-graphique (M2) |
| `ESC 2X YY` (8≤X≤F, 30≤YY≤7F) | Fin de transparence écran, M1 |
| `ESC 2F 3F` | Fin de transparence écran, M1B — **à utiliser** |
| `ESC 35 da` | Filtré. Mise en route d'un dispositif auxiliaire — voir [§8](#8-dispositifs-auxiliaires) |
| `ESC 36 da` | Filtré. Arrêt d'un dispositif auxiliaire |
| `ESC 37 da` | Filtré. Mise en attente d'un dispositif auxiliaire |
| `ESC 39` `XX` | Commande protocole à un argument (PRO1) |
| `ESC 3A` `XX XX` | Commande protocole à deux arguments (PRO2) |
| `ESC 3B` `XX XX XX` | Commande protocole à trois arguments (PRO3) |
| `ESC 61` | Demande de position du curseur (réponse : `US Pl+64 Pc+64`) |

## 7. Attributs vidéotex (couleurs, effets)

Séquences `ESC` + un octet, applicables au caractère suivant sur la ligne
courante (un attribut ne peut être posé qu'en début de mot, jamais en milieu
de mot affiché).

| Fonction | Hex | Déc. | Car. | | Fonction | Hex | Déc. | Car. |
|---|---|---|---|-|---|---|---|---|
| Caractère noir | `1B 40` | 27 64 | `ESC @` | | Fond noir | `1B 50` | 27 80 | `ESC P` |
| Caractère rouge | `1B 41` | 27 65 | `ESC A` | | Fond rouge | `1B 51` | 27 81 | `ESC Q` |
| Caractère vert | `1B 42` | 27 66 | `ESC B` | | Fond vert | `1B 52` | 27 82 | `ESC R` |
| Caractère jaune | `1B 43` | 27 67 | `ESC C` | | Fond jaune | `1B 53` | 27 83 | `ESC S` |
| Caractère bleu | `1B 44` | 27 68 | `ESC D` | | Fond bleu | `1B 54` | 27 84 | `ESC T` |
| Caractère magenta | `1B 45` | 27 69 | `ESC E` | | Fond magenta | `1B 55` | 27 85 | `ESC U` |
| Caractère cyan | `1B 46` | 27 70 | `ESC F` | | Fond cyan | `1B 56` | 27 86 | `ESC V` |
| Caractère blanc | `1B 47` | 27 71 | `ESC G` | | Fond blanc | `1B 57` | 27 87 | `ESC W` |
| Clignotement | `1B 48` | 27 72 | `ESC H` | | Fixe | `1B 49` | 27 73 | `ESC I` |
| Début d'incrustation | `1B 4B` | 27 75 | `ESC K` | | Fin d'incrustation | `1B 4A` | 27 74 | `ESC J` |
| Taille normale | `1B 4C` | 27 76 | `ESC L` | | Double hauteur | `1B 4D` | 27 77 | `ESC M` |
| Double largeur | `1B 4E` | 27 78 | `ESC N` | | Double taille (hauteur+largeur) | `1B 4F` | 27 79 | `ESC O` |
| Début de masquage | `1B 58` | 27 88 | `ESC X` | | Fin de masquage | `1B 5F` | 27 95 | `ESC _` |
| Début de soulignement (\*) | `1B 5A` | 27 90 | `ESC Z` | | Fin de soulignement | `1B 59` | 27 89 | `ESC Y` |
| Vidéo inverse | `1B 5D` | 27 93 | `ESC ]` | | Vidéo normale | `1B 5C` | 27 92 | `ESC \` |
| Fond transparent | `1B 5E` | 27 94 | `ESC ^` | | | | | |

\* En semi-graphique (G1), « début de soulignement » bascule les motifs
mosaïques vers le rendu disjoint — voir [§10](#10-jeu-semi-graphique-g1-mosaïque).

## 8. Dispositifs auxiliaires

Codes utilisés en second argument des commandes `ESC 35/36/37` (mise en
route / arrêt / mise en attente).

| Code | Car. | Dispositif | Référence |
|------|------|------------|-----------|
| `40` | @ | Recopie d'écran | `ESC 35 40` : recopie d'écran des M1B |
| `41` | A | Dispositif d'enregistrement | — |
| `42` | B | Roll Up | — |
| `43` | C | Roll Down | — |
| `4D` | M | Invitation À Numéroter (IAN) | `ESC 35 4D` : codage officiel de l'IAN |
| `4E` | N | *(non documenté)* | — |
| `4F` | O | *(usage interne)* | `ESC 36 4F` : pour les besoins internes de l'administration |

## 9. Positionnement du curseur

| Séquence | Fonction |
|----------|----------|
| `RS` (`1E`) | Curseur en ligne 1, colonne 1 (Home) |
| `US 30` | Curseur en début de la ligne courante |
| `US 31 3X 3Y` (1) | Positionne le curseur en ligne `XY` (décimal), colonne inchangée |
| `US Pl+64 Pc+64` | Positionnement direct : ligne `Pl` (1-24), colonne `Pc` (1-40) |
| `US 40+64 Pc` (@) | Positionnement sur la ligne 0 (ligne d'état), colonne `Pc` (0<Pc<64) |
| `ESC 61` | Demande de la position du curseur — réponse : `US Pl+64 Pc+64` |

## 10. Jeu semi-graphique G1 (mosaïque)

Basculement de jeu : `SO` (`0E`) passe en G1, `SI` (`0F`) revient en G0.

Le G1 définit **64 motifs mosaïques** distincts, chacun formé de 6 points
disposés en 2 colonnes × 3 rangées :

```
Disposition et poids binaire des points :
 1 (poids 1)   4 (poids 2)
 2 (poids 4)   5 (poids 8)
 3 (poids 16)  6 (poids 32)
```

L'indice « Graphique » (0-63) d'un motif est la somme des poids des points
allumés, obtenu à partir du code comme suit :

| Plage ASCII | Indices Graphique | Formule |
|---|---|---|
| `20`-`3F` (32-63 déc.) | 0-31 | indice Graphique = code − `20` |
| `60`-`7F` (96-127 déc.) | 32-63 | indice Graphique = code − `40` |

Les caractères semi-graphiques (G1) de code `40` à `5F` reproduisent ceux de
`60` à `7F`.

Le rendu « jointif » (dessins accolés) ou « disjoint » (dessins avec un
espace autour de chaque point) ne dépend pas du code : il est introduit par
l'attribut de soulignement — `ESC Z` (début de soulignement) affiche les
motifs disjoints, `ESC Y` (fin de soulignement) les affiche jointifs.

### Table des 64 motifs

Chaque motif est représenté ci-dessous par ses 6 points dans l'ordre
haut-gauche, haut-droit, milieu-gauche, milieu-droit, bas-gauche, bas-droit
(`█` = point allumé, `·` = point éteint).

| Idx | Motif | Code |  | Motif | Code |  | Motif | Code |  | Motif | Code |
|---|---|---|-|---|---|-|---|---|-|---|---|
| 0..3 | `··`<br>`··`<br>`··` | `20` |  | `█·`<br>`··`<br>`··` | `21` |  | `·█`<br>`··`<br>`··` | `22` |  | `██`<br>`··`<br>`··` | `23` |
| 4..7 | `··`<br>`█·`<br>`··` | `24` |  | `█·`<br>`█·`<br>`··` | `25` |  | `·█`<br>`█·`<br>`··` | `26` |  | `██`<br>`█·`<br>`··` | `27` |
| 8..11 | `··`<br>`·█`<br>`··` | `28` |  | `█·`<br>`·█`<br>`··` | `29` |  | `·█`<br>`·█`<br>`··` | `2A` |  | `██`<br>`·█`<br>`··` | `2B` |
| 12..15 | `··`<br>`██`<br>`··` | `2C` |  | `█·`<br>`██`<br>`··` | `2D` |  | `·█`<br>`██`<br>`··` | `2E` |  | `██`<br>`██`<br>`··` | `2F` |
| 16..19 | `··`<br>`··`<br>`█·` | `30` |  | `█·`<br>`··`<br>`█·` | `31` |  | `·█`<br>`··`<br>`█·` | `32` |  | `██`<br>`··`<br>`█·` | `33` |
| 20..23 | `··`<br>`█·`<br>`█·` | `34` |  | `█·`<br>`█·`<br>`█·` | `35` |  | `·█`<br>`█·`<br>`█·` | `36` |  | `██`<br>`█·`<br>`█·` | `37` |
| 24..27 | `··`<br>`·█`<br>`█·` | `38` |  | `█·`<br>`·█`<br>`█·` | `39` |  | `·█`<br>`·█`<br>`█·` | `3A` |  | `██`<br>`·█`<br>`█·` | `3B` |
| 28..31 | `··`<br>`██`<br>`█·` | `3C` |  | `█·`<br>`██`<br>`█·` | `3D` |  | `·█`<br>`██`<br>`█·` | `3E` |  | `██`<br>`██`<br>`█·` | `3F` |
| 32..35 | `··`<br>`··`<br>`·█` | `60` |  | `█·`<br>`··`<br>`·█` | `61` |  | `·█`<br>`··`<br>`·█` | `62` |  | `██`<br>`··`<br>`█·` | `63` |
| 36..39 | `··`<br>`█·`<br>`·█` | `64` |  | `█·`<br>`█·`<br>`·█` | `65` |  | `·█`<br>`█·`<br>`·█` | `66` |  | `██`<br>`█·`<br>`·█` | `67` |
| 40..43 | `··`<br>`·█`<br>`·█` | `68` |  | `█·`<br>`·█`<br>`·█` | `69` |  | `·█`<br>`·█`<br>`·█` | `6A` |  | `██`<br>`·█`<br>`·█` | `6B` |
| 44..47 | `··`<br>`██`<br>`·█` | `6C` |  | `█·`<br>`██`<br>`·█` | `6D` |  | `·█`<br>`██`<br>`·█` | `6E` |  | `██`<br>`██`<br>`·█` | `6F` |
| 48..51 | `··`<br>`··`<br>`██` | `70` |  | `█·`<br>`··`<br>`██` | `71` |  | `·█`<br>`··`<br>`██` | `72` |  | `██`<br>`··`<br>`██` | `73` |
| 52..55 | `··`<br>`█·`<br>`██` | `74` |  | `█·`<br>`█·`<br>`██` | `75` |  | `·█`<br>`█·`<br>`██` | `76` |  | `██`<br>`█·`<br>`██` | `77` |
| 56..59 | `··`<br>`·█`<br>`██` | `78` |  | `█·`<br>`·█`<br>`██` | `79` |  | `·█`<br>`·█`<br>`██` | `7A` |  | `██`<br>`·█`<br>`██` | `7B` |
| 60..63 | `··`<br>`██`<br>`██` | `7C` |  | `█·`<br>`██`<br>`██` | `7D` |  | `·█`<br>`██`<br>`██` | `7E` |  | `██`<br>`██`<br>`██` | `7F` |

Les caractères semi-graphiques (G1) de code `40` à `5F` reproduisent ceux de
`60` à `7F`.

## 11. Caractères spéciaux G2 (accents, symboles)

Précédés par `SS2` (`19`) — valables pour un seul caractère, sans changer le
jeu courant (G0 ou G1).

| Fonction | Hex | Déc. | Car. | | Fonction | Hex | Déc. | Car. |
|---|---|---|---|-|---|---|---|---|
| Accents (préfixe) | `19` | 25 | `^Y` | | Accent circonflexe | `19 43` | 25 67 | `^Y C` |
| Livre (£) | `19 23` | 25 35 | `^Y #` | | Tréma | `19 48` | 25 72 | `^Y H` |
| Paragraphe (§) | `19 27` | 25 39 | `^Y '` | | Œ majuscule | `19 6A` | 25 106 | `^Y j` |
| Flèche gauche | `19 2C` | 25 44 | `^Y ,` | | œ minuscule | `19 7A` | 25 122 | `^Y z` |
| Flèche haute | `19 2D` | 25 45 | `^Y -` | | β (bêta) | `19 7B` | 25 123 | `^Y {` |
| Flèche droite | `19 2E` | 25 46 | `^Y .` | | Accent grave (\`) | `19 41` | 25 65 | `^Y A` |
| Flèche basse | `19 2F` | 25 47 | `^Y /` | | Accent aigu (´) | `19 42` | 25 66 | `^Y B` |
| Rond (°) | `19 30` | 25 48 | `^Y 0` | | Quart (¼) | `19 3C` | 25 60 | `^Y <` |
| Plus/moins (±) | `19 31` | 25 49 | `^Y 1` | | Demi (½) | `19 3D` | 25 61 | `^Y =` |
| | | | | | Trois quarts (¾) | `19 3E` | 25 62 | `^Y >` |

Les lettres accentuées s'obtiennent en enchaînant `SS2` + accent, suivi de la
lettre nue (ex. `SS2 42 65` = é).

## 12. Téléchargement DRCS et numéros de téléphone

### DRCS (jeux de caractères redéfinissables, M2)

Voir [§2](#2-codes-us) pour les séquences complètes de téléchargement.
Sélection du jeu chargé à la place du jeu standard :

| Séquence | Fonction |
|----------|----------|
| `ESC 28 20 42` | Sélectionne G'0 (DRCS alphanumérique) comme jeu G0 |
| `ESC 29 20 43` | Sélectionne G'1 (DRCS semi-graphique) comme jeu G1 |
| `ESC 28 40` | Revient au jeu G0 standard |
| `ESC 29 63` | Revient au jeu G1 standard |

### Téléchargement d'un numéro de téléphone (Minitel 10)

```
DLE SOH <index 2 chiffres> DLE EOT <libellé libre, ex. le nom>
DLE STX <numéro avec indicatif entre parenthèses> DLE ETX
```
soit en hexadécimal : `10 01 <index> 10 04 <nom>` puis `10 02 <numéro> 10 03`.

- Minitel 2 : pas d'index, un seul numéro téléchargeable.
- Minitel 10/10B/12 : 14 numéros téléchargeables.

## 13. Commandes protocole PRO1 / PRO2 / PRO3

Préfixes : PRO1 = `ESC 39`, PRO2 = `ESC 3A`, PRO3 = `ESC 3B`.

### Liste complète des commandes

| # | Séquence | Fonction | Modèle |
|---|----------|----------|--------|
| — | `PRO1 50` | Numérotation du dernier numéro (BIS) | M10 |
| — | `PRO3 51` `3x 3y` | Numérotation à partir du répertoire | M2 Philips |
| — | `PRO3 52` `3x 3y` | Numérotation à partir de l'écran | M2/M10 |
| — | `PRO1 53` | Prise de ligne | M2/M10 |
| — | `PRO1 54` | Commutation données-phonie | M10 |
| — | `PRO2 55` `N` | Commutation données-phonie pendant N × 2 s | M10 |
| — | `PRO2 56` `N` | Idem, en mode opposé | M12 |
| — | `PRO1 57` | Libération de ligne | M2/M10 |
| — | `PRO1 58` | Coupure Calibrée | M10 |
| — | `PRO1 59` | Effacement mémoire tampon (14 derniers n° tél.) | M10 |
| — | `PRO1 5A` | Demande de status téléphonique | M2/M10 |
| — | `PRO2 5B` `st` | Réponse à la demande de status téléphonique | M2/M10 |
| 1 | `PRO3 60` `cr, ce` | Arrêt d'aiguillage (OFF) | — |
| 1b | `PRO1 60` | Demande d'activation de la PCE | M12 |
| 2 | `PRO3 61` `cr, ce` | Aiguillage (ON) | — |
| 2b | `PRO1 61` | Demande d'arrêt de la PCE | M12 |
| 3 | `PRO2 62` `cr/ce` | Demande de status d'un module (TO) | — |
| 3b | `PRO1 62` | Passage en mode répondeur | M12 |
| 4 | `PRO3 63` `cr/ce, s` | Réponse à une demande de status ou acquittement | — |
| 4b | `PRO1 63` | Inhibition de la réception STUTEL | M12 |
| 5 | `PRO2 64` `cr` | Diffusion restreinte des acquittements protocole | — |
| 5b | `PRO2 64` `ce` | Acquittement non renvoyé | M1B |
| 6 | `PRO2 65` `cr` | Diffusion systématique des acquittements protocole | — |
| 6b | `PRO2 65` `ce` | Acquittement renvoyé | M1B |
| 7 | `PRO2 66` `x` | Mise en transparence du protocole (`0<x<128`) | — |
| 8 | `PRO1 67` | Déconnexion physique du modem | — |
| 9 | `PRO1 68` | Assure la connexion du modem | — |
| 10 | `PRO2 69` `mf` | Mise en route d'une fonction particulière du terminal | — |
| 10b | `PRO3 69` `cr, cmd` | Idem, pour un module | M2/M1B/M12 |
| 11 | `PRO2 6A` `mf` | Arrêt d'une fonction particulière du terminal | — |
| 11b | `PRO3 6A` `cr, cmd` | Idem, pour un module | M2/M1B/M12 |
| 12 | `PRO2 6B` `pv` | Programmation des vitesses par périphérique | — |
| 13 | `PRO1 6C` | Retournement du modem | — |
| 14 | `PRO1 6D` | Retournement inverse du modem | — |
| 15 | `PRO1 6E` | Acquittement de retournement | — |
| 16 | `PRO1 6F` | Retournement pour l'opposabilité | — |
| 17 | `PRO2 6F` `31` | Passage du mode opposé à esclave (OPPORE) | — |
| 18 | `PRO1 70` | Demande de status terminal | — |
| 19 | `PRO2 71` `st` | Réponse à la demande de status terminal | — |
| 20 | `PRO1 72` | Demande de status fonctionnement | — |
| 20b | `PRO2 72` `cr` | Demande de status d'un module | M2/M1B/M12 |
| 21 | `PRO2 73` `sf` | Réponse à la demande de status fonctionnement | — |
| 21b | `PRO3 73` `cr, sx` | Réponse à la demande de status d'un module | M2/M1B/M12 |
| 22 | `PRO1 74` | Demande de status vitesse | — |
| 23 | `PRO2 75` `sv` | Réponse à la demande de status vitesse | — |
| 24 | `PRO1 76` | Demande de status protocole | — |
| 25 | `PRO2 77` `sp` | Réponse à la demande de status protocole | — |
| 26 | `PRO1 78` `01 .. 04` | Téléchargement RAM 1 (chaîne encadrée par Ctrl-A/Ctrl-D) | M1 |
| 27 | `PRO1 79` `01 .. 04` | Téléchargement RAM 2 | M1 |
| 28 | `PRO1 7A` | Lecture RAM 2 | M1 |
| 29 | `PRO1 7B` | Lecture ROM (identification du terminal) | — |
| 30 | `PRO2 7C` `si` | Commande de copie d'écran | M1B |
| 31 | `PRO2 31` `7D` | Passage en Téléinformatique | M1B |
| 32 | `PRO2 32` `7D` | Passage du mode Videotex à Mixte | M1B |
| 33 | `PRO2 32` `7E` | Passage du mode Mixte à Videotex | M1B |
| 34 | `PRO1 7F` (DEL) | Réinitialisation en Videotex | M1B |

Pour écrire dans une RAM du Minitel (\*\*\*) : téléchargement suivi de `01`
puis le texte (14 caractères max.) puis `04`. Si le texte ne commence pas par
`01`, la RAM est considérée comme vide lors d'une demande d'identification.
Si le texte dépasse 14 caractères, le `04` n'est pas renvoyé.

### Codage des modules (émission `ce` / réception `cr`)

| Module | ce (émission) | cr (réception) |
|--------|:---:|:---:|
| Écran | `50` | `58` |
| Clavier | `51` | `59` |
| Modem | `52` | `5A` |
| Prise | `53` | `5B` |
| Poste (téléphonique) | `54` | `5C` — Minitel 10 |
| Logiciel | `55` | `5D` |

### Status aiguillage

```
Bit:  7  6  5    4      3      2      1       0
      P  1  -  Poste  Prise  Modem  Clavier  Écran
```
Pour chaque module : `1` = liaison établie, `0` = liaison coupée.

### Codes de fonction (`mf`), modules (`cr`) et commandes (`cmd`)

| `mf` | Fonction terminal | | `cr` | Module | `cmd` | Commande | Modèle |
|---|---|-|---|---|---|---|---|
| `43` | Mode rouleau/page | | `58` | Écran | `41` | Veille | New M2 |
| `44` | Procédure de correction d'erreur (PCE) | | `59` | Clavier | `41` | Mode étendu | M1B |
| `45` | Mode enseignement (clavier minuscules) | | | | `43` | C0 (ou CSI) | M1B |
| `46` | Mode loupe haut (M1/M10) | | `5A` | Modem | `41` | Gestion de flux | M12 |
| `47` | Mode loupe bas (M1/M10) | | | | `42` | Signature auto. | M12 |

### Programmation / status vitesse (prise)

```
Bit:  7  6  5   4   3   2   1   0
      P  1  E2  E1  E0  R2  R1  R0
```
`R` : vitesse de réception (3 bits). `E` : vitesse d'émission (3 bits).

| Valeur | Vitesse |
|---|---|
| `001` | 75 Bd (M1 Telic non retournable) |
| `010` | 300 Bd |
| `100` | 1200 Bd |
| `110` | 4800 Bd (M1B) |
| `111` | 9600 Bd (M2) |

### Status terminal

```
Bit:  7  6  5   4   3   2   1   0
      P  1  0   PT  DP  MT  VM  EC
```
- `EC` : état du terminal à la connexion (1 = opposé).
- `VM` : vitesse modem (1 = 1200 Bd, sens base de données → terminal).
- `MT` : module téléphonique présent (M10/M10B/M12/M2).
- `DP` : détection de porteuse (1 = connecté).
- `PT` : état du fil PT sur la prise (1 = session active).

### Status fonctionnement

```
Bit:  7  6  5   4   3   2   1  0
      P  1  L1  L2  ME  PC  RL F
```
- `F` : format d'écran (1 = 80 colonnes), M1B.
- `RL` : mode rouleau (1 = actif).
- `PC` : PCE (1 = actif).
- `ME` : mode enseignement (1 = actif).
- `L` : position de la loupe (2 bits, M1/M10) — `00` pas de loupe, `01` loupe haute, `10` loupe basse.

### Status protocole

```
Bit:  7  6  5    4   3   2   1   0
      P  1  0   PAD  A2  A1  D2  D1
```
- `D1` : 0 si les acquittements sont diffusés vers le modem.
- `D2` : 0 si les acquittements sont diffusés vers la prise.
- `A1`/`A2` (M1B) : 1 si modem/prise en mode non retour d'acquittement.
- `PAD` : 1 si la compatibilité PAD-X3 est active.

### Status téléphonique (Minitel 10)

```
Bit:  7  6  5     4    3     2    1    0
      P  1  0   FMEM  DCL  Num. Com.  RPL
```
- `RPL` : état du Relais Prise de Ligne (0 = ouvert).
- `Com.` : état du combiné (0 = raccroché).
- `Num.` : numérotation décimale/multifréquence (0 = décimale).
- `DCL` : détection de courant de ligne (0 = absence).
- `FMEM` : fonction MEM (0 = inactive), M10.

### Standard d'impression (Minitel 1B)

| Code | Jeu |
|------|-----|
| `6A` | Français |
| `6B` | Américain |

### Status clavier (Minitel 1B)

```
Bit:  7  6  5  4  3  2   1  0
      P  1  0  0  0  C0  0  Eten.
```
- `Eten.` : mode étendu (1 = actif).
- `C0` : codage en jeu C0 des touches de gestion du curseur (1 = actif).

### Status modem (Minitel 12 et 2)

```
Bit:  7  6  5  4  3  2   1     0
      P  1  0  0  0  AA  FLUX  PCE
```
- `PCE` : procédure de correction d'erreur en émission (1 = active), M12.
- `FLUX` : contrôle de flux sur la prise (1 = actif), M12.
- `AA` : appel automatique (1 = demandé).

### Status écran (New Minitel 2)

```
Bit:  7  6  5  4  3  2  1  0
      P  1  0  0  0  0  0  VEIL.
```
- `VEIL.` : mise en/hors veille écran (0 = veille active).

### Format des ROM et RAM

```
01 (Ctrl-A) ...contenu de la ROM ou de la RAM... 04 (Ctrl-D)
```

Le Ctrl-A et le Ctrl-D sont toujours présents pour une ROM. Pour une RAM, le
Ctrl-D peut être absent si elle est complètement remplie ; en revanche, si le
Ctrl-A est absent, la RAM ne répondra plus jamais rien.

Contenu : `Constructeur` (1 octet) + `Type de minitel` (1 octet) + `Version`
(1 octet).

### Constructeur

| Code | Constructeur |
|------|--------------|
| `41` | Matra (M5 uniquement) |
| `42` | TRT (M1), RTIC (M1B), RPIC (M2), Philips (M12) |
| `43` | Telic-Alcatel (M1/M1C/M10/M10B/M12) |
| `44` | Thomson |
| `45` | CCS |
| `46` | Fiet |
| `47` | Fime |
| `48` | Unitel |
| `49` | Option |
| `4A` | Bull |
| `4B` | Télématique |
| `4C` | Desmet |

### Type de minitel (ou de périphérique)

| Code | Type |
|------|------|
| `62` | Minitel 1, modem non retournable, clavier ABCD |
| `63` | Minitel 1, modem non retournable |
| `64` | Minitel 10, modem non retournable |
| `65` | Minitel 1 Couleur, modem non retournable, entrée vidéo, incrustation |
| `66` | Minitel 10 |
| `67` | Émulateur |
| `6A` | Imprimante |
| `72` | Minitel 1 |
| `73` | Minitel 1 Couleur |
| `74` | Terminatel 252 |
| `75` | Minitel 1 Bi-standard ⇒ pas de RAM |
| `76` | Minitel 2 ⇒ demi-RAM 1 en lecture seule |
| `77` | Minitel 10 Bi-standard |
| `78` | (Thomson ?) |
| `79` | Minitel 5 |
| `7A` | Minitel 12 ⇒ RAM 1 en lecture seule |

### Version

```
Bit:  7       6       5  4      3-0
      Parité  PAD-X3  1  1      N° de version (4 bits)
```

## 14. Clavier

### Clavier M1/M10

| Touche | Seule | + TS | Ctrl |
|--------|-------|------|------|
| ENVOI | `SEP A` (41) | `CR` (0D) | Retour chariot |
| RETOUR | `SEP B` (42) | `SS2 B` (42) | Accent aigu |
| RÉPÉTITION | `SEP C` (43) | `SEP J` (4A) | Demande d'activation de la PCE |
| GUIDE | `SEP D` (44) | `SS2 H` (48) | Accent tréma |
| ANNULATION | `SEP E` (45) | `\` (5C) | Anti-slash |
| SOMMAIRE | `SEP F` (46) | `SS2 C` (43) | Accent circonflexe |
| CORRECTION | `SEP G` (47) | Prog. vitesse | puis 1=75 Bd, 2=300 Bd, 4=1200 Bd |
| SUITE | `SEP H` (48) | `SS2 A` (41) | Accent grave |
| CONNEXION/FIN | `SEP I` (49) | `SEP I` (49) | ⇒ prise |
| LOUPE | La loupe | Copie écran / Inhibe prise | puis 1=Français, 2=Américain, puis 0 (bascule) |
| CC | `SEP a` (61) | — | — |
| HP+ | `SEP b` (62) | — | — |
| HP- | `SEP c` (63) | — | — |
| BIS | `SEP d` (64) | `SEP h` (68) | ⇒ prise |
| RT puis n° XX (ou mnémo.) | `SEP e` (65) | compose le n° | — |
| EC puis n° XX | compose le n° | `FF` (0C) — sort de MEM | — |
| MEM | Accès à MEM | `SEP g` (67) | ⇒ prise |

### Clavier M1B/M10B

| Touche | Seule | + TS | + Ctrl |
|--------|-------|------|--------|
| ENVOI | `SEP A` (41) | `}` (7D) | — |
| RETOUR | `SEP B` (42) | `SS2 B` (42) | `SS2 j` (6A) — Œ |
| RÉPÉTITION | `SEP C` (43) | `{` (7B) | `SS2 z` (7A) — œ |
| GUIDE | `SEP D` (44) | `SS2 H` (48) | — |
| ANNULATION | `SEP E` (45) | `\` (5C) | `SS2 #` (23) — £ |
| SOMMAIRE | `SEP F` (46) | `SS2 C` (43) | — |
| CORRECTION | `SEP G` (47) | `SS2 '` (27) | `SS2 K` (4B) — ç |
| SUITE | `SEP H` (48) | `SS2 A` (41) | `SS2 {` (7B) — β |
| CONNEXION/FIN | `SEP I` (49) | `SEP I` (49) | -Break- |
| CC | `SEP a` (61) | — | — |
| HP+ | `SEP b` (62) | — | — |
| HP- | `SEP c` (63) | — | — |
| BIS | `SEP d` (64) | `SEP h` (68) | — |
| RT puis n° XX (ou mnémo.) | `SEP e` (65) | compose le n° | — |
| EC puis n° XX | compose le n° | — | — |
| MEM | — | `SEP g` (67) | — |

#### Flèches (M1B/M10B)

| Touche | CSI | C0 |
|--------|-----|-----|
| Flèche haut | `CSI A` (41) | `VT` (0B) |
| Flèche bas | `CSI B` (42) | `LF` (0A) |
| Flèche gauche | `CSI D` (44) | `BS` (08) |
| Flèche droite | `CSI C` (43) | `HT` (09) |
| Retour chariot | `CR` (0D) | `CR` (0D) |

| Touche | Séquence |
|--------|----------|
| TS + Flèche haut | `CSI M` (4D) |
| TS + Flèche bas | `CSI L` (4C) |
| TS + Flèche gauche | `CSI P` (50) |
| TS + Flèche droite | `CSI 4` (34) `h`/`l` (68/6C) |
| TS + Retour chariot | `CSI H` (48) / `RS` (1E) |
| Ctrl + Flèche gauche | `DEL` (7F) |
| Ctrl + Retour chariot | `CSI 2` (32) `J` (4A) / `FF` (0C) |

#### Chiffres et caractères spéciaux avec Ctrl (M1B/M10B)

| Touche | Ctrl | | Touche | Ctrl | | Touche | Ctrl |
|---|---|-|---|---|-|---|---|
| 1 | `{` (7B) | | 2 | `\|` (7C) | | 3 | `}` (7D) |
| 4 | `~` (7E) | | 5 | `` ` `` (60) | | 6 | `_` (5F) |
| 7 | `SS2 8` (38) | | 8 | `SS2 ,` (2C) | | 9 | `SS2 .` (2E) |
| * | `SS2 0` (30) | | 0 | `SS2 1` (31) | | # | `SS2 /` (2F) |
| , | `FS` (1C) | | . | `RS` (1E) | | ' | `NUL` (00) |
| - | `GS` (1D) | | : | `LF` (0A) | | ? | `US` (1F) |
| ; | `VT` (0B) | | | | | | |

#### Mode compatible PAD-X3

| Touche | Séquence |
|--------|----------|
| ENVOI | `ESC 21 34 0D` |
| RETOUR | `ESC 22 34 0D` |
| RÉPÉTITION | `ESC 23 34 0D` |
| GUIDE | `ESC 24 34 0D` |
| ANNULATION | `ESC 2F 34 0D` (ESC 25 = transparence écran) |
| SOMMAIRE | `ESC 26 34 0D` |
| CORRECTION | `ESC 27 34 0D` |
| SUITE | `ESC 28 34 0D` |
| CONNEXION/FIN | `ESC 29 34 0D` (idem avec TS) |

#### Mode téléinformatique — touches fonctions

| Touche | Séquence | Équiv. |
|--------|----------|--------|
| ENVOI | `ESC 4F 4D` | ENTER |
| SOMMAIRE | `ESC 4F 50` | PF1 |
| ANNULATION | `ESC 4F 51` | PF2 |
| RETOUR | `ESC 4F 52` | PF3 |
| RÉPÉTITION | `ESC 4F 53` | PF4 |
| CORRECTION | `ESC 4F 6C` | , |
| GUIDE | `ESC 4F 6D` | - |
| SUITE | `ESC 4F 6E` | . |

| Touche | Séquence | | Touche | Séquence |
|---|---|-|---|---|
| Fnct 0 | `ESC 4F 70` | | Fnct 5 | `ESC 4F 75` |
| Fnct 1 | `ESC 4F 71` | | Fnct 6 | `ESC 4F 76` |
| Fnct 2 | `ESC 4F 72` | | Fnct 7 | `ESC 4F 77` |
| Fnct 3 | `ESC 4F 73` | | Fnct 8 | `ESC 4F 78` |
| Fnct 4 | `ESC 4F 74` | | Fnct 9 | `ESC 4F 79` |

| Touche | TS (US) | TS (Français) | Ctrl (Français) |
|--------|---------|----------------|-------------------|
| ENVOI | `}` (7D) | è grave (7D) | — |
| RÉPÉTITION | `{` (7B) | é aigu (7B) | — |
| GUIDE | — | guillemet (22/7E) | — |
| ANNULATION | `\` (5C) | ç cédille (5C) | £ livre (23) |
| CORRECTION | — | § paragraphe (5D) | ç cédille (5C) |

### Configuration du terminal via la touche Fnct

| Configuration | Touche | Bascule |
|---------------|--------|:---:|
| Modem, PCE | Fnct M puis C | F-F |
| Modem, retourné | Fnct M puis R | — |
| Prise, inhibée/non | Fnct P puis I | F-F |
| Prise, 300 Bd | Fnct P puis 3 | — |
| Prise, 1200 Bd | Fnct P puis 1 | — |
| Prise, 4800 Bd | Fnct P puis 4 | — |
| Prise, 9600 Bd (M2) | Fnct P puis 9 | — |
| Terminal, écho/pas d'écho | Fnct T puis E | F-F |
| Terminal, Videotex | Fnct T puis V | — |
| Terminal, téléinformatique américain | Fnct T puis A | — |
| Terminal, téléinformatique français | Fnct T puis F | — |
| Terminal, PAD-X3 On | Fnct T puis / | — |
| Terminal, PAD-X3 Off (M10B) | Fnct T puis * | — |
| Terminal, initialisation (M2) | Fnct T puis I | — |
| Impression, jeu américain | Fnct I puis A | — |
| Impression, jeu français | Fnct I puis F | — |
| Clavier, C0/CSI | Fnct C puis C | F-F |
| Clavier, étendu (+ Esc/Ctrl/flèches) | Fnct C puis E | — |
| Clavier, vidéotex (- Esc/Ctrl/flèches) | Fnct C puis V | — |
| Clavier, majuscule/minuscule | Fnct C puis M | F-F |
| Écran, format 40/80 colonnes | Fnct E puis F | F-F |
| Écran, rouleau | Fnct E puis R | — |
| Écran, page | Fnct E puis P | — |
| Écran, mise en veille 3 h (New M2) | Fnct E puis M | — |
| Écran, arrêt de la veille 3 h (New M2) | Fnct E puis A | — |

#### Configuration M12

| Configuration | Touche |
|---------------|--------|
| Relance de l'exécution d'un logon en cours | Fnct S |
| Arrêt d'apprentissage | Fnct F |
| Réinitialisation d'apprentissage | Fnct Répétition |
| Suspension d'un accès automatique | Fnct : |
| Programmation d'une pause à l'apprentissage | Fnct - |
| Activation de la connexion du répondeur | Fnct R puis Envoi |
| Envoi d'un message préparé | Fnct Envoi puis n° |

#### Configuration M2

| Configuration | Touche | Bascule |
|---------------|--------|:---:|
| Accès à MEM | Fnct Sommaire | F-F |
| Recopie d'écran dans le jeu courant | Fnct Guide | — |
| Augmentation du volume HP | Fnct Correction | — |
| Diminution du volume HP | Fnct Annulation | — |

## 15. Matériel (prise péri-informatique)

### Brochage de la prise DIN

| Broche | Signal | Fonction |
|--------|--------|----------|
| 1 | RX | Réception de données par le terminal |
| 2 | GND | Masse |
| 3 | TX | Transmission de données par le terminal |
| 4 | PT | Périphérique en transmission |
| 5 | TP | Terminal Prêt (M1) — sortie alimentation 8,5 V / 1 A (M1B) |

### Ligne 0 (ligne d'état) des M1/M10

```
           1         2         3         4
  1234567890123456789012345678901234567890
  APPEL                              IR X
```
Minitel 1 : `X` = F ou C (fixe/clignotant). Minitel 10 : message Appel
(IAI), prise Inhibée (I), Recopie d'écran (R).

### Ligne 0 des M1B/M10B

```
           1         2         3         4
  1234567890123456789012345678901234567890
  APPEL                               IRX
```
`X` = F/f/C (fixe/clignotant). Message Appel (IAI), prise Inhibée (I),
Recopie d'écran (R).

## 16. Mode Téléinformatique 80 colonnes

`CSI` = `ESC 5B` (`ESC [`). Les paramètres `Pn`/`Pl`/`Pc` sont des chiffres
ASCII décimaux, séparés par `;` s'il y en a plusieurs ; une valeur absente ou
nulle prend la valeur implicite.

### Fonctions curseur (ANSI X3.64 / ISO 6429)

| Cmd | Fonction | Séquence | Notes |
|-----|----------|----------|-------|
| CUP | Position du curseur | `CSI Pl ; Pc H` | |
| HVP | Position horizontale et verticale | `CSI Pl ; Pc f` | |
| CUU | Curseur haut | `CSI Pn A` | |
| CUD | Curseur bas | `CSI Pn B` | |
| CUF | Curseur droite | `CSI Pn C` | |
| CUB | Curseur gauche | `CSI Pn D` | |
| DSR | Demande de statut (Device Status Report) | `CSI 6 n` | Réponse : CPR |
| CPR | Position du curseur (réponse) | `CSI Pl ; Pc R` | M12/M2 |
| SCP | Sauvegarde de la position du curseur | `CSI s` | |
| RCP | Restitution de la position du curseur | `CSI u` | |

### Effacement, insertion, suppression

| Cmd | Fonction | Séquence | Notes |
|-----|----------|----------|-------|
| ED | Effacement écran | `CSI Ps J` | `0`=fin, `1`=début, `2`=entier |
| EUD | Effacement écran supérieur | `CSI 1 J` | |
| ELD | Effacement écran inférieur | `CSI 0 J` | |
| EL | Effacement ligne | `CSI Ps K` | `0`=fin, `1`=début, `2`=entière |
| EBL | Effacement début de ligne | `CSI 1 K` | |
| EC | Effacement de caractères | `CSI Pn P` | |
| SL / DL | Suppression de ligne | `CSI Pn M` | |
| IL | Insertion de ligne | `CSI Pn L` | |
| ICH / IC | Insertion de caractère | `CSI Pn @` | M1B RTIC |
| DCH | Suppression de caractère | `CSI Pn P` | |
| BIC / SM4 | Début d'insertion de caractères | `CSI 4 h` | Insertion/Replacement Mode (IRM) |
| EIC / RM4 | Fin d'insertion de caractères | `CSI 4 l` | |

### Sélection de modes (80 colonnes uniquement)

| Cmd | Fonction | Séquence | Notes |
|-----|----------|----------|-------|
| IND | Index | `ESC D` | équivalent LF |
| NEL | Ligne suivante | `ESC E` | équivalent CR+LF |
| RI | Index inverse | `ESC M` | équivalent VT |
| RIS | Réinitialisation totale | `ESC c` | |
| SM/RM | Curseur on/off (privé) | `CSI ?1 h` / `CSI ?1 l` | M12/M2 |
| SM2/RM2 | Keyboard Action Mode (KAM) | `CSI 2 h` / `CSI 2 l` | |
| SM/RM | 40/80 colonnes (privé) | `CSI ?3 h` / `CSI ?3 l` | M12/M2 |
| SM/RM | Mode page / mode rouleau (privé) | `CSI ?4 h` / `CSI ?4 l` | M12/M2 |
| SM12/RM12 | Send/Receive Mode (SRM) | `CSI 12 h` / `CSI 12 l` | M12/M2 |
| MC | Media Copy | `CSI i` | |

### Attributs graphiques (SGR)

`CSI Ps ... Ps m` — plusieurs paramètres séparés par `;`.

| `Ps` | Attribut | | `Ps` | Attribut |
|------|----------|-|------|----------|
| `0` | Annule tous les attributs | | `27` | Fin de vidéo inverse (fond normal) |
| `1` | Gras / sur-intensité | | `30`-`37` | Couleur caractère (noir → blanc) |
| `2` | Intensité réduite | | `40`-`47` | Couleur de fond (noir → blanc) |
| `4` | Souligné | | `24` | Fin de soulignement |
| `5` | Clignotant | | `25` | Fin de clignotement |
| `7` | Vidéo inverse | | `22` | Intensité normale |
| `8` | Vidéo normale | | | |

### Autres codes 80 colonnes (hors ANSI X3.64)

| Séquence | Fonction |
|----------|----------|
| `BEL` (Ctrl-G) | Signal sonore |
| `BS` (Ctrl-H) | Curseur gauche |
| `TAB` (Ctrl-I) | Tabulation |
| `LF`/`VT`/`FF` (Ctrl-J/K/L) | Curseur bas |
| `CR` (Ctrl-M) | Retour chariot |
| `SO` (Ctrl-N) | Passage au jeu G1 (français) |
| `SI` (Ctrl-O) | Passage au jeu G0 (américain) |
| `CAN`/`EOF` (Ctrl-X/Z) | Pavé plein (DEL) |
| `ESC` (Ctrl-[) | Introduit une séquence escape |
| `US 40 Pc` (@) | Accès à la ligne 0, colonne `Pc` (0<Pc<64) |

### Sélection du jeu de caractères

| Séquence | Fonction | Modèle |
|----------|----------|--------|
| `ESC 28 42` | (B — G0 = jeu américain | M12 |
| `ESC 28 52` | (R — G0 = jeu français | M12 |
| `ESC 28 33` | (3 — G0 = jeu complémentaire | M12 |
| `ESC 28 30` | (0 — G0 = jeu DEC | M2 |
| `ESC 29 42` | )B — G1 = jeu américain | M12 |
| `ESC 29 52` | )R — G1 = jeu français | M12 |
| `ESC 29 33` | )3 — G1 = jeu complémentaire | M12 |
| `ESC 29 30` | )0 — G1 = jeu DEC | M2 |

### Autres séquences 80 colonnes

| Séquence | Fonction |
|----------|----------|
| `ESC 37` | Mémorisation du contexte écran |
| `ESC 38` | Restitution du contexte écran |
| `ESC 4F XX` (O) | Codage des touches de fonction — voir [§14](#14-clavier) |
| `CSI 3F 7A` | Acquittement de passage en téléinformatique |
| `CSI 3F 7B` | Retour au standard Télétel, mode Videotex |

### TermInfo (Unix) pour M1/M1B, 40/80 colonnes

Définitions `terminfo` associées (référence croisée, hors séquences
Minitel proprement dites) :

```
m1|minitel 1,
	cols#40, lines#24, am, bw,
	bel=^G, cr=^M,
	civis=^T, cnorm=^Q,
	cub1=^H, cuf1=^I, cud1=^J, cuu1=^K, home=^^, nel=^M^J,
	cup=^_%p1%'A'%+%c%p2%'A'%+%c,
	clear=^L, el=^X,
	acsc=f0g1\,\,+../, enacs=^Y,
	ind=^J, ri=^K,
	blink=\EH, rev=\E], sgr0=\EI\E\\,
	smso=\E], rmso=\E\\, msgr,
	sgr=%?%p1%t\E]%;%?%p3%t\E]%;%?%p4%t\EH%;,
	hs, tsl=^_@%p1%'A'%+%c, fsl=^J,
	is2=\E;`ZQ\E:iC\E:iE^Q,
	rep=%p1%c^R%p2%'?'%+%c, eslok, hz,
	colors#8, pairs#8, op=\EG,
	setf=\E%?%p1%{1}%=%tD%e%p1%{3}%=%tF%e%p1%{4}%=%tA%e%p1%{6}%=%tC%e%p1%'@'%+%c%;,
# is2 = Fnct TE, Fnct MR, Fnct CM et pour finir : curseur ON.

m1b|minitel 1-bistandard (in 40cols mode),
	cub=\E[%p1%dD, cuf=\E[%p1%dC, cuu=\E[%p1%dA, cud=\E[%p1%dB,
	ed=\E[J, el1=\E[1K,
	il1=\E[L, il=\E[%p1%dL, dl1=\E[M, dl=\E[%p1%dM,
	smir=\E[4h, rmir=\E[4l, mir,
	dch1=\E[P, dch=\E[%p1%dP,
	smkx=\E;iYA\E;jYC, .rmkx=\E;jYA,
	is1=\E;iYA\E;jYC,
	kcub1=\E[D, kcuf1=\E[C, kcuu1=\E[A, kcud1=\E[B,
	kdch1=\E[P, kdl1=\E[M, kel=^X, kctab=^I,
	khome=\E[H, kclr=\E[2J, kich1=\E[4h, kil1=\E[L,
	use=m1,
# rmkx posait des problèmes (logout en sortant de vi).

m1b-x80|minitel 1-bistandard (standard teleinformatique),
	cols#80, am@, bw@,
	civis=^_@A^T^J, cnorm=^_@A^Q^J,
	cuf1=\E[C, cuu1=\E[A, home=\E[H, nel=\EE,
	it#8, ht=^I,
	cup=\E[%i%p1%d;%p2%dH,
	clear=\E[H\E[2J, el=\E[K,
	ind=\ED, ri=\EM,
	blink=\E[5m, rev=\E[7m, bold=\E[1m, sgr0=\E[m,
	smso=\E[7m, rmso=\E[27m,
	smul=\E[4m, rmul=\E[24m,
	sgr=\E[%?%p1%t7;%;%?%p2%t4;%;%?%p3%t7;%;%?%p4%t5;%;%?%p6%t1;%;m,
	sc=\E7, rc=\E8,
	smkx@, rmkx@,
	is1@, is2@, rep@, hz@,
	kf0=\EOp, kf1=\EOq, kf2=\EOr, kf3=\EOs, kf4=\EOt,
	kf5=\EOu, kf6=\EOv, kf7=\EOw, kf8=\EOx, kf9=\EOy,
	kent=\EOM,
	colors@, pairs@, op@, setf@,
	use=m1b,
```

## 17. Codes TRANSPAC (PAD X.3)

Ces commandes s'adressent au PAD X.3/X.28/X.29 du réseau Transpac, en amont
du protocole Minitel proprement dit — incluses ici pour référence complète.

```
<^P>            en cours d'usage, stoppe le transfert et préfixe une commande PAD
<CR>            termine la commande PAD et relance la transmission
<^P>PAR?        état de tous les paramètres du PAD
<^P>PAR? 1,2,5  état des paramètres 1, 2 et 5 du PAD
<^P>SET 1:0,3:126  met à 0 le paramètre 1 et à 126 le paramètre 3
<^P>SET?        demande confirmation du changement de paramètres
<^P>PROF 4      configure les paramètres du PAD selon le profil 4
```

Messages PAD (libération / diagnostic de connexion) :

| Message | Signification |
|---------|----------------|
| DTE | Libération par le correspondant qui refuse |
| PAP | Libération par le correspondant |
| OCC | Correspondant occupé |
| DER | Correspondant en dérangement |
| RPE | Le correspondant s'est « planté » |
| PCV | Le correspondant refuse le PCV |
| NP | Correspondant inexistant |
| NA | Le correspondant ne peut être appelé |
| RC | Le correspondant a eu des problèmes mais est de nouveau prêt |
| NC | Incident réseau |
| INV | Demande invalide |

## 18. Lecteur de carte à mémoire (LECAM)

Protocole applicatif d'échange entre un lecteur de carte à mémoire (LECAM)
connecté au Minitel et le serveur — inclus ici pour référence complète bien
qu'il ne s'agisse pas de séquences d'affichage.

### Structure des messages applicatifs

```
<d> bloc 1 <f> <d> bloc 2 <f> ... <d> bloc n <f> CR
```

### Drapeaux

| Nom | ASCII | Décimal | Hexa | Explication |
|-----|-------|---------|------|-------------|
| `<d>` | `US < IT [IC]` | `31 60 IT [IC]` | `1F 3C IT [IC]` | Début de bloc |
| `<f>` | `US < (` | `31 60 40` | `1F 3C 28` | Fin, serveur → terminal |
| `<f>` | `US < 8` | `31 60 56` | `1F 3C 38` | Fin, terminal → serveur |
| `<dc>` | `US < +` | `31 60 43` | `1F 3C 2B` | Début chiffré |
| `<fc>` | `US < >` | `31 60 46` | `1F 3C 2E` | Fin chiffré |
| `<r>` | `US < * IC` | `31 60 42 IC` | `1F 3C 2A IC` | Demande de répétition, serveur → terminal |
| `<r>` | `US < : IC` | `31 60 58 IC` | `1F 3C 3A IC` | Demande de répétition, terminal → serveur |

### Octet IT

```
Bit:  7  6   5    4     3    2    1    0
      P  1  RTM  sens  SSP  TLV  CRC  IC
```
- `RTM` (LECAM 210 uniquement) : retournement immédiat du modem sur
  détection de fin de message.
- `sens` : sens des échanges (1 = terminal vers serveur).
- `SSP` : dans le sens serveur → lecteur, indique que le serveur n'attend pas
  de réponse du lecteur.
- `TLV` : format des données (1 = format TLV codé en P/1/6).
- `CRC` : présence d'un CRC (1 = présent).
- `IC` : présence de l'octet IC (1 = présent).

### Octet IC

```
Bit:  7  6  5   4     3   2   1   0
      P  1  1  rep.  n3  n2  n1  n0
```
- `rep.` : bloc répété (1 = bloc émis suite à une demande de répétition).
- `n3-n0` : numéro de bloc (0-15).

### CRC

Polynôme générateur : `X^16 + X^12 + X^5 + 1`, initialisation à 0. Les 16
bits du CRC sont éclatés en 4 quartets X, Y, Z, T (X = poids fort), transmis
en 4 octets `3X 3Y 3Z 3T`, juste avant le drapeau de fin de bloc.

### Format TLV

`T` (1 octet, type consigne/réponse), `L` (1 octet, longueur du champ `V`),
`V` (`L` octets, données).

### Codage P/1/6

But : transférer un octet 8 bits via un modem V23 (7 bits, le 8e servant de
parité paire), en éliminant les caractères `< 32`.

```
Bit 7 (P) : parité
Bit 6 (1) : forcé à 1 (caractère ⇒ + 64)
Bits 5-0  : bits utiles
```
Deux octets 8 bits codés en P/1/6 occupent 3 octets, avec 2 bits inutilisés.

### Liste des consignes (format TLV)

| Type | Contenu (`Type,Lg,V...`) | Fonction |
|------|---------------------------|----------|
| `41` | `CM,02,mode,rg` | Mise en mode |
| `43` | `C1,Lg,adr.,données` | Chargement |
| `45` | `C2,Lg,données` | — |
| `46` | `C3,01,n` | — |
| `44` | `CC,Lg,données` | — |
| `47` | `LI,02,adr.` | Exécution |
| `5D` | `FS,02,adr.` | — |
| `4D` | `CA,Lg,texte` | Éditeur |
| `4F` | `CE,Lg,texte` | — |
| `51` | `CS,01,val` | — |
| `53` | `TC,01,val` | — |
| `55` | `XS,01,val` | — |
| `57` | `CH,Lg,type,synchro,[clé de déchiffrement]` | Sécurité |
| `58` | `PR,02,rang` | — |
| `49` | `CD,00` | Saisie et affichage |
| `4B` | `CF,00` | — |
| `5F` | `AC,01,dest` | — |
| `59` | `SC,01,ncs` | — |
| `59`\* | `SC,Lg,ligne1,colonne1,ncs1,ligne2,colonne2,ncs2,...` | LECAM 210 uniquement |
| `5B` | `SS,01,ncs` | — |
| `5B`\* | `SS,Lg,ligne1,colonne1,ncs1,ligne2,colonne2,ncs2,...` | LECAM 210 uniquement |

### Liste des réponses aux consignes

| Type | Contenu (`Type,Lg,V...`) |
|------|---------------------------|
| `70` | `IL,04,TM,VM,TL,VL` |
| `72` | `EL,Lg,ME,[CC,TC],[CI,adr],[CT]` |
| `74` | `EC,03,ME1,ME2,MDC` |
| `76` | `RZ,Lg,données` |
| `78` | `SE,Lg,données en clair` |
| `79` | `SE,Lg,données chiffrées` |
| `7C` | `IF,01,val` |

### Adresses connues dans la carte

| Adresse | Contenu |
|---------|---------|
| `09C8` | ADLibre, ADTransaction |
| `09F0` | Numéro de série de la carte |
| `09F8` | Locks (?) |

### Modèles de cartes

| Type | Application | Nom | Connexion auto. | Bloc de sécurité |
|------|-------------|-----|:---:|:---:|
| M4 | Masque | BC | Oui | Non |
| M6 | — | CC | Oui | Non |
| M8\* | Bull CP8 | ?C | — | — |
| B0 | Bancaire | BC | Non | Non |
| B1 | — | CB | Oui | Oui |
| B2\* | — | CB | — | — |
| PC1 | Portes-clefs | AC | Oui | Oui |
| DES\* | Philips | D0 | — | — |

\* LECAM 210 uniquement.

### Instruction Afnor — format

| Champ | Longueur | Contenu |
|-------|----------|---------|
| Nom | 1 octet | Type de carte |
| Ins | 1 octet | Ordre |
| A1 A2 | 2 octets | Adresse |
| L | 1 octet | Longueur des données |

### Quelques ordres

| Ordre | Fonction |
|-------|----------|
| `20` | Demande de vérification du code |
| `40` | Validation de lecture |
| `A0` | Recherche sur argument |
| `B0` | Lecture de `n` octets à l'adresse A1 A2 |
| `C0` | Demande de résultat (cf. `A0`) |

### Bloc de connexion automatique (`23h`) — en-tête

| Type de carte | En-tête |
|---|---|
| M4(B0)/M6/M8 [bit système `0xx1`] | `0yx0 xxxx | 23 | longueur | 111 CCR` (y=0 : zone de lecture libre ADL ; y=1 : zone de transaction ATD) |
| B1 [bit système `0xx1`] | `0010 c1xx | 23 | longueur | 111 CCR` (c=0 : données protégées ; xx=10 : clé banque ; xx=01 : clé d'ouverture) |
| PC1 [bit système `0x1x`] | `40 | 23 | 00 | 00` |
| D1 | `0010 yyyy | 23 | ... | ...` (yyyy = 0010, 0100, 1011, 1101) |

TLV pouvant figurer dans ce bloc :

| Type | Contenu | Fonction |
|------|---------|----------|
| `01` | `NA,Lg,numéro d'appel` | — |
| `02` | `TX,Lg,texte à transmettre` | — |
| `03` | `DF,01,délai de détection de fin de message` | — |
| `04` | `DS,01,délai de suspension` | — |
| `05`\* | `T,Lg,numéro d'ordre,mnémonique` | LECAM 210 uniquement |

### Bloc de sécurité (`24h`) — en-tête

| Type de carte | En-tête |
|---|---|
| B1 | `2E | 24 | ... | ...` |
| PC1 | `40 | 24 | 00 | 00` |
| D1 | `2B | 24 | ... | ...` |

TLV pouvant figurer dans ce bloc :

| Type | Contenu | Description |
|------|---------|--------------|
| `10` | `T,Lg,EMPLACEMENT,PROFIL_BINAIRE,MASQUE` | Ordre entrant à surveiller pour les calculs de signature |
| `11` | `T,01,POSITION` | Position du champ où placer le comprimé dans les données entrantes |
| `12`\* | `T,01,C` | Longueur du comprimé à générer par le LECAM |
| `20` | `T,Lg,EMPLACEMENT,PROFIL_BINAIRE,MASQUE` | Ordre entrant pour le calcul de la clé de chiffrement |
| `21` | `T,05,NOM,INS,A1,A2,L` | Ordre sortant à exécuter pour obtenir la clé de chiffrement |
| `22` | `T,05,NOM,INS,A1,A2,L` | Idem 21, suivi d'une mise hors tension |
| `23`\* | `T,05,NOM,INS,A1,A2,L (?)` | Ordre entrant à exécuter immédiatement après l'ordre sortant |

\* LECAM 210 uniquement.

## Références

- Documents source : Spécifications Vidéotex Visualisation/Codage (mai 1980,
  Télétel) ; Spécification de la fonction décodage Vidéotex des Minitel
  (août 1984, CNET/CCETT) ; STUM M1 (édition provisoire de septembre 1984) ;
  STUM M10 (édition provisoire d'août 1985) ; STURM Réseau Minitel (août
  1986) ; STUM 1B (novembre 1986) ; S.T.U.P.A.V. (mars 1987) ; S.T.U.C.A.M.
  (décembre 1987, complément mars 1989) ; S.T.U.T.E.L. (décembre 1987) ;
  STUM 12 (avril 1990) ; STUM 2 (février 1991). Documents disponibles à la
  vente au CNET d'Issy-les-Moulineaux à l'époque de leur publication.
- Compilations en ligne utilisées pour ce document :
  <https://millevaches.hydraule.org/info/minitel/specs/index.htm>
  (reprenant elle-même <http://canal.chez.com/videotex.htm> et un fil du
  forum developpez.net).
- Autres documents du dépôt : [`../STUM2.md`](../STUM2.md) (extraction brute
  du STUM 2), [`../mode80.md`](../mode80.md) (extraction brute du mode 80
  colonnes / téléinformatique).
