#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Génère les variantes du jeu G0 pour le standard Télétel mode Mixte et le
standard Téléinformatique (STUM2 §3.1/§3.2).

Le G0 Videotex (assets/g0g2.png, généré par ttf2minterm.py) ne correspond
pas au jeu Américain de la norme ISO 646/STUM2 §3.10 sur 6 positions —
celles-ci ont été redéfinies pour des besoins spécifiques au Videotex :

    0x5E '^' -> flèche haut, 0x60 '`' -> barre, 0x7B '{' -> barre verticale,
    0x7C '|' -> vide, 0x7D '}' -> vide, 0x7E '~' -> vide

(0x7F reste correctement un pavé plein, qui correspond à DEL dans le jeu
Américain — inchangé.)

Ce script part de g0g2.png, ne repeint que ces 6 cellules 8x10 avec les
glyphes ASCII attendus, et produit :
  - assets/g0_american.png : le jeu Américain complet.
  - assets/g0_french.png : pour l'instant une copie identique de l'Américain
    (TODO : à patcher avec la vraie table du jeu Français, STUM 1B p.164/171,
    non retrouvée sous forme exploitable à ce jour — voir STUM2.md §3.11,
    tronqué dans la conversion PDF->Markdown de ce repo).
"""

from PIL import Image

ATLAS_WIDTH = 64
CELL_W = 8
CELL_H = 10


def cell_origin(code):
    return (code // 16) * CELL_W, (code % 16) * CELL_H


# Un octet par ligne, bit de poids fort = colonne de gauche (8 colonnes).
# Chaque glyphe : 10 octets (lignes 0-9 de la cellule 8x10).
AMERICAN_PATCHES = {
    0x5E: [0b00010000,  # '^'
           0b00101000,
           0b01000100,
           0, 0, 0, 0, 0, 0, 0],
    0x60: [0b00110000,  # '`'
           0b00001100,
           0, 0, 0, 0, 0, 0, 0, 0],
    0x7B: [0,            # '{'
           0b00011100,
           0b00010000,
           0b00010000,
           0b00100000,
           0b00010000,
           0b00010000,
           0b00011100,
           0, 0],
    0x7C: [0b00010000] * 10,  # '|' : barre verticale pleine hauteur
    0x7D: [0,            # '}'
           0b01110000,
           0b00010000,
           0b00010000,
           0b00001000,
           0b00010000,
           0b00010000,
           0b01110000,
           0, 0],
    0x7E: [0, 0, 0,      # '~'
           0b01100100,
           0b10011000,
           0, 0, 0, 0, 0],
}


def apply_patches(img, patches):
    px = img.load()
    for code, rows in patches.items():
        gx, gy = cell_origin(code)
        for row, bits in enumerate(rows):
            for col in range(CELL_W):
                on = (bits >> (CELL_W - 1 - col)) & 1
                px[gx + col, gy + row] = (0, 0, 0, 255 if on else 0)


def main():
    base = Image.open('../assets/g0g2.png').convert('RGBA')

    american = base.copy()
    apply_patches(american, AMERICAN_PATCHES)
    american.save('../assets/g0_american.png')
    print("Wrote assets/g0_american.png")

    # Placeholder : identique à l'Américain en attendant la vraie table.
    french = american.copy()
    french.save('../assets/g0_french.png')
    print("Wrote assets/g0_french.png (placeholder, identique à l'Américain)")


if __name__ == '__main__':
    main()
