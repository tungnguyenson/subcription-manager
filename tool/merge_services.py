#!/usr/bin/env python3
"""Merge the per-batch dataset files into assets/services.json.

Refuses to write when any batch fails validation, when two batches claim the
same id, or when an alias would make two services answer the same search. The
app's search returns the first prefix match, so a shared alias is not a warning:
it is one of the two services becoming unreachable.

    python3 tool/merge_services.py            # check only
    python3 tool/merge_services.py --write
"""

import glob
import json
import statistics
import sys
from datetime import date

sys.path.insert(0, "tool")
from validate_services import validate  # noqa: E402

BATCH_GLOB = "data/services/*.json"
OUT = "assets/services.json"
SCHEMA_VERSION = 3

# The app's own normaliser, kept in step with ServiceCatalog._foldMap.
FOLD = {}
for plain, accented in {
    "a": "àáạảãâầấậẩẫăằắặẳẵ", "e": "èéẹẻẽêềếệểễ", "i": "ìíịỉĩ",
    "o": "òóọỏõôồốộổỗơờớợởỡ", "u": "ùúụủũưừứựửữ", "y": "ỳýỵỷỹ", "d": "đ",
}.items():
    for ch in accented:
        FOLD[ch] = plain


def normalize(s):
    return "".join(FOLD.get(c, c) for c in s.lower()).strip()


def legacy_fields(entry):
    """Rebuild the v2 fields so existing app code keeps working unchanged.

    Prefers the Vietnamese price, because that is what the user is actually
    charged; falls back to the global one. Monthly over yearly, because the
    add form shows a per-cycle figure.
    """
    plans = entry.get("plans") or []
    default = entry.get("defaultPlan")
    candidates = [p for p in plans if p.get("tier") == default] or plans
    for region in ("VN", "GLOBAL"):
        for cycle in ("MONTHLY", "YEARLY", "QUARTERLY", "WEEKLY", "SEMIANNUAL"):
            for p in candidates:
                if p.get("region") == region and p.get("cycle") == cycle:
                    return p["amountMinor"], p["currency"], cycle
    return None, None, entry.get("defaultCycle")


def main(argv):
    write = "--write" in argv
    paths = sorted(glob.glob(BATCH_GLOB))
    if not paths:
        raise SystemExit(f"no batch files at {BATCH_GLOB}")

    failed = False
    for path in paths:
        rep = validate(path)
        if rep.errors:
            failed = True
            print(f"FAIL  {path}")
            for e in rep.errors[:10]:
                print(f"      {e}")
    if failed:
        raise SystemExit("fix the batch files first; nothing was written")

    entries, seen_id, seen_alias = [], {}, {}
    for path in paths:
        data = json.load(open(path, encoding="utf-8"))
        for e in data["entries"]:
            if e["id"] in seen_id:
                raise SystemExit(
                    f'id "{e["id"]}" is in both {seen_id[e["id"]]} and {path}')
            seen_id[e["id"]] = path

            for alias in [e["name"]] + e.get("aliases", []):
                key = normalize(alias)
                if key in seen_alias and seen_alias[key] != e["id"]:
                    raise SystemExit(
                        f'"{alias}" is a search term for both '
                        f'{seen_alias[key]} and {e["id"]}')
                seen_alias[key] = e["id"]

            amount, currency, cycle = legacy_fields(e)
            clean = {k: v for k, v in e.items()
                     if not k.startswith("_") and v is not None and v != []}
            clean["plans"] = e.get("plans") or []
            if amount is not None:
                clean["typicalAmountMinor"] = amount
                clean["currency"] = currency
            if cycle:
                clean["defaultCycle"] = cycle
            entries.append(clean)

    entries.sort(key=lambda e: (e["category"], e["id"]))

    # A price three times off its category's median is usually a tier mix-up
    # (the family plan recorded as the individual one), not a real outlier.
    by_category = {}
    for e in entries:
        for p in e["plans"]:
            if p["cycle"] != "MONTHLY":
                continue
            by_category.setdefault((e["category"], p["currency"]), []).append(
                (p["amountMinor"], e["id"]))
    for (category, cur), rows in sorted(by_category.items()):
        if len(rows) < 5:
            continue
        median = statistics.median(a for a, _ in rows)
        for amount, eid in rows:
            if amount > median * 3 or amount * 3 < median:
                print(f"  check  {eid}: {amount} {cur}/tháng vs {category} "
                      f"median {median:.0f}")

    priced = sum(1 for e in entries if e["plans"])
    yearly = sum(1 for e in entries
                 if any(p["cycle"] == "YEARLY" for p in e["plans"]))
    print(f"{len(entries)} entries, {priced} priced, {yearly} with a yearly "
          f"plan to compare against")

    if not write:
        print("(dry run — pass --write to update assets/services.json)")
        return 0

    with open(OUT, "w", encoding="utf-8") as f:
        json.dump({"schemaVersion": SCHEMA_VERSION,
                   "generatedAt": date.today().isoformat(),
                   "entries": entries}, f, ensure_ascii=False, indent=2)
        f.write("\n")
    print(f"wrote {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
