"""Paraplay app icon (the design; make_icons.py turns it into the app's PNG and SVG files): a row of frosted-glass
sound bars of uneven height on a dark tile, lit from behind by the app's green.

svg(kind, scale) builds the artwork. kind: "full" (tile + bars), "background" (tile only),
"foreground" (bars only, transparent), "mono" (flat silhouette). scale shrinks the bars about the centre
(smaller for Android's adaptive icon, whose edges get cropped by the launcher).
"""
import math

GREEN = "#16a34a"

# The bars, left to right: (height, vertical nudge), on a 1024 grid. Roughly climbing like a hand-drawn
# sketch, but not in order: a dip here, a jump there.
BARS = [(150, 8), (300, -6), (240, 12), (470, -4), (390, 10), (640, -8), (560, 6), (330, -2)]
BAR_W = 58
BAR_GAP = 26


def _rr(x, y, w, h, r):
    return (f"M{x+r:.1f},{y:.1f} H{x+w-r:.1f} A{r:.1f},{r:.1f} 0 0 1 {x+w:.1f},{y+r:.1f} "
            f"V{y+h-r:.1f} A{r:.1f},{r:.1f} 0 0 1 {x+w-r:.1f},{y+h:.1f} H{x+r:.1f} "
            f"A{r:.1f},{r:.1f} 0 0 1 {x:.1f},{y+h-r:.1f} V{y+r:.1f} A{r:.1f},{r:.1f} 0 0 1 {x+r:.1f},{y:.1f} Z")


