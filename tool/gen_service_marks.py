#!/usr/bin/env python3
"""Download brand marks and compile them into Dart path data.

Run from the repo root:  python3 tool/gen_service_marks.py

Why compile rather than ship SVG assets: the app draws its own tab marks with
CustomPainter and bundles no icon font on purpose, so adding an SVG runtime and
thirty asset files to draw thirty more shapes would be the one dependency the
rest of the UI was built to avoid. Flattening the paths here leaves a runtime
parser with four cases (see service_mark.dart) and nothing to load from disk.

Sources, all permissively licensed. Attribution lives in docs/icon-credits.md:
  thesvg  -- theSVG, MIT
  cib     -- CoreUI Brands, CC0 1.0
  logos   -- SVG Logos by Gil Barbara, CC0
  mdi     -- Material Design Icons, Apache 2.0
The marks themselves stay the trademarks of their owners; they are used here
only to label the user's own subscription to that service.
"""

import json
import re
import sys
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from svg_path import flatten  # noqa: E402

ICONIFY = "https://api.iconify.design/{}.svg"
SIMPLE_ICONS_DATA = "https://cdn.jsdelivr.net/npm/simple-icons@16.28.0/data/simple-icons.json"

# key -> (iconify icon, brand colour, simple-icons slug to read the colour from)
#
# The colour is the brand's own, not a palette choice: a Netflix mark in the app
# accent would read as decoration. Where Simple Icons publishes the hex it wins,
# because it is maintained against the brand guidelines; the literal below is
# the fallback for marks that come from another set.
BRANDS = {
    "netflix":         ("thesvg:netflix",             "E50914", "netflix"),
    "youtube":         ("thesvg:youtube",             "FF0000", "youtube"),
    "spotify":         ("thesvg:spotify",             "1DB954", "spotify"),
    "hbo":             ("thesvg:hbo",                 "000000", "hbo"),
    "apple-tv":        ("thesvg:apple-tv",            "000000", "appletv"),
    "apple-music":     ("thesvg:apple-music",         "FA243C", "applemusic"),
    "xbox":            ("cib:xbox",                   "107C10", None),
    "playstation":     ("thesvg:playstation",         "003791", "playstation"),
    "nintendo-switch": ("cib:nintendo-switch",        "E60012", None),
    "steam":           ("thesvg:steam",               "000000", "steam"),
    "claude":          ("thesvg:claude",              "D97757", "claude"),
    "chatgpt":         ("thesvg:openai-chatgpt",      "000000", None),
    "gemini":          ("thesvg:google-gemini",       "8E75B2", "googlegemini"),
    "github-copilot":  ("thesvg:github-copilot",      "000000", "githubcopilot"),
    "cursor":          ("thesvg:cursor",              "000000", "cursor"),
    "midjourney":      ("logos:midjourney",           "000000", None),
    "perplexity":      ("thesvg:perplexity",          "1FB8CD", "perplexity"),
    "adobe":           ("cib:adobe-creative-cloud",   "DA1F26", None),
    "figma":           ("thesvg:figma",               "F24E1E", "figma"),
    "notion":          ("thesvg:notion",              "000000", "notion"),
    "jetbrains":       ("thesvg:jetbrains",           "000000", "jetbrains"),
    "microsoft":       ("cib:microsoft",              "0078D4", None),
    "1password":       ("thesvg:1password",           "3B66BC", "1password"),
    "vercel":          ("thesvg:vercel",              "000000", "vercel"),
    "icloud":          ("thesvg:icloud",              "3693F3", "icloud"),
    "google-drive":    ("thesvg:google-drive",        "4285F4", "googledrive"),
    "dropbox":         ("thesvg:dropbox",             "0061FF", "dropbox"),
    "onedrive":        ("mdi:microsoft-onedrive",     "0078D4", None),
    "backblaze":       ("thesvg:backblaze",           "E21F26", "backblaze"),
}


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "subdock-icon-gen"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8")


