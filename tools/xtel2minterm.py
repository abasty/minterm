#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from bdfparser import Font, Bitmap, Glyph
from PIL import Image

# Do not consider file 'g28x10.bdf', use Minitel.ttf instead

file = 'g18x10.bdf'

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
        print(f"Glyph for codepoint {cp} is not available, generate space char at #{cp}.")
    else:
        glyph: Glyph = font.glyphbycp(cp)
        print(f'Generate char #{cp}.')
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

alls: Bitmap = Bitmap.concatall(columns, direction=1)
print('Bitmap size is', alls.width(), 'x', alls.height(), 'pixels.')

# Convert the bitmap to an image
image: Image = Image.frombytes('RGBA', (alls.width(), alls.height()), alls.tobytes('RGBA'))

# Remove font extension from the filename and add save as PNG
image.save('../assets/g1.png')
