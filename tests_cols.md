# Tests des séquences 40/80 colonnes sur Minitel 2 réel

Tests effectués par Alain BASTY sur un Minitel 2 (M2) réel, pour vérifier
quelles séquences documentées dans
[docs/SEQUENCES-STANDARD.md](docs/SEQUENCES-STANDARD.md) fonctionnent
réellement pour basculer entre les modes Videotex 40 colonnes et
Téléinformatique 80 colonnes.

| # | Sens | Séquence | Chaîne | M2 |
|---|---|---|---|---|
| 1 | Videotex → Téléinformatique 80 | `PRO2 31 7D` | `"\x1B\x3A\x31\x7D"` | OK (pas Mixte, cf. synthèse) |
| 2 | Téléinfo 80 → 40 | `CSI <3 h` | `"\x1B\x5B\x3C\x33\x68"` | OK (glitch : touches fonction KO) |
| 3 | Téléinfo 40 → 80 | `CSI ?3 l` | `"\x1B\x5B\x3F\x33\x6C"` | OK |
| 4 | Téléinfo → Videotex | `CSI ?{` | `"\x1B\x5B\x3F\x7B"` | **OK** |
| 5 | Videotex → Mixte 80 | `PRO2 32 7D` | `"\x1B\x3A\x32\x7D"` | OK |
| 6 | Mixte → Videotex 40 | `PRO2 32 7E` | `"\x1B\x3A\x32\x7E"` | **OK** |
| 7 | (Mixte ou Téléinfo) → 80 col | `CSI <3 l` | `"\x1B\x5B\x3C\x33\x6C"` | **NOK** (7a: Téléinfo 40, aucun effet ; 7b: Mixte 80, aucun effet) |
| 8 | (Mixte ou Téléinfo) → 40 col | `CSI ?3 h` | `"\x1B\x5B\x3F\x33\x68"` | **NOK** (8a: Téléinfo 80, aucun effet ; 8b: Mixte, aucun effet) |
| 9 | Télétel (Videotex ou Mixte) → Videotex 40 | `PRO1 7F` | `"\x1B\x39\x7F"` | **OK depuis Mixte (9b)** ; **bloqué en Téléinfo comme attendu (9c)** |
| RT | Téléinfo 80→40→80 (paire confirmée `CSI <3 h` / `CSI ?3 l`) | — | **OK** (round-trip validé) |

Notes sur le tableau ci-dessus :
- **Résolu (négatif)** : les séquences 7 (`CSI <3 l`) et 8 (`CSI ?3 h`) n'ont
  strictement aucun effet, ni en Mixte ni en Téléinformatique. Les marqueurs
  `<` et `?` ne sont donc **pas** interchangeables pour cette commande :
  seule la paire confirmée fonctionne (2 : `CSI <3 h` → 40 col ; 3 : `CSI ?3
  l` → 80 col). Corrigé dans l'émulateur (`lib/min_emulator.dart`) et dans
  `docs/SEQUENCES-STANDARD.md`.
