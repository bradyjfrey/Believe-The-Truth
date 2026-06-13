"""Generate a seamless 45-degree diagonal stripe tile for the killer-select card background.

Matches the mockup's CSS:
    repeating-linear-gradient(45deg, #120a0e 0 14px, #160d12 14px 28px)

A 45-degree stripe's color depends on (x + y). We pick a period that divides the tile size so
the pattern wraps seamlessly when Roblox tiles it (ScaleType = Tile).

Run:  python3 mockups/generate-card-stripes.py
Out:  mockups/card-stripes.png   (upload to Roblox, then point the portrait ImageLabel at the asset)
"""

from PIL import Image

TILE = 128          # tile is TILE x TILE pixels; tiles seamlessly because PERIOD divides TILE
PERIOD = 64         # full light+dark cycle, measured along the x+y diagonal
DARK  = (18, 10, 14)   # #120a0e
LIGHT = (24, 14, 20)   # slightly lifted from the mockup's #160d12 so the stripes actually read

img = Image.new("RGB", (TILE, TILE))
px = img.load()
for y in range(TILE):
    for x in range(TILE):
        # Which half of the cycle are we in along the diagonal?
        px[x, y] = LIGHT if ((x + y) % PERIOD) < (PERIOD // 2) else DARK

out = __file__.rsplit("/", 1)[0] + "/card-stripes.png"
img.save(out)
print("wrote", out, img.size)
