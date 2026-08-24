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
  file    -- tool/brand_icons/<key>.svg, checked into the repo

The "file" source exists because a brand that publishes no vector in any open
set used to have no route to a mark at all. Its logo is downloaded once by hand
and committed, which also means a mark cannot disappear underneath us: several
brands have had themselves removed from the open sets after we started using
them, and a checked-in file is immune to that.

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

# Kept in step with BrandMark.grid in service_mark.dart.
BrandMark_grid = 24.0
SIMPLE_ICONS_DATA = "https://cdn.jsdelivr.net/npm/simple-icons@16.28.0/data/simple-icons.json"

# key -> (source, brand colour, simple-icons slug to read the colour from)
#
# The source is either an Iconify icon ("prefix:name") or "file:<key>", which
# reads tool/brand_icons/<key>.svg instead of going to the network.
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

    # -- the 2026 catalogue expansion ---------------------------------------
    "airtable":             ("thesvg:airtable", "18BFFF", None),
    "amazon-music":         ("simple-icons:amazonmusic", "FF9900", "amazonmusic"),
    "amazon-prime-video":   ("simple-icons:primevideo", "00A8E1", "primevideo"),
    "apple-arcade":         ("thesvg:apple-arcade", "000000", None),
    "apple-news":           ("thesvg:apple-news", "FD415E", None),
    "asana":                ("thesvg:asana", "F06A6A", None),
    "audible":              ("thesvg:audible", "F8991C", None),
    "badoo":                ("thesvg:badoo", "783BF9", None),
    "bitwarden":            ("thesvg:bitwarden", "175DDC", None),
    "bkav-pro":             ("file:bkav-pro", "FF6E01", None),
    "box":                  ("thesvg:box", "0061D5", None),
    "bumble":               ("file:bumble", "FFDB5B", None),
    "canva":                ("cib:canva", "00C4CC", None),
    "cleanmymac":           ("thesvg:macpaw", "000000", None),
    "clickup":              ("thesvg:clickup", "7B68EE", None),
    "cloudflare":           ("thesvg:cloudflare", "F38020", None),
    "codecademy":           ("thesvg:codecademy", "1F4056", None),
    "coursera":             ("thesvg:coursera", "0056D2", None),
    "crunchyroll":          ("thesvg:crunchyroll", "FF5E00", None),
    "dashlane":             ("thesvg:dashlane", "0E353D", None),
    "datacamp":             ("thesvg:datacamp", "03EF62", None),
    "deezer":               ("thesvg:deezer", "A238FF", None),
    "deliveroo-plus":       ("thesvg:deliveroo", "00CCBC", None),
    "discord-nitro":        ("thesvg:discord", "5865F2", None),
    "duolingo":             ("thesvg:duolingo", "58CC02", None),
    "ea-play":              ("thesvg:ea", "000000", None),
    "elevenlabs":           ("thesvg:elevenlabs", "000000", None),
    "elsa-speak":           ("file:elsa-speak", "042132", None),
    "evernote":             ("thesvg:evernote", "00A82D", None),
    "expressvpn":           ("thesvg:expressvpn", "DA3940", None),
    "fiin":                 ("file:fiin", "06509F", None),
    "fitbit-premium":       ("thesvg:fitbit", "00B0B9", None),
    "fonos":                ("file:fonos", "ED7873", None),
    "garmin-connect-plus":  ("thesvg:garmin", "000000", None),
    "geforce-now":          ("thesvg:nvidia", "76B900", None),
    "github":               ("thesvg:github", "181717", None),
    "google-play-pass":     ("thesvg:google-play", "414141", None),
    "grab-unlimited":       ("thesvg:grab", "00B14F", None),
    "grammarly":            ("thesvg:grammarly", "027E6F", None),
    "grok":                 ("logos:x-ai", "000000", None),
    "headspace":            ("thesvg:headspace", "F47D31", None),
    "hellofresh":           ("thesvg:hellofresh", "99CC33", None),
    "hulu":                 ("cib:hulu", "1CE783", None),
    "lastpass":             ("thesvg:lastpass", "D32D27", None),
    "linear":               ("thesvg:linear", "5E6AD2", None),
    "linkedin-learning":    ("cib:linkedin", "0A66C2", None),
    "linkedin-premium":     ("cib:linkedin", "0A66C2", None),
    "malwarebytes":         ("thesvg:malwarebytes", "0D3ECC", None),
    "masterclass":          ("file:masterclass", "E32652", None),
    "mcafee":               ("thesvg:mcafee", "C01818", None),
    "medium":               ("thesvg:medium", "000000", None),
    "mega":                 ("thesvg:mega", "D9272E", None),
    "meta-verified":        ("thesvg:meta", "0467DF", None),
    "miro":                 ("thesvg:miro", "050038", None),
    "mubi":                 ("thesvg:mubi", "000000", None),
    "mullvad":              ("thesvg:mullvad", "294D73", None),
    "nebula":               ("thesvg:nebula", "2CADFE", None),
    "noom":                 ("file:noom", "FB513B", None),
    "nordvpn":              ("thesvg:nordvpn", "4687FF", None),
    "norton-360":           ("thesvg:norton", "FFE01A", None),
    "nyt":                  ("thesvg:new-york-times", "000000", None),
    "obsidian-sync":        ("thesvg:obsidian", "7C3AED", None),
    "okcupid":              ("thesvg:okcupid", "0500BE", None),
    "paramount-plus":       ("thesvg:paramountplus", "0064FF", None),
    "patreon":              ("thesvg:patreon", "000000", None),
    "peacock":              ("file:peacock", "000000", None),
    "peloton":              ("thesvg:peloton", "181A1D", None),
    "poe":                  ("thesvg:poe", "5D5CDE", None),
    "proton-drive":         ("thesvg:proton-drive", "EB508D", None),
    "proton-vpn":           ("thesvg:proton-vpn", "66DEB1", None),
    "quizlet":              ("thesvg:quizlet", "4255FF", None),
    "raycast":              ("thesvg:raycast", "FF6363", None),
    "reddit-premium":       ("thesvg:reddit", "FF4500", None),
    "replit":               ("thesvg:replit", "F26207", None),
    "roblox-premium":       ("thesvg:roblox", "000000", None),
    "runway":               ("file:runway", "0C0C0C", None),
    "setapp":               ("thesvg:setapp", "E6C3A5", None),
    "skillshare":           ("thesvg:skillshare", "00FF84", None),
    "slack":                ("simple-icons:slack", "4A154B", "slack"),
    "snapchat-plus":        ("thesvg:snapchat", "FFFC00", None),
    "soundcloud-go":        ("thesvg:soundcloud", "FF5500", None),
    "strava":               ("thesvg:strava", "FC4C02", None),
    "substack":             ("thesvg:substack", "FF6719", None),
    "suno":                 ("thesvg:suno", "000000", None),
    "surfshark":            ("thesvg:surfshark", "1EBFBF", None),
    "synology-c2":          ("thesvg:synology", "B5B5B6", None),
    "telegram-premium":     ("thesvg:telegram", "26A5E4", None),
    "the-economist":        ("file:the-economist", "E3120B", None),
    "tidal":                ("thesvg:tidal", "000000", None),
    "tinder":               ("thesvg:tinder", "FF6B6B", None),
    "todoist":              ("thesvg:todoist", "E44332", None),
    "tradingview":          ("thesvg:tradingview", "131622", None),
    "trello":               ("thesvg:trello", "0052CC", None),
    "twitch-turbo":         ("thesvg:twitch", "9146FF", None),
    "uber-one":             ("thesvg:uber", "000000", None),
    "v0":                   ("thesvg:v0", "000000", None),
    "webtoon":              ("thesvg:webtoon", "00D564", None),
    "whoop":                ("file:whoop", "000000", None),
    "x-premium":            ("thesvg:x", "000000", None),
    "zoom":                 ("thesvg:zoom", "0B5CFF", None),
}


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "subdock-icon-gen"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read().decode("utf-8")


