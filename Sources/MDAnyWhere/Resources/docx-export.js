(() => {
  'use strict';
  const t = (key, args) => (globalThis.MDAnyWhereI18n || (typeof require === 'function' ? require('./i18n.js') : null))?.t(key, args) ?? key;
  const bindText = (element, render) => globalThis.MDAnyWhereI18n.bindText(element, render);
  const bindAttribute = (element, attribute, render) => globalThis.MDAnyWhereI18n.bindAttribute(element, attribute, render);


  const defaultLayoutSettings = {
    bodyCjkFont: '宋体', bodyLatinFont: 'Times New Roman',
    headingCjkFont: '黑体', headingLatinFont: 'Arial',
    mathCjkFont: '宋体', mathLatinFont: 'Cambria Math', codeFont: 'Menlo',
    bodySize: 11, headingScale: 1.55, lineSpacing: 1.5, paragraphAfter: 8,
    firstLineIndent: 0, bodyAlign: 'justify', headingAlign: 'left',
    pageSize: 'letter', marginTop: 25, marginBottom: 25, marginLeft: 25, marginRight: 25,
    pageNumbers: false
  };
  const layoutPresets = {
    standard: defaultLayoutSettings,
    'academic-cn': {
      ...defaultLayoutSettings, bodyCjkFont: '宋体', bodyLatinFont: 'Times New Roman',
      headingCjkFont: '黑体', headingLatinFont: 'Times New Roman',
      mathLatinFont: 'Times New Roman', bodySize: 12,
      headingScale: 1.5, lineSpacing: 1.5, paragraphAfter: 6,
      firstLineIndent: 8, pageSize: 'a4', marginTop: 28, marginBottom: 25,
      marginLeft: 30, marginRight: 25, pageNumbers: true
    },
    report: {
      ...defaultLayoutSettings, bodyCjkFont: 'PingFang SC', bodyLatinFont: 'Calibri',
      headingCjkFont: 'PingFang SC', headingLatinFont: 'Arial',
      bodySize: 11, lineSpacing: 1.25, paragraphAfter: 10,
      bodyAlign: 'left', marginTop: 22, marginBottom: 22
    }
  };
  const layoutControlIDs = {
    bodyCjkFont: 'docx-body-cjk-font', bodyLatinFont: 'docx-body-latin-font',
    headingCjkFont: 'docx-heading-cjk-font', headingLatinFont: 'docx-heading-latin-font',
    mathCjkFont: 'docx-math-cjk-font', mathLatinFont: 'docx-math-latin-font',
    codeFont: 'docx-code-font',
    bodySize: 'docx-body-size', headingScale: 'docx-heading-scale',
    lineSpacing: 'docx-line-spacing', paragraphAfter: 'docx-paragraph-after',
    firstLineIndent: 'docx-first-line-indent', bodyAlign: 'docx-body-align',
    headingAlign: 'docx-heading-align', pageSize: 'docx-page-size',
    marginTop: 'docx-margin-top', marginBottom: 'docx-margin-bottom',
    marginLeft: 'docx-margin-left', marginRight: 'docx-margin-right',
    pageNumbers: 'docx-page-numbers'
  };
  const numericLayoutKeys = new Set([
    'bodySize', 'headingScale', 'lineSpacing', 'paragraphAfter', 'firstLineIndent',
    'marginTop', 'marginBottom', 'marginLeft', 'marginRight'
  ]);
  const fontLayoutKeys = new Set([
    'bodyCjkFont', 'bodyLatinFont', 'headingCjkFont', 'headingLatinFont',
    'mathCjkFont', 'mathLatinFont', 'codeFont'
  ]);
  const allowedNumericRanges = {
    bodySize: [8, 24], headingScale: [1.05, 2.4], lineSpacing: [1, 3],
    paragraphAfter: [0, 36], firstLineIndent: [0, 20],
    marginTop: [10, 50], marginBottom: [10, 50], marginLeft: [10, 50], marginRight: [10, 50]
  };
  let editorBridge = null;
  let pendingLayoutSuggestion = null;
  let generatedListCount = 0;

  const elementByID = id => document.getElementById(id);
  const exportDialog = () => elementByID('docx-dialog');

  function normalizeLayoutSettings(raw) {
    const settings = { ...defaultLayoutSettings };
    if (!raw || typeof raw !== 'object') return settings;
    const migrated = { ...raw };
    // Settings saved before script-specific font support used one font per style.
    for (const [oldKey, cjkKey, latinKey] of [
      ['bodyFont', 'bodyCjkFont', 'bodyLatinFont'],
      ['headingFont', 'headingCjkFont', 'headingLatinFont']
    ]) {
      const oldFont = migrated[oldKey];
      if (typeof oldFont !== 'string' || !oldFont.trim()) continue;
      const isCjkFont = /[\u3400-\u9fff]|PingFang|Songti|Heiti|Noto.*CJK/i.test(oldFont);
      const destination = isCjkFont ? cjkKey : latinKey;
      if (migrated[destination] == null) migrated[destination] = oldFont;
    }
    for (const key of Object.keys(layoutControlIDs)) {
      const value = migrated[key];
      if (numericLayoutKeys.has(key)) {
        const number = Number(value);
        if (Number.isFinite(number)) settings[key] = Math.min(allowedNumericRanges[key][1], Math.max(allowedNumericRanges[key][0], number));
      } else if (key === 'pageNumbers') {
        if (typeof value === 'boolean') settings[key] = value;
      } else if (fontLayoutKeys.has(key)) {
        if (typeof value === 'string' && value.trim()) settings[key] = value.trim().slice(0, 80);
      } else if (key === 'pageSize') {
        if (['letter', 'a4'].includes(value)) settings[key] = value;
      } else if (key === 'bodyAlign') {
        if (['left', 'center', 'right', 'justify'].includes(value)) settings[key] = value;
      } else if (key === 'headingAlign') {
        if (['left', 'center', 'right'].includes(value)) settings[key] = value;
      }
    }
    return settings;
  }

  function getLayoutPreset(name) {
    return Object.hasOwn(layoutPresets, name) ? normalizeLayoutSettings(layoutPresets[name]) : null;
  }

  function readLayoutControls() {
    const raw = {};
    for (const [key, id] of Object.entries(layoutControlIDs)) {
      const value = elementByID(id).value;
      raw[key] = numericLayoutKeys.has(key) ? Number(value) : key === 'pageNumbers' ? value === 'true' : value;
    }
    return normalizeLayoutSettings(raw);
  }

  function applyLayoutToControls(settings, preset = 'custom') {
    const normalized = normalizeLayoutSettings(settings);
    for (const [key, id] of Object.entries(layoutControlIDs)) {
      elementByID(id).value = String(normalized[key]);
    }
    elementByID('docx-preset').value = preset;
    updateLayoutPreview();
    return normalized;
  }

  function renderMixedFontSample(host, text, cjkFont, latinFont) {
    const parts = text.match(/[\u3000-\u303f\u3400-\u9fff\uf900-\ufaff\uff00-\uffef]+|[^\u3000-\u303f\u3400-\u9fff\uf900-\ufaff\uff00-\uffef]+/gu) || [];
    const safeFamily = name => `"${name.replace(/["\\]/g, '')}", serif`;
    host.replaceChildren(...parts.map(part => {
      const span = document.createElement('span');
      span.textContent = part;
      span.style.fontFamily = safeFamily(/[\u3400-\u9fff\uf900-\ufaff]/u.test(part) ? cjkFont : latinFont);
      return span;
    }));
  }

  function updateLayoutPreview() {
    const settings = readLayoutControls();
    const page = elementByID('docx-page-preview');
    const title = page.querySelector('h3');
    renderMixedFontSample(title, editorBridge?.getTitle()?.replace(/\.md$/i, '') || t("web.5c4f95ad79"),
      settings.headingCjkFont, settings.headingLatinFont);
    title.style.fontSize = `${Math.min(settings.bodySize * settings.headingScale * 1.35, 27)}px`;
    title.style.textAlign = settings.headingAlign;
    page.style.fontSize = `${settings.bodySize}px`;
    page.style.lineHeight = settings.lineSpacing;
    page.style.textAlign = settings.bodyAlign;
    page.style.padding = `${Math.min(settings.marginTop, 40)}px ${Math.min(settings.marginLeft, 40)}px`;
    page.querySelectorAll('p').forEach(p => {
      const sampleText = t(p.classList.contains('docx-math-sample') ? 'web.27cbea00ec' : 'web.ed52dba279');
      renderMixedFontSample(p, sampleText,
        p.classList.contains('docx-math-sample') ? settings.mathCjkFont : settings.bodyCjkFont,
        p.classList.contains('docx-math-sample') ? settings.mathLatinFont : settings.bodyLatinFont);
      p.style.marginBottom = `${settings.paragraphAfter}px`;
      p.style.textIndent = `${settings.firstLineIndent}px`;
    });
    bindText(elementByID('docx-layout-summary'), () => t("web.fa010e6a66", { p0: settings.pageSize.toUpperCase(), p1: settings.bodyCjkFont, p2: settings.bodyLatinFont, p3: settings.mathCjkFont, p4: settings.mathLatinFont, p5: settings.bodySize, p6: settings.lineSpacing }));
    localStorage.docxLayout = JSON.stringify(settings);
  }

  function serializeMathMLNode(node) {
    if (!node || node.nodeType !== Node.ELEMENT_NODE) return null;
    const type = node.localName?.toLowerCase() || '';
    if (['annotation', 'annotation-xml'].includes(type)) return null;
    const children = [...node.children].map(serializeMathMLNode).filter(Boolean);
    const result = { type, children };
    if (['mi', 'mn', 'mo', 'mtext'].includes(type)) result.text = node.textContent || '';
    if (type === 'mfenced') {
      // Keep the serialized `open` key: Swift's DocxMathNode decodes it.
      result.open = node.getAttribute('open') || '(';
      result.close = node.getAttribute('close') || ')';
    }
    return result;
  }

  function mathMLFromElement(node) {
    const math = node.querySelector('math');
    return math ? serializeMathMLNode(math) : null;
  }

  function collectInlineDocxRuns(root, inheritedStyleFlags = {}, skipNestedLists = false) {
    const runs = [];
    const appendInlineRunsFromNode = (node, style) => {
      if (node.nodeType === Node.TEXT_NODE) {
        const text = style.code ? node.nodeValue : node.nodeValue.replace(/\s+/g, ' ');
        if (text) runs.push({ text, ...style });
        return;
      }
      if (node.nodeType !== Node.ELEMENT_NODE) return;
      const tag = node.localName?.toLowerCase();
      if (skipNestedLists && (tag === 'ul' || tag === 'ol')) return;
      if (node.classList?.contains('mdanywhere-mermaid')) {
        runs.push({ text: `\n${node.getAttribute('data-mermaid-source') || node.textContent || ''}\n`, code: true });
        return;
      }
      if (node.classList?.contains('katex')) {
        const math = mathMLFromElement(node);
        if (math) runs.push({ kind: 'math', math });
        else runs.push({ text: node.textContent || '' });
        return;
      }
      if (tag === 'img') {
        runs.push({ kind: 'image', source: node.getAttribute('src') || '', alt: node.getAttribute('alt') || '' });
        return;
      }
      if (tag === 'input' && node.type === 'checkbox') {
        runs.push({ text: node.checked ? '☑ ' : '☐ ' });
        return;
      }
      if (tag === 'br') { runs.push({ text: '\n' }); return; }
      if (tag === 'script' || tag === 'style') return;
      const next = { ...style };
      if (tag === 'strong' || tag === 'b') next.bold = true;
      if (tag === 'em' || tag === 'i') next.italic = true;
      if (tag === 'code') next.code = true;
      if (tag === 'a') next.underline = true;
      if (tag === 'sup') next.superscript = true;
      if (tag === 's' || tag === 'del') next.strike = true;
      for (const child of node.childNodes) appendInlineRunsFromNode(child, next);
      if (tag === 'p' && node !== root) runs.push({ text: '\n' });
    };
    for (const child of root.childNodes) appendInlineRunsFromNode(child, inheritedStyleFlags);
    while (runs.length && !runs[0].kind && !runs[0].text?.trim()) runs.shift();
    while (runs.length && !runs.at(-1).kind && !runs.at(-1).text?.trim()) runs.pop();
    return runs;
  }

  function collectDocxBlocks(article) {
    generatedListCount = 0;
    const blocks = [];
    const appendElementAsDocxBlocks = (node, insideQuote = false, listDepth = 0) => {
      if (node.nodeType !== Node.ELEMENT_NODE) return;
      const tag = node.localName?.toLowerCase();
      if (node.classList?.contains('mdanywhere-mermaid')) {
        // Synchronous callers and failed rasterizations retain editable source.
        blocks.push({ type: 'code', text: node.getAttribute('data-mermaid-source') || node.textContent || '' });
        return;
      }
      if (node.classList?.contains('katex-display')) {
        const math = mathMLFromElement(node);
        if (math) blocks.push({ type: 'math', math });
        return;
      }
      if (/^h[1-6]$/.test(tag)) {
        blocks.push({ type: 'heading', level: Number(tag[1]), runs: collectInlineDocxRuns(node) });
      } else if (tag === 'p') {
        const display = node.querySelector('.katex-display');
        if (display && node.children.length === 1) {
          const math = mathMLFromElement(display);
          if (math) { blocks.push({ type: 'math', math }); return; }
        }
        blocks.push({ type: insideQuote ? 'quote' : 'paragraph', runs: collectInlineDocxRuns(node) });
      } else if (tag === 'pre') {
        blocks.push({ type: 'code', text: node.textContent || '' });
      } else if (tag === 'hr') {
        blocks.push({ type: 'rule' });
      } else if (tag === 'table') {
        const rows = [...node.querySelectorAll('tr')].map(row =>
          [...row.children].filter(cell => ['th', 'td'].includes(cell.localName)).map(cell =>
            ({ runs: collectInlineDocxRuns(cell), header: cell.localName === 'th' })));
        blocks.push({ type: 'table', rows });
      } else if (tag === 'blockquote') {
        for (const child of node.children) appendElementAsDocxBlocks(child, true, listDepth);
      } else if (tag === 'ul' || tag === 'ol') {
        const currentID = `list-${++generatedListCount}`;
        for (const child of node.children) {
          if (child.localName !== 'li') continue;
          blocks.push({
            type: child.classList.contains('task-list-item') ? 'task' : 'list',
            ordered: tag === 'ol', level: Math.min(listDepth, 5),
            listID: currentID, runs: collectInlineDocxRuns(child, {}, true)
          });
          for (const nested of child.children) {
            if (nested.localName === 'ul' || nested.localName === 'ol') {
              appendElementAsDocxBlocks(nested, false, listDepth + 1);
            }
          }
        }
      } else if (tag === 'img') {
        blocks.push({ type: 'paragraph', runs: [{ kind: 'image', source: node.getAttribute('src') || '', alt: node.getAttribute('alt') || '' }] });
      } else {
        for (const child of node.children) appendElementAsDocxBlocks(child, insideQuote, listDepth);
      }
    };
    for (const child of article.children) appendElementAsDocxBlocks(child);
    return blocks;
  }

  async function rasterizeFlowchart(source) {
    // Regenerate only our offline flowchart syntax, never arbitrary embedded SVG.
    const host = document.createElement('div');
    host.innerHTML = window.mdAnyWhereMermaid.renderSVG(source);
    const svg = host.querySelector('svg');
    const [, , width, height] = svg.getAttribute('viewBox').split(/\s+/).map(Number);
    if (![width, height].every(value => Number.isFinite(value) && value > 0)) throw new Error(t("web.bc1eb82882"));
    svg.removeAttribute('style');
    svg.setAttribute('width', width);
    svg.setAttribute('height', height);
    // Export on white paper, independent of the app's current light/dark theme.
    const style = document.createElementNS('http://www.w3.org/2000/svg', 'style');
    style.textContent = `
      .mdanywhere-flow-node rect,.mdanywhere-flow-node ellipse,.mdanywhere-flow-node polygon { fill:#f5f3ff;stroke:#a999ec;stroke-width:1.55 }
      .mdanywhere-flow-node text,.mdanywhere-flow-edge-label { fill:#24212c;font:500 14px -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif }
      .mdanywhere-flow-edge { fill:none;stroke:#45414d }
      .mdanywhere-flow-edge:not([stroke-width]) { stroke-width:1.55 }
      .mdanywhere-flow-arrow { fill:#24212c }
      .mdanywhere-flow-edge-label { paint-order:stroke;stroke:#fff;stroke-width:6px;stroke-linejoin:round;font-size:12px }
    `;
    svg.prepend(style);
    const imageURL = URL.createObjectURL(new Blob([new XMLSerializer().serializeToString(svg)], { type: 'image/svg+xml' }));
    try {
      const image = await new Promise((resolve, reject) => {
        const image = new Image();
        const timer = setTimeout(() => { image.src = ''; reject(new Error(t("web.69d0b81f9e"))); }, 5000);
        image.onload = () => { clearTimeout(timer); resolve(image); };
        image.onerror = () => { clearTimeout(timer); reject(new Error(t("web.83b187b231"))); };
        image.src = imageURL;
      });
      // Bound canvas memory even for long graphs; native export fits the page.
      const scale = Math.min(2, 3000 / Math.max(width, height));
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.round(width * scale));
      canvas.height = Math.max(1, Math.round(height * scale));
      const context = canvas.getContext('2d');
      if (!context) throw new Error(t("web.b48af5c687"));
      context.fillStyle = '#fff';
      context.fillRect(0, 0, canvas.width, canvas.height);
      context.drawImage(image, 0, 0, canvas.width, canvas.height);
      const result = canvas.toDataURL('image/png');
      if (!result.startsWith('data:image/png;base64,')) throw new Error(t("web.f0e298df73"));
      return result;
    } finally {
      URL.revokeObjectURL(imageURL);
    }
  }

  async function prepareDocxBlocks(article) {
    // Freeze the preview before awaiting images; never mutate the live editor.
    const snapshot = article.cloneNode(true);
    let fallbackCount = 0;
    for (const diagram of snapshot.querySelectorAll('.mdanywhere-mermaid[data-mermaid-source]')) {
      try {
        const image = document.createElement('img');
        image.src = await rasterizeFlowchart(diagram.getAttribute('data-mermaid-source'));
        image.alt = t("web.716c18b72b");
        diagram.replaceWith(image);
      } catch (_) {
        fallbackCount += 1;
      }
    }
    return { blocks: collectDocxBlocks(snapshot), fallbackCount };
  }

  function showLayoutProposal(raw, label) {
    const host = elementByID('docx-agent-proposal');
    host.replaceChildren();
    try {
      const start = raw.indexOf('{'), end = raw.lastIndexOf('}');
      if (start < 0 || end <= start) throw new Error(t("web.669676e349"));
      const parsed = JSON.parse(raw.slice(start, end + 1));
      const suggestion = parsed.settings || parsed.layout || parsed;
      const currentSettings = readLayoutControls();
      pendingLayoutSuggestion = normalizeLayoutSettings({ ...currentSettings, ...suggestion });
      const changed = Object.keys(layoutControlIDs).filter(key => pendingLayoutSuggestion[key] !== currentSettings[key]);
      if (!changed.length) throw new Error(t("web.20db4dc81e"));
      const reason = typeof parsed.reason === 'string' ? parsed.reason.slice(0, 400) : '';
      const paragraph = document.createElement('div');
      bindText(paragraph, () => t("web.39dd1ab316", { p0: label, p1: changed.length, p2: changed.map(key => `${key} → ${pendingLayoutSuggestion[key]}`).join('，'), p3: reason ? t("web.b7a39573eb", { p0: reason }) : '' }));
      const apply = document.createElement('button');
      apply.type = 'button'; bindText(apply, () => t("web.8aeb60b405"));
      apply.onclick = () => {
        applyLayoutToControls(pendingLayoutSuggestion);
        pendingLayoutSuggestion = null;
        bindText(host, () => t("web.1477fb5d00"));
      };
      host.append(paragraph, apply);
    } catch (error) {
      pendingLayoutSuggestion = null;
      bindText(host, () => t("web.1cc521f3d8", { p0: label, p1: error.message }));
    }
  }

  function parseLocalLayoutInstruction(prompt, currentSettings = readLayoutControls()) {
    const value = { ...currentSettings };
    if (/\bA4\b/i.test(prompt)) value.pageSize = 'a4';
    if (/\bLetter\b/i.test(prompt)) value.pageSize = 'letter';
    const knownFonts = ['Times New Roman', 'Cambria Math', 'STIX Two Math', 'PingFang SC',
      'Calibri', 'Cambria', 'Arial', '宋体', '仿宋', '楷体', '黑体'];
    for (const font of knownFonts) {
      const matches = prompt.matchAll(new RegExp(font.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'gi'));
      for (const match of matches) {
        const context = prompt.slice(0, match.index).split(/[，,；;。\n]/).at(-1) || '';
        const isMath = /公式|数学|方程/.test(context);
        const isHeading = !isMath && /标题/.test(context);
        const scriptHint = (context.match(/英文|英语|西文|拉丁|中文|汉字/g) || []).at(-1);
        const isLatin = scriptHint ? /英文|英语|西文|拉丁/.test(scriptHint)
          : !/[\u3400-\u9fff]/u.test(font) && !/PingFang/i.test(font);
        const key = `${isMath ? 'math' : isHeading ? 'heading' : 'body'}${isLatin ? 'Latin' : 'Cjk'}Font`;
        value[key] = font;
      }
    }
    if (/小四/.test(prompt)) value.bodySize = 12;
    if (/五号/.test(prompt)) value.bodySize = 10.5;
    if (/四号/.test(prompt) && !/小四/.test(prompt)) value.bodySize = 14;
    if (/双倍|2\s*倍/.test(prompt)) value.lineSpacing = 2;
    else if (/1[.,，．]5\s*倍|一\.五倍/.test(prompt)) value.lineSpacing = 1.5;
    else if (/单倍/.test(prompt)) value.lineSpacing = 1;
    if (/首行缩进.{0,5}(两|二|2)\s*字/.test(prompt)) value.firstLineIndent = 8;
    if (/标题.{0,10}居中/.test(prompt)) value.headingAlign = 'center';
    if (/正文.{0,10}左对齐/.test(prompt)) value.bodyAlign = 'left';
    if (/两端对齐/.test(prompt)) value.bodyAlign = 'justify';
    if (/页码|页脚页数/.test(prompt)) value.pageNumbers = true;
    if (/不要页码|无页码/.test(prompt)) value.pageNumbers = false;
    const margin = prompt.match(/(?:页边距|四边边距).{0,5}(\d+(?:\.\d+)?)\s*(毫米|mm|厘米|cm)/i);
    if (margin) {
      const mm = Number(margin[1]) * (/厘米|cm/i.test(margin[2]) ? 10 : 1);
      value.marginTop = value.marginBottom = value.marginLeft = value.marginRight = mm;
    }
    return value;
  }

  function refreshAvailableAgents() {
    const select = elementByID('docx-agent-select');
    const selected = select.value;
    select.replaceChildren();
    const agents = editorBridge?.getAgents()?.filter(profile => profile.enabled) || [];
    if (!agents.length) {
      const option = new Option(t("web.c9aee5190c"), '');
      select.add(option);
      elementByID('docx-agent-run').disabled = true;
    } else {
      agents.forEach(profile => select.add(new Option(profile.name, profile.id)));
      if (agents.some(profile => profile.id === selected)) select.value = selected;
      elementByID('docx-agent-run').disabled = false;
    }
  }

  function bindEditorBridge(options) {
    editorBridge = options;
    const saved = (() => { try { return JSON.parse(localStorage.docxLayout || '{}'); } catch (_) { return {}; } })();
    applyLayoutToControls(saved);
    for (const id of Object.values(layoutControlIDs)) {
      elementByID(id).addEventListener('input', () => { elementByID('docx-preset').value = 'custom'; updateLayoutPreview(); });
    }
    elementByID('docx-preset').onchange = event => {
      const preset = getLayoutPreset(event.target.value);
      if (preset) applyLayoutToControls(preset, event.target.value);
    };
    elementByID('docx-local-parse').onclick = () => {
      const prompt = elementByID('docx-request').value.trim();
      if (!prompt) { bindText(elementByID('docx-agent-proposal'), () => t("web.455f888087")); return; }
      showLayoutProposal(JSON.stringify({ settings: parseLocalLayoutInstruction(prompt) }), t("web.838b672342"));
    };
    elementByID('docx-agent-run').onclick = () => {
      const prompt = elementByID('docx-request').value.trim();
      const profileID = elementByID('docx-agent-select').value;
      if (!prompt || !profileID) { bindText(elementByID('docx-agent-proposal'), () => t("web.c4fd06e454")); return; }
      bindText(elementByID('docx-agent-proposal'), () => t("web.65a4a0e0c0"));
      setAgentLayoutBusy(true);
      editorBridge.post('agentFormat', { profileID, prompt, settings: readLayoutControls() });
    };
    elementByID('docx-export').onclick = async () => {
      const button = elementByID('docx-export');
      if (button.disabled) return;
      button.disabled = true;
      const request = { id: editorBridge.getID(), title: editorBridge.getTitle(), settings: readLayoutControls() };
      try {
        const { blocks, fallbackCount } = await prepareDocxBlocks(editorBridge.getArticle());
        if (request.id !== editorBridge.getID()) { editorBridge.showToast(t("web.b91d132a70")); return; }
        if (!blocks.length) { editorBridge.showToast(t("web.9bd47f977d")); return; }
        if (fallbackCount) editorBridge.showToast(t("web.70f03f9389", { p0: fallbackCount }));
        editorBridge.post('exportDOCX', { ...request, blocks });
      } catch (_) {
        editorBridge.showToast(t("web.32b6ec9601"));
      } finally {
        button.disabled = false;
      }
    };
  }

  window.addEventListener?.('mdanywherelanguagechange', () => {
    if (editorBridge && exportDialog().open) updateLayoutPreview();
  });

  function openExportDialog() {
    if (!editorBridge) return;
    refreshAvailableAgents();
    updateLayoutPreview();
    exportDialog().showModal();
  }

  function setAgentLayoutBusy(value) {
    elementByID('docx-agent-run').disabled = value || !elementByID('docx-agent-select').value;
    bindText(elementByID('docx-agent-run'), () => value ? t("web.8a40bed311") : t("web.e3adab4931"));
  }

  function receiveAgentLayoutSuggestion(text, error) {
    setAgentLayoutBusy(false);
    if (error) { bindText(elementByID('docx-agent-proposal'), () => t("web.4747d9186f", { p0: error })); return; }
    showLayoutProposal(text, 'Agent');
  }

  function notifyDocumentExported() {
    exportDialog().close();
    editorBridge?.showToast(t("web.23a317d838"));
  }

  // These keys are the stable JavaScript bridge consumed by app.js/AppDelegate.
  window.mdAnyWhereDocx = {
    bind: bindEditorBridge,
    open: openExportDialog,
    updateAgents: refreshAvailableAgents,
    setBusy: setAgentLayoutBusy,
    receiveAgent: receiveAgentLayoutSuggestion,
    exported: notifyDocumentExported,
    collectBlocks: collectDocxBlocks,
    prepareBlocks: prepareDocxBlocks,
    cleanSettings: normalizeLayoutSettings,
    preset: getLayoutPreset,
    parseInstruction: parseLocalLayoutInstruction
  };
})();
