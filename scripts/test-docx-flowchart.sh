#!/bin/zsh
set -euo pipefail

project_dir="${0:A:h:h}"
test_dir="$(mktemp -d /private/tmp/dot-md-docx-flowchart.XXXXXXXX)"
trap 'rm -rf "$test_dir"' EXIT
module_cache="${TMPDIR:-/private/tmp}/dot-md-docx-flowchart-module-cache"
cp -R "$project_dir/Sources/DOTMD/Resources" "$test_dir/Editor"
python3 "$project_dir/scripts/bundle-editor-localizations.py" "$test_dir/Editor"
cp "$project_dir/tests/fixtures/mobile-demo.md" "$test_dir/Editor/mobile-demo.md"
python3 - "$test_dir/Editor/index.html" <<'PY'
from pathlib import Path
import sys
page = Path(sys.argv[1])
html = page.read_text().replace('</head>', '<link rel="stylesheet" href="ipad.css">\n</head>')
page.write_text(html.replace('</body>', '<script src="ipad.js"></script>\n</body>'))
PY
CLANG_MODULE_CACHE_PATH="$module_cache" SWIFT_MODULECACHE_PATH="$module_cache" \
  xcrun swiftc -swift-version 5 "$project_dir/Sources/DOTMDLocalization/InterfaceLocalization.swift" \
  "$project_dir/Sources/DOTMDLocalization/EnglishFallback.swift" \
  "$project_dir/Sources/DOTMD/DocxExporter.swift" \
  "$project_dir/scripts/test-docx-flowchart.swift" -o "$test_dir/test-flowchart" -framework AppKit -framework WebKit
"$test_dir/test-flowchart" "$test_dir/Editor" "$test_dir/flowchart.docx"
python3 - "$test_dir/flowchart.docx" <<'PY'
from pathlib import Path
import sys, zipfile, struct, xml.etree.ElementTree as ET
with zipfile.ZipFile(sys.argv[1]) as docx:
    assert docx.testzip() is None
    for name in docx.namelist():
        if name.endswith(('.xml', '.rels')):
            ET.fromstring(docx.read(name))
    media = [name for name in docx.namelist() if name.startswith('word/media/')]
    assert len(media) == 1, media
    png = docx.read(media[0])
    assert png[:8] == b'\x89PNG\r\n\x1a\n'
    assert min(struct.unpack('>II', png[16:24])) > 100
    ns = {'w':'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
          'm':'http://schemas.openxmlformats.org/officeDocument/2006/math',
          'a':'http://schemas.openxmlformats.org/drawingml/2006/main',
          'r':'http://schemas.openxmlformats.org/officeDocument/2006/relationships'}
    document = ET.fromstring(docx.read('word/document.xml'))
    assert len(document.findall('.//w:drawing', ns)) == 1
    assert document.findall('.//m:oMath', ns)
    assert document.findall('.//w:tbl', ns)
    assert '公开演示文稿' in ''.join(document.itertext())
    relationship_id = document.find('.//a:blip', ns).attrib['{' + ns['r'] + '}embed']
    relationships = ET.fromstring(docx.read('word/_rels/document.xml.rels'))
    assert any(rel.get('Id') == relationship_id and 'word/' + rel.get('Target', '') == media[0] for rel in relationships)
print('DOCX flowchart media, relationship, formula, table and document text regression passed.')
PY
