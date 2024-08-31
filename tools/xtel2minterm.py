#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from bdfparser import Font, Bitmap, Glyph
from PIL import Image

# Do not consider this file: 'g28x10.bdf'

for file in ['g08x10.bdf', 'g18x10.bdf']:
    # Load the font
    font = Font(file)
    width = font.headers['fbbx']
    height = font.headers['fbby']

    # Print some information
    print(f"The '{file}' font's global size is "
        f"{font.headers['fbbx']} x {font.headers['fbby']} pixels, "
        f"it contains {len(font)} glyphs.")

    columns = []
    column = []
    for cp in range(0, 128):
        if (cp not in font.glyphs):
            glyph: Glyph = font.glyphbycp(0x20)
            print(f"Glyph for codepoint {cp} is not available, fallback to space (0x20).")
        else:
            glyph: Glyph = font.glyphbycp(cp)
            print(f'Glyph for codepoint {cp} exists.')
        # end if

        # Draw the glyph
        bitmap: Bitmap = glyph.draw()

        # Add bitmap in the current column
        column.append(bitmap)

        if (len(column) == 16):
            # Add column to the list of columns
            columns.append(Bitmap.concatall(column, direction=0))
            column = []
        # end if
    # end for

    if (file == 'g08x10.bdf'):
        # Compute the 16 accented characters "àèùéâêîôûäëïöüçÇ" and assign them
        # to 0x80 to 0x8F
        column = []
        # Compose letters "aeu" with grave accent (0x0B) and define new glyphs
        # 0x80 to 0x82
        accent = font.glyphbycp(0x0B)
        for cp, letter in zip([0x80, 0x81, 0x82], 'aeu'):
            glyph: Glyph = font.glyph(letter)
            bitmap: Bitmap = glyph.draw().overlay(accent.draw())
            column.append(bitmap)
        # end for

        # Compose letter "e" with acute accent (0x0C) and define the new glyph
        # 0x83
        accent = font.glyphbycp(0x0C)
        glyph: Glyph = font.glyph('e')
        bitmap: Bitmap = glyph.draw().overlay(accent.draw())
        column.append(bitmap)

        # Compose letters "aeiou" with circumflex accent (0x0D) and define new
        # glyphs 0x84 to 0x88
        accent = font.glyphbycp(0x0D)
        for cp, letter in zip([0x84, 0x85, 0x86, 0x87, 0x88], 'ae\x19ou'):
            glyph: Glyph = font.glyph(letter)
            bitmap: Bitmap = glyph.draw().overlay(accent.draw())
            column.append(bitmap)
        # end for

        # Compose letters "aeiou" with diaeresis (0x0E) and define new glyphs
        # 0x89 to 0x8D
        accent = font.glyphbycp(0x0E)
        for cp, letter in zip([0x89, 0x8A, 0x8B, 0x8C, 0x8D], 'ae\x19ou'):
            glyph: Glyph = font.glyph(letter)
            bitmap: Bitmap = glyph.draw().overlay(accent.draw())
            column.append(bitmap)
        # end for

        # Compose letter "c" with cedilla (0x0F) and define the new glyph 0x8E
        accent = font.glyphbycp(0x0F)
        glyph: Glyph = font.glyph('c')
        bitmap: Bitmap = glyph.draw().overlay(accent.draw())
        column.append(bitmap)

        # Compose letter "C" with cedilla (0x0F) and define the new glyph 0x8F
        accent = font.glyphbycp(0x0F)
        glyph: Glyph = font.glyph('C')
        bitmap: Bitmap = glyph.draw().overlay(accent.draw())
        column.append(bitmap)

        # Add column to the list of columns
        columns.append(Bitmap.concatall(column, direction=0))
    # end if

    alls: Bitmap = Bitmap.concatall(columns, direction=1)
    print('Bitmap size is', alls.width(), 'x', alls.height(), 'pixels.')

    # Convert the bitmap to an image
    image: Image = Image.frombytes('RGBA', (alls.width(), alls.height()), alls.tobytes('RGBA'))

    # Remove font extension from the filename and add save as .png
    image.save('../assets/' + file.replace('.bdf', '.png'))
# end for
