"""Bake the "CHOOSE YOUR YOKAI" title into a transparent PNG in Cinzel Decorative.

Roblox can't use custom fonts in published games, but it CAN use uploaded images. The title is fixed
text, so we render it once here (exact font) and use it as an ImageLabel in the picker.

Run:  python3 mockups/generate-title-image.py
Out:  mockups/title-choose-your-yokai.png   (upload via Asset Manager -> Images)
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter

FONT_PATH = "/Users/bradyfrey/Downloads/Cinzel_Decorative,Open_Sans/Cinzel_Decorative/CinzelDecorative-Black.ttf"
SIZE      = 160                      # render big; Roblox scales it down crisply
TRACKING  = int(SIZE * 0.08)         # letter-spacing (mockup used ~5px at 46px)
PAD       = 60                       # room around the text for the glow

INK  = (243, 233, 236, 255)          # #f3e9ec  "CHOOSE YOUR"
RED  = (255, 59, 65, 255)            # #ff3b41  "YOKAI" + the glow

# Each (text, color) segment, drawn left to right. Trailing space keeps the gap before YOKAI.
SEGMENTS = [("CHOOSE YOUR ", INK), ("YOKAI", RED)]

font = ImageFont.truetype(FONT_PATH, SIZE)
ascent, descent = font.getmetrics()

# Flatten to a list of (char, color) so we can letter-space every glyph.
chars = [(c, color) for text, color in SEGMENTS for c in text]

# Total width = sum of glyph advances + tracking between glyphs.
total_w = 0
for i, (c, _) in enumerate(chars):
    total_w += font.getlength(c)
    if i < len(chars) - 1:
        total_w += TRACKING

W = int(total_w) + PAD * 2
H = ascent + descent + PAD * 2
baseline = PAD + ascent

def draw_text(layer, fill_override=None):
    d = ImageDraw.Draw(layer)
    x = PAD
    for c, color in chars:
        d.text((x, baseline), c, font=font, fill=(fill_override or color), anchor="ls")
        x += font.getlength(c) + TRACKING

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

# Soft red glow behind everything (mockup: text-shadow 0 0 18px rgba(255,59,65,.35)).
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
draw_text(glow, fill_override=RED)
glow = glow.filter(ImageFilter.GaussianBlur(SIZE * 0.07))
# Knock the glow back so it reads as a halo, not a second copy.
alpha = glow.split()[3].point(lambda a: int(a * 0.45))
glow.putalpha(alpha)
img.alpha_composite(glow)

# The real two-color text on top.
draw_text(img)

out = __file__.rsplit("/", 1)[0] + "/title-choose-your-yokai.png"
img.save(out)
print("wrote", out, img.size)
