#!/usr/bin/env python3
"""Split the work of building the service dataset into per-batch files.

Run once. It hands every collector agent a file of stubs to fill in, which is
what keeps ten agents working in parallel from either duplicating a service or
dropping one between them. Ids are assigned here, up front and globally unique,
so the merge at the end cannot collide.

Existing entries from assets/services.json are carried over whole, with their
old price parked in "_legacyPrice" for the agent to re-source or drop. The old
prices carry no source url, so they are not plans yet.

    python3 tool/seed_batches.py
"""

import json
import os
import unicodedata

OUT_DIR = "data/services"
EXISTING = "assets/services.json"

# id -> category, for the 71 entries that already ship.
EXISTING_CATEGORY = {
    "netflix": "STREAMING", "youtube-premium": "STREAMING",
    "hbo-go": "STREAMING", "disney-plus": "STREAMING",
    "fpt-play": "STREAMING", "vieon": "STREAMING",
    "galaxy-play": "STREAMING", "apple-tv": "STREAMING",
    "spotify": "MUSIC", "apple-music": "MUSIC", "nhaccuatui": "MUSIC",
    "zing-mp3": "MUSIC",
    "xbox-gamepass": "GAMING", "playstation-plus": "GAMING",
    "nintendo-online": "GAMING", "steam": "GAMING",
    "claude": "AI", "chatgpt": "AI", "gemini": "AI", "github-copilot": "AI",
    "cursor": "AI", "midjourney": "AI", "perplexity": "AI",
    "adobe-cc": "PRODUCTIVITY", "figma": "PRODUCTIVITY",
    "notion": "PRODUCTIVITY", "jetbrains": "PRODUCTIVITY",
    "microsoft-365": "PRODUCTIVITY", "domain": "PRODUCTIVITY",
    "vps-hosting": "PRODUCTIVITY", "vercel": "PRODUCTIVITY",
    "1password": "SECURITY",
    "icloud": "STORAGE", "google-one": "STORAGE", "dropbox": "STORAGE",
    "onedrive": "STORAGE", "backblaze": "STORAGE",
    "sim-viettel": "PHONE", "sim-vinaphone": "PHONE", "sim-mobifone": "PHONE",
    "sim-vietnamobile": "PHONE", "sim-itel": "PHONE", "sim-wintel": "PHONE",
    "goi-cuoc-data": "PHONE", "internet-fpt": "PHONE",
    "internet-viettel": "PHONE", "internet-vnpt": "PHONE",
    "truyen-hinh-cap": "PHONE",
    "dien": "UTILITIES", "nuoc": "UTILITIES", "gas": "UTILITIES",
    "phi-chung-cu": "HOUSING", "phi-rac": "HOUSING", "phi-gui-xe": "HOUSING",
    "khoan-vay": "FINANCE", "tra-gop": "FINANCE", "the-tin-dung": "FINANCE",
    "phi-thuong-nien": "FINANCE",
    "bhyt": "INSURANCE", "bh-nhan-tho": "INSURANCE", "bh-xe": "INSURANCE",
    "bh-suc-khoe": "INSURANCE", "bh-du-lich": "INSURANCE",
    "ho-chieu": "DOCUMENTS", "cccd": "DOCUMENTS", "gplx": "DOCUMENTS",
    "dang-kiem": "DOCUMENTS", "visa": "DOCUMENTS", "the-tam-tru": "DOCUMENTS",
    "giay-phep-kd": "DOCUMENTS", "chung-chi": "DOCUMENTS",
}