- Séquence 9 (`PRO1 7F`, RESET) : d'après le STUM 1B, *« en standard
  Téléinformatique, la séquence de reset n'est pas interprétée »* — elle doit
  donc être envoyée depuis le standard Télétel (Videotex ou Mixte), pas
  depuis Téléinformatique (où c'est la séquence 4 qui fait ce travail).
- Séquence 6 (`PRO2 32 7E`) : trouvaille de la session BASTOS — c'est
  exactement l'octet séquence de `P_MODE_40`, envoyée par `MODE_INIT_STRING`
  (donc par `MODE 0`/`MODE 1`, en tête de quasiment tous les `.bas` du
  projet), pendant que `P_80_COLS` envoyée par `MODE 2` (séquence 5) est
  identique bit à bit à notre séquence 5 confirmée. Le couple 5/6 est donc
  déjà exercé en continu depuis le début du développement BASTOS à chaque
  `MODE 2` suivi d'un `MODE 0`/`1` — la séquence 6 n'est donc pas vraiment
  une inconnue, juste jamais testée isolément jusqu'ici.

## Programme de test (BASTOS)

La session `minwifi-esp01-a1` a écrit `disk/tests.bas` (repo BASTOS) pour
tester #4, #6, #7, #8, #9 en partant bien de l'état de départ requis à
chaque fois (walk explicite vers la précondition avant chaque séquence, pas
d'hypothèse de continuité entre tests). #7 et #8 sont testées deux fois
(depuis Mixte et depuis Téléinformatique), #9 deux fois aussi (9b depuis
Mixte, censé marcher ; 9c depuis Téléinformatique, censé échouer — pour
confirmer le Protocole figé du STUM 1B). Le script attend une frappe entre
chaque étape et affiche une description à l'écran ; il ne touche jamais aux
commandes BASTOS de haut niveau (AT/CLS/CURSOR/MODE) pour ne pas fausser
l'observation avec le suivi d'état interne de BASTOS. Reste à exécuter sur
le vrai M2 et à reporter les résultats ici.

## Remarques

Les commandes ECHO 0 ne marche pas en seq 1.

### Séquence 1
- Séquence 1 (`PRO2 31 7D`) fonctionne pour passer en 80 colonnes.
- Touches de fonctions envoient d'autres codes
- Echo est activé (doublage des caractères)
- La séquence 2 passe en 40 cols, mais efface l'écran, le curseur reste le
  curseur souligné, les touches de fonctions ne sont pas respectées


1 ->

## Recherche doc (STUM 1B officiel)

Source : https://jbellue.github.io/stum1b/ (section « Commandes Protocole
relatives au changement de standard »).

- `PRO2 31 7D` (séquence 1) fait passer du **standard Télétel au standard
  Téléinformatique** — ce n'est pas le mode Mixte (`PRO2 32 7D`/`7E`, qui
  reste à l'intérieur du standard Télétel).
- Citation : *« Cette transition bloquant le Protocole, l'acquittement ne
  fait pas partie du langage Protocole. »* → une fois en standard
  Téléinformatique, **les commandes PRO1/PRO2/PRO3 ne sont plus interprétées
  du tout**. Ça explique pourquoi la séquence 6 (`PRO2 32 7E`) ne peut pas
  fonctionner pour revenir.
- La séquence 2 (`CSI <3 h`) ne fait basculer que le nombre de colonnes à
  l'intérieur du standard Téléinformatique — elle ne fait pas sortir de ce
  standard.
- **Commande officielle de retour** (citation) : *« Le Protocole étant
  bloqué, la commande est de type CSI : CSI, 0x3F 0x7B »*, soit `ESC [ ? {`.
  L'acquittement attendu en retour est `SEP 0x5E` (`13 5E`).
- **Implémenté côté émulateur minterm** (le 3 axes Videotex/Mixte/
  Téléinformatique, la gestion `_isMixte`, `CSI ?{`, le gel du Protocole en
  Téléinformatique, et les touches de fonction spécifiques Téléinformatique
  — voir §"Implémentation émulateur" plus bas). Confirmé sur le vrai M2
  (toutes les séquences du tableau, voir §"Validation finale").

Quand on revient en mode Videotex, le clavier n'est plus en mode étendu => pb
pour Bastos.

## Synthèse par mode/standard

Précision suite aux tests : la séquence 1 (`PRO2 31 7D`) ne mène PAS au mode
Mixte mais au standard Téléinformatique — le mode Mixte, c'est la séquence 5
(`PRO2 32 7D`), confirmée séparément « MODE 2 / OK ».

### Videotex (standard Télétel, mode Videotex)

Toujours 40 colonnes, pas de bascule 40/80 interne ; il faut en sortir pour
passer à 80 colonnes.

