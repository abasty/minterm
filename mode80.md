# mode 80 colonnes

## Spécificités rendu graphique

- La lettre F/C en ligne 0 n'est pas en video inverse
- Le curseur est clignotant et représenté par un trait de soulignement sous le
  caractère
- Le déplacement curseur en ligne 0 est réalisé par la même séquence qu'en 40
  colonnes. '\n' permet de sortir de la ligne 0. Il y a sauvegarde et
  restitution du contexte, comme en mode 40 colonnes
- Le déplacement curseur ailleurs qu'en ligne 0 est assurée par la séquence :
  CSI Pr 3/B Pc 4/8
- La séquence


## Codes C0

| Séquence | Interprétations | (1) | (2) | (3) |
| :--- | :--- | :---: | :---: | :---: |
| 0/0 | NUL : Caractère de bourrage ignoré par l'écran | ● | ● | ● |
| 0/7 | BEL : Provoque un signal sonore d'une durée de 0,75 s non cumulable | ● | ● | ● |
| 0/8 | BS : Déplacement du curseur d'une position vers la gauche sans débordement | | ● | ● |
| 0/9 | HT : Déplacement du curseur sans débordement | | ● | ● |
| 0/A | LF : Saut d'une rangée ; le débordement en rangée 24 est conditionné par le mode page | ● | ● | ● |
| 0/B | VT : Effet identique à LF | | ● | ● |
| 0/C | FF : Effet identique à LF | | ● | ● |
| 0/D | CR : Retour chariot ; le curseur est positionné en colonne 0 de la rangée courante | ● | ● | ● |
| 0/E | SO : Passage en jeu G1 | ● | ● | ● |
| 0/F | SI : Passage en jeu G0 | ● | ● | ● |
| 1/1 | Con : Ignoré | ● | | |
| 1/2 | REP : Ignoré | ● | | |
| 1/3 | SEP : Ignoré | ● | | |
| 1/4 | Coff : Ignoré | ● | | |
| 1/8 | CAN : Affichage du caractère de substitution (pavé plein) | | ● | ● |
| 1/F | US : Ignorée sauf pour ligne 0 (déplacement curseur)

# Curseur

| Séquence | Interprétations | (1) | (2) | (3) |
| :--- | :--- | :---: | :---: | :---: |
| CSI 3/1 3/2 6/C | Mise en marche de l'écho local | | | ■ |
| CSI 3/1 3/2 6/8 | Mise en arrêt de l'écho local | | | ■ |
| CSI 3/C 3/1 6/C | Allumage du curseur | | ■ | ■ |
| CSI 3/C 3/1 6/8 | Arrêt du curseur | | ■ | ■ |