# batch -> (categorys it owns, new services to add as [id, name, category, note])
NEW = {
    "ai": [
        ("grok", "Grok", "AI", "gói riêng và gói kèm X Premium — lấy gói riêng"),
        ("microsoft-copilot", "Microsoft Copilot", "AI", ""),
        ("elevenlabs", "ElevenLabs", "AI", ""),
        ("suno", "Suno", "AI", ""),
        ("runway", "Runway", "AI", ""),
        ("leonardo-ai", "Leonardo AI", "AI", ""),
        ("deepseek", "DeepSeek", "AI", "chủ yếu bán theo API — có gói thuê bao không?"),
        ("windsurf", "Windsurf", "AI", ""),
        ("v0", "v0", "AI", "của Vercel"),
        ("lovable", "Lovable", "AI", ""),
        ("replit", "Replit", "AI", ""),
        ("poe", "Poe", "AI", ""),
        ("character-ai", "Character.AI", "AI", ""),
    ],
    "streaming": [
        ("k-plus", "K+", "STREAMING", "truyền hình thể thao VN"),
        ("tv360", "TV360", "STREAMING", "Viettel"),
        ("mytv", "MyTV", "STREAMING", "VNPT"),
        ("amazon-prime-video", "Amazon Prime Video", "STREAMING", ""),
        ("viu", "Viu", "STREAMING", ""),
        ("iqiyi", "iQIYI", "STREAMING", ""),
        ("wetv", "WeTV", "STREAMING", ""),
        ("crunchyroll", "Crunchyroll", "STREAMING", ""),
        ("hulu", "Hulu", "STREAMING", "Mỹ"),
        ("paramount-plus", "Paramount+", "STREAMING", "Mỹ"),
        ("peacock", "Peacock", "STREAMING", "Mỹ"),
        ("twitch-turbo", "Twitch Turbo", "STREAMING", ""),
    ],
    "music-gaming": [
        ("soundcloud-go", "SoundCloud Go+", "MUSIC", ""),
        ("tidal", "Tidal", "MUSIC", ""),
        ("amazon-music", "Amazon Music Unlimited", "MUSIC", ""),
        ("deezer", "Deezer", "MUSIC", ""),
        ("qobuz", "Qobuz", "MUSIC", ""),
        ("ea-play", "EA Play", "GAMING", ""),
        ("ubisoft-plus", "Ubisoft+", "GAMING", ""),
        ("apple-arcade", "Apple Arcade", "GAMING", ""),
        ("google-play-pass", "Google Play Pass", "GAMING", ""),
        ("geforce-now", "GeForce NOW", "GAMING", ""),
        ("discord-nitro", "Discord Nitro", "GAMING", "xếp Gaming, không xếp Social"),
        ("roblox-premium", "Roblox Premium", "GAMING", ""),
        ("minecraft-realms", "Minecraft Realms", "GAMING", ""),
        ("wow-sub", "World of Warcraft", "GAMING", "thuê bao chơi game"),
    ],
    "productivity": [
        ("google-workspace", "Google Workspace", "PRODUCTIVITY", ""),
        ("canva", "Canva Pro", "PRODUCTIVITY", "có bảng giá VND riêng"),
        ("zoom", "Zoom", "PRODUCTIVITY", ""),
        ("slack", "Slack", "PRODUCTIVITY", ""),
        ("grammarly", "Grammarly", "PRODUCTIVITY", ""),
        ("todoist", "Todoist", "PRODUCTIVITY", ""),
        ("evernote", "Evernote", "PRODUCTIVITY", ""),
        ("obsidian-sync", "Obsidian Sync", "PRODUCTIVITY", ""),
        ("trello", "Trello", "PRODUCTIVITY", ""),
        ("asana", "Asana", "PRODUCTIVITY", ""),
        ("clickup", "ClickUp", "PRODUCTIVITY", ""),
        ("linear", "Linear", "PRODUCTIVITY", ""),
        ("airtable", "Airtable", "PRODUCTIVITY", ""),
        ("miro", "Miro", "PRODUCTIVITY", ""),
        ("raycast", "Raycast Pro", "PRODUCTIVITY", ""),
        ("setapp", "Setapp", "PRODUCTIVITY", ""),
        ("github", "GitHub", "PRODUCTIVITY", "gói Pro cho cá nhân"),
        ("cloudflare", "Cloudflare", "PRODUCTIVITY", "gói Pro cho một site"),
    ],
    "social-news": [
        ("x-premium", "X Premium", "SOCIAL", "Twitter Blue cũ"),
        ("telegram-premium", "Telegram Premium", "SOCIAL", ""),
        ("linkedin-premium", "LinkedIn Premium", "SOCIAL", ""),
        ("meta-verified", "Meta Verified", "SOCIAL", ""),
        ("snapchat-plus", "Snapchat+", "SOCIAL", ""),
        ("reddit-premium", "Reddit Premium", "SOCIAL", ""),
        ("apple-news", "Apple News+", "NEWS", "chưa bán ở VN"),
        ("nyt", "The New York Times", "NEWS", ""),
        ("the-economist", "The Economist", "NEWS", ""),
        ("bloomberg", "Bloomberg", "NEWS", ""),
        ("wsj", "The Wall Street Journal", "NEWS", ""),
        ("financial-times", "Financial Times", "NEWS", ""),
        ("medium", "Medium", "NEWS", ""),
        ("substack", "Substack", "NEWS", "trả cho từng newsletter — giá thay đổi theo tác giả"),
        ("the-athletic", "The Athletic", "NEWS", ""),
    ],
    "food-fitness": [
        ("grab-unlimited", "GrabUnlimited", "FOOD", "VN"),
        ("shopeefood-xtra", "ShopeeFood Xtra", "FOOD", "VN, kiểm tra tên gói hiện tại"),
        ("be-hoi-vien", "be — Hội viên", "FOOD", "VN"),
        ("uber-one", "Uber One", "FOOD", ""),
        ("dashpass", "DoorDash DashPass", "FOOD", "Mỹ"),
        ("deliveroo-plus", "Deliveroo Plus", "FOOD", ""),
        ("hellofresh", "HelloFresh", "FOOD", ""),
        ("strava", "Strava", "FITNESS", ""),
        ("apple-fitness", "Apple Fitness+", "FITNESS", ""),
        ("myfitnesspal", "MyFitnessPal", "FITNESS", ""),
        ("fitbit-premium", "Fitbit Premium", "FITNESS", ""),
        ("garmin-connect-plus", "Garmin Connect+", "FITNESS", ""),
        ("whoop", "Whoop", "FITNESS", ""),
        ("oura", "Oura", "FITNESS", "membership tính theo tháng"),
        ("calm", "Calm", "FITNESS", ""),
        ("headspace", "Headspace", "FITNESS", ""),
        ("peloton", "Peloton", "FITNESS", ""),
        ("zwift", "Zwift", "FITNESS", ""),
        ("noom", "Noom", "FITNESS", ""),
        ("the-tap-gym", "Thẻ tập gym", "FITNESS", "MỤC CHUNG — plans: [], không bịa giá"),
    ],
    "finance-education": [
        ("tradingview", "TradingView", "FINANCE", ""),
        ("money-lover", "Money Lover", "FINANCE", "VN"),
        ("ynab", "YNAB", "FINANCE", ""),
        ("fiin", "FiinTrade", "FINANCE", "VN, dữ liệu chứng khoán"),
        ("vietstock", "Vietstock", "FINANCE", "VN"),
        ("simplize", "Simplize", "FINANCE", "VN"),
        ("phi-quan-ly-tk", "Phí quản lý tài khoản ngân hàng", "FINANCE", "MỤC CHUNG"),
        ("sms-banking", "SMS Banking", "FINANCE", "MỤC CHUNG, phí theo tháng"),
        ("duolingo", "Duolingo Super", "EDUCATION", ""),
        ("elsa-speak", "ELSA Speak", "EDUCATION", "VN"),
        ("monkey-junior", "Monkey", "EDUCATION", "VN, thường bán theo năm/trọn đời"),
        ("coursera", "Coursera Plus", "EDUCATION", ""),
        ("skillshare", "Skillshare", "EDUCATION", ""),
        ("masterclass", "MasterClass", "EDUCATION", ""),
        ("linkedin-learning", "LinkedIn Learning", "EDUCATION", ""),
        ("datacamp", "DataCamp", "EDUCATION", ""),
        ("codecademy", "Codecademy Pro", "EDUCATION", ""),
        ("brilliant", "Brilliant", "EDUCATION", ""),
        ("quizlet", "Quizlet Plus", "EDUCATION", ""),
        ("oreilly", "O'Reilly", "EDUCATION", ""),
        ("frontend-masters", "Frontend Masters", "EDUCATION", ""),
        ("babbel", "Babbel", "EDUCATION", ""),
        ("hoc-phi", "Học phí", "EDUCATION", "MỤC CHUNG, category BILL"),
    ],
    "security-storage": [
        ("nordvpn", "NordVPN", "SECURITY", ""),
        ("expressvpn", "ExpressVPN", "SECURITY", ""),
        ("surfshark", "Surfshark", "SECURITY", ""),
        ("proton-vpn", "Proton VPN", "SECURITY", ""),
        ("mullvad", "Mullvad", "SECURITY", ""),
        ("bitwarden", "Bitwarden Premium", "SECURITY", ""),
        ("dashlane", "Dashlane", "SECURITY", ""),
        ("lastpass", "LastPass", "SECURITY", ""),
        ("norton-360", "Norton 360", "SECURITY", ""),
        ("kaspersky", "Kaspersky", "SECURITY", ""),
        ("mcafee", "McAfee", "SECURITY", ""),
        ("malwarebytes", "Malwarebytes", "SECURITY", ""),
        ("bkav-pro", "Bkav Pro", "SECURITY", "VN"),
        ("cleanmymac", "CleanMyMac", "SECURITY", ""),
        ("mega", "MEGA", "STORAGE", ""),
        ("pcloud", "pCloud", "STORAGE", "có gói trọn đời — không phải chu kỳ"),
        ("proton-drive", "Proton Drive", "STORAGE", ""),
        ("box", "Box", "STORAGE", ""),
        ("sync-com", "Sync.com", "STORAGE", ""),
        ("synology-c2", "Synology C2", "STORAGE", ""),
        ("terabox", "TeraBox", "STORAGE", ""),
    ],
    "ent-travel-dating": [
        ("audible", "Audible", "ENTERTAINMENT", ""),
        ("kindle-unlimited", "Kindle Unlimited", "ENTERTAINMENT", ""),
        ("everand", "Everand", "ENTERTAINMENT", "Scribd cũ"),
        ("storytel", "Storytel", "ENTERTAINMENT", ""),
        ("waka", "Waka", "ENTERTAINMENT", "VN, ebook"),
        ("fonos", "Fonos", "ENTERTAINMENT", "VN, sách nói"),
        ("patreon", "Patreon", "ENTERTAINMENT", "trả cho từng creator — giá thay đổi"),
        ("nebula", "Nebula", "ENTERTAINMENT", ""),
        ("mubi", "MUBI", "ENTERTAINMENT", ""),
        ("webtoon", "WEBTOON", "ENTERTAINMENT", ""),
        ("priority-pass", "Priority Pass", "TRAVEL", "phòng chờ sân bay"),
        ("airalo", "Airalo", "TRAVEL", "eSIM du lịch, bán theo gói dung lượng"),
        ("ve-thang-xe-buyt", "Vé tháng xe buýt / metro", "TRAVEL", "MỤC CHUNG, VN"),
        ("tinder", "Tinder", "DATING", ""),
        ("bumble", "Bumble Premium", "DATING", ""),
        ("hinge", "Hinge", "DATING", ""),
        ("grindr", "Grindr XTRA", "DATING", ""),
        ("coffee-meets-bagel", "Coffee Meets Bagel", "DATING", ""),
        ("badoo", "Badoo Premium", "DATING", ""),
        ("happn", "happn Premium", "DATING", ""),
        ("okcupid", "OkCupid", "DATING", ""),
    ],
    "phone-vn": [
        ("vnsky", "VNSKY", "PHONE", "VN, nhà mạng ảo Mobicast"),
        ("goi-cuoc-tra-sau", "Gói cước trả sau", "PHONE", "MỤC CHUNG"),
    ],
}

