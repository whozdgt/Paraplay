"""Renders every icon file the app uses from icon.py.

Needs Python 3 with Playwright and its Chromium (pip install playwright && playwright install chromium).
Run from anywhere:  python3 packaging/icon/make_icons.py
"""
import base64
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import icon  # noqa: E402
from playwright.sync_api import sync_playwright  # noqa: E402

ADAPTIVE_SCALE = 0.80      # keeps the bars inside the part every launcher mask leaves visible
LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
DESKTOP = (48, 64, 128, 256, 512)


def render(page, svg_text, size, out, transparent=False, circle=False):
    os.makedirs(os.path.dirname(out), exist_ok=True)
    page.set_viewport_size({"width": size, "height": size})
    b64 = base64.b64encode(svg_text.encode()).decode()
    style = "border-radius:50%;" if circle else ""
    page.set_content(f'<body style="margin:0;background:transparent"><img id="i" src="data:image/svg+xml;base64,{b64}" '
                     f'width="{size}" height="{size}" style="display:block;{style}"></body>')
    page.wait_for_function("document.getElementById('i').complete")
    page.screenshot(path=out, omit_background=transparent or circle, clip={"x": 0, "y": 0, "width": size, "height": size})


def main():
    res = os.path.join(ROOT, "android", "res")
    full = icon.svg("full")
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page()
        for d, size in LEGACY.items():
            render(page, full, size, f"{res}/mipmap-{d}/ic_launcher.png")
            render(page, full, size, f"{res}/mipmap-{d}/ic_launcher_round.png", circle=True)
        for d, size in ADAPTIVE.items():
            render(page, icon.svg("background", ADAPTIVE_SCALE), size, f"{res}/mipmap-{d}/ic_launcher_background.png")
            render(page, icon.svg("foreground", ADAPTIVE_SCALE), size, f"{res}/mipmap-{d}/ic_launcher_foreground.png", transparent=True)
            render(page, icon.svg("mono", ADAPTIVE_SCALE), size, f"{res}/mipmap-{d}/ic_launcher_monochrome.png", transparent=True)
        for size in DESKTOP:
            render(page, full, size, os.path.join(ROOT, "packaging", "icons", f"musicplayer-{size}.png"))
        browser.close()
    with open(os.path.join(ROOT, "packaging", "musicplayer.svg"), "w") as f:
        f.write(full)
    print("icons written")


if __name__ == "__main__":
    main()
