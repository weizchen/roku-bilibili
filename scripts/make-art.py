"""Render the channel icons, splash and UI chrome into channel/images.

    tools/.venv/bin/python scripts/make-art.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "channel" / "images"
OUT.mkdir(parents=True, exist_ok=True)
PINK = (251, 114, 153)
BG = (15, 15, 20)
CJK = "/System/Library/Fonts/Hiragino Sans GB.ttc"


# palettes for the mascot: the app's pink one, and a grey one for image placeholders
DOG = {"head": PINK, "ear": (217, 87, 126), "patch": (232, 98, 138), "muzzle": (255, 214, 226),
       "ink": (38, 22, 30), "tongue": (255, 79, 123), "shine": (255, 255, 255)}
DOG_GREY = {"head": (70, 70, 84), "ear": (58, 58, 70), "patch": (63, 63, 76), "muzzle": (88, 88, 102),
            "ink": (40, 40, 50), "tongue": (80, 80, 94), "shine": (100, 100, 114)}


def dog(size: int, pal=DOG) -> Image.Image:
    """The 狗哩狗哩 mascot: a floppy-eared puppy face, drawn on a 1000-unit grid at 4x and shrunk."""
    S = size * 4
    k = S / 1000

    def box(x0, y0, x1, y1):
        return [x0 * k, y0 * k, x1 * k, y1 * k]

    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # ears hang from the top of the head, tilted outwards
    for cx, angle in ((262, -22), (738, 22)):
        layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        ImageDraw.Draw(layer).ellipse(box(cx - 118, 300, cx + 118, 730), fill=pal["ear"])
        img = Image.alpha_composite(img, layer.rotate(angle, center=(cx * k, 330 * k), resample=Image.BICUBIC))
    d = ImageDraw.Draw(img)
    d.ellipse(box(215, 245, 785, 800), fill=pal["head"])
    d.ellipse(box(545, 368, 705, 535), fill=pal["patch"])
    d.ellipse(box(345, 548, 655, 772), fill=pal["muzzle"])
    for ex in (395, 605):
        d.ellipse(box(ex - 40, 430, ex + 40, 510), fill=pal["ink"])
        d.ellipse(box(ex - 2, 440, ex + 24, 466), fill=pal["shine"])
    d.ellipse(box(468, 662, 532, 742), fill=pal["tongue"])
    d.ellipse(box(438, 548, 562, 628), fill=pal["ink"])
    d.line([500 * k, 620 * k, 500 * k, 655 * k], fill=pal["ink"], width=int(14 * k))
    d.arc(box(425, 612, 500, 690), 0, 180, fill=pal["ink"], width=int(14 * k))
    d.arc(box(500, 612, 575, 690), 0, 180, fill=pal["ink"], width=int(14 * k))
    return img.resize((size, size), Image.LANCZOS)


def paste_centered(canvas: Image.Image, art: Image.Image, cx: int, cy: int):
    canvas.paste(art, (cx - art.width // 2, cy - art.height // 2), art)


def poster(size):
    w, h = size
    img = Image.new("RGB", size, BG)
    d = ImageDraw.Draw(img)
    paste_centered(img, dog(int(h * 0.62)), w // 2, int(h * 0.38))
    font = ImageFont.truetype(CJK, int(h * 0.15), index=1)
    text = "狗哩狗哩"
    tw = d.textlength(text, font=font)
    d.text(((w - tw) / 2, int(h * 0.72)), text, font=font, fill=(240, 240, 245))
    return img


poster((540, 405)).save(OUT / "icon_focus_fhd.png")
poster((290, 218)).save(OUT / "icon_focus_hd.png")

splash = Image.new("RGB", (1920, 1080), BG)
d = ImageDraw.Draw(splash)
paste_centered(splash, dog(420), 960, 450)
font = ImageFont.truetype(CJK, 64, index=1)
t = "狗哩狗哩"
d.text(((1920 - d.textlength(t, font=font)) / 2, 700), t, font=font, fill=(240, 240, 245))
splash.save(OUT / "splash_fhd.jpg", quality=90)
print("art ->", OUT)


# ---------- UI chrome ----------

def nine_patch(img: Image.Image, stretch_x: tuple[int, int], stretch_y: tuple[int, int], name: str):
    """Wrap img in the 1px guide border Roku's .9.png format wants."""
    w, h = img.size
    out = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    out.paste(img, (1, 1))
    px = out.load()
    for x in range(stretch_x[0], stretch_x[1]):
        px[x + 1, 0] = (0, 0, 0, 255)
    for y in range(stretch_y[0], stretch_y[1]):
        px[0, y + 1] = (0, 0, 0, 255)
    out.save(OUT / name)


def rounded(size, radius, fill=None, outline=None, width=0, scale=4):
    """Antialiased rounded rect: draw large, shrink."""
    W, H = size[0] * scale, size[1] * scale
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(img).rounded_rectangle([0, 0, W - 1, H - 1], radius=radius * scale,
                                          fill=fill, outline=outline, width=width * scale)
    return img.resize(size, Image.LANCZOS)


nine_patch(rounded((48, 48), 14, outline=PINK + (255,), width=5), (20, 28), (20, 28), "focus.9.png")
nine_patch(rounded((56, 56), 28, fill=PINK + (255,)), (27, 29), (27, 29), "pill.9.png")
nine_patch(rounded((56, 56), 28, fill=(255, 255, 255, 34)), (27, 29), (27, 29), "pill_dim.9.png")
nine_patch(rounded((32, 32), 8, fill=(0, 0, 0, 170)), (12, 20), (12, 20), "badge.9.png")
nine_patch(rounded((40, 40), 12, fill=(28, 28, 36, 255)), (16, 24), (16, 24), "card.9.png")

Image.new("RGBA", (4, 4), (0, 0, 0, 0)).save(OUT / "clear.png")

ph = Image.new("RGB", (480, 270), (28, 28, 36))
paste_centered(ph, dog(150, DOG_GREY), 240, 135)
ph.save(OUT / "placeholder.png")

logo = Image.new("RGBA", (96, 80), (0, 0, 0, 0))
paste_centered(logo, dog(80), 48, 40)
logo.save(OUT / "logo.png")

spin = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
ImageDraw.Draw(spin).arc([16, 16, 240, 240], 0, 270, fill=PINK + (255,), width=20)
spin.resize((64, 64), Image.LANCZOS).save(OUT / "spinner.png")

# left-to-right scrim for the detail page backdrop, top scrim for the player HUD
scrim = Image.new("RGBA", (480, 4), (0, 0, 0, 0))
for x in range(480):
    a = 255 if x < 200 else int(255 * max(0.0, 1 - (x - 200) / 280) ** 1.4)
    for y in range(4):
        scrim.putpixel((x, y), BG + (a,))
scrim.save(OUT / "scrim_left.png")
top = Image.new("RGBA", (4, 270), (0, 0, 0, 0))
for y in range(270):
    a = int(220 * (1 - y / 270) ** 1.6)
    for x in range(4):
        top.putpixel((x, y), (0, 0, 0, a))
top.save(OUT / "scrim_top.png")
bottom = top.transpose(Image.FLIP_TOP_BOTTOM)
bottom.save(OUT / "scrim_bottom.png")
print("ui chrome ->", OUT)

nine_patch(rounded((28, 28), 10, fill=PINK + (255,)), (12, 16), (12, 16), "chip.9.png")
