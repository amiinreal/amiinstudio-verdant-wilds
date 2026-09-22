#!/usr/bin/env python3
"""Generates the MSIX Store tile/icon assets from the studio logo.

Re-run this whenever Logo/X8y06N.png changes:
    python3 Launcher/Packaging/generate-assets.py

These are placeholder-quality (nearest-neighbor-free, simple padded resize)
assets that satisfy Partner Center's minimum asset requirements so the
package validates. Swap them for professionally designed tiles before a
real Store submission if you want a polished listing -- Partner Center's
"Store logo assets" generator (in the Store Listings > Icons section) can
regenerate the full scale set from a single 300x300+ source image.
"""
import pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
SOURCE = ROOT / "Logo" / "X8y06N.png"
OUT = pathlib.Path(__file__).resolve().parent / "Assets"

# (filename, canvas size, logo fill ratio)
TARGETS = [
    ("Square44x44Logo.png", 44, 0.75),
    ("Square71x71Logo.png", 71, 0.75),
    ("Square150x150Logo.png", 150, 0.7),
    ("Square310x310Logo.png", 310, 0.7),
    ("StoreLogo.png", 50, 0.75),
]
WIDE = ("Wide310x150Logo.png", 310, 150, 0.55)
SPLASH = ("SplashScreen.png", 620, 300, 0.35)


def paste_centered(canvas: Image.Image, logo: Image.Image, fill_ratio: float) -> None:
    cw, ch = canvas.size
    target = int(min(cw, ch) * fill_ratio)
    resized = logo.resize((target, target), Image.LANCZOS)
    canvas.alpha_composite(resized, ((cw - target) // 2, (ch - target) // 2))


def main() -> None:
    if not SOURCE.exists():
        raise SystemExit(f"Source logo not found: {SOURCE}")
    OUT.mkdir(parents=True, exist_ok=True)
    logo = Image.open(SOURCE).convert("RGBA")

    for name, size, ratio in TARGETS:
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        paste_centered(canvas, logo, ratio)
        canvas.save(OUT / name)
        print("wrote", name)

    name, w, h, ratio = WIDE
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    paste_centered(canvas, logo, ratio)
    canvas.save(OUT / name)
    print("wrote", name)

    name, w, h, ratio = SPLASH
    # Splash screen wants an opaque background (matches the app's dark theme).
    canvas = Image.new("RGBA", (w, h), (20, 22, 28, 255))
    paste_centered(canvas, logo, ratio)
    canvas.save(OUT / name)
    print("wrote", name)


if __name__ == "__main__":
    main()
