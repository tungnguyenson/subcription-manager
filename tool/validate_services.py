#!/usr/bin/env python3
"""Validate one batch file of the service dataset.

Run by each collector agent before it reports done, and again over every batch
at merge time. It refuses a file rather than repairing it: a price that quietly
gets "fixed" here would ship looking exactly like a verified one.

    python3 tool/validate_services.py data/services/ai.json
    python3 tool/validate_services.py data/services/*.json
"""

import json
import re
import sys
from datetime import date

CATEGORIES = {
    "AI", "STREAMING", "MUSIC", "GAMING", "PRODUCTIVITY", "SOCIAL", "NEWS",
    "FOOD", "FITNESS", "FINANCE", "EDUCATION", "SECURITY", "ENTERTAINMENT",
    "TRAVEL", "DATING", "STORAGE", "PHONE",
    "UTILITIES", "HOUSING", "DOCUMENTS", "INSURANCE",
}
CYCLES = {"WEEKLY", "MONTHLY", "QUARTERLY", "SEMIANNUAL", "YEARLY"}
REGIONS = {"VN", "GLOBAL"}
CURRENCY_OF_REGION = {"VN": "VND", "GLOBAL": "USD"}

ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")

# Widest plausible band per currency, in minor units. Deliberately loose: this
# catches the 100x slip and the "typed the monthly price into the yearly row"
# slip, not an opinion about what a service should cost.
VND_MIN, VND_MAX = 1_000, 100_000_000
USD_MIN, USD_MAX = 99, 200_000

TODAY = date.today().isoformat()


class Report:
    def __init__(self, path):
        self.path = path
        self.errors = []
        self.warnings = []

    def error(self, where, msg):
        self.errors.append(f"{where}: {msg}")

    def warn(self, where, msg):
        self.warnings.append(f"{where}: {msg}")


def check_plan(rep, eid, i, plan):
    where = f"{eid}.plans[{i}]"
    if not isinstance(plan, dict):
        rep.error(where, "must be an object")
        return

    for key in ("tier", "name", "region", "currency", "cycle", "amountMinor",
                "source", "checkedAt"):
        if plan.get(key) in (None, ""):
            rep.error(where, f'missing "{key}"')

    tier = plan.get("tier")
    if isinstance(tier, str) and not ID_RE.match(tier):
        rep.error(where, f'tier "{tier}" must be a lowercase slug')

    region = plan.get("region")
    if region not in REGIONS:
        rep.error(where, f'region "{region}" is not one of {sorted(REGIONS)}')

    currency = plan.get("currency")
    if region in CURRENCY_OF_REGION and currency != CURRENCY_OF_REGION[region]:
        rep.error(where, f'region {region} must be priced in '
                         f'{CURRENCY_OF_REGION[region]}, got "{currency}"')

    cycle = plan.get("cycle")
    if cycle not in CYCLES:
        rep.error(where, f'cycle "{cycle}" is not one of {sorted(CYCLES)}')

    amount = plan.get("amountMinor")
    if not isinstance(amount, int) or isinstance(amount, bool):
        rep.error(where, "amountMinor must be a whole number of minor units")
    elif currency == "VND" and not (VND_MIN <= amount <= VND_MAX):
        rep.error(where, f"{amount} VND is outside the plausible band "
                         f"(looks multiplied or divided by 100)")
    elif currency == "USD" and not (USD_MIN <= amount <= USD_MAX):
        rep.error(where, f"{amount} US cents is outside the plausible band")
    elif currency == "VND" and amount % 1000 != 0:
        rep.warn(where, f"{amount} VND is not a round thousand — double check")

    source = plan.get("source")
    if isinstance(source, str) and not source.startswith("https://"):
        rep.error(where, "source must be an https url to the vendor's own "
                         "pricing page")

    checked = plan.get("checkedAt")
    if isinstance(checked, str):
        if not DATE_RE.match(checked):
            rep.error(where, f'checkedAt "{checked}" must be YYYY-MM-DD')
        elif checked > TODAY:
            rep.error(where, f"checkedAt {checked} is in the future")

    seats = plan.get("seats")
    if seats is not None and (not isinstance(seats, int) or seats < 1):
        rep.error(where, "seats must be a positive whole number")