def parse_svg(svg, name):
    if "<" not in svg:
        raise SystemExit(f"{name}: not an SVG -- {svg[:80]!r}")
    if "<g" in svg and "transform" in svg:
        # No consumer of a transform below; better to stop than to silently
        # emit a mark drawn in the wrong place.
        raise SystemExit(f"{name}: has a transformed group, handle it by hand")

    box = re.search(r'viewBox="([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)"', svg)
    if not box:
        raise SystemExit(f"{name}: no viewBox")
    vx, vy, vw, vh = (float(g) for g in box.groups())

    paths = re.findall(r"<path\b([^>]*)>", svg)
    if not paths:
        raise SystemExit(f"{name}: no <path>")

    even_odd = any('fill-rule="evenodd"' in attrs for attrs in paths)
    segments = []
    for attrs in paths:
        d = re.search(r'\bd="([^"]+)"', attrs)
        if d:
            segments += flatten(d.group(1))
    return segments, (vx, vy, vw, vh), even_odd


def encode(segments, viewbox, grid=24.0):
    """Absolute path ops on a `grid`-unit square, as one whitespace-free-ish string.

    Every mark is normalised to the same square here so the runtime never has to
    know an icon's original viewBox -- it scales one number and draws.
    """
    vx, vy, vw, vh = viewbox
    # Uniform scale, centred: a non-square source (a wordmark) would otherwise
    # stretch, and a stretched logo is worse than no logo.
    scale = grid / max(vw, vh)
    ox = (grid - vw * scale) / 2.0
    oy = (grid - vh * scale) / 2.0

    def num(v):
        s = f"{v:.2f}".rstrip("0").rstrip(".")
        return "0" if s in ("-0", "") else s

    out = []
    for seg in segments:
        op, coords = seg[0], seg[1:]
        if op == "Z":
            out.append("Z")
            continue
        parts = []
        for i in range(0, len(coords), 2):
            parts.append(num((coords[i] - vx) * scale + ox))
            parts.append(num((coords[i + 1] - vy) * scale + oy))
        out.append(op + " " + " ".join(parts))
    return " ".join(out)


def main():
    root = Path(__file__).resolve().parent.parent
    hexes = {}
    for icon in json.loads(fetch(SIMPLE_ICONS_DATA)):
        hexes[icon["slug"]] = icon["hex"]

    rows = []
    for key, (icon, fallback_hex, si_slug) in BRANDS.items():
        svg = fetch(ICONIFY.format(icon))
        segments, viewbox, even_odd = parse_svg(svg, key)
        data = encode(segments, viewbox)
        colour = hexes.get(si_slug or "", fallback_hex)
        rows.append((key, icon, colour, even_odd, data))
        print(f"  {key:18s} {icon:28s} #{colour}  {len(data):5d} chars", file=sys.stderr)

    lines = [
        "// GENERATED by tool/gen_service_marks.py -- do not edit by hand.",
        "//",
        "// Brand marks flattened to absolute move/line/cubic/close on a 24-unit",
        "// square. Sources and licences: docs/icon-credits.md.",
        "",
        "import 'package:subdock/ui/widgets/service_mark.dart';",
        "",
        "const Map<String, BrandMark> brandMarks = {",
    ]
    for key, icon, colour, even_odd, data in rows:
        lines.append(f"  // {icon}")
        lines.append(f"  '{key}': BrandMark(")
        lines.append(f"    colour: 0xFF{colour.upper()},")
        if even_odd:
            lines.append("    evenOdd: true,")
        lines.append(f"    path:\n        '{data}',")
        lines.append("  ),")
    lines.append("};")

    out = root / "lib" / "ui" / "widgets" / "service_marks.data.dart"
    out.write_text("\n".join(lines) + "\n")
    print(f"wrote {out} ({out.stat().st_size} bytes)", file=sys.stderr)


if __name__ == "__main__":
    main()