def parse_svg(svg, name):
    if "<" not in svg:
        raise SystemExit(f"{name}: not an SVG -- {svg[:80]!r}")
    # Any positional transform, on any element. The earlier form of this check
    # looked for "<g" and "transform" separately, which got both answers wrong:
    # a transform sitting directly on a <path> passed through and drew the mark
    # in the wrong place, while a file with an unrelated <g> and a
    # gradientTransform was rejected for a transform it did not have.
    transformed = re.search(r'(?<![-\w])transform\s*=', svg)
    if transformed:
        raise SystemExit(f"{name}: has a transform, handle it by hand")

    box = re.search(r'viewBox="([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)"', svg)
    if not box:
        raise SystemExit(f"{name}: no viewBox")
    vx, vy, vw, vh = (float(g) for g in box.groups())

    paths = re.findall(r"<path\b([^>]*)>", svg)
    if not paths:
        raise SystemExit(f"{name}: no <path>")

    # Illustrator exports put the fill rule in a <style> block and reference it
    # by class, so reading the attribute alone misses it and the holes in a mark
    # come out filled solid -- a difference that only shows up in the render.
    even_odd = any('fill-rule="evenodd"' in attrs for attrs in paths) or bool(
        re.search(r"fill-rule\s*:\s*evenodd", svg)
    )
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
        if icon.startswith("file:"):
            path = root / "tool" / "brand_icons" / f"{icon[5:]}.svg"
            if not path.exists():
                raise SystemExit(f"{key}: {path} is missing")
            svg = path.read_text()
        else:
            svg = fetch(ICONIFY.format(icon))
            if svg.strip() == "404":
                raise SystemExit(f"{key}: {icon} is gone from its icon set")
        segments, viewbox, even_odd = parse_svg(svg, key)
        data = encode(segments, viewbox)
        # Some sources draw outside the viewBox they declare. Scaling by that
        # viewBox then leaves the mark hanging over the tile, and the clip makes
        # it look like a badly cropped logo rather than a broken source file.
        coords = [float(t) for t in data.split() if t not in ("M", "L", "C", "Z")]
        if coords and (min(coords) < -1 or max(coords) > BrandMark_grid + 1):
            raise SystemExit(
                f"{key}: {icon} draws outside its own viewBox "
                f"({min(coords):.1f}..{max(coords):.1f} on a {BrandMark_grid:.0f} "
                f"grid) -- give this one a category glyph instead"
            )
        colour = hexes.get(si_slug or "", fallback_hex)
        # A wordmark two units tall on a 24-unit grid is a smudge, not a mark.
        # Not fatal -- Zoom reads fine at 5.6 -- but worth saying out loud,
        # because it is only visible in the golden sheet otherwise.
        ys = coords[1::2]
        if ys and max(ys) - min(ys) < 6:
            print(
                f"  ! {key}: only {max(ys) - min(ys):.1f} units tall, check it "
                f"is still legible in the golden sheet",
                file=sys.stderr,
            )

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
