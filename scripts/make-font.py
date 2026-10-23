"""Subset a CJK font into channel/fonts/cjk.otf -- Roku's system font has no CJK glyphs.

    tools/.venv/bin/python scripts/make-font.py [path/to/font.otf]

Keeps ASCII/Latin-1, punctuation, arrows/shapes, kana, full-width forms, all
GB2312 hanzi and Big5 level-1 traditional hanzi. Works with any OFL CJK font
(Source Han / Noto Sans CJK). The subset is renamed, as the OFL asks of
modified versions, and keeps the original copyright and licence records.
"""
import os
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont, TTCollection

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "channel" / "fonts" / "cjk.otf"
# one bit per BMP code point (LSB first): which characters the font can draw.
# The channel drops the rest (emoji...) so Roku does not paint boxes.
COV = ROOT / "channel" / "fonts" / "cjk.cov"
DEFAULT = os.environ.get("CJK_FONT", "")


def charset() -> set[int]:
    cps: set[int] = set()
    for lo, hi in [(0x20, 0x7E), (0xA0, 0xFF), (0x2000, 0x206F), (0x2100, 0x214F),
                   (0x2190, 0x21FF), (0x2460, 0x24FF), (0x2500, 0x257F), (0x25A0, 0x25FF),
                   (0x2600, 0x26FF), (0x3000, 0x303F), (0x3040, 0x30FF), (0x31F0, 0x31FF),
                   (0xFF00, 0xFFEF)]:
        cps.update(range(lo, hi + 1))
    for a in range(0xA1, 0xF8):  # GB2312: symbols + 6763 hanzi
        for b in range(0xA1, 0xFF):
            try:
                cps.add(ord(bytes([a, b]).decode("gb2312")))
            except UnicodeDecodeError:
                pass
    for a in range(0xA4, 0xC7):  # Big5 level 1: frequently used traditional
        for b in list(range(0x40, 0x7F)) + list(range(0xA1, 0xFF)):
            try:
                cps.add(ord(bytes([a, b]).decode("big5")))
            except UnicodeDecodeError:
                pass
    return cps


def load(path: str) -> TTFont:
    if path.lower().endswith((".ttc", ".otc")):
        return TTCollection(path).fonts[0]
    return TTFont(path)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    if not src:
        sys.exit("usage: make-font.py <font.otf|ttf|ttc>  (or set CJK_FONT)")
    font = load(src)
    opts = subset.Options()
    opts.layout_features = []
    opts.name_IDs = ["*"]
    opts.name_languages = ["*"]
    opts.notdef_outline = True
    opts.hinting = False
    opts.drop_tables += ["VORG", "vhea", "vmtx", "GSUB", "GPOS", "BASE", "DSIG"]
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=charset() & set(font.getBestCmap()))
    sub.subset(font)

    # OFL: a modified font may not keep the Reserved Font Name
    for rec in font["name"].names:
        if rec.nameID in (1, 3, 4, 6, 16, 17, 21, 22):
            new = {1: "BiliTV CJK", 3: "BiliTV CJK subset", 4: "BiliTV CJK",
                   6: "BiliTV-CJK", 16: "BiliTV CJK", 17: "Regular",
                   21: "BiliTV CJK", 22: "Regular"}[rec.nameID]
            rec.string = new
    if "CFF " in font:
        cff = font["CFF "].cff
        cff.fontNames = ["BiliTV-CJK"]

    OUT.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUT)
    cov = bytearray(65536 // 8)
    for cp in font.getBestCmap():
        if cp < 65536:
            cov[cp // 8] |= 1 << (cp % 8)
    COV.write_bytes(bytes(cov))
    print(f"{OUT}  {OUT.stat().st_size / 1e6:.2f} MB  {len(font.getBestCmap())} chars")


if __name__ == "__main__":
    main()
