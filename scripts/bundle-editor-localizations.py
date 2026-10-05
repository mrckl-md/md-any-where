#!/usr/bin/env python3
"""Compile offline browser catalogs in an editor resource directory.

JSON catalogs remain the source of truth. App packaging and WebKit regression
fixtures call this after copying resources, so a stale generated source bundle
cannot omit newly translated languages from a release.
"""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('editor', type=Path, help='Editor resource directory containing locales/*.json')
args = parser.parse_args()
catalogs = {}
for path in sorted((args.editor / 'locales').glob('*.json')):
    values = json.loads(path.read_text())
    if not isinstance(values, dict) or not all(isinstance(key, str) and isinstance(value, str) for key, value in values.items()):
        raise SystemExit(f'Invalid flat string catalog: {path}')
    catalogs[path.stem] = values
if 'en' not in catalogs:
    raise SystemExit('The editor must include its English fallback catalog.')
# Escaping separators and closing-script characters also makes this safe to
# inspect/embed during tooling; the application loads it as an external script.
encoded = json.dumps(catalogs, ensure_ascii=False, separators=(',', ':'))
encoded = encoded.replace('\u2028', '\\u2028').replace('\u2029', '\\u2029').replace('</', '<\\/')
(args.editor / 'catalogs.js').write_text('/* Generated from locales/*.json; no network requests. */\nwindow.DotMDLocaleCatalogs = ' + encoded + ';\n')
