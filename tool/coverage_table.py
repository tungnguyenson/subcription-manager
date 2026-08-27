#!/usr/bin/env python3
"""Bảng độ phủ từng dịch vụ, để người duyệt xem mục nào thu được gì.

Sinh ra từ dữ liệu thật chứ không viết tay, nên chạy lại sau mỗi đợt cập nhật là
bảng đúng trở lại:

    python3 tool/coverage_table.py > docs/research/catalog-coverage.md
"""

import json
import re
from collections import defaultdict

CATALOG = "assets/services.json"
MARKS = "lib/ui/widgets/service_mark.dart"

CATEGORY_VI = {
    "AI": "AI", "STREAMING": "Xem phim", "MUSIC": "Nghe nhạc",
    "GAMING": "Game", "PRODUCTIVITY": "Làm việc", "SOCIAL": "Mạng xã hội",
    "NEWS": "Báo chí", "FOOD": "Đồ ăn", "FITNESS": "Sức khoẻ",
    "FINANCE": "Tài chính", "EDUCATION": "Học tập", "SECURITY": "Bảo mật",
    "ENTERTAINMENT": "Giải trí", "TRAVEL": "Đi lại", "DATING": "Hẹn hò",
    "STORAGE": "Lưu trữ", "PHONE": "Di động & mạng",
    "UTILITIES": "Điện nước", "HOUSING": "Nhà cửa",
    "DOCUMENTS": "Giấy tờ", "INSURANCE": "Bảo hiểm",
}


def icon_rules():
    """Đọc luật nhận diện icon thẳng từ code, để bảng không lệch với app."""
    block = open(MARKS).read().split("_rules = [", 1)[1].split("\n  ];", 1)[0]
    pattern = re.compile(
        r"\(\s*'((?:[^'\\]|\\')*)',\s*"
        r"(BrandSpec\('[^']*'\)|GlyphSpec\([^()]*(?:\([^()]*\))?[^()]*\))\s*,?\s*\)",
        re.S,
    )
    return [
        (k.replace("\\'", "'"), re.sub(r"\s+", " ", v).strip())
        for k, v in pattern.findall(block)
    ]


def icon_tier(rules, name):
    haystack = name.lower()
    for keyword, spec in rules:
        if keyword in haystack:
            if spec.startswith("BrandSpec"):
                return "hãng"
            return "hình + màu" if "brandColour" in spec else "hình xám"
    return "**thiếu**"


def main():
    entries = json.load(open(CATALOG, encoding="utf-8"))["entries"]
    rules = icon_rules()

    by_category = defaultdict(list)
    for entry in entries:
        by_category[entry["category"]].append(entry)

    priced = sum(1 for e in entries if e.get("plans"))
    both = sum(
        1
        for e in entries
        if {p["cycle"] for p in e.get("plans", [])} >= {"MONTHLY", "YEARLY"}
    )

    out = []
    w = out.append
    w("# Bảng độ phủ từng dịch vụ")
    w("")
    w("Sinh tự động bằng `python3 tool/coverage_table.py`. Đừng sửa tay: chạy lại")
    w("sau mỗi lần cập nhật danh mục thì bảng tự đúng.")
    w("")
    w(f"**{len(entries)} dịch vụ | {priced} có giá | {both} so được gói năm**")
    w("")
    w("Cột **Giá** ghi số dòng giá thu được. Cột **Th+Năm** đánh dấu mục có đủ cả")
    w("gói tháng lẫn gói năm của cùng một gói, tức là mục app tính được tiền tiết")
    w("kiệm. Ô đánh dấu `·` nghĩa là không có.")
    w("")

    for category in sorted(by_category, key=lambda s: -len(by_category[s])):
        rows = sorted(by_category[category], key=lambda e: e["name"].lower())
        n_priced = sum(1 for e in rows if e.get("plans"))
        n_both = sum(
            1
            for e in rows
            if {p["cycle"] for p in e.get("plans", [])} >= {"MONTHLY", "YEARLY"}
        )
        w(f"## {CATEGORY_VI.get(category, category)} ({category})")
        w("")
        w(f"{len(rows)} mục, {n_priced} có giá, {n_both} so được gói năm.")
        w("")
        w("| Dịch vụ | Giá | Vùng | Th+Năm | Icon | Link gói | Link huỷ |")
        w("|---|---|---|---|---|---|---|")
        for e in rows:
            plans = e.get("plans", [])
            cycles = {p["cycle"] for p in plans}
            regions = sorted({p["region"] for p in plans})
            region = "+".join("VN" if r == "VN" else "toàn cầu" for r in regions)
            w(
                f"| {e['name']} "
                f"| {len(plans) or '·'} "
                f"| {region or '·'} "
                f"| {'✓' if cycles >= {'MONTHLY', 'YEARLY'} else '·'} "
                f"| {icon_tier(rules, e['name'])} "
                f"| {'✓' if e.get('manageUrl') else '·'} "
                f"| {'✓' if e.get('cancelUrl') else '·'} |"
            )
        w("")

    print("\n".join(out))


if __name__ == "__main__":
    main()
