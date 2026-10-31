"""Paraplay app icon (the design; make_icons.py turns it into the app's PNG and SVG files): frosted-glass over-ear headphones on a dark tile lit by the app's green.

svg(kind, s) builds the artwork. kind: "full" (tile + headphones), "background" (tile only),
"foreground" (headphones only, transparent), "mono" (flat silhouette). s scales the headphones
about the centre (smaller for Android's adaptive icon, whose edges get cropped by the launcher).
"""
import math

GREEN = "#16a34a"


def _rr(x, y, w, h, r):
    return (f"M{x+r:.1f},{y:.1f} H{x+w-r:.1f} A{r:.1f},{r:.1f} 0 0 1 {x+w:.1f},{y+r:.1f} "
            f"V{y+h-r:.1f} A{r:.1f},{r:.1f} 0 0 1 {x+w-r:.1f},{y+h:.1f} H{x+r:.1f} "
            f"A{r:.1f},{r:.1f} 0 0 1 {x:.1f},{y+h-r:.1f} V{y+r:.1f} A{r:.1f},{r:.1f} 0 0 1 {x+r:.1f},{y:.1f} Z")


def _arc(cx, cy, r, a1, a2):
    p = lambda a: (cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
    (x1, y1), (x2, y2) = p(a1), p(a2)
    large = 1 if abs(a2 - a1) > 180 else 0
    return f"M{x1:.1f},{y1:.1f} A{r:.1f},{r:.1f} 0 {large} 1 {x2:.1f},{y2:.1f}"


def _lens(cx, cy, R, a1, a2, t):
    """A crescent highlight hugging a circle of radius R between angles a1..a2, t thick in the middle."""
    p = lambda a: (cx + R * math.cos(math.radians(a)), cy + R * math.sin(math.radians(a)))
    (x1, y1), (x2, y2) = p(a1), p(a2)
    half = math.radians(abs(a2 - a1)) / 2
    c2 = R * math.sin(half)                 # half the chord
    sag = R * (1 - math.cos(half)) - t      # sagitta of the inner, flatter arc
    R2 = (sag * sag + c2 * c2) / (2 * sag)
    return f"M{x1:.1f},{y1:.1f} A{R:.1f},{R:.1f} 0 0 1 {x2:.1f},{y2:.1f} A{R2:.1f},{R2:.1f} 0 0 0 {x1:.1f},{y1:.1f} Z"


def _streak(x, y1, y2, t):
    """A tall thin highlight: straight on the left, bulging t to the right."""
    c2 = (y2 - y1) / 2
    R = (t * t + c2 * c2) / (2 * t)
    return f"M{x:.1f},{y1:.1f} L{x:.1f},{y2:.1f} A{R:.1f},{R:.1f} 0 0 0 {x:.1f},{y1:.1f} Z"


class Geo:
    """Headphone shapes, designed on a 1024 grid and scaled by s about the centre."""
    def __init__(self, s=1.0, pads=True):
        self.s = s
        self.has_pads = pads
        X = lambda v: 512 + (v - 512) * s
        L = lambda v: v * s
        self.X, self.L = X, L
        # headband: a thick upside-down U whose legs drop behind the ear cups
        self.bcx, self.bcy = X(512), X(500)
        self.ro, self.ri = L(290), L(236)
        ye = X(610)
        bcx, bcy, ro, ri = self.bcx, self.bcy, self.ro, self.ri
        self.band = (f"M{bcx-ro:.1f},{ye:.1f} L{bcx-ro:.1f},{bcy:.1f} A{ro:.1f},{ro:.1f} 0 0 1 {bcx+ro:.1f},{bcy:.1f} "
                     f"L{bcx+ro:.1f},{ye:.1f} L{bcx+ri:.1f},{ye:.1f} L{bcx+ri:.1f},{bcy:.1f} "
                     f"A{ri:.1f},{ri:.1f} 0 0 0 {bcx-ri:.1f},{bcy:.1f} L{bcx-ri:.1f},{ye:.1f} Z")
        # ear cups and the cushions on their inner side
        self.cups = []
        cw = 154 if pads else 168
        for x in ((174, 696) if pads else (168, 688)):
            self.cups.append((X(x), X(516), L(cw), L(276), L(62)))
        self.pads = []
        for x in (318, 650):
            self.pads.append((X(x), X(548), L(56), L(212), L(26)))

    def cup_path(self, i):
        return _rr(*self.cups[i])

    def pad_path(self, i):
        return _rr(*self.pads[i])


def _defs(g, mono=False):
    s, L = g.s, g.L
    d = []
    d.append(f'''
  <radialGradient id="base" cx="0.5" cy="0.42" r="0.78">
    <stop offset="0" stop-color="#171717"/><stop offset="1" stop-color="#050505"/>
  </radialGradient>
  <filter id="glow1" filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><feGaussianBlur stdDeviation="90"/></filter>
  <filter id="glow2" filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><feGaussianBlur stdDeviation="70"/></filter>
  <filter id="frost" filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024">
    <feGaussianBlur stdDeviation="{24*s:.1f}"/>
    <feColorMatrix type="saturate" values="1.7"/>
    <feComponentTransfer><feFuncR type="linear" slope="1.15" intercept="0.025"/><feFuncG type="linear" slope="1.15" intercept="0.025"/><feFuncB type="linear" slope="1.15" intercept="0.025"/></feComponentTransfer>
  </filter>
  <filter id="soft" filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><feGaussianBlur stdDeviation="{4*s:.1f}"/></filter>
  <filter id="crisp" filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><feGaussianBlur stdDeviation="{1.6*s:.1f}"/></filter>
  <filter id="softer" filterUnits="userSpaceOnUse" x="0" y="0" width="1024" height="1024"><feGaussianBlur stdDeviation="{10*s:.1f}"/></filter>
  <linearGradient id="body" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="0.24"/><stop offset="0.5" stop-color="#fff" stop-opacity="0.06"/><stop offset="1" stop-color="#fff" stop-opacity="0.05"/>
  </linearGradient>
  <linearGradient id="bandBody" gradientUnits="userSpaceOnUse" x1="0" y1="{g.bcy - g.ro:.1f}" x2="0" y2="{g.X(610):.1f}">
    <stop offset="0" stop-color="#fff" stop-opacity="0.12"/><stop offset="0.6" stop-color="#fff" stop-opacity="0.03"/><stop offset="1" stop-color="#fff" stop-opacity="0.03"/>
  </linearGradient>
  <linearGradient id="bandLight" gradientUnits="userSpaceOnUse" x1="0" y1="{g.bcy - g.ro:.1f}" x2="0" y2="{g.X(610):.1f}">
    <stop offset="0" stop-color="#4ade80" stop-opacity="0.04"/><stop offset="0.55" stop-color="#4ade80" stop-opacity="0.22"/><stop offset="1" stop-color="#4ade80" stop-opacity="0.5"/>
  </linearGradient>
  <linearGradient id="padRimL" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#fff" stop-opacity="0.15"/><stop offset="1" stop-color="#bbf7d0" stop-opacity="0.95"/>
  </linearGradient>
  <linearGradient id="padRimR" x1="1" y1="0" x2="0" y2="0">
    <stop offset="0" stop-color="#fff" stop-opacity="0.15"/><stop offset="1" stop-color="#bbf7d0" stop-opacity="0.95"/>
  </linearGradient>
  <linearGradient id="padBody" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="0.16"/><stop offset="1" stop-color="#fff" stop-opacity="0.05"/>
  </linearGradient>
  <linearGradient id="rim" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset="0.25" stop-color="#fff" stop-opacity="0.6"/>
    <stop offset="0.6" stop-color="#fff" stop-opacity="0.2"/><stop offset="1" stop-color="#fff" stop-opacity="0.9"/>
  </linearGradient>
  <linearGradient id="faceRim" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#fff" stop-opacity="0.15"/><stop offset="0.5" stop-color="#fff" stop-opacity="0.05"/><stop offset="1" stop-color="#fff" stop-opacity="0.55"/>
  </linearGradient>
  <radialGradient id="sheen" cx="0.3" cy="0.2" r="0.6">
    <stop offset="0" stop-color="#fff" stop-opacity="0.32"/><stop offset="1" stop-color="#fff" stop-opacity="0"/>
  </radialGradient>
  <linearGradient id="padTint" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#000" stop-opacity="0.55"/><stop offset="1" stop-color="#000" stop-opacity="0.7"/>
  </linearGradient>''')
    # background group: base + coloured light
    d.append(f'''
  <g id="bg">
    <rect width="1024" height="1024" fill="url(#base)"/>
    <circle cx="512" cy="600" r="240" fill="{GREEN}" opacity="1" filter="url(#glow1)"/>
    <circle cx="512" cy="640" r="110" fill="#4ade80" opacity="0.55" filter="url(#glow2)"/>
    <circle cx="290" cy="270" r="100" fill="#4ade80" opacity="0.28" filter="url(#glow2)"/>
    <circle cx="820" cy="840" r="150" fill="#0d9488" opacity="0.35" filter="url(#glow1)"/>
  </g>''')
    # clip paths
    d.append(f'<clipPath id="cBand"><path d="{g.band}"/></clipPath>')
    for i in range(2):
        d.append(f'<clipPath id="cCup{i}"><path d="{g.cup_path(i)}"/></clipPath>')
        d.append(f'<clipPath id="cPad{i}"><path d="{g.pad_path(i)}"/></clipPath>')
    return "\n".join(d)


def _glass(clip, path, backdrop, body="body", rim_w=5.0, s=1.0, extra="", edge=0.24, under="", rim="rim"):
    """One piece of frosted glass: blurred backdrop, milky body, glowing edge, crisp rim, highlights."""
    return f'''
  <g clip-path="url(#{clip})">
    <use xlink:href="#{backdrop}" filter="url(#frost)"/>
    {under}
    <path d="{path}" fill="url(#{body})"/>
    <path d="{path}" fill="none" stroke="#fff" stroke-opacity="{edge}" stroke-width="{56*s:.1f}" filter="url(#softer)"/>
    <path d="{path}" fill="none" stroke="url(#{rim})" stroke-width="{2*rim_w*s:.1f}"/>
    {extra}
  </g>'''


def svg(kind="full", scale=1.0, pads=False):
    """scale shrinks the whole picture about the centre (Android's adaptive icon shows only the middle two-thirds)."""
    s = 1.0
    g = Geo(s, pads)
    L = g.L
    head = '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 1024 1024" width="1024" height="1024">'
    if kind == "mono":
        shapes = [g.band] + [g.cup_path(i) for i in range(2)] + ([g.pad_path(i) for i in range(2)] if g.has_pads else [])
        inner = "".join(f'<path d="{p}" fill="#fff"/>' for p in shapes)
        if scale != 1.0:
            inner = f'<g transform="translate(512 512) scale({scale}) translate(-512 -512)">{inner}</g>'
        return head + inner + "</svg>"

    # highlights
    band_spec = (f'<path d="{_lens(g.bcx, g.bcy, g.ro - L(9), 196, 286, L(15))}" fill="#fff" fill-opacity="0.85" filter="url(#crisp)"/>'
                 f'<path d="{_lens(g.bcx, g.bcy, g.ri + L(9), 300, 345, L(7))}" fill="#fff" fill-opacity="0.35" filter="url(#soft)"/>'
                 f'<path d="{_arc(g.bcx, g.bcy, g.ro - L(10), 292, 338)}" fill="none" stroke="#fff" stroke-opacity="0.45" '
                 f'stroke-width="{L(2.5):.1f}" stroke-linecap="round"/>')
    pieces = []
    pieces.append(_glass("cBand", g.band, "bg", body="bandBody", s=s, rim_w=6, extra=band_spec, edge=0.14,
                         under=f'<path d="{g.band}" fill="url(#bandLight)"/>'))
    pad_parts = []
    for i in (range(2) if g.has_pads else []):
        pad_parts.append(_glass(f"cPad{i}", g.pad_path(i), "bg", body="padBody", rim_w=4.5, s=s, edge=0.06,
                                under=f'<path d="{g.pad_path(i)}" fill="url(#padTint)"/>', rim="padRimL" if i == 0 else "padRimR"))
    cup_parts = []
    for i in range(2):
        x, y, w, h, r = g.cups[i]
        spec = (f'<path d="{_streak(x + L(20), y + L(66), y + h - L(74), L(13))}" fill="#fff" fill-opacity="0.55" filter="url(#crisp)"/>'
                f'<path d="{_arc(x+r, y+r, r-L(13), 188, 262)}" fill="none" stroke="#fff" stroke-opacity="0.95" stroke-width="{L(9):.1f}" '
                f'stroke-linecap="round" filter="url(#soft)"/>')
        inset = L(20)
        face = _rr(x + inset, y + inset, w - 2 * inset, h - 2 * inset, r - inset * 0.8)
        spec = (f'<path d="{face}" fill="url(#sheen)"/>'
                f'<path d="{face}" fill="none" stroke="url(#faceRim)" stroke-width="{L(3):.1f}"/>') + spec
        cup_parts.append(_glass(f"cCup{i}", g.cup_path(i), "behindCups", s=s, rim_w=6, extra=spec, edge=0.2))

    defs = _defs(g)
    defs += '\n  <g id="bandG">' + pieces[0] + '</g>'
    defs += '\n  <g id="padsG">' + "".join(pad_parts) + '</g>'
    defs += '\n  <g id="behindCups"><use xlink:href="#bg"/><use xlink:href="#bandG"/><use xlink:href="#padsG"/></g>'
    defs += '\n  <g id="cupsG">' + "".join(cup_parts) + '</g>'

    body = []
    if kind in ("full", "background"):
        body.append('<use xlink:href="#bg"/>')
    if kind in ("full", "foreground"):
        body += ['<use xlink:href="#bandG"/>', '<use xlink:href="#padsG"/>', '<use xlink:href="#cupsG"/>']
    scene = "".join(body)
    if scale != 1.0:
        scene = f'<g transform="translate(512 512) scale({scale}) translate(-512 -512)">{scene}</g>'
        if kind == "background":   # the tile's dark colour continues past the scaled picture
            scene = '<rect width="1024" height="1024" fill="#050505"/>' + scene
    return head + "<defs>" + defs + "</defs>" + scene + "</svg>"