def check_entry(rep, entry, seen_ids):
    if not isinstance(entry, dict):
        rep.error("<entry>", "must be an object")
        return

    eid = entry.get("id")
    if not isinstance(eid, str) or not ID_RE.match(eid or ""):
        rep.error(str(eid), "id must be a lowercase kebab-case slug")
        return
    if eid in seen_ids:
        rep.error(eid, "duplicate id in this file")
    seen_ids.add(eid)

    if not entry.get("name"):
        rep.error(eid, 'missing "name"')

    if entry.get("category") not in CATEGORIES:
        rep.error(eid, f'category "{entry.get("category")}" is not one of '
                       f'{sorted(CATEGORIES)}')
    elif entry.get("category") == "OTHER":
        rep.error(eid, "OTHER means the catalog knows the service and still "
                       "makes the user classify it")

    aliases = entry.get("aliases", [])
    if not isinstance(aliases, list):
        rep.error(eid, "aliases must be a list")
    else:
        for a in aliases:
            if not isinstance(a, str) or a != a.lower():
                rep.error(eid, f'alias "{a}" must be a lowercase string')

    cycle = entry.get("defaultCycle")
    if cycle is not None and cycle not in CYCLES:
        rep.error(eid, f'defaultCycle "{cycle}" is not one of {sorted(CYCLES)}')

    for field in ("cancelUrl", "manageUrl"):
        url = entry.get(field)
        if url is not None and not str(url).startswith("https://"):
            rep.error(eid, f"{field} must be https")

    if entry.get("_todo"):
        rep.error(eid, "still marked _todo — the stub was never filled in")

    plans = entry.get("plans")
    if not isinstance(plans, list):
        rep.error(eid, '"plans" must be a list (use [] when no price could be '
                       'sourced)')
        return

    for i, plan in enumerate(plans):
        check_plan(rep, eid, i, plan)

    combos = {}
    for plan in plans:
        if not isinstance(plan, dict):
            continue
        key = (plan.get("tier"), plan.get("region"), plan.get("cycle"))
        if key in combos:
            rep.error(eid, f"two plans share tier/region/cycle {key}")
        combos[key] = plan.get("amountMinor")

    # The slip this catches: a yearly row holding the monthly figure, which
    # would make the app claim a 92% saving on switching to yearly.
    for (tier, region, cycle), amount in combos.items():
        if cycle != "YEARLY":
            continue
        monthly = combos.get((tier, region, "MONTHLY"))
        if not isinstance(monthly, int) or not isinstance(amount, int):
            continue
        if amount <= monthly:
            rep.error(eid, f"yearly {tier}/{region} ({amount}) is not above "
                           f"the monthly price ({monthly})")
        elif amount > monthly * 12:
            rep.error(eid, f"yearly {tier}/{region} ({amount}) costs more than "
                           f"12 monthly payments ({monthly * 12})")

    default = entry.get("defaultPlan")
    tiers = {p.get("tier") for p in plans if isinstance(p, dict)}
    if plans and default not in tiers:
        rep.error(eid, f'defaultPlan "{default}" matches no plan tier '
                       f'{sorted(t for t in tiers if t)}')
    if not plans and default:
        rep.error(eid, "defaultPlan is set but there are no plans")


def validate(path):
    rep = Report(path)
    try:
        data = json.loads(open(path, encoding="utf-8").read())
    except (OSError, json.JSONDecodeError) as e:
        rep.error(path, str(e))
        return rep

    if not isinstance(data, dict) or not isinstance(data.get("entries"), list):
        rep.error(path, 'root must be an object with an "entries" list')
        return rep

    seen = set()
    for entry in data["entries"]:
        check_entry(rep, entry, seen)
    return rep


def main(argv):
    if len(argv) < 2:
        print(__doc__)
        return 2

    failed = False
    for path in argv[1:]:
        rep = validate(path)
        priced = 0
        try:
            entries = json.load(open(path, encoding="utf-8"))["entries"]
            priced = sum(1 for e in entries if e.get("plans"))
            total = len(entries)
        except Exception:
            total = 0
        for w in rep.warnings:
            print(f"  warn  {w}")
        for e in rep.errors:
            print(f"  ERROR {e}")
        status = "FAIL" if rep.errors else "ok"
        print(f"{status:>5}  {path}  —  {total} entries, {priced} priced, "
              f"{len(rep.errors)} errors, {len(rep.warnings)} warnings")
        failed = failed or bool(rep.errors)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