| Transition | Séquence | Chaîne | M2 |
|---|---|---|---|
| Videotex 40 → Mixte 80 | `PRO2 32 7D` | `"\x1B\x3A\x32\x7D"` | OK |
| Videotex 40 → Téléinformatique 80 | `PRO2 31 7D` | `"\x1B\x3A\x31\x7D"` | OK |

### Mixte

Toujours 80 colonnes par définition (STUM 1B : *« le mode Mixte permet
l'exploitation... dans un format de 25 rangées de 80 colonnes »*) — pas de
sous-état 40 colonnes documenté. Seule transition : retour Videotex.

| Transition | Séquence | Chaîne | M2 |
|---|---|---|---|
| Mixte 80 → Videotex 40 | `PRO2 32 7E` | `"\x1B\x3A\x32\x7E"` | OK (#6) |

### Téléinformatique

Seul standard où 40 et 80 colonnes coexistent sur M2 (le STUM 1B dit que
c'est réservé au clavier — `Fnct E + F` — et *« inutilisable par le
serveur »* sur M1B, mais nos tests le contredisent pour le M2).

| Transition | Séquence | Chaîne | M2 |
|---|---|---|---|
| Téléinfo 80 → 40 | `CSI <3 h` | `"\x1B\x5B\x3C\x33\x68"` | OK (glitch : touches fonction KO) |
| Téléinfo 40 → 80 | `CSI ?3 l` | `"\x1B\x5B\x3F\x33\x6C"` | OK |
| Téléinfo → Videotex | `CSI ?{` | `"\x1B\x5B\x3F\x7B"` | OK (#4) |

### Problème clavier ouvert

Au retour en mode Videotex (quel que soit le chemin), le clavier n'est plus
en mode étendu — pose problème pour BASTOS. Cause et séquence de
correction encore à identifier.

### Question résolue : boot BASTOS, Videotex ou Mixte ?

Remontée par la session BASTOS : `MODE_INIT_STRING` (envoyée par `MODE 0`/
`MODE 1`, donc en tête de quasiment tous les `.bas` du projet) inclut
`P_MODE_40` = `PRO2 32 7E` — ajoutée à l'origine (commit `bd7897f`)
uniquement pour corriger un problème de comptage de colonnes 40/80, sans
notion de standard Videotex/Mixte (ce modèle à 3 états n'existait pas
encore). Question posée : le boot BASTOS atterrit-il en réalité en Mixte
plutôt qu'en vrai Videotex ?

**Résolu par déduction** (pas besoin d'un nouveau test matériel) : le test
#6 (confirmé O sur M2) établit que `PRO2 32 7E`, envoyée depuis Mixte,
bascule sans condition vers Videotex (ce n'est pas un toggle relatif à
l'état courant). Combiné au modèle à 3 états maintenant validé de bout en
bout (Mixte est toujours 80 colonnes, sans variante 40 colonnes ; le
standard Téléinformatique ne s'atteint que via `PRO2 31 7D`, jamais envoyée
par le boot BASTOS), les seuls états de départ possibles au boot sont
Videotex ou Mixte — jamais Téléinformatique. Donc arriver en 40 colonnes
via cette commande, depuis l'un ou l'autre état de départ, ne peut
correspondre qu'à un vrai Videotex. Documenté dans le commentaire de
`P_MODE_40` (`lib/basic/tty-minitel.h`, côté BASTOS), avec référence aux
tests #6/#9c ; suite de régression BASTOS (272 tests) rejouée, propre.

Cas limite non couvert (hors périmètre du boot normal) : un terminal déjà
bloqué en Téléinformatique pour une raison externe avant le lancement de
BASTOS — `P_MODE_40` y serait probablement gelée comme `PRO1 7F` (test
#9c), mais par analogie seulement, non testé directement.

## Implémentation émulateur (minterm)

Le modèle à 3 états (Videotex / Mixte / Téléinformatique) est maintenant
implémenté dans `lib/min_emulator.dart` :

- `TMinitel._isMixte` distingue Mixte de Téléinformatique quand
  `screenMode == teleinfo80` ; `isMixteMode` / `isTeleinformatiqueStandard`
  exposent cette distinction, `enterMixte()` / `enterTeleinformatique()`
  centralisent les transitions.
- `PRO2 31 7D` → Téléinformatique, `PRO2 32 7D`/`7E` → Mixte (correctement
  distingués, alors qu'avant les deux étaient confondus).
- `CSI ?{` (`1B 5B 3F 7B`) implémenté : retour en Videotex depuis
  Téléinformatique, avec acquittement `SEP 0x5E`.
- Le Protocole (PRO1/PRO2/PRO3) est maintenant gelé en standard
  Téléinformatique (filtré dès la réception de `ESC 9`/`ESC :`), mais reste
  actif en Mixte — donc `PRO1 7F` (RESET) ne fonctionne plus qu'en
  Videotex/Mixte, jamais en Téléinformatique, conformément au STUM 1B.
- Les touches de fonction (Envoi, Sommaire, Annulation, Retour, Répétition,
  Correction, Guide, Suite, Connexion/Fin) envoient maintenant le code STUM
  1B `ESC O x` en standard Téléinformatique au lieu du code SEP
  Videotex/Mixte (`TMinitelKey.teleinformatiqueOverrides`,
  `MinModel.handleKeys`).
- **Séquences 7/8 corrigées** suite aux résultats M2 (voir tableau du haut) :
  `CSI <3 l` et `CSI ?3 h` retirés (aucun effet réel), seuls `CSI <3 h`
  (→40) et `CSI ?3 l` (→80) restent câblés, aussi bien côté entrée Videotex
  (`handleSequence`) que côté décodeur Téléinformatique
  (`_executeTeleinfoCsi`).
- **Écho local** (remarque d'Alain : écho activé par défaut, provoquant un
  doublage de caractères, et `CSI 12 h/l` — SM12/RM12, sans marqueur privé —
  non géré) :
  - Règle générale (Alain) : *« quand on est en mode connecté, l'émulateur
    doit désactiver l'écho »* — indépendamment du mode Videotex/Mixte/
    Téléinformatique. Vérification faite : **déjà implémenté** dans
    `lib/min_model.dart` — `connect()` met `isEchoed = false`, `end()`
    (déconnexion) le remet à `true`, pour les 3 types de connexion (série,
    WebSocket, TCP/UDP).
  - Le correctif précédent (`enterTeleinformatique()` forçant `isEchoed =
    false`) a été retiré : redondant en connecté, et faux en local (le
    STUM 1B veut l'écho actif hors connexion, y compris en
    Téléinformatique). La règle connexion/déconnexion suffit, quel que soit
    le mode.
  - `CSI 12 h` (coupe l'écho) / `CSI 12 l` (rétablit l'écho) sont
    implémentés dans `_executeTeleinfoCsi` (`lib/min_emulator.dart`).
- Tests unitaires ajoutés/corrigés dans `test/min_emulator_teleinfo_test.dart`
  et `test/min_emulator_videotex_test.dart` ; suite complète au vert (hors
  2 échecs préexistants sans rapport sur le clavier compact).

## Validation finale sur M2 réel (résumé `disk/tests.bas`)

Tous les points restants ont été confirmés sur le vrai M2 via le script
BASTOS (capture d'écran, résumé O/N) :

```
#4  Teleinfo->Videotex CSI?{      : O
#6  Mixte->Videotex 32 7E         : O
#7a Teleinfo40 CSI<3l ->80        : N
#7b Mixte CSI<3l                  : N
#8a Teleinfo80 CSI?3h ->40        : N
#8b Mixte CSI?3h                  : N
#9b Mixte RESET->Videotex         : O
#9c Teleinfo RESET bloque         : O
RT  Teleinfo 80->40->80           : O
```

Tous ces résultats correspondent exactement à l'implémentation actuelle de
l'émulateur — **aucun changement de code supplémentaire n'était
nécessaire**. Le modèle à 3 états (Videotex/Mixte/Téléinformatique) est
donc considéré comme validé de bout en bout sur matériel réel.

Reste ouvert (indépendant de ce modèle) : le doublage de caractères observé
en séquence 1 lors des tout premiers tests, et la question BASTOS sur
l'état de boot (Videotex ou Mixte) — voir sections ci-dessus.

## Cause réelle du doublage de caractères : trouvée (capture `sonytel.vdt`)

Analyse de la capture Videotex `sonytel.vdt` (session Minipavi → SonyTel,
tout en 40 colonnes, aucune séquence Mixte/Téléinformatique) : le doublage
observé n'a **rien à voir** avec le modèle Videotex/Mixte/Téléinformatique
— c'est un bug séparé, dans la gestion `PRO3` de l'aiguillage clavier↔modem.

- `PRO3 61 (a) Z Q` (`1B 3B 61 5A 51`, « aiguillage rétabli ») apparaît dans
  la capture juste avant que SonyTel n'entre dans son contenu interactif.
- Le code de l'émulateur (`lib/min_emulator.dart`, gestion `kStatePro3`)
  associait *aiguillage ON → écho local ON* — l'inverse de la logique
  réelle : aiguillage coupé (clavier déconnecté du modem) doit activer
  l'écho local (aucun autre moyen de voir ce qu'on tape), aiguillage
  rétabli (fonctionnement normal, le serveur échoue) doit le couper.
- **Corrigé** : `isEchoed = !_isPro3On` au lieu de `isEchoed = _isPro3On`.
  Test de régression ajouté avec les octets exacts de la capture
  (`test/min_emulator_teleinfo_test.dart`).

## Bug du passage 80 colonnes non détecté : trouvé (capture `sonytel-rtc.vdt`)

Analyse de la capture `sonytel-rtc.vdt` (session RTC → serveur BBS listant
des micro-serveurs) : le rapport était double — pas de passage en 80
colonnes visible, et la liste s'affichait en caractères G1 (mosaïque) au
lieu de l'ASCII attendu. Un seul bug racine explique les deux symptômes.

- Le serveur envoie `SEP p` (`0x13 0x70`) pour passer directement en Mixte
  — **sans** passer par `PRO2 32 7D`. Cette commande, pourtant déjà
  documentée dans `docs/SEQUENCES-STANDARD.md`, n'était jamais implémentée :
  `case $sep:` dans la boucle principale de `emulate()` jetait purement et
  simplement l'octet suivant (`stateCode = 0; break;`).
- Conséquence en cascade : l'émulateur restant en Videotex 40 colonnes, le
  `SO` (0x0E) envoyé ensuite par le serveur était traité par le handler
  Videotex standard (`fadr[0x0E] = setG1Charset`), qui bascule
  `state.charset` vers G1 pour de vrai — d'où le texte de la liste rendu en
  mosaïque. Ce n'est **pas** un bug séparé du décodeur Téléinformatique :
  une fois le mode Mixte activé au bon moment, le même `SO` est traité par
  `_handleTeleinfoControl` (chemin ISO 6429), où `state.charset` est mis à
  jour mais n'est jamais appliqué au caractère écrit (`_putCharTeleinfo` ne
  lit pas `state.charset`) — donc aucun effet visuel, texte ASCII correct.
- **Corrigé** (`lib/min_emulator.dart`) :
  - `case $sep:` (boucle principale, mode Videotex) traite maintenant
    `0x70` → `enterMixte()` et `0x71` → retour Videotex.
  - Ajout du même traitement côté Téléinformatique/Mixte
    (`_handleTeleinfoControl` + nouvel état `kStateTeleinfoSep` +
    `_handleTeleinfoSep`), pour le cas où `SEP p/q` arrive alors qu'on est
    déjà en 80 colonnes.
- Tests de régression ajoutés dans `test/min_emulator_teleinfo_test.dart`
  reproduisant l'ordre exact de la capture (`SEP p` puis `SO` puis texte).

## BASTOS : MODE 3 = Téléinformatique 80 colonnes implémenté (session `minwifi-esp01-a1`)

MODE 3 est maintenant un mode de premier rang côté BASTOS (au même titre
que MODE 0/1/2), plus seulement une cible de script de test ad hoc.

- Entrée `PRO2 31 7D` (test #1) / sortie `CSI ?{` (test #4) — confirmés.
- Nouveaux champs `current_mode`/`saved_mode` (BASTOS) : MODE 3 mémorise le
  mode précédent (0/1/2) ; comme le Protocole est gelé en Téléinformatique,
  tout appel `MODE x` pendant qu'on est en MODE 3 envoie d'abord `CSI ?{`
  avant de continuer — que `x` soit 3 (retour au mode mémorisé) ou une
  destination explicite. Évite le piège où un `MODE 1` direct depuis MODE 3
  ne ferait rien sur le vrai terminal (Protocole gelé) alors que BASTOS
  penserait avoir réussi.
- `CODE_SEQUENCE_MAX_SIZE` passé de 32 à 40 (marge pour `CSI ?{` + relance
  de `MODE_INIT_STRING`).
- Suite de 272 tests + builds croisés Linux/Windows/ESP32/ESP8266 : verts.
- Corrigé au passage : mislabeling préexistant dans les manuels BASTOS
  ("MODE 2 = Téléinformatique" — c'est en fait Mixte, cf. synthèse
  ci-dessus).
- MODE 1 (`PRO2 32 7E`) : sémantique **inchangée**, toujours du vrai
  Videotex (cf. section précédente) — confirmé ne pas avoir été touché par
  ce travail.
- Écho à l'entrée : **fait**. `P_TELEINFO_80` (`PRO2 31 7D`) est maintenant
  immédiatement suivi de `CSI 12 h` (`ESC[12h`) dans une seule séquence
  combinée à l'entrée de MODE 3. Vérifié octet à octet côté interprète
  BASTOS : `ESC:1}` puis `ESC[12h`.
- Écho à la sortie : **volontairement pas touché**. Deux raisons données
  par `minwifi-esp01-a1` : on ne sait pas si `CSI ?{` restaure l'écho tel
  que laissé par le PRO3 aiguillage, tel que laissé par `CSI 12 h`, ou un
  autre défaut — et empiler une deuxième hypothèse non vérifiée par-dessus
  la première (déjà corrigée une fois côté minterm à tort) serait risqué
  sans donnée M2 réelle. À noter : `P_LOCAL_ECHO_OFF` fait déjà partie de
  `MODE_INIT_STRING` pour MODE 1, mais MODE 0/2 n'envoient rien côté écho —
  donc un retour vers MODE 0/2 depuis MODE 3 est le cas le plus à risque.

**Point ouvert (échangé avec `minwifi-esp01-a1`)** : les bugs d'écho
corrigés côté minterm (inversion PRO3, `SEP p/q`) concernent uniquement
minterm-en-tant-que-client connecté à de vrais serveurs Videotex en ligne
(captures `sonytel*.vdt`) — **minterm n'est pas dans la boucle** des tests
BASTOS sur M2 réel (câblage direct M2↔BASTOS). Le doublement de caractères
initialement observé en Téléinformatique (section « Remarques » /
Séquence 1 ci-dessus) est donc un vrai problème d'écho matériel M2, non
résolu par les correctifs minterm.

**À tester sur M2 réel (reste ouvert)** : entrer en MODE 3 (écho `CSI 12 h`
envoyé), taper du texte pour confirmer que le doublement a disparu, puis
sortir vers MODE 0/1/2 et vérifier l'état de l'écho à l'arrivée — en
particulier le retour vers MODE 0/2 (aucune commande écho envoyée par ces
modes). Si l'écho revient dans un mauvais état, corriger soit par un
`CSI 12 l` juste avant la sortie de MODE 3, soit en s'appuyant sur la
commande écho déjà envoyée par le mode restauré (MODE 1 seulement, pour
l'instant).

### Contre-vérification indépendante minterm ↔ BASTOS (5 séquences réelles)

À la demande de `minwifi-esp01-a1` (qui n'a pas d'accès direct à minterm),
les 5 séquences exactes émises par `bastos-linux-amd64` ont été rejouées
octet pour octet dans `TMinitel.emulate()` avant toute session M2 réelle,
pour comparer deux implémentations indépendantes du même modèle à 3 états.

| # | Séquence | Résultat minterm | Attendu BASTOS |
|---|---|---|---|
| 1 | `PRO2 32 7D` depuis Videotex | Mixte, 80 col | Mixte, 80 col — ✅ |
| 2 | `PRO2 31 7D` + `CSI 12h` (un seul envoi) depuis Mixte | Téléinfo, 80 col, écho **off** | idem — ✅ |
| 3 | `CSI ?{` + `PRO2 32 7D` (retour Mixte) | Mixte, 80 col, écho off (hérité) | Mixte, 80 col — ✅ |
| 4 | `CSI ?{` + `PRO2 32 7E` (retour MODE 0) | Videotex 40 col, écho off (hérité) | Videotex 40 col — ✅ |
| 5 | `CSI ?{` + `MODE_INIT_STRING` complet (retour MODE 1) | Videotex 40 col, écho **on** | idem — ✅ |

Les 5 atterrissages concordent avec le suivi d'état interne de BASTOS.
Bonus : ce test confirme aussi, au niveau protocole (pas juste supputé),
que ni `CSI ?{` ni `PRO2 32 7D/7E` ne touchent à l'écho — seuls le PRO3
aiguillage et `CSI 12 h/l` le font. Donc le retour d'écho resté « off »
aux tests #3/#4 n'est pas un hasard : c'est la conséquence directe et
inévitable du fait que MODE 0/2 n'envoient rien côté écho. Reste
néanmoins à confirmer sur le vrai M2 que le matériel suit bien la même
règle (cf. point ouvert ci-dessus) — ce test ne couvre que le modèle
protocolaire, pas le firmware M2 lui-même.

**Correction sur le test #5** : le résultat « écho on » a d'abord semblé
indiquer que la constante BASTOS `P_LOCAL_ECHO_OFF` (`PRO3 60 5A 51`,
aiguillage Clavier↔Modem coupé) serait mal nommée/inversée. Après examen,
c'est en fait une **limitation de la modélisation minterm**, pas un bug
BASTOS : `MODE_INIT_STRING` envoie juste avant (`PRO2 64 53`) une
restriction des acquittements protocole au module **Prise** (`53` = code
« ce » de Prise) — preuve que BASTOS est relié par la Prise, pas par le
Modem interne. Le STUM 1B documente Clavier↔Modem et Clavier↔Prise comme
deux aiguillages indépendants (mêmes commandes PRO3 60/61, arguments `cr,ce`
différents) ; couper Clavier↔Modem ne devrait donc rien changer à l'écho
réel d'une session reliée par la Prise. Mais minterm ne modélise qu'un seul
drapeau global d'écho, qui ne réagit qu'à la paire d'octets exacte
Modem(`5A`)+Clavier(`51`) (`kStatePro3+2` dans `lib/min_emulator.dart`) —
il ne distingue donc pas « aiguillage Modem, pertinent » de « aiguillage
Modem envoyé mais sans rapport avec la connexion réelle (Prise) ». Le
résultat « echo on » du test #5 est donc un artefact de cette
simplification, pas une preuve que `P_LOCAL_ECHO_OFF` inverse l'écho sur
vrai M2. **Pas de changement recommandé côté BASTOS** sur la base de ce
signal ; limitation notée côté minterm (pas de suivi d'aiguillage par
module) pour amélioration future éventuelle, hors périmètre BASTOS.
