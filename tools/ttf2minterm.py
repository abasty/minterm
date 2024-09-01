#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from PIL import ImageFont, ImageDraw, Image

x_size = 64
y_size = 160

font_size = 8

imageFont = ImageFont.truetype('Minitel.ttf', font_size)
print(imageFont)

image = Image.new(mode='RGBA', size=(x_size, y_size))
draw = ImageDraw.Draw(image, mode='RGBA')

text = '£\u2190\u2191\u2192\u2193°\u00B1\u00F7\u00BC\u00BD\u00BE\u0152\u0153\u00DF\u00A7'
for letter, y in zip(text, range(0, 16)):
    draw.text((0, y * 10), letter, font=imageFont, spacing=0, fill='black')
# end for

text = 'àèùéâêîôûäëïöüçC'
for letter, y in zip(text, range(0, 16)):
    draw.text((8, y * 10), letter, font=imageFont, spacing=0, fill='black')
# end for

# Draw a cedilla at 11, 158 on "C"
draw.point([11, 158], fill='black')
draw.point([10, 159], fill='black')

text = ' !"#$%&\'()*+,-./'
for letter, y in zip(text, range(0, 16)):
    draw.text((16, y * 10), letter, font=imageFont, spacing=0, fill='black')
# end for

text = '0123456789:;<=>?'
for letter, y in zip(text, range(0, 16)):
    draw.text((24, y * 10), letter, font=imageFont, spacing=0, fill='black')
# end for

text = '@ABCDEFGHIJKLMNO'
for letter, y in zip(text, range(0, 16)):
    draw.text((32, y * 10), letter, font=imageFont, spacing=0, fill='black')
# end for

text = 'PQRSTUVWXYZ[\\]^_'
for letter, y in zip(text, range(0, 16)):
    draw.text((40, y * 10), letter, font=imageFont, spacing=0, fill='black')
# end for

text = '\u2212abcdefghijklmno'
for letter, y in zip(text, range(0, 16)):
    draw.text((48, y * 10), letter, font=imageFont, spacing=0, fill='black')
# end for

text = 'pqrstuvwxyz |   '
for letter, y in zip(text, range(0, 16)):
    draw.text((56, y * 10), letter, font=imageFont, spacing=0, fill='black')
# end for

# Draw a left bar at (56, 110) with a height of 10 pixels
draw.rectangle([56, 110, 56, 119], fill='black')

# Draw a right bar at (63, 130) with a height of 10 pixels
draw.rectangle([63, 130, 63, 139], fill='black')

# Draw a top bar at (56, 140) with a height of 10 pixels
draw.rectangle([56, 140, 63, 140], fill='black')

# Draw a block at (56, 150) with a height of 10 pixels
draw.rectangle([56, 150, 63, 159], fill='black')

# Save the image
image.save('../assets/g0g2.png')
