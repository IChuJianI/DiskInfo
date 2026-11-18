#!/usr/bin/env python3
"""Convert CrystalDiskInfo .lang SMART dictionaries to JSON rawfiles."""
import json
import os
import re
import sys

LANGS = {
    "en": "English.lang",
    "zh": "Simplified Chinese.lang",
}
SECTIONS = ("Smart", "SmartSsd", "SmartNVMe")


def parse_lang(path):
    text = open(path, "rb").read().decode("utf-16")
    result = {}
    current = None
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("["):
            match = re.match(r"\[([^\]]+)\]", stripped)
            current = match.group(1) if match else None
            continue
        if not current or "=" not in line or stripped.startswith(";"):
            continue
        key, value = line.split("=", 1)
        result.setdefault(current, {})[key.strip()] = value.strip()
    return result


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    lang_dir = os.path.join(root, "CrystalDiskInfo-master", "Language")
    out_dir = os.path.join(root, "entry", "src", "main", "resources", "rawfile", "smart")
    os.makedirs(out_dir, exist_ok=True)

    for code, filename in LANGS.items():
        source = os.path.join(lang_dir, filename)
        if not os.path.exists(source):
            sys.exit(f"missing language file: {source}")
        parsed = parse_lang(source)
        payload = {}
        for section in SECTIONS:
            entries = parsed.get(section)
            if not entries:
                continue
            payload[section] = {k: entries[k] for k in sorted(entries)}
        target = os.path.join(out_dir, f"{code}.json")
        with open(target, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, separators=(",", ":"))
        print(f"{target}: {sum(len(v) for v in payload.values())} keys")


if __name__ == "__main__":
    main()