def _arc(cx, cy, r, a1, a2):
    p = lambda a: (cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
    (x1, y1), (x2, y2) = p(a1), p(a2)
    large = 1 if abs(a2 - a1) > 180 else 0
    return f"M{x1:.1f},{y1:.1f} A{r:.1f},{r:.1f} 0 {large} 1 {x2:.1f},{y2:.1f}"


def _streak(x, y1, y2, t):
    """A tall thin highlight: straight on the left, bulging t to the right."""
    c2 = (y2 - y1) / 2
    R = (t * t + c2 * c2) / (2 * t)
    return f"M{x:.1f},{y1:.1f} L{x:.1f},{y2:.1f} A{R:.1f},{R:.1f} 0 0 0 {x:.1f},{y1:.1f} Z"


def _bars():
    """(x, y, w, h, r) for every bar, centred on the tile."""
    n = len(BARS)
    total = n * BAR_W + (n - 1) * BAR_GAP
    x0 = 512 - total / 2
    out = []
    for i, (h, dy) in enumerate(BARS):
        out.append((x0 + i * (BAR_W + BAR_GAP), 512 + dy - h / 2, BAR_W, h, BAR_W / 2))
    return out


def _defs(bars):
    d = ['''
  <radialGradient id="base" cx="0.5" cy="0.42" r="0.78">
    <stop offset="0" stop-color="#171717"/><stop offset="1" stop-color="#050505"/>
  </radialGradient>
  <filter id="glow1" filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><feGaussianBlur stdDeviation="90"/></filter>
  <filter id="glow2" filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><feGaussianBlur stdDeviation="60"/></filter>
  <filter id="frost" filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024">
    <feGaussianBlur stdDeviation="22"/>
    <feColorMatrix type="saturate" values="1.7"/>
    <feComponentTransfer><feFuncR type="linear" slope="1.15" intercept="0.025"/><feFuncG type="linear" slope="1.15" intercept="0.025"/><feFuncB type="linear" slope="1.15" intercept="0.025"/></feComponentTransfer>
  </filter>
  <filter id="soft" filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><feGaussianBlur stdDeviation="4"/></filter>
  <filter id="crisp" filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><feGaussianBlur stdDeviation="1.6"/></filter>
  <filter id="softer" filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><feGaussianBlur stdDeviation="9"/></filter>
  <linearGradient id="body" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="0.26"/><stop offset="0.5" stop-color="#fff" stop-opacity="0.07"/><stop offset="1" stop-color="#fff" stop-opacity="0.06"/>
  </linearGradient>
  <linearGradient id="inner" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#4ade80" stop-opacity="0.03"/><stop offset="0.6" stop-color="#4ade80" stop-opacity="0.2"/><stop offset="1" stop-color="#86efac" stop-opacity="0.5"/>
  </linearGradient>
  <linearGradient id="rim" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset="0.3" stop-color="#fff" stop-opacity="0.55"/>
    <stop offset="0.65" stop-color="#fff" stop-opacity="0.18"/><stop offset="1" stop-color="#fff" stop-opacity="0.85"/>
  </linearGradient>''']
    # coloured light behind everything: strongest in the middle, so the middle bars glow most
    d.append(f'''
  <g id="bg">
    <rect width="1024" height="1024" fill="url(#base)"/>
    <ellipse cx="560" cy="540" rx="330" ry="230" fill="{GREEN}" filter="url(#glow1)"/>
    <ellipse cx="600" cy="600" rx="150" ry="110" fill="#4ade80" opacity="0.55" filter="url(#glow2)"/>
    <circle cx="250" cy="250" r="100" fill="#4ade80" opacity="0.26" filter="url(#glow2)"/>
    <circle cx="830" cy="850" r="150" fill="#0d9488" opacity="0.38" filter="url(#glow1)"/>
  </g>''')
    for i, (x, y, w, h, r) in enumerate(bars):
        d.append(f'<clipPath id="cb{i}"><path d="{_rr(x, y, w, h, r)}"/></clipPath>')
    return "\n".join(d)


def _bar_glass(i, bar):
    """One bar of frosted glass: blurred backdrop, milky body, inner glow, glowing edge, crisp rim, highlights."""
    x, y, w, h, r = bar
    p = _rr(x, y, w, h, r)
    spec = (f'<path d="{_streak(x + w * 0.2, y + r * 1.1, y + h - r * 1.3, w * 0.11)}" fill="#fff" fill-opacity="0.6" filter="url(#crisp)"/>'
            f'<path d="{_arc(x + r, y + r, r - w * 0.14, 196, 300)}" fill="none" stroke="#fff" stroke-opacity="0.95" '
            f'stroke-width="{w * 0.15:.1f}" stroke-linecap="round" filter="url(#soft)"/>')
    return f'''
  <g clip-path="url(#cb{i})">
    <use xlink:href="#bg" filter="url(#frost)"/>
    <path d="{p}" fill="url(#inner)"/>
    <path d="{p}" fill="url(#body)"/>
    <path d="{p}" fill="none" stroke="#fff" stroke-opacity="0.2" stroke-width="{w * 0.9:.1f}" filter="url(#softer)"/>
    <path d="{p}" fill="none" stroke="url(#rim)" stroke-width="{w * 0.1:.1f}"/>
    {spec}
  </g>'''


def svg(kind="full", scale=1.0, pads=False):
    bars = _bars()
    head = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1024 1024" width="1024" height="1024">'
    wrap = lambda inner: (f'<g transform="translate(512 512) scale({scale}) translate(-512 -512)">{inner}</g>'
                          if scale != 1.0 else inner)
    if kind == "mono":
        return head + wrap("".join(f'<path d="{_rr(*b)}" fill="#fff"/>' for b in bars)) + "</svg>"

    glass = "".join(_bar_glass(i, b) for i, b in enumerate(bars))
    defs = _defs(bars)
    body = []
    if kind in ("full", "background"):
        body.append('<use xlink:href="#bg"/>')
    if kind in ("full", "foreground"):
        body.append(glass)
    scene = "".join(body)
    if scale != 1.0 and kind != "background":      # the tile itself always fills the whole square
        scene = wrap(scene)
    return head + "<defs>" + defs + "</defs>" + scene + "</svg>"
