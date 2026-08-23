"""Turn an SVG path `d` attribute into the three commands Flutter needs.

SVG has twenty path commands; `Path` in Dart has about six worth using. Every
mark this project ships is a filled outline, so the whole grammar collapses to
moveTo / lineTo / cubicTo / close once relative coordinates are resolved, arcs
are approximated and quadratics are raised a degree. Doing that here, once, at
build time, keeps the runtime parser in Dart down to four cases.
"""

import math
import re

_TOKEN = re.compile(r"[MmZzLlHhVvCcSsQqTtAa]|[-+]?[0-9]*\.?[0-9]+(?:[eE][-+]?[0-9]+)?")

# How many arguments each command consumes per repetition. A command may repeat
# its arguments without repeating its letter -- `L 1 2 3 4` is two line segments
# -- so every consumer below loops until the argument list runs dry.
_ARITY = {
    "M": 2, "L": 2, "H": 1, "V": 1,
    "C": 6, "S": 4, "Q": 4, "T": 2, "A": 7, "Z": 0,
}


def _tokenize(d):
    out = []
    for tok in _TOKEN.findall(d):
        out.append(tok if tok.isalpha() else float(tok))
    return out


def _commands(d):
    """Yield (letter, [args]) with each repetition split into its own tuple."""
    tokens = _tokenize(d)
    i = 0
    letter = None
    while i < len(tokens):
        if isinstance(tokens[i], str):
            letter = tokens[i]
            i += 1
        elif letter is None:
            raise ValueError("path data starts with a number")
        elif letter in "Mm":
            # An implicit repeat after a moveto is a lineto, per the spec.
            letter = "L" if letter == "M" else "l"

        n = _ARITY[letter.upper()]
        args = tokens[i:i + n]
        if len(args) != n:
            raise ValueError(f"command {letter} wants {n} args, got {args}")
        i += n
        yield letter, args


def _arc_to_cubics(x0, y0, rx, ry, phi_deg, large_arc, sweep, x, y):
    """Endpoint-parameterised elliptical arc -> a list of cubic segments.

    Straight out of the SVG implementation notes (F.6). Split into 90-degree
    slices because a single cubic only tracks a circular arc convincingly up to
    about that much sweep.
    """
    if (x0, y0) == (x, y):
        return []
    if rx == 0 or ry == 0:
        return [(x0, y0, x, y, x, y)]  # degenerate: the spec says draw a line

    rx, ry = abs(rx), abs(ry)
    phi = math.radians(phi_deg % 360)
    cos_p, sin_p = math.cos(phi), math.sin(phi)

    dx2, dy2 = (x0 - x) / 2.0, (y0 - y) / 2.0
    x1p = cos_p * dx2 + sin_p * dy2
    y1p = -sin_p * dx2 + cos_p * dy2

    # Radii too small to reach the endpoint get scaled up until they just do.
    lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
    if lam > 1:
        s = math.sqrt(lam)
        rx, ry = rx * s, ry * s

    num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
    den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
    factor = math.sqrt(max(num / den, 0.0))
    if large_arc == sweep:
        factor = -factor
    cxp = factor * rx * y1p / ry
    cyp = -factor * ry * x1p / rx

    cx = cos_p * cxp - sin_p * cyp + (x0 + x) / 2.0
    cy = sin_p * cxp + cos_p * cyp + (y0 + y) / 2.0

    def angle(ux, uy, vx, vy):
        dot = ux * vx + uy * vy
        norm = math.hypot(ux, uy) * math.hypot(vx, vy)
        a = math.acos(max(-1.0, min(1.0, dot / norm)))
        return -a if ux * vy - uy * vx < 0 else a

    theta1 = angle(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry)
    delta = angle((x1p - cxp) / rx, (y1p - cyp) / ry,
                  (-x1p - cxp) / rx, (-y1p - cyp) / ry)
    if not sweep and delta > 0:
        delta -= 2 * math.pi
    elif sweep and delta < 0:
        delta += 2 * math.pi

    segments = max(1, int(math.ceil(abs(delta) / (math.pi / 2))))
    step = delta / segments
    # Control-point distance for a cubic approximating a `step`-wide arc.
    k = 4.0 / 3.0 * math.tan(step / 4.0)

    def point(t):
        ct, st = math.cos(t), math.sin(t)
        return (cx + rx * ct * cos_p - ry * st * sin_p,
                cy + rx * ct * sin_p + ry * st * cos_p)

    def derivative(t):
        ct, st = math.cos(t), math.sin(t)
        return (-rx * st * cos_p - ry * ct * sin_p,
                -rx * st * sin_p + ry * ct * cos_p)

    out = []
    px, py = x0, y0
    for i in range(segments):
        t0 = theta1 + i * step
        t1 = t0 + step
        d0x, d0y = derivative(t0)
        d1x, d1y = derivative(t1)
        ex, ey = point(t1)
        out.append((px + k * d0x, py + k * d0y, ex - k * d1x, ey - k * d1y, ex, ey))
        px, py = ex, ey
    return out