BATCH_OWNS = {
    "ai": ["AI"],
    "streaming": ["STREAMING"],
    "music-gaming": ["MUSIC", "GAMING"],
    "productivity": ["PRODUCTIVITY"],
    "social-news": ["SOCIAL", "NEWS"],
    "food-fitness": ["FOOD", "FITNESS"],
    "finance-education": ["FINANCE", "EDUCATION"],
    "security-storage": ["SECURITY", "STORAGE"],
    "ent-travel-dating": ["ENTERTAINMENT", "TRAVEL", "DATING"],
    "phone-vn": ["PHONE", "UTILITIES", "HOUSING", "DOCUMENTS", "INSURANCE"],
}


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    existing = json.load(open(EXISTING, encoding="utf-8"))["entries"]
    by_id = {e["id"]: e for e in existing}

    missing = set(by_id) - set(EXISTING_CATEGORY)
    if missing:
        raise SystemExit(f"no category assigned for: {sorted(missing)}")

    category_to_batch = {s: b for b, ss in BATCH_OWNS.items() for s in ss}
    all_ids = set()

    for batch, categorys in BATCH_OWNS.items():
        entries = []

        for eid, old in by_id.items():
            category = EXISTING_CATEGORY[eid]
            if category_to_batch[category] != batch:
                continue
            entry = {
                "id": eid,
                "name": old["name"],
                "aliases": old.get("aliases", []),
                "category": category,
                "category": old["category"],
                "defaultCycle": old.get("defaultCycle"),
                "cancelUrl": old.get("cancelUrl"),
                "defaultPlan": None,
                "plans": [],
            }
            if old.get("typicalAmountMinor") is not None:
                entry["_legacyPrice"] = {
                    "amountMinor": old["typicalAmountMinor"],
                    "currency": old.get("currency"),
                    "cycle": old.get("defaultCycle"),
                    "note": "giá cũ, chưa có nguồn — xác minh lại rồi ghi vào plans",
                }
            entries.append(entry)

        for eid, name, category, note in NEW.get(batch, []):
            entries.append({
                "id": eid,
                "name": name,
                "aliases": [],
                "category": category,
                "category": "SUBSCRIPTION",
                "defaultCycle": "MONTHLY",
                "cancelUrl": None,
                "defaultPlan": None,
                "plans": [],
                "_todo": True,
                "_hint": note,
            })

        for e in entries:
            if e["id"] in all_ids:
                raise SystemExit(f"duplicate id across batches: {e['id']}")
            all_ids.add(e["id"])

        path = os.path.join(OUT_DIR, f"{batch}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump({"batch": batch, "categorys": categorys, "entries": entries},
                      f, ensure_ascii=False, indent=2)
            f.write("\n")
        todo = sum(1 for e in entries if e.get("_todo"))
        print(f"{path}: {len(entries)} entries ({todo} new, "
              f"{len(entries) - todo} carried over)")

    print(f"total {len(all_ids)} unique ids")


if __name__ == "__main__":
    main()
