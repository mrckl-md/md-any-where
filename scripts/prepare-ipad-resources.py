#!/usr/bin/env python3
"""Package the shared editor with iPad-only additions, leaving macOS intact."""
from pathlib import Path
import shutil
import sys
import subprocess

project = Path(__file__).resolve().parent.parent
destination = Path(sys.argv[1]) / "Editor"
source = project / "Sources" / "MDAnyWhere" / "Resources"
destination.mkdir(parents=True, exist_ok=True)
shutil.copytree(source, destination, dirs_exist_ok=True,
                ignore=shutil.ignore_patterns(".DS_Store", "AppIcon.icns"))
html = (source / "index.html").read_text()
html = html.replace('width=device-width, initial-scale=1',
                    'width=device-width, initial-scale=1, viewport-fit=cover')
html = html.replace('</head>', '  <link rel="stylesheet" href="ipad.css">\n</head>')
html = html.replace('</body>', '  <script src="ipad.js"></script>\n</body>')
(destination / "index.html").write_text(html)

subprocess.run([sys.executable, str(project / "scripts/prepare-localizations.py"),
                str(destination.parent), "--catalogs", str(destination / "locales")], check=True)

subprocess.run([sys.executable, str(project / "scripts/bundle-editor-localizations.py"),
                str(destination)], check=True)
