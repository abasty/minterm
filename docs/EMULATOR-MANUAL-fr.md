# Manuel d'utilisation — Minterm

Minterm est un émulateur de terminal Minitel. Il reproduit les deux modes
d'affichage du Minitel :

- **Videotex, 40 colonnes** — le mode Minitel classique (Vidéotex, jeux de
  caractères G0/G1/G2, couleurs, semi-graphique).
- **Téléinformatique, 80 colonnes** — un mode texte façon VT100/ANSI, utilisé
  par certains services et par les Minitel 1B et supérieurs.

Il peut se connecter à un service Minitel en ligne — WebSocket (toutes
plateformes) ou TCP (desktop et applications mobiles, pas en web) —, ou à un
dispositif branché en port série (desktop uniquement).

## Sommaire

- [Se connecter à un service](#se-connecter-à-un-service)
- [Basculer entre les deux modes d'écran](#basculer-entre-les-deux-modes-décran)
- [Le clavier](#le-clavier)
- [Affichage](#affichage)
- [Plein écran](#plein-écran)
- [Capture et relecture d'une session](#capture-et-relecture-dune-session)
- [Menu et autres réglages](#menu-et-autres-réglages)
- [Annexe : table des touches spéciales](#annexe--table-des-touches-spéciales)

## Se connecter à un service

Le menu (icône ☰ en haut à gauche) liste vos connexions récentes, prêtes à
relancer d'un tap. Un choix de services connus est proposé par défaut : 3611,
3615, Minipavi, Hacker, Galaxy...

Pour ajouter, modifier, dupliquer, réordonner ou supprimer une connexion,
ouvrez **Autre... → Gérer toutes les connexions**. Chaque connexion est
définie par :

- un **nom** ;
- une **URL**, sous la forme `ws://hôte/chemin`, `wss://hôte/chemin` (WebSocket
  sécurisé) ou `tcp://hôte:port` (TCP direct, indisponible en web) ;
- l'option **Vérifier Sec-WebSocket-Accept** (connexions WebSocket
  uniquement) : à décocher si un service ne renvoie pas correctement cet
  en-tête lors de l'établissement de la connexion (certains serveurs de test
  ou passerelles non strictement conformes).

La liste des connexions peut être exportée/importée au format JSON (icônes en
haut de l'écran de gestion), pratique pour la transférer d'un appareil à
l'autre.

**Vitesse (bps)** — dans le menu, l'entrée **Speed** fait défiler les vitesses
disponibles (300, 1200, 4800, 9600, ou *max*), pour simuler un Minitel plus
lent ou laisser filer la connexion à sa vitesse réelle. Le service connecté
peut aussi commander ce changement lui-même par une commande protocole ; dans
ce cas l'entrée Speed se met à jour automatiquement pour refléter la vitesse
demandée.

### Port série (dispositif physique)

Sur Linux desktop, l'entrée **Serial ports** du menu liste les ports série
disponibles (adaptateur USB-série relié à un vrai Minitel, par exemple).
Sélectionner un port l'ouvre en lecture/écriture à la place d'une connexion
réseau.

Dans ce cas, l'entrée **Speed** du menu configure aussi la vitesse (bps) du
port série lui-même : à régler avant de se connecter au port. Si le
dispositif connecté demande ensuite un changement de vitesse par commande
protocole, le port série est reconfiguré automatiquement à la nouvelle
vitesse.

## Basculer entre les deux modes d'écran

L'entrée **Mode écran** du menu bascule manuellement entre **Minitel 40**
(Videotex) et **Téléinfo 80** (Téléinformatique). Le service auquel vous êtes
connecté peut aussi demander ce changement automatiquement (séquence
protocole), l'émulateur suit alors la demande.

Passer en 80 colonnes configure le clavier en minuscules par défaut (comme
sur un Minitel 1B) ; repasser en 40 colonnes remet le clavier en majuscules
seules et éteint le curseur, comme sur un Minitel classique.

## Le clavier

### Clavier virtuel

Sur mobile, l'icône clavier de la barre d'outils fait défiler trois modes :
clavier bitmap (image d'un clavier Minitel), clavier virtuel + zone de saisie
compacte (pratique pour la saisie au clavier tactile du système), ou clavier
compact seul.

Sur desktop web/natif, la même icône bascule entre le clavier **bitmap**
(image) et le clavier **compact** (boutons). Le clavier bitmap comporte ses
propres touches **Ctrl** et **Shift**, qui fonctionnent comme des *bascules* :
on appuie dessus, puis sur la touche à combiner ; un petit indicateur rond
s'allume sur la touche tant qu'elle est active.

### Clavier physique (PC)

Le clavier physique de l'ordinateur est directement utilisable, avec les
correspondances suivantes vers les touches fonctionnelles du Minitel :

| Touche PC | Fonction Minitel |
|---|---|
| Flèche haut / bas / gauche / droite | Déplacement du curseur |
| Retour arrière (Backspace) | Correction |
| Entrée | Envoi (40 colonnes) / retour chariot (80 colonnes) |
| Origine (Home) | Sommaire |
| Page suivante / précédente | Suite / Retour |
| F1 | Guide |
| Échap | Échap |
| Ctrl+A | Annulation |
| Ctrl+C | Cx/Fin (40 colonnes) / interruption (80 colonnes) |
| Ctrl+G | Bip |

Les accents et caractères spéciaux du clavier Minitel sont produits à partir
des touches mortes/lettres du clavier français : `à`, `é`, `è`, `ù`, `ç`, `Ç`,
`£`, `§`, `°`.

### Touches d'édition avancées

Combinées à **Shift**, les flèches déclenchent les fonctions d'édition ligne
et caractère, disponibles aussi bien en 40 qu'en 80 colonnes, au clavier
physique comme sur le clavier bitmap :

| Combinaison | Effet |
|---|---|
| Shift + ↑ | Suppression de ligne |
| Shift + ↓ | Insertion de ligne |
| Shift + ← | Suppression de caractère |
| Shift + → | Bascule mode insertion caractère (les caractères tapés ensuite décalent le reste de la ligne au lieu de l'écraser) |

## Affichage

- **Couleurs** (icône palette) : bascule entre l'affichage couleur normal et
  un rendu en niveaux de gris.
- **Fond** (icône soleil/lune) : bascule le fond de l'application entre
  blanc et noir.
- L'écran et le clavier se redimensionnent automatiquement à la taille de la
  fenêtre.

## Plein écran

Le comportement diffère selon la plateforme :

- **Desktop (Linux, Windows, macOS)** : une icône plein écran est présente
  dans la barre d'outils. Elle bascule la fenêtre de l'application en plein
  écran, géré directement par l'application.
- **Web** : il n'y a pas d'icône dédiée — c'est le navigateur qui gère son
  propre plein écran. Utilisez **F11** pour entrer ou sortir du plein écran :
  c'est **le seul moyen d'en sortir**. Échap ne fait pas sortir du plein
  écran (F11 bascule le plein écran du navigateur lui-même — barre d'adresse
  et onglets masqués —, un mode invisible pour la page qu'aucun site ne peut
  fermer via Échap, contrairement au plein écran déclenché par une page web
  via l'API Fullscreen, que Minterm n'utilise plus). Échap reste en revanche
  transmise normalement au service connecté, comme n'importe quelle autre
  touche.

## Capture et relecture d'une session

Le menu et la barre d'outils proposent d'enregistrer une session :

- **Capture** (icône ●) : démarre/arrête l'enregistrement de tout ce qui
  s'affiche à l'écran dans un fichier au format `.vdt` (format Videotex,
  compatible avec d'autres outils Minitel).
- **Replay capture** (icône ▶) : rejoue la dernière capture enregistrée,
  caractère par caractère. Pendant la relecture, appuyer sur n'importe quelle
  touche ou toucher l'écran met en pause (bandeau rouge affiché) ; retoucher
  reprend la lecture, **Échap** l'arrête.
- **Import capture** / **Export capture** : charger un fichier `.vdt`
  existant ou sauvegarder la capture courante sur le disque (ou en
  téléchargement, en mode web).

La capture et la relecture sont mutuellement exclusives : on ne peut pas
lancer une relecture pendant qu'une capture est active.

## Menu et autres réglages

- **Clear** : ferme la connexion en cours, efface l'écran et repositionne le
  curseur, avec un signal sonore.
- Un bip sonore accompagne chaque frappe de touche et les cloches (`BEL`)
  envoyées par le service distant.

## Annexe : table des touches spéciales

Séquences envoyées par les touches d'édition (identiques en 40 et 80
colonnes) :

| Touche | Séquence (hexadécimal) |
|---|---|
| Suppression de ligne (Shift+↑) | `1B 5B 4D` (`ESC [ M`) |
| Insertion de ligne (Shift+↓) | `1B 5B 4C` (`ESC [ L`) |
| Suppression de caractère (Shift+←) | `1B 5B 50` (`ESC [ P`) |
| Mode insertion ON (Shift+→, bascule) | `1B 5B 34 68` (`ESC [ 4 h`) |
| Mode insertion OFF (Shift+→, bascule) | `1B 5B 34 6C` (`ESC [ 4 l`) |

## Liens utiles

- [Micro-serveur Minitel — Wikipédia](https://fr.wikipedia.org/wiki/Micro-serveur_Minitel)
- [Spécification STUM1B (archive.org)](https://archive.org/details/minitel-stum1b/page/n39/mode/1up?view=theater)
