#!/usr/bin/env python3
"""Package native language metadata from the same offline editor JSON catalogs.

This writes only build products; it does not rewrite translator-owned catalogs.
"""
import argparse
import json
import plistlib
from pathlib import Path

project = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('resources', type=Path, help='Application or extension resource directory')
parser.add_argument('--kind', choices=('application', 'preview', 'thumbnail'), default='application')
parser.add_argument('--catalogs', type=Path, default=project / 'Sources/DOTMD/Resources/locales')
args = parser.parse_args()
locales = json.loads((project / 'Support/Localization/locales.json').read_text())
english = json.loads((project / 'Support/Localization/native-en.json').read_text())
english.update(json.loads((args.catalogs / 'en.json').read_text()))
# Include the development language as well as every supported store locale.
for locale in ['en', *locales]:
    catalog = dict(english)
    locale_file = args.catalogs / f'{locale}.json'
    if locale_file.is_file():
        catalog.update(json.loads(locale_file.read_text()))
    name = 'md any where' if args.kind == 'application' else catalog[f'native.info.{args.kind}']
    values = {
        'CFBundleDisplayName': name,
        'CFBundleName': name,
        'Markdown Document': catalog['native.info.markdown'],
        'md any where Agent Command': catalog['native.info.agentCommand'],
    }
    destination = args.resources / f'{locale}.lproj'
    destination.mkdir(parents=True, exist_ok=True)
    # XML property lists are valid .strings files and safely escape all scripts,
    # quotations, line breaks, and ampersands from translated values.
    (destination / 'InfoPlist.strings').write_bytes(plistlib.dumps(values, fmt=plistlib.FMT_XML, sort_keys=True))
