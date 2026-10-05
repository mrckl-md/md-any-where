#!/usr/bin/env python3
"""Validate the offline App Store metadata set without contacting any service."""
import json
from pathlib import Path

root = Path(__file__).resolve().parent
manifest = json.loads((root / "localizations/manifest.json").read_text())
entries = manifest["locales"]
assert len(entries) == 50, "The checked Apple locale set contains 50 entries."
assert len({entry["app_store_locale"] for entry in entries}) == 50
expected_keys = set(json.loads((root / "en-US.json").read_text()))
assert expected_keys == set(json.loads((root / "zh-Hans.json").read_text()))
english = json.loads((root / "en-US.json").read_text())
required_tokens = ("md any where", "macOS", "iPhone", "iPad", "HTML", "PDF", "DOCX", "MCP", "CLI", "MIT")
for entry in entries:
    code = entry["app_store_locale"]
    path = root / "localizations" / entry["metadata_file"]
    document = json.loads(path.read_text())
    assert set(document) == expected_keys, (code, "Metadata field mismatch")
    assert document["name"] == "md any where", (code, "Brand must not be translated")
    assert all(isinstance(value, str) and value.strip() for value in document.values()), code
    for field, maximum in (("name", 30), ("subtitle", 30), ("promotional_text", 170), ("description", 4000)):
        # UTF-16 also catches supplementary characters that count as two units.
        units = len(document[field].encode("utf-16-le")) // 2
        assert units <= maximum, (code, field, units, maximum)
    assert len(document["keywords"].encode("utf-8")) <= 100, (code, "Keyword byte limit")
    for token in required_tokens:
        assert token in document["description"], (code, "Missing product boundary", token)
    if not code.startswith("en-"):
        assert document["description"] != english["description"], (code, "English copy is not a translation")
        assert document["review_notes"] != english["review_notes"], (code, "Untranslated review notes")
    assert document["support_email"] == "longshenggdgz@163.com"
    assert document["copyright"] == "© 2026 陈科霖"
    assert "�" not in "".join(document.values()), (code, "Invalid replacement character")
print("Validated all 50 App Store metadata locales, schema, UTF-16 lengths, keyword bytes, brand and platform boundaries.")
