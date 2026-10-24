"""Render the central torch from the university's original PDF-compatible AI.

Run with PyMuPDF and Pillow. Only the two torch paths (flame + bowl) are used;
the outer rings and all lettering are excluded. This does not redraw the mark.
"""
from pathlib import Path
import hashlib
import io
import json

import fitz
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Design/Branding/sustech-emblem-source.ai"
CATALOG = ROOT / "App/Assets.xcassets"
ICONSET = CATALOG / "AppIcon.appiconset"
BACKGROUND = (0, 72, 81)

def main():
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == "316e4aadab9f3ff8897b0d129ea3b80fe94ce07b4556e83372f5679cfa27bb85", "Unexpected university source artwork"
    original = fitz.open(SOURCE)
    paths = original[0].get_drawings()
    # These two paths are the original central flame and bowl in the official file.
    torch = [paths[index] for index in (5, 6)]
    doc = fitz.open()
    page = doc.new_page(width=original[0].rect.width, height=original[0].rect.height)
    bounds = fitz.Rect()
    for path in torch:
        bounds |= path["rect"]
        shape = page.new_shape()
        for item in path["items"]:
            if item[0] == "c":
                shape.draw_bezier(*item[1:])
            elif item[0] == "l":
                shape.draw_line(*item[1:])
            else:
                raise ValueError(f"Unexpected torch path operation: {item[0]}")
        shape.finish(fill=path["fill"], color=path["color"], even_odd=path["even_odd"], closePath=path["closePath"])
        shape.commit()
    pix = page.get_pixmap(matrix=fitz.Matrix(10, 10), clip=bounds + (-1, -1, 1, 1), alpha=True)
    mark = Image.open(io.BytesIO(pix.tobytes("png"))).convert("RGBA")
    mark.thumbnail((710, 710), Image.Resampling.LANCZOS)
    icon = Image.new("RGB", (1024, 1024), BACKGROUND)
    icon.paste(mark, ((1024-mark.width)//2, (1024-mark.height)//2), mark)
    CATALOG.mkdir(parents=True, exist_ok=True)
    ICONSET.mkdir(exist_ok=True)
    info = {"version": 1, "author": "xcode"}
    (CATALOG/"Contents.json").write_text(json.dumps({"info": info}, indent=2)+"\n", encoding="utf-8")
    entries = []
    sizes = {"iphone": [(20, 2), (20, 3), (29, 2), (29, 3), (40, 2), (40, 3), (60, 2), (60, 3)],
             "ipad": [(20, 1), (20, 2), (29, 1), (29, 2), (40, 1), (40, 2), (76, 1), (76, 2), (83.5, 2)],
             "ios-marketing": [(1024, 1)]}
    for idiom, variants in sizes.items():
        for size, scale in variants:
            filename = f"Icon-{idiom}-{size}-{scale}x.png"
            pixels = int(size * scale)
            icon.resize((pixels, pixels), Image.Resampling.LANCZOS).save(ICONSET/filename)
            entries.append({"idiom": idiom, "size": f"{size}x{size}", "scale": f"{scale}x", "filename": filename})
    (ICONSET/"Contents.json").write_text(json.dumps({"images": entries, "info": info}, indent=2)+"\n", encoding="utf-8")
    (ROOT/"Design/Branding/torch-only.pdf").write_bytes(doc.tobytes())
    icon.save(ROOT/"Design/Branding/AppIcon-preview.png")
    print("Generated opaque app icons from official central torch paths; no rings or text.")
    print("Source SHA256:", hashlib.sha256(SOURCE.read_bytes()).hexdigest())

if __name__ == "__main__":
    main()