def flatten(d):
    """Return [('M'|'L'|'C'|'Z', coords...)] in absolute user units."""
    out = []
    cx = cy = 0.0          # current point
    sx = sy = 0.0          # start of the current subpath, where Z returns to
    last_cubic_ctrl = None   # for S / s
    last_quad_ctrl = None    # for T / t

    for letter, args in _commands(d):
        upper = letter.upper()
        rel = letter.islower()

        if upper == "M":
            x, y = args
            if rel:
                x, y = cx + x, cy + y
            out.append(("M", x, y))
            cx = sx = x
            cy = sy = y
            last_cubic_ctrl = last_quad_ctrl = None

        elif upper == "L":
            x, y = args
            if rel:
                x, y = cx + x, cy + y
            out.append(("L", x, y))
            cx, cy = x, y
            last_cubic_ctrl = last_quad_ctrl = None

        elif upper == "H":
            x = args[0] + (cx if rel else 0)
            out.append(("L", x, cy))
            cx = x
            last_cubic_ctrl = last_quad_ctrl = None

        elif upper == "V":
            y = args[0] + (cy if rel else 0)
            out.append(("L", cx, y))
            cy = y
            last_cubic_ctrl = last_quad_ctrl = None

        elif upper == "C":
            x1, y1, x2, y2, x, y = args
            if rel:
                x1, y1, x2, y2, x, y = (cx + x1, cy + y1, cx + x2, cy + y2,
                                        cx + x, cy + y)
            out.append(("C", x1, y1, x2, y2, x, y))
            cx, cy = x, y
            last_cubic_ctrl = (x2, y2)
            last_quad_ctrl = None

        elif upper == "S":
            x2, y2, x, y = args
            if rel:
                x2, y2, x, y = cx + x2, cy + y2, cx + x, cy + y
            # The reflected control point; absent a previous cubic it is the
            # current point, which makes the segment start out straight.
            if last_cubic_ctrl is None:
                x1, y1 = cx, cy
            else:
                x1, y1 = 2 * cx - last_cubic_ctrl[0], 2 * cy - last_cubic_ctrl[1]
            out.append(("C", x1, y1, x2, y2, x, y))
            cx, cy = x, y
            last_cubic_ctrl = (x2, y2)
            last_quad_ctrl = None

        elif upper in ("Q", "T"):
            if upper == "Q":
                qx, qy, x, y = args
                if rel:
                    qx, qy, x, y = cx + qx, cy + qy, cx + x, cy + y
            else:
                x, y = args
                if rel:
                    x, y = cx + x, cy + y
                if last_quad_ctrl is None:
                    qx, qy = cx, cy
                else:
                    qx, qy = 2 * cx - last_quad_ctrl[0], 2 * cy - last_quad_ctrl[1]
            # Degree elevation: a quadratic is exactly a cubic whose controls
            # sit two thirds of the way to the quadratic's single control.
            out.append(("C",
                        cx + 2.0 / 3.0 * (qx - cx), cy + 2.0 / 3.0 * (qy - cy),
                        x + 2.0 / 3.0 * (qx - x), y + 2.0 / 3.0 * (qy - y),
                        x, y))
            cx, cy = x, y
            last_quad_ctrl = (qx, qy)
            last_cubic_ctrl = None

        elif upper == "A":
            rx, ry, rot, large, sweep, x, y = args
            if rel:
                x, y = cx + x, cy + y
            for seg in _arc_to_cubics(cx, cy, rx, ry, rot,
                                      bool(round(large)), bool(round(sweep)), x, y):
                out.append(("C",) + seg)
            cx, cy = x, y
            last_cubic_ctrl = last_quad_ctrl = None

        elif upper == "Z":
            out.append(("Z",))
            cx, cy = sx, sy
            last_cubic_ctrl = last_quad_ctrl = None

    return out
