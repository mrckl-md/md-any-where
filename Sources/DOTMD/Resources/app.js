(() => {
  const initial = `# 欢迎使用 DOT MD

现在可以直接编辑 Markdown，右侧会即时呈现排版结果。

## 快速写作

- 使用顶部工具栏或快捷键插入格式
- 输入列表后按回车会自动延续
- 按 **⌘S** 保存，支持自动保存已打开的文稿
- 按 **⌘C / ⌘X / ⌘V / ⌘A / ⌘D** 复制、剪切、粘贴、全选或取消选择
- 按 **⌘Z / ⌘⇧Z** 回退或前进，**⌘⌥Z** 打开操作记录
- 按 **⌘T** 新建标签页，**⌃Tab** 循环切换，**⌘1…⌘9** 直接跳转
- 按 **⌘⇧1 / ⌘⇧2 / ⌘⇧3** 切换编辑、分栏与预览
- 按 **⌘⇧G** 插入 Mermaid 流程图，也可由 Agent 通过 MCP 生成

## Agent 与公式工具

- 选中文字后按 **⌘⇧A**，可调用一个或多个 Agent 润色、校对或生成公式
- 选中公式后按 **⌘⌥M**，可转换并复制到 Word、WPS、LibreOffice、MathType 或 Overleaf
- API Key 只保存在 macOS 钥匙串；只有点击运行时才会发送选中内容

## LaTeX

行内公式：$e^{i\\pi}+1=0$。

$$
\\int_{-\\infty}^{\\infty} e^{-x^2}\\,dx = \\sqrt{\\pi}
$$

也支持矩阵、对齐、分式、根式和常用宏：

$$\\mathbf{A}=\\begin{bmatrix}a&b\\\\c&d\\end{bmatrix}$$

> 这是一个源码完整、可继续迭代的升级工程。
`;

  const source = document.getElementById('source');
  const preview = document.getElementById('preview');
  const previewPane = document.getElementById('preview-pane');
  const workspace = document.getElementById('workspace');
  const outlineList = document.getElementById('outline-list');
  let renderTimer = null;
  let lastRenderedText = null;
  let syncingScroll = false;
  let suppressChanges = true;
  const tabs = new Map();
  const documentTabElements = new Map();
  const documentTabOrder = [];
  let activeDocumentID = null;
  let agentProfiles = [];
  let lastSelection = null;
  let currentFormula = '';
  let searchMatches = [];
  let searchMarks = [];
  let activeSearchMark = null;
  let activeSearchIndex = -1;
  let searchIndex = -1;
  let searchTimer = null;
  let searchLimited = false;
  let historyLimit = Number(localStorage.historyDepth) || 10;
  let historyTimer = null;
  let pendingHistoryLabel = '';
  let dragRegionFrame = null;
  let sourceMappedPreviewBlocks = [];
  let highlightedPreviewBlocks = [];
  let agentConsoleHelperPath = '';

  const md = window.markdownit({
    html: false,
    linkify: false,
    typographer: true,
    breaks: false,
    highlight(str, lang) {
      if (lang && window.hljs.getLanguage(lang)) {
        try { return window.hljs.highlight(str, { language: lang, ignoreIllegals: true }).value; } catch (_) {}
      }
      return md.utils.escapeHtml(str);
    }
  });
  md.validateLink = value => !/^(?:https?|ftp|wss?):/i.test(value.trim());
  if (window.markdownitFootnote) md.use(window.markdownitFootnote);
  if (window.markdownitTaskLists) md.use(window.markdownitTaskLists, { enabled: true, label: true });
  if (window.texmath && window.katex) {
    md.use(window.texmath, {
      engine: window.katex,
      delimiters: ['dollars', 'brackets'],
      katexOptions: { throwOnError: false, strict: false, trust: false, macros: { '\\RR': '\\mathbb{R}', '\\NN': '\\mathbb{N}' } }
    });
  }
  if (window.dotmdMermaid) window.dotmdMermaid.installMarkdownIt(md);
  else {
    const originalFence = md.renderer.rules.fence;
    md.renderer.rules.fence = (tokens, index, options, env, self) =>
      (tokens[index].info || '').trim().split(/\s+/)[0].toLowerCase() === 'mermaid'
        ? '<div class="render-error">流程图模块未加载，请重新打开 DOT MD。</div>'
        : originalFence(tokens, index, options, env, self);
  }
  md.core.ruler.push('dotmd_source_map', state => {
    state.tokens.forEach(token => {
      if (token.map && token.nesting === 1) {
        token.attrSet('data-source-start', String(token.map[0]));
        token.attrSet('data-source-end', String(token.map[1]));
      }
    });
  });
  ['fence', 'code_block', 'math_block', 'math_block_eqno'].forEach(type => {
    const baseRenderer = md.renderer.rules[type];
    if (!baseRenderer) return;
    md.renderer.rules[type] = (tokens, index, options, env, self) => {
      const token = tokens[index];
      const rendered = baseRenderer(tokens, index, options, env, self);
      if (!token.map) return rendered;
      return `<div class="source-mapped-block" data-source-start="${token.map[0]}" data-source-end="${token.map[1]}">${rendered}</div>`;
    };
  });

  const editor = CodeMirror.fromTextArea(source, {
    mode: { name: 'markdown', highlightFormatting: true },
    lineNumbers: true,
    lineWrapping: true,
    autofocus: true,
    autoCloseBrackets: true,
    extraKeys: {
      Enter: 'newlineAndIndentContinueMarkdownList',
      'Cmd-B': () => applyMarkdownFormatting('bold'),
      'Cmd-I': () => applyMarkdownFormatting('italic'),
      'Cmd-K': () => applyMarkdownFormatting('link'),
      'Cmd-Shift-M': () => applyMarkdownFormatting('math'),
      'Cmd-Shift-G': () => applyMarkdownFormatting('diagram'),
      'Cmd-Alt-M': () => openFormulaTools(),
      'Cmd-Shift-A': () => openAgentTools(),
      'Cmd-Alt-1': () => applyMarkdownFormatting('heading'),
      'Cmd-C': () => copySelection(false),
      'Cmd-X': () => copySelection(true),
      'Cmd-V': () => sendNativeMessage('pasteRequest'),
      'Cmd-S': () => sendNativeMessage('save'),
      'Cmd-A': 'selectAll',
      'Cmd-D': () => clearSelection(),
      'Cmd-Z': () => stepHistory(-1),
      'Shift-Cmd-Z': () => stepHistory(1),
      'Cmd-Alt-Z': () => openHistoryTools(),
      'Cmd-F': () => openSearchTools(),
      'Cmd-Alt-F': () => openSearchTools(true),
      'Esc': cm => cm.execCommand('clearSearch')
    }
  });

  function titleForUntitledDocument(text, fallback) {
    if (!/^未命名|^欢迎/.test(fallback)) return fallback;
    const heading = text.match(/^#\s+(.+)$/m);
    return heading ? `${heading[1].trim().slice(0, 36)}.md` : fallback;
  }

  function renderTabs() {
    const list = document.getElementById('tabs-list');
    list.replaceChildren();
    documentTabElements.clear();
    documentTabOrder.forEach((id, index) => {
      const tab = tabs.get(id); if (!tab) return;
      const item = document.createElement('div');
      item.className = `document-tab${id === activeDocumentID ? ' active' : ''}${tab.dirty ? ' dirty' : ''}`;
      item.draggable = true; item.dataset.id = id; item.title = `${tab.title}\n⌘${index + 1} 切换`;
      const dot = document.createElement('span'); dot.className = 'tab-dirty';
      const title = document.createElement('span'); title.className = 'tab-title'; title.textContent = tab.title;
      const close = document.createElement('button'); close.className = 'tab-close'; close.textContent = '×'; close.title = '关闭标签页（⌘W）';
      close.onclick = event => { event.stopPropagation(); sendNativeMessage('close', { id }); };
      item.onclick = () => switchTab(id);
      item.ondragstart = event => { event.dataTransfer.setData('text/tab-id', id); event.dataTransfer.effectAllowed = 'move'; };
      item.ondragover = event => { event.preventDefault(); event.dataTransfer.dropEffect = 'move'; };
      item.ondrop = event => {
        event.preventDefault(); const sourceID = event.dataTransfer.getData('text/tab-id');
        const from = documentTabOrder.indexOf(sourceID), to = documentTabOrder.indexOf(id);
        if (from >= 0 && to >= 0 && from !== to) { documentTabOrder.splice(from, 1); documentTabOrder.splice(to, 0, sourceID); renderTabs(); }
      };
      item.append(dot, title, close); list.append(item);
      documentTabElements.set(id, item);
    });
    list.querySelector('.document-tab.active')?.scrollIntoView({ inline: 'nearest', block: 'nearest' });
    updateHistoryControls();
    scheduleDragRegionUpdate();
  }

  function updateTabPresentation(tab) {
    const item = documentTabElements.get(tab.id);
    if (!item) return;
    item.classList.toggle('dirty', tab.dirty);
    const title = item.querySelector('.tab-title');
    if (title.textContent !== tab.title) {
      title.textContent = tab.title;
      item.title = `${tab.title}\n⌘${documentTabOrder.indexOf(tab.id) + 1} 切换`;
    }
  }

  function switchTab(id, notify = true) {
    if (!tabs.has(id) || id === activeDocumentID) return;
    commitHistorySnapshot();
    const current = tabs.get(activeDocumentID);
    if (current) { current.editorScroll = editor.getScrollInfo().top; current.previewScroll = previewPane.scrollTop; }
    activeDocumentID = id;
    const next = tabs.get(id);
    ensureHistory(next);
    suppressChanges = true;
    editor.swapDoc(next.doc);
    suppressChanges = false;
    updateCursorStatus();
    renderTabs(); renderMarkdownPreview();
    requestAnimationFrame(() => { editor.scrollTo(null, next.editorScroll || 0); previewPane.scrollTop = next.previewScroll || 0; editor.focus(); });
    if (notify) sendNativeMessage('activate', { id });
  }

  function addDocument(id, title, content, dirty = false) {
    if (tabs.has(id)) { switchTab(id); return; }
    createDocument(id, title, content, dirty);
    switchTab(id);
  }

  function createDocument(id, title, content, dirty = false) {
    const doc = new CodeMirror.Doc(content, { name: 'markdown', highlightFormatting: true });
    tabs.set(id, { id, title, doc, dirty, editorScroll: 0, previewScroll: 0,
      timeline: [createHistoryEntry('初始状态', content, { line: 0, ch: 0 })], timelineIndex: 0 });
    documentTabOrder.push(id);
  }

  function addDocuments(entries, selectedID) {
    entries.forEach(([id, title, content, dirty]) => {
      if (!tabs.has(id)) createDocument(id, title, content, dirty);
    });
    const nextID = tabs.has(selectedID) ? selectedID : entries.at(-1)?.[0];
    if (nextID && nextID !== activeDocumentID) switchTab(nextID, false);
    else renderTabs();
  }

  function removeTab(id) {
    const index = documentTabOrder.indexOf(id);
    if (index < 0) return;
    tabs.delete(id); documentTabOrder.splice(index, 1);
    if (id === activeDocumentID) {
      activeDocumentID = null;
      const replacement = documentTabOrder[Math.min(index, documentTabOrder.length - 1)];
      if (replacement) switchTab(replacement);
    }
    renderTabs();
  }

  function cycleTab(direction) {
    if (documentTabOrder.length < 2) return;
    const index = documentTabOrder.indexOf(activeDocumentID);
    switchTab(documentTabOrder[(index + direction + documentTabOrder.length) % documentTabOrder.length]);
  }

  function sendNativeMessage(type, extra = {}) {
    try { window.webkit.messageHandlers.editor.postMessage({ type, ...extra }); } catch (_) {}
  }

  function scheduleDragRegionUpdate() {
    if (dragRegionFrame !== null) return;
    dragRegionFrame = requestAnimationFrame(() => {
      dragRegionFrame = null;
      const regions = [...document.querySelectorAll('.topbar button,.topbar input,.topbar select,.topbar textarea,.topbar a,.topbar .document-tab')]
        .map(element => {
          const rect = element.getBoundingClientRect();
          return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
        });
      sendNativeMessage('dragRegions', { regions, enabled: !document.querySelector('dialog[open]') });
    });
  }

  function renderMarkdownPreview() {
    const text = editor.getValue();
    if (text === lastRenderedText) { updatePreviewSelection(false); return; }
    highlightedPreviewBlocks = [];
    try {
      preview.innerHTML = md.render(text);
      if (window.dotmdMermaid) window.dotmdMermaid.renderInto(preview);
      document.getElementById('latex-status').textContent = 'LaTeX 就绪';
    } catch (error) {
      preview.innerHTML = `<div class="render-error">预览失败：${md.utils.escapeHtml(error.message)}</div>`;
      document.getElementById('latex-status').textContent = '预览有错误';
    }
    sourceMappedPreviewBlocks = [...preview.querySelectorAll('[data-source-start][data-source-end]')];
    lastRenderedText = text;
    rebuildDocumentOutline();
    updateWordCount(text);
    updatePreviewSelection(false);
  }

  function updatePreviewSelection(reveal = true) {
    highlightedPreviewBlocks.forEach(element => element.classList.remove('preview-selection'));
    highlightedPreviewBlocks = [];
    if (!editor.somethingSelected()) return;
    const from = editor.getCursor('from');
    const to = editor.getCursor('to');
    const endLine = to.ch === 0 && to.line > from.line ? to.line - 1 : to.line;
    const matches = sourceMappedPreviewBlocks.filter(element => {
      const start = Number(element.dataset.sourceStart);
      const end = Number(element.dataset.sourceEnd) - 1;
      return start <= endLine && end >= from.line;
    });
    const matchSet = new Set(matches);
    const nonLeaves = new Set();
    matches.forEach(element => {
      for (let parent = element.parentElement; parent && parent !== preview; parent = parent.parentElement) {
        if (matchSet.has(parent)) nonLeaves.add(parent);
      }
    });
    const leaves = matches.filter(element => !nonLeaves.has(element));
    leaves.forEach(element => element.classList.add('preview-selection'));
    highlightedPreviewBlocks = leaves;
    const first = leaves[0];
    if (reveal && first) {
      const pane = previewPane.getBoundingClientRect();
      const item = first.getBoundingClientRect();
      if (item.top < pane.top + 24 || item.bottom > pane.bottom - 24) {
        first.scrollIntoView({ behavior: 'smooth', block: 'center' });
      }
    }
  }

  function schedulePreviewRender(changed = true) {
    clearTimeout(renderTimer);
    const text = editor.getValue();
    updateWordCount(text);
    // The hidden preview need not parse and rebuild the complete DOM on each keypress.
    if (!workspace.classList.contains('mode-editor')) {
      renderTimer = setTimeout(renderMarkdownPreview, text.length > 200_000 ? 450 : 160);
    }
    if (changed && activeDocumentID) {
      const tab = tabs.get(activeDocumentID);
      tab.dirty = true;
      tab.title = titleForUntitledDocument(text, tab.title);
      updateTabPresentation(tab);
      sendNativeMessage('change', { id: activeDocumentID, content: text, title: tab.title });
    }
  }

  function rebuildDocumentOutline() {
    const headings = preview.querySelectorAll('h1,h2,h3,h4,h5,h6');
    outlineList.replaceChildren();
    if (!headings.length) {
      const empty = document.createElement('div'); empty.className = 'outline-empty'; empty.textContent = '添加标题后会在这里显示'; outlineList.append(empty); return;
    }
    const visibleCount = Math.min(headings.length, 500);
    for (let index = 0; index < visibleCount; index++) {
      const heading = headings[index];
      heading.id = `heading-${index}`;
      const button = document.createElement('button');
      button.className = 'outline-item'; button.style.paddingLeft = `${7 + (Number(heading.tagName[1]) - 1) * 11}px`; button.textContent = heading.textContent;
      button.onclick = () => heading.scrollIntoView({ behavior: 'smooth', block: 'start' });
      outlineList.append(button);
    }
    if (headings.length > visibleCount) {
      const note = document.createElement('div');
      note.className = 'outline-empty';
      note.textContent = `大纲只展示前 ${visibleCount} 个标题，以保持编辑流畅。`;
      outlineList.append(note);
    }
  }

  function updateWordCount(text) {
    const cjk = (text.match(/[\u3400-\u9fff\uf900-\ufaff]/g) || []).length;
    const latin = (text.replace(/[\u3400-\u9fff\uf900-\ufaff]/g, ' ').match(/[\p{L}\p{N}]+/gu) || []).length;
    document.getElementById('word-count').textContent = `${cjk + latin} 字 · ${text.length} 字符`;
  }

  function wrapSelectedText(before, after = before, placeholder = '文本') {
    const from = editor.getCursor('from'), to = editor.getCursor('to');
    const selected = editor.getSelection() || placeholder;
    editor.replaceSelection(before + selected + after, 'around');
    if (!editor.getSelection()) editor.setSelection({line:from.line,ch:from.ch+before.length},{line:from.line,ch:from.ch+before.length+selected.length});
    editor.focus();
  }

  function toggleLinePrefix(prefix) {
    const from = editor.getCursor('from'), to = editor.getCursor('to');
    editor.operation(() => {
      for (let line = from.line; line <= to.line; line++) {
        const value = editor.getLine(line);
        editor.replaceRange(value.startsWith(prefix) ? '' : prefix, { line, ch: 0 }, { line, ch: value.startsWith(prefix) ? prefix.length : 0 });
      }
    });
    editor.focus();
  }

  function applyMarkdownFormatting(command) {
    switch(command) {
      case 'bold': wrapSelectedText('**','**','粗体'); break;
      case 'italic': wrapSelectedText('*','*','斜体'); break;
      case 'link': wrapSelectedText('[','](https://)','链接文字'); break;
      case 'heading': toggleLinePrefix('# '); break;
      case 'bullet': toggleLinePrefix('- '); break;
      case 'task': toggleLinePrefix('- [ ] '); break;
      case 'quote': toggleLinePrefix('> '); break;
      case 'code': wrapSelectedText('```\n','\n```','代码'); break;
      case 'math': wrapSelectedText('$$\n','\n$$','\\frac{a}{b}'); break;
      case 'diagram': wrapSelectedText('```mermaid\nflowchart TD\n  A[输入内容] --> B{是否保留？}\n  B -->|否| C[丢弃]\n  B -->|是| D[整理为 Markdown]\n  D --> E[完成]\n','\n```',''); break;
    }
  }

  function setMode(mode) {
    workspace.classList.remove('mode-editor','mode-split','mode-preview'); workspace.classList.add(`mode-${mode}`);
    document.querySelectorAll('[data-mode]').forEach(button => {
      const isSelected = button.dataset.mode === mode;
      button.classList.toggle('active', isSelected);
      button.setAttribute('aria-pressed', String(isSelected));
    });
    editor.refresh();
    if (mode !== 'editor') renderMarkdownPreview();
  }

  function clearSelection() {
    const cursor = editor.getCursor('head');
    editor.setCursor(cursor);
    updatePreviewSelection(false);
    editor.focus();
  }

  function copySelection(cut = false) {
    const text = editor.getSelection();
    if (!text) return;
    sendNativeMessage('copySelection', { text });
    if (cut) editor.replaceSelection('', 'start', 'cut');
  }

  function insertClipboardText(text) {
    if (typeof text !== 'string' || !text.length) return;
    editor.replaceSelection(text, 'end', 'paste');
    editor.focus();
  }

  function createHistoryEntry(label, content = editor.getValue(), cursor = editor.getCursor()) {
    return { label, content, cursor, timestamp: Date.now() };
  }

  function ensureHistory(tab = tabs.get(activeDocumentID)) {
    if (!tab) return;
    if (!Array.isArray(tab.timeline) || !tab.timeline.length) {
      tab.timeline = [createHistoryEntry('初始状态', tab.doc.getValue(), { line: 0, ch: 0 })];
      tab.timelineIndex = 0;
    }
  }

  function labelForEditorChange(change) {
    const origin = change?.origin || '';
    if (origin === 'paste') return '粘贴内容';
    if (origin === 'cut') return '剪切内容';
    if (origin === '+delete') return '删除内容';
    if (origin === 'around') return '应用格式';
    if (origin === 'setValue') return '替换文稿';
    return '输入内容';
  }

  function trimUndoHistory(tab) {
    const maximum = historyLimit + 1;
    if (tab.timeline.length <= maximum) return;
    const removeCount = tab.timeline.length - maximum;
    tab.timeline.splice(0, removeCount);
    tab.timelineIndex = Math.max(0, tab.timelineIndex - removeCount);
  }

  function commitHistorySnapshot(label = pendingHistoryLabel || '编辑内容') {
    clearTimeout(historyTimer); historyTimer = null;
    const tab = tabs.get(activeDocumentID);
    if (!tab) { pendingHistoryLabel = ''; return; }
    ensureHistory(tab);
    const content = editor.getValue();
    if (tab.timeline[tab.timelineIndex]?.content === content) {
      pendingHistoryLabel = ''; updateHistoryControls(); return;
    }
    if (tab.timelineIndex < tab.timeline.length - 1) tab.timeline.splice(tab.timelineIndex + 1);
    tab.timeline.push(createHistoryEntry(label, content, editor.getCursor('head')));
    tab.timelineIndex = tab.timeline.length - 1;
    trimUndoHistory(tab);
    pendingHistoryLabel = '';
    updateHistoryControls();
  }

  function scheduleHistorySnapshot(label) {
    if (historyTimer && pendingHistoryLabel && pendingHistoryLabel !== label) commitHistorySnapshot();
    pendingHistoryLabel = label;
    clearTimeout(historyTimer);
    historyTimer = setTimeout(() => commitHistorySnapshot(), 650);
  }

  function applyHistoryIndex(index) {
    const tab = tabs.get(activeDocumentID);
    if (!tab || index < 0 || index >= tab.timeline.length || index === tab.timelineIndex) return;
    const entry = tab.timeline[index];
    tab.timelineIndex = index;
    suppressChanges = true;
    editor.setValue(entry.content);
    editor.clearHistory();
    const lastLine = Math.max(0, editor.lineCount() - 1);
    const line = Math.min(entry.cursor?.line ?? lastLine, lastLine);
    const ch = Math.min(entry.cursor?.ch ?? editor.getLine(line).length, editor.getLine(line).length);
    editor.setCursor({ line, ch });
    suppressChanges = false;
    schedulePreviewRender(true);
    updateHistoryControls();
    renderHistoryList();
    editor.focus();
  }

  function stepHistory(direction) {
    if (historyTimer) commitHistorySnapshot();
    const tab = tabs.get(activeDocumentID); if (!tab) return;
    ensureHistory(tab);
    applyHistoryIndex(tab.timelineIndex + direction);
  }

  function updateHistoryControls() {
    const tab = tabs.get(activeDocumentID);
    if (tab) ensureHistory(tab);
    const index = tab?.timelineIndex ?? 0;
    document.getElementById('undo-action').disabled = !tab || index <= 0;
    document.getElementById('redo-action').disabled = !tab || index >= tab.timeline.length - 1;
  }

  function renderHistoryList() {
    const host = document.getElementById('history-list');
    if (!host) return;
    host.replaceChildren();
    const tab = tabs.get(activeDocumentID);
    if (!tab) { host.innerHTML = '<div class="history-empty">当前没有可用记录</div>'; return; }
    ensureHistory(tab);
    [...tab.timeline].map((entry, index) => ({ entry, index })).reverse().forEach(({ entry, index }) => {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = `history-entry${index === tab.timelineIndex ? ' current' : ''}`;
      const time = document.createElement('time');
      time.textContent = new Date(entry.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
      const label = document.createElement('span'); label.className = 'history-label'; label.textContent = entry.label;
      const position = document.createElement('span'); position.className = 'history-position';
      position.textContent = index === tab.timelineIndex ? '当前' : (index < tab.timelineIndex ? `回退 ${tab.timelineIndex - index} 步` : `前进 ${index - tab.timelineIndex} 步`);
      button.append(time, label, position);
      button.onclick = () => applyHistoryIndex(index);
      host.append(button);
    });
  }

  function openHistoryTools() {
    if (historyTimer) commitHistorySnapshot();
    renderHistoryList();
    const dialog = document.getElementById('history-dialog');
    if (!dialog.open) dialog.showModal();
  }

  function clearSearchMarks() {
    clearTimeout(searchTimer);
    searchTimer = null;
    searchMarks.forEach(mark => mark.clear());
    searchMarks = [];
    activeSearchMark?.clear();
    activeSearchMark = null;
    activeSearchIndex = -1;
    searchMatches = [];
    searchIndex = -1;
    searchLimited = false;
  }

  function scheduleSearch() {
    clearTimeout(searchTimer);
    const status = document.getElementById('search-status');
    status.textContent = '查找中…';
    searchTimer = setTimeout(collectSearchMatches, 180);
  }

  function collectSearchMatches() {
    clearSearchMarks();
    const query = document.getElementById('search-query').value;
    const mode = document.getElementById('search-mode').value;
    if (!query) { updateSearchStatus(); return; }
    if (mode === 'fuzzy' && query.length > 64) {
      document.getElementById('search-status').textContent = '模糊查找最多支持 64 个字符；请缩短关键词';
      return;
    }
    const caseSensitive = mode === 'exact';
    const needle = caseSensitive ? query : query.toLocaleLowerCase();
    const maximumMatches = 10_000;
    for (let lineNumber = 0; lineNumber < editor.lineCount(); lineNumber++) {
      const line = editor.getLine(lineNumber);
      if (mode === 'fuzzy') {
        const result = window.dotmdFuzzySearch.findInLine(line, query);
        if (result.limited) searchLimited = true;
        const match = result.match;
        if (match) searchMatches.push({ from: { line: lineNumber, ch: match.ch }, to: { line: lineNumber, ch: match.ch + match.length }, score: match.score });
      } else {
        const sourceText = caseSensitive ? line : line.toLocaleLowerCase();
        let ch = 0;
        while ((ch = sourceText.indexOf(needle, ch)) >= 0) {
          searchMatches.push({ from: { line: lineNumber, ch }, to: { line: lineNumber, ch: ch + query.length }, score: 1 });
          ch += Math.max(1, query.length);
          if (searchMatches.length >= maximumMatches) break;
        }
      }
      if (searchMatches.length >= maximumMatches) {
        searchLimited = true;
        break;
      }
    }
    // Keep all located positions (up to the safety limit), but only draw a
    // bounded number of marks. Moving to any result still highlights it.
    searchMarks = searchMatches.slice(0, 200).map(match =>
      editor.markText(match.from, match.to, { className: 'search-hit' }));
    if (searchMatches.length) searchIndex = 0;
    updateActiveSearchMark(false);
  }

  function updateSearchStatus(reveal = true) {
    const status = document.getElementById('search-status');
    if (!document.getElementById('search-query').value) { status.textContent = '输入内容开始查找'; return; }
    if (!searchMatches.length) {
      status.textContent = searchLimited ? '未找到匹配；超长行已限量，请缩小关键词' : '没有找到匹配内容';
      return;
    }
    const match = searchMatches[searchIndex];
    const suffix = match.score < 1 ? ` · 相似度 ${Math.round(match.score * 100)}%` : '';
    status.textContent = `${searchIndex + 1} / ${searchMatches.length}${suffix}${searchLimited ? ' · 结果已限量，请缩小范围' : ''}`;
    if (reveal) {
      editor.setSelection(match.from, match.to);
      editor.scrollIntoView({ from: match.from, to: match.to }, 90);
      editor.focus();
    }
  }

  function updateActiveSearchMark(reveal = true) {
    activeSearchMark?.clear();
    if (activeSearchIndex >= 0 && activeSearchIndex < searchMarks.length) {
      const old = searchMatches[activeSearchIndex];
      searchMarks[activeSearchIndex] = editor.markText(old.from, old.to, { className: 'search-hit' });
    }
    activeSearchMark = null;
    activeSearchIndex = searchIndex;
    if (searchIndex >= 0) {
      if (searchIndex < searchMarks.length) searchMarks[searchIndex]?.clear();
      const match = searchMatches[searchIndex];
      activeSearchMark = editor.markText(match.from, match.to, { className: 'search-hit search-hit-active' });
    }
    updateSearchStatus(reveal);
  }

  function moveSearch(direction) {
    if (searchTimer) collectSearchMatches();
    if (!searchMatches.length) collectSearchMatches();
    if (!searchMatches.length) return;
    searchIndex = (searchIndex + direction + searchMatches.length) % searchMatches.length;
    updateActiveSearchMark(true);
  }

  function replaceCurrentSearch() {
    if (searchTimer) collectSearchMatches();
    if (!searchMatches.length) return;
    const match = searchMatches[searchIndex];
    editor.replaceRange(document.getElementById('replace-value').value, match.from, match.to);
    collectSearchMatches();
    if (searchMatches.length) updateActiveSearchMark(true);
  }

  function replaceAllSearch() {
    if (searchTimer) collectSearchMatches();
    if (!searchMatches.length) return;
    if (searchLimited) { showToast('结果已限量，缩小查询后再执行全部替换'); return; }
    const replacement = document.getElementById('replace-value').value;
    const matches = [...searchMatches].reverse();
    editor.operation(() => matches.forEach(match => editor.replaceRange(replacement, match.from, match.to)));
    const count = matches.length;
    collectSearchMatches();
    showToast(`已替换 ${count} 处`);
  }

  function openSearchTools(focusReplacement = false) {
    const dialog = document.getElementById('search-dialog');
    const selected = editor.getSelection();
    if (selected && !selected.includes('\n')) document.getElementById('search-query').value = selected;
    if (!dialog.open) dialog.showModal();
    collectSearchMatches();
    requestAnimationFrame(() => {
      const input = document.getElementById(focusReplacement ? 'replace-value' : 'search-query');
      input.focus(); input.select();
    });
  }

  function selectedAgentProfileIDs() {
    return agentProfiles.filter(profile => profile.enabled).map(profile => profile.id);
  }

  function updateActiveAgentSummary() {
    const names = agentProfiles.filter(profile => profile.enabled).map(profile => profile.name);
    document.getElementById('agent-active-services').textContent = names.length
      ? `已启用：${names.join('、')}。模型和密钥在设置中管理。`
      : '尚未启用 Agent。请先在设置中选择服务并保存。';
  }

  function runSearchAgent(purpose) {
    const query = document.getElementById('search-query').value.trim();
    if (purpose === 'agent-find' && !query) { showToast('请先输入要查找的内容或含义'); return; }
    const instruction = purpose === 'summary'
      ? '总结完整文稿，输出结构清晰、可直接保存为 Markdown 的总结。保留关键结论、论据、公式和待办事项，不要使用代码围栏。'
      : `在完整 Markdown 文稿中进行语义查找：${query}。只返回严格 JSON，格式为 {"matches":[{"quote":"文稿中的原句","reason":"匹配原因"}]}。quote 必须逐字复制原文，最多返回 20 条。`;
    document.getElementById('search-results').innerHTML = '<div class="empty-result">Agent 处理中…</div>';
    sendNativeMessage('agentRun', { profileIDs: selectedAgentProfileIDs(), instruction, selection: '', context: editor.getValue(), mode: 'single', purpose });
  }

  function toggleOutline() { workspace.classList.toggle('outline-open'); setTimeout(() => editor.refresh(), 160); }

  function rememberEditorSelection() {
    const from = editor.getCursor('from'), to = editor.getCursor('to');
    let text = editor.getRange(from, to);
    if (!text) {
      const line = editor.getLine(from.line) || '';
      const matches = [...line.matchAll(/\$\$?([^$]+)\$\$?|\\\((.+?)\\\)|\\\[(.+?)\\\]/g)];
      const hit = matches.find(match => match.index <= from.ch && match.index + match[0].length >= from.ch) || matches[0];
      if (hit) text = hit[1] || hit[2] || hit[3] || hit[0];
    }
    lastSelection = { from, to, text };
    return text;
  }

  function normalizeLatexFormula(value) {
    let text = value.trim().replace(/^\$\$?|\$\$?$/g, '').replace(/^\\[\[(]|\\[\])]$/g, '').trim();
    const replacements = [['∞','\\infty'],['≤','\\leq'],['≥','\\geq'],['≠','\\neq'],['×','\\times '],['÷','\\div '],['∑','\\sum '],['∫','\\int '],['π','\\pi '],['α','\\alpha '],['β','\\beta '],['γ','\\gamma '],['θ','\\theta '],['→','\\to '],['²','^{2}'],['³','^{3}']];
    replacements.forEach(([from,to]) => text = text.split(from).join(to));
    text = text.replace(/√\s*\(([^)]+)\)/g, '\\sqrt{$1}').replace(/√\s*([A-Za-z0-9]+)/g, '\\sqrt{$1}');
    text = text.replace(/\b([A-Za-z0-9]+)\s*\/\s*([A-Za-z0-9]+)\b/g, '\\frac{$1}{$2}');
    return text.replace(/^```(?:latex)?\s*|\s*```$/g, '').trim();
  }

  function updateFormulaPreview() {
    currentFormula = normalizeLatexFormula(document.getElementById('formula-source').value);
    const host = document.getElementById('formula-preview');
    try { window.katex.render(currentFormula, host, { displayMode:true, throwOnError:true, strict:false }); }
    catch (error) { host.textContent = `格式错误：${error.message}`; }
  }

  function openFormulaTools(value) {
    const selected = value ?? rememberEditorSelection();
    document.getElementById('formula-source').value = selected || '';
    updateFormulaPreview();
    document.getElementById('formula-dialog').showModal();
  }

  function prepareFormulaClipboardFormats() {
    const latex = normalizeLatexFormula(document.getElementById('formula-source').value);
    const mathML = window.katex.renderToString(latex, { displayMode:true, output:'mathml', throwOnError:false, strict:false });
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="220" viewBox="0 0 1200 220"><foreignObject width="1200" height="220"><div xmlns="http://www.w3.org/1999/xhtml" style="font-size:32px;text-align:center;padding:60px;color:#111;background:#fff;font-family:'STIX Two Math','Cambria Math',serif">${mathML}</div></foreignObject></svg>`;
    return { latex, mathML, svg };
  }

  function replaceRememberedSelection(text, asFormula = false) {
    const value = asFormula ? `$${normalizeLatexFormula(text)}$` : text;
    if (lastSelection && (lastSelection.from.line !== lastSelection.to.line || lastSelection.from.ch !== lastSelection.to.ch)) editor.replaceRange(value, lastSelection.from, lastSelection.to);
    else editor.replaceSelection(value);
    editor.focus();
  }

  function openAgentTools(instruction) {
    rememberEditorSelection();
    if (instruction) document.getElementById('agent-instruction').value = instruction;
    document.getElementById('agent-dialog').showModal();
  }

  function renderAgentProfiles() {
    const host = document.getElementById('agent-profiles');
    host.replaceChildren();
    const header = document.createElement('div');
    header.className = 'agent-profile-header';
    ['启用', '名称', '接口类型', 'API 端点', '模型'].forEach(label => {
      const column = document.createElement('span');
      column.textContent = label;
      header.append(column);
    });
    host.append(header);
    agentProfiles.forEach(profile => {
      const row = document.createElement('div');
      row.className = 'agent-profile';
      row.dataset.id = profile.id;
      const enabled = document.createElement('input');
      enabled.type = 'checkbox';
      enabled.checked = profile.enabled;
      enabled.className = 'enabled';
      enabled.title = '加入当前 Agent 集群';
      enabled.setAttribute('aria-label', `${profile.name}：启用此服务`);
      const name = document.createElement('input');
      name.value = profile.name;
      name.className = 'name';
      name.title = '显示名称';
      name.setAttribute('aria-label', `${profile.name} 显示名称`);
      const kind = document.createElement('select');
      kind.className = 'kind';
      kind.setAttribute('aria-label', `${profile.name} 接口类型`);
      const kinds = [
        ['openai-responses', 'OpenAI Responses'], ['openai-chat', 'OpenAI compatible'],
        ['anthropic', 'Anthropic'], ['gemini', 'Gemini'], ['local', '本地 compatible']
      ];
      kinds.forEach(([value, label]) => {
        const option = document.createElement('option');
        option.value = value;
        option.textContent = label;
        option.selected = profile.kind === value;
        kind.append(option);
      });
      const endpoint = document.createElement('input');
      endpoint.value = profile.endpoint;
      endpoint.className = 'endpoint';
      endpoint.title = 'API 端点';
      endpoint.setAttribute('aria-label', `${profile.name} API 端点`);
      const model = document.createElement('input');
      model.value = profile.model;
      model.className = 'model';
      model.title = '模型名称';
      model.setAttribute('aria-label', `${profile.name} 模型名称`);
      const key = document.createElement('input');
      key.type = 'password';
      key.className = 'key';
      key.setAttribute('aria-label', `${profile.name} API Key`);
      key.placeholder = profile.keyPresent
        ? 'API Key 已保存在钥匙串；留空表示不更改'
        : '输入 API Key（仅存入 macOS 钥匙串）';
      const keyGroup = document.createElement('div');
      keyGroup.className = 'key-group';
      const clearKey = document.createElement('button');
      clearKey.type = 'button';
      clearKey.textContent = '清除密钥';
      clearKey.setAttribute('aria-label', `清除 ${profile.name} 的已存 API Key`);
      clearKey.onclick = () => {
        key.value = '';
        key.disabled = true;
        keyGroup.dataset.clearKey = 'true';
        key.placeholder = '保存配置后清除钥匙串中的密钥';
      };
      keyGroup.append(key, clearKey);
      row.append(enabled, name, kind, endpoint, model, keyGroup);
      host.append(row);
    });
    updateActiveAgentSummary();
  }

  function collectAgentProfiles() {
    const keys = {};
    const profiles = [...document.querySelectorAll('.agent-profile')].map(row => {
      const id = row.dataset.id;
      const key = row.querySelector('.key').value;
      if (row.querySelector('.key-group').dataset.clearKey === 'true') keys[id] = '';
      else if (key) keys[id] = key;
      return {
        id,
        name: row.querySelector('.name').value,
        kind: row.querySelector('.kind').value,
        endpoint: row.querySelector('.endpoint').value,
        model: row.querySelector('.model').value,
        enabled: row.querySelector('.enabled').checked,
        keyPresent: row.querySelector('.key-group').dataset.clearKey !== 'true' &&
          (agentProfiles.find(profile => profile.id === id)?.keyPresent || !!key)
      };
    });
    return { profiles, keys };
  }

  function requestAgentEdits() {
    if (document.getElementById('cluster-mode').value === 'workflow') {
      runEditedWorkflow();
      return;
    }
    const selectedAction = document.getElementById('agent-action').value;
    const customInstruction = document.getElementById('agent-instruction').value.trim();
    const instruction = selectedAction === 'custom' ? customInstruction : (customInstruction || selectedAction);
    const selectedText = lastSelection?.text || '';
    const fullDocument = editor.getValue();
    const cursorOffset = editor.indexFromPos(editor.getCursor());
    const nearbyContext = fullDocument.slice(
      Math.max(0, cursorOffset - 3000), Math.min(fullDocument.length, cursorOffset + 3000));
    const selectedProfileIDs = selectedAgentProfileIDs();
    const purpose = selectedAction.startsWith('总结完整文稿') ? 'summary' : 'edit';
    sendNativeMessage('agentRun', {
      profileIDs: selectedProfileIDs, instruction, selection: selectedText,
      context: purpose === 'summary' ? fullDocument : nearbyContext,
      mode: document.getElementById('cluster-mode').value, purpose
    });
  }

  const workflowStoreKey = 'agentWorkflow.v1';
  let editedWorkflow;
  try { editedWorkflow = JSON.parse(localStorage.getItem(workflowStoreKey) || 'null'); } catch (_) {}
  if (!editedWorkflow || !Array.isArray(editedWorkflow.stages)) editedWorkflow = dotmdWorkflow.template([]);
  let pendingWorkflowProposal = null;

  function availableWorkflowAgents() {
    return agentProfiles.filter(profile => profile.enabled);
  }

  function rememberWorkflow() {
    localStorage.setItem(workflowStoreKey, JSON.stringify(editedWorkflow));
    updateWorkflowPreview();
  }

  function updateWorkflowPreview() {
    const preview = document.getElementById('workflow-preview');
    const enabled = availableWorkflowAgents();
    try {
      const checked = dotmdWorkflow.normalize(editedWorkflow, enabled.map(profile => profile.id));
      const destinations = checked.stages.map((stage, index) => {
        const names = stage.profileIDs.map(id => enabled.find(profile => profile.id === id)?.name || id);
        return `${index + 1}. ${stage.title} → ${names.join(' + ')}`;
      });
      const calls = checked.stages.reduce((total, stage) => total + stage.profileIDs.length, 0);
      const scope = document.getElementById('workflow-scope').value === 'full' ? '完整文稿' : '选中文字与附近内容';
      preview.textContent = `${destinations.join('  ·  ')}。预计 ${calls} 次 Agent 请求；每一步会收到${scope}与此前的答案。`;
      preview.classList.remove('workflow-warning');
    } catch (error) {
      preview.textContent = enabled.length ? error.message : '请先在“设置 → Agent 与模型”中启用并保存至少一位 Agent。';
      preview.classList.add('workflow-warning');
    }
  }

  function renderWorkflowPlanner() {
    const picker = document.getElementById('workflow-planner');
    const previous = picker.value;
    picker.replaceChildren();
    availableWorkflowAgents().forEach(profile => {
      const option = document.createElement('option'); option.value = profile.id; option.textContent = `${profile.name} 设计流程`;
      picker.append(option);
    });
    if ([...picker.options].some(option => option.value === previous)) picker.value = previous;
    document.getElementById('workflow-generate').disabled = !picker.options.length;
  }

  function renderWorkflowStages() {
    const host = document.getElementById('workflow-stages'); host.replaceChildren();
    const agents = availableWorkflowAgents();
    editedWorkflow.stages.forEach((stage, index) => {
      const card = document.createElement('section'); card.className = 'workflow-stage';
      const top = document.createElement('div'); top.className = 'workflow-stage-top';
      const number = document.createElement('span'); number.className = 'workflow-number'; number.textContent = String(index + 1);
      const title = document.createElement('input'); title.value = stage.title || ''; title.maxLength = 60;
      title.setAttribute('aria-label', `第 ${index + 1} 步名称`);
      title.oninput = () => { stage.title = title.value; rememberWorkflow(); };
      const controls = document.createElement('div'); controls.className = 'workflow-stage-controls';
      [['上移', -1], ['下移', 1]].forEach(([label, direction]) => {
        const button = document.createElement('button'); button.type = 'button';
        button.textContent = direction < 0 ? '↑' : '↓'; button.title = label;
        button.setAttribute('aria-label', `第 ${index + 1} 步${label}`);
        button.disabled = direction < 0 ? index === 0 : index === editedWorkflow.stages.length - 1;
        button.onclick = () => {
          const other = index + direction;
          [editedWorkflow.stages[index], editedWorkflow.stages[other]] = [editedWorkflow.stages[other], editedWorkflow.stages[index]];
          rememberWorkflow(); renderWorkflowStages();
        };
        controls.append(button);
      });
      const remove = document.createElement('button'); remove.type = 'button'; remove.textContent = '×';
      remove.title = '删除这一步'; remove.setAttribute('aria-label', `删除第 ${index + 1} 步`);
      remove.disabled = editedWorkflow.stages.length === 1;
      remove.onclick = () => { editedWorkflow.stages.splice(index, 1); rememberWorkflow(); renderWorkflowStages(); };
      controls.append(remove); top.append(number, title, controls);
      const mode = document.createElement('select'); mode.setAttribute('aria-label', `第 ${index + 1} 步方式`);
      [['single', '一位 Agent 完成'], ['parallel', '几位 Agent 并行评审']].forEach(([value, label]) => {
        const option = document.createElement('option'); option.value = value; option.textContent = label; mode.append(option);
      });
      mode.value = stage.mode === 'parallel' ? 'parallel' : 'single';
      mode.onchange = () => { stage.mode = mode.value; if (mode.value === 'single') stage.profileIDs = stage.profileIDs.slice(0, 1); rememberWorkflow(); renderWorkflowStages(); };
      const agentBox = document.createElement('div'); agentBox.className = 'workflow-agents';
      if (stage.mode === 'parallel') {
        agents.forEach(profile => {
          const label = document.createElement('label');
          const checkbox = document.createElement('input'); checkbox.type = 'checkbox'; checkbox.value = profile.id;
          checkbox.checked = stage.profileIDs.includes(profile.id);
          checkbox.onchange = () => {
            stage.profileIDs = checkbox.checked ? [...stage.profileIDs, profile.id] : stage.profileIDs.filter(id => id !== profile.id);
            rememberWorkflow();
          };
          label.append(checkbox, document.createTextNode(profile.name)); agentBox.append(label);
        });
      } else {
        const picker = document.createElement('select'); picker.setAttribute('aria-label', `第 ${index + 1} 步 Agent`);
        agents.forEach(profile => {
          const option = document.createElement('option'); option.value = profile.id; option.textContent = profile.name; picker.append(option);
        });
        picker.value = stage.profileIDs[0] || agents[0]?.id || '';
        if (picker.options.length && !picker.value) picker.selectedIndex = 0;
        if (picker.value && !agents.some(profile => profile.id === stage.profileIDs[0])) stage.profileIDs = [picker.value];
        picker.onchange = () => { stage.profileIDs = [picker.value]; rememberWorkflow(); };
        agentBox.append(picker);
      }
      const promptLabel = document.createElement('label'); promptLabel.className = 'workflow-prompt';
      const caption = document.createElement('span'); caption.textContent = '这一步要做什么';
      const prompt = document.createElement('textarea'); prompt.rows = 2; prompt.maxLength = 1200;
      prompt.value = stage.prompt || ''; prompt.setAttribute('aria-label', `第 ${index + 1} 步提示词`);
      prompt.oninput = () => { stage.prompt = prompt.value; rememberWorkflow(); };
      promptLabel.append(caption, prompt); card.append(top, mode, agentBox, promptLabel); host.append(card);
    });
    updateWorkflowPreview();
  }

  function refreshWorkflowEditor() {
    renderWorkflowPlanner();
    document.getElementById('workflow-goal').value = editedWorkflow.goal || '';
    document.getElementById('workflow-scope').value = editedWorkflow.scope === 'full' ? 'full' : 'nearby';
    document.getElementById('workflow-outcome').value = editedWorkflow.outcome === 'summary' ? 'summary' : 'edit';
    renderWorkflowStages();
  }

  function runEditedWorkflow() {
    const available = availableWorkflowAgents();
    let workflow;
    try { workflow = dotmdWorkflow.normalize(editedWorkflow, available.map(profile => profile.id)); }
    catch (error) { showToast(error.message); document.getElementById('workflow-preview').focus(); return; }
    const purpose = document.getElementById('workflow-outcome').value;
    const fullDocument = editor.getValue();
    const offset = editor.indexFromPos(editor.getCursor());
    sendNativeMessage('agentWorkflowRun', {
      workflow, selection: lastSelection?.text || '',
      context: document.getElementById('workflow-scope').value === 'full'
        ? fullDocument : fullDocument.slice(Math.max(0, offset - 3000), offset + 3000),
      purpose
    });
  }

  function showWorkflowProposal(text, error) {
    const host = document.getElementById('workflow-proposal'); host.replaceChildren(); host.hidden = false;
    if (error) { host.textContent = `设计失败：${error}`; pendingWorkflowProposal = null; return; }
    try {
      pendingWorkflowProposal = dotmdWorkflow.parseProposal(text, availableWorkflowAgents().map(profile => profile.id));
      const heading = document.createElement('strong'); heading.textContent = `建议流程：${pendingWorkflowProposal.title}`;
      const list = document.createElement('ol');
      pendingWorkflowProposal.stages.forEach(stage => {
        const item = document.createElement('li'); item.textContent = `${stage.title}：${stage.prompt}`; list.append(item);
      });
      const apply = document.createElement('button'); apply.type = 'button'; apply.textContent = '采用并继续修改';
      apply.onclick = () => {
        editedWorkflow = pendingWorkflowProposal;
        editedWorkflow.goal = document.getElementById('workflow-goal').value.trim();
        editedWorkflow.scope = document.getElementById('workflow-scope').value;
        editedWorkflow.outcome = document.getElementById('workflow-outcome').value;
        pendingWorkflowProposal = null; host.hidden = true; rememberWorkflow(); renderWorkflowStages();
      };
      host.append(heading, list, apply);
    } catch (parseError) { host.textContent = parseError.message; pendingWorkflowProposal = null; }
  }

  function showWorkflowResults(results, purpose = 'edit') {
    const completed = results.at(-1)?.answers.filter(answer => !answer.error) || [];
    showAgentResults(completed.length ? completed : results.at(-1)?.answers || [], purpose);
    const host = document.getElementById('agent-results');
    if (results.length && purpose !== 'summary') {
      const finalLabel = document.createElement('div'); finalLabel.className = 'workflow-result-label';
      finalLabel.textContent = `第 ${results.length} 步 · ${results.at(-1).title}${completed.length ? ' · 可采用下方结果' : ' · 未完成'}`;
      host.prepend(finalLabel);
    }
    results.slice(0, -1).reverse().forEach((stage, reverseIndex) => {
      const index = results.length - reverseIndex - 2;
      const card = document.createElement('section'); card.className = 'agent-result';
      const header = document.createElement('header'); header.textContent = `第 ${index + 1} 步 · ${stage.title}`;
      const pre = document.createElement('pre');
      pre.textContent = stage.answers.map(answer => `${answer.name}：${answer.error || answer.text}`).join('\n\n');
      card.append(header, pre); host.prepend(card);
    });
  }

  function suggestedSummaryTitle() {
    const tab = tabs.get(activeDocumentID);
    const base = (tab?.title || '未命名.md').replace(/\.md$/i, '');
    return `${base} - 总结.md`;
  }

  function parseAgentSearchMatches(text) {
    const cleaned = text.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
    try {
      const value = JSON.parse(cleaned);
      return Array.isArray(value.matches) ? value.matches.filter(item => typeof item.quote === 'string' && item.quote.trim()) : [];
    } catch (_) { return []; }
  }

  function displayAgentSearchMatches(answers) {
    const host = document.getElementById('search-results'); host.replaceChildren();
    clearSearchMarks();
    const full = editor.getValue();
    const located = [];
    answers.filter(answer => !answer.error).forEach(answer => {
      parseAgentSearchMatches(answer.text).forEach(item => {
        const index = full.indexOf(item.quote);
        if (index < 0) return;
        const from = editor.posFromIndex(index), to = editor.posFromIndex(index + item.quote.length);
        located.push({ from, to, score: 1, reason: item.reason || '', quote: item.quote, agent: answer.name });
      });
    });
    searchMatches = located;
    searchIndex = located.length ? 0 : -1;
    updateActiveSearchMark(false);
    if (!located.length) {
      const error = answers.find(answer => answer.error)?.error;
      host.innerHTML = `<div class="empty-result">${md.utils.escapeHtml(error || 'Agent 没有返回可定位的原文匹配。')}</div>`;
      document.getElementById('search-status').textContent = '没有可定位的 Agent 匹配';
      return;
    }
    located.forEach((match, index) => {
      const card = document.createElement('section'); card.className = 'agent-result';
      const header = document.createElement('header'); header.textContent = `${match.agent} · 第 ${match.from.line + 1} 行`;
      const pre = document.createElement('pre'); pre.textContent = `${match.quote}${match.reason ? `\n\n${match.reason}` : ''}`;
      const footer = document.createElement('footer');
      const locate = document.createElement('button'); locate.type = 'button'; locate.textContent = '定位';
      locate.onclick = () => { searchIndex = index; updateActiveSearchMark(true); };
      footer.append(locate); card.append(header, pre, footer); host.append(card);
    });
    document.getElementById('search-status').textContent = `Agent 找到 ${located.length} 处语义匹配`;
  }

  function showAgentResults(answers, purpose = 'edit') {
    if (purpose === 'agent-find') {
      displayAgentSearchMatches(answers);
      document.getElementById('search-dialog').classList.remove('busy');
      return;
    }
    const searchDialogOpen = document.getElementById('search-dialog').open;
    const host = purpose === 'summary' && searchDialogOpen ? document.getElementById('search-results') : document.getElementById('agent-results');
    host.replaceChildren();
    answers.forEach(answer => {
      const card = document.createElement('section');
      card.className = 'agent-result';
      const header = document.createElement('header');
      header.textContent = answer.name;
      const pre = document.createElement('pre');
      pre.textContent = answer.error || answer.text;
      if (answer.error) pre.className = 'agent-error';
      const footer = document.createElement('footer');
      if (!answer.error) {
        const replace = document.createElement('button');
        replace.type = 'button';
        replace.textContent = '替换选中内容';
        replace.onclick = () => replaceRememberedSelection(answer.text, false);
        const formula = document.createElement('button');
        formula.type = 'button';
        formula.textContent = '作为公式检查';
        formula.onclick = () => openFormulaTools(answer.text);
        const copy = document.createElement('button');
        copy.type = 'button';
        copy.textContent = '复制文本';
        copy.onclick = () => sendNativeMessage('copyText', { text: answer.text });
        footer.append(replace, formula, copy);
        if (purpose === 'summary') {
          replace.remove();
          formula.remove();
          const create = document.createElement('button');
          create.type = 'button';
          create.textContent = '生成新的 Markdown 文稿';
          create.onclick = () => sendNativeMessage('newWithContent', { title: suggestedSummaryTitle(), content: answer.text });
          footer.prepend(create);
        }
      }
      card.append(header, pre, footer);
      host.append(card);
    });
    if (purpose === 'summary' && searchDialogOpen) {
      document.getElementById('search-dialog').classList.remove('busy');
      document.getElementById('search-status').textContent = answers.some(answer => !answer.error) ? '总结完成，可生成新文稿' : '总结失败';
    }
  }

  function showToast(message) {
    const toast = document.getElementById('toast');
    toast.textContent = message;
    toast.classList.add('show');
    clearTimeout(toast._timer);
    toast._timer = setTimeout(() => toast.classList.remove('show'), 2200);
  }

  function updateRangeProgress(rangeControl) {
    const minimum = Number(rangeControl.min);
    const maximum = Number(rangeControl.max);
    const progress = maximum > minimum
      ? ((Number(rangeControl.value) - minimum) / (maximum - minimum)) * 100 : 0;
    rangeControl.style.setProperty('--range-progress', `${Math.max(0, Math.min(100, progress))}%`);
  }

  editor.on('change', (_instance, change) => {
    if (!suppressChanges) {
      schedulePreviewRender(true);
      scheduleHistorySnapshot(labelForEditorChange(change));
    }
    if (document.getElementById('search-dialog').open) scheduleSearch();
  });
  function updateCursorStatus() {
    const cursorPosition = editor.getCursor();
    document.getElementById('cursor-status').textContent =
      `第 ${cursorPosition.line + 1} 行，第 ${cursorPosition.ch + 1} 列`;
  }
  editor.on('cursorActivity', () => {
    updateCursorStatus();
    updatePreviewSelection(true);
  });
  editor.on('scroll', () => {
    if (!document.getElementById('sync-scroll').checked || syncingScroll) return;
    const editorScroll = editor.getScrollInfo();
    const maxEditorScroll = editorScroll.height - editorScroll.clientHeight;
    if (maxEditorScroll <= 0) return;
    syncingScroll = true;
    previewPane.scrollTop = (editorScroll.top / maxEditorScroll) *
      (previewPane.scrollHeight - previewPane.clientHeight);
    requestAnimationFrame(() => { syncingScroll = false; });
  });

  document.querySelectorAll('[data-command]').forEach(button => button.addEventListener('click', () => applyMarkdownFormatting(button.dataset.command)));
  document.querySelectorAll('[data-mode]').forEach(button => button.addEventListener('click', () => setMode(button.dataset.mode)));
  document.getElementById('outline-toggle').onclick = toggleOutline;
  document.getElementById('close-outline').onclick = toggleOutline;
  document.getElementById('new-tab').onclick = () => sendNativeMessage('new');
  document.getElementById('search-tools').onclick = openSearchTools;
  document.getElementById('undo-action').onclick = () => stepHistory(-1);
  document.getElementById('redo-action').onclick = () => stepHistory(1);
  document.getElementById('history-tools').onclick = openHistoryTools;
  document.getElementById('formula-tools').onclick = () => openFormulaTools();
  document.getElementById('docx-tools').onclick = () => window.dotmdDocx.open();
  document.getElementById('agent-tools').onclick = () => openAgentTools();
  document.getElementById('formula-source').oninput = updateFormulaPreview;
  document.getElementById('formula-normalize').onclick = () => { document.getElementById('formula-source').value=normalizeLatexFormula(document.getElementById('formula-source').value); updateFormulaPreview(); };
  document.getElementById('formula-agent').onclick = () => { document.getElementById('formula-dialog').close(); openAgentTools('把选中内容转换为正确、可渲染的 LaTeX 公式，只返回公式源码'); };
  document.getElementById('formula-copy').onclick = () => {
    const clipboardFormats = prepareFormulaClipboardFormats();
    sendNativeMessage('copyFormula', {
      ...clipboardFormats, target: document.getElementById('formula-target').value
    });
  };
  document.getElementById('formula-replace').onclick = () => { replaceRememberedSelection(document.getElementById('formula-source').value,true); document.getElementById('formula-dialog').close(); };
  document.getElementById('agent-action').onchange = event => { if(event.target.value!=='custom') document.getElementById('agent-instruction').value=''; };
  document.getElementById('agent-run').onclick = requestAgentEdits;
  document.getElementById('cluster-mode').onchange = event => {
    document.getElementById('workflow-builder').hidden = event.target.value !== 'workflow';
    if (event.target.value === 'workflow') refreshWorkflowEditor();
  };
  document.getElementById('workflow-template').onclick = () => {
    const scope = document.getElementById('workflow-scope').value;
    const outcome = document.getElementById('workflow-outcome').value;
    editedWorkflow = dotmdWorkflow.template(availableWorkflowAgents().map(profile => profile.id), document.getElementById('workflow-goal').value.trim());
    editedWorkflow.scope = scope; editedWorkflow.outcome = outcome;
    rememberWorkflow(); renderWorkflowStages();
  };
  document.getElementById('workflow-goal').oninput = event => {
    editedWorkflow.goal = event.target.value.trim(); rememberWorkflow();
  };
  for (const id of ['workflow-scope', 'workflow-outcome']) {
    document.getElementById(id).onchange = event => {
      editedWorkflow[id === 'workflow-scope' ? 'scope' : 'outcome'] = event.target.value;
      rememberWorkflow();
    };
  }
  document.getElementById('workflow-add').onclick = () => {
    if (editedWorkflow.stages.length >= dotmdWorkflow.MAX_STAGES) { showToast('最多添加 5 步。'); return; }
    const firstID = availableWorkflowAgents()[0]?.id || '';
    editedWorkflow.stages.push({ title: `第 ${editedWorkflow.stages.length + 1} 步`, mode: 'single', profileIDs: [firstID], prompt: '' });
    rememberWorkflow(); renderWorkflowStages();
  };
  document.getElementById('workflow-generate').onclick = () => {
    const goal = document.getElementById('workflow-goal').value.trim();
    const planner = document.getElementById('workflow-planner').value;
    if (!goal) { showToast('先用一句话描述目标。'); return; }
    if (!planner) { showToast('先启用一位 Agent。'); return; }
    sendNativeMessage('agentPlanWorkflow', { profileID: planner, goal });
  };
  document.getElementById('search-query').oninput = scheduleSearch;
  document.getElementById('search-mode').onchange = scheduleSearch;
  document.getElementById('search-query').onkeydown = event => {
    if (event.key === 'Enter') { event.preventDefault(); moveSearch(event.shiftKey ? -1 : 1); }
  };
  document.getElementById('find-previous').onclick = () => moveSearch(-1);
  document.getElementById('find-next').onclick = () => moveSearch(1);
  document.getElementById('replace-current').onclick = replaceCurrentSearch;
  document.getElementById('replace-all').onclick = replaceAllSearch;
  document.getElementById('agent-find').onclick = () => runSearchAgent('agent-find');
  document.getElementById('agent-summary').onclick = () => runSearchAgent('summary');
  document.getElementById('search-dialog').addEventListener('close', clearSearchMarks);
  document.getElementById('save-agents').onclick = () => {
    const savedProfiles = collectAgentProfiles();
    agentProfiles = savedProfiles.profiles;
    updateActiveAgentSummary();
    refreshWorkflowEditor();
    window.dotmdDocx.updateAgents();
    sendNativeMessage('saveAgentProfiles', savedProfiles);
  };
  document.getElementById('agent-open-settings').onclick = () => {
    document.getElementById('agent-dialog').close();
    document.getElementById('settings-dialog').showModal();
    document.getElementById('settings-agent-title').scrollIntoView({ block: 'start' });
  };
  document.getElementById('open-privacy-policy').onclick = event => {
    event.preventDefault();
    document.getElementById('settings-dialog').close();
    document.getElementById('privacy-policy').showModal();
  };
  document.getElementById('font-size').oninput = event => {
    updateRangeProgress(event.target);
    document.documentElement.style.setProperty('--editor-size', `${event.target.value}px`);
    document.getElementById('font-size-value').textContent = `${event.target.value} px`;
    localStorage.editorSize = event.target.value;
  };
  document.getElementById('reading-width').oninput = event => {
    updateRangeProgress(event.target);
    document.documentElement.style.setProperty('--reading-width', `${event.target.value}px`);
    document.getElementById('reading-width-value').textContent = `${event.target.value} px`;
    localStorage.readingWidth = event.target.value;
  };
  document.getElementById('line-numbers').onchange = event => { editor.setOption('lineNumbers', event.target.checked); localStorage.lineNumbers = event.target.checked; };
  document.getElementById('sync-scroll').onchange = event => localStorage.syncScroll = event.target.checked;
  document.getElementById('history-depth').oninput = event => {
    updateRangeProgress(event.target);
    historyLimit = Number(event.target.value) || 10;
    document.getElementById('history-depth-value').textContent = `${historyLimit} 步`;
    localStorage.historyDepth = historyLimit;
    tabs.forEach(trimUndoHistory);
    editor.setOption('undoDepth', historyLimit);
    updateHistoryControls();
    if (document.getElementById('history-dialog').open) renderHistoryList();
  };
  window.addEventListener('resize', scheduleDragRegionUpdate);
  document.getElementById('tabs-list').addEventListener('scroll', scheduleDragRegionUpdate);
  new MutationObserver(scheduleDragRegionUpdate).observe(document.querySelector('.topbar'), { childList: true, subtree: true });
  document.querySelectorAll('dialog').forEach(dialog => {
    new MutationObserver(scheduleDragRegionUpdate).observe(dialog, { attributes: true, attributeFilter: ['open'] });
  });
  document.getElementById('liquid-glass').onchange = event => {
    const enabled = event.target.checked;
    document.body.classList.toggle('liquid-glass', enabled);
    localStorage.liquidGlass = enabled;
    sendNativeMessage('liquidGlass', { enabled });
  };
  function agentConsoleSetupText() {
    const quoted = `'${agentConsoleHelperPath.replace(/'/g, `'\\''`)}'`;
    const platform = document.getElementById('agent-console-platform').value;
    if (!agentConsoleHelperPath) return '请先启用 Agent 控制台';
    if (platform === 'codex') return `codex mcp add dot-md -- ${quoted} mcp`;
    if (platform === 'claude') return `claude mcp add dot-md --scope user -- ${quoted} mcp`;
    if (platform === 'cursor') return JSON.stringify({mcpServers:{'dot-md':{command:agentConsoleHelperPath,args:['mcp']}}}, null, 2);
    if (platform === 'opencode') return JSON.stringify({mcp:{'dot-md':{type:'local',command:[agentConsoleHelperPath,'mcp'],enabled:true}}}, null, 2);
    return `${quoted} mcp`;
  }
  function refreshAgentConsoleSetup() {
    document.getElementById('agent-console-command').textContent = agentConsoleSetupText();
    document.getElementById('agent-console-cli-help').textContent = agentConsoleHelperPath
      ? `${agentConsoleHelperPath} status\nprintf '# 新内容' | ${agentConsoleHelperPath} replace`
      : 'dotmd-agent status';
  }
  document.getElementById('agent-console-enabled').onchange = () => sendNativeMessage('agentConsole', {
    enabled: document.getElementById('agent-console-enabled').checked,
    access: document.getElementById('agent-console-access').value
  });
  document.getElementById('agent-console-access').onchange = () => sendNativeMessage('agentConsole', {
    enabled: document.getElementById('agent-console-enabled').checked,
    access: document.getElementById('agent-console-access').value
  });
  document.getElementById('agent-console-platform').onchange = refreshAgentConsoleSetup;
  document.getElementById('copy-agent-console-command').onclick = () => {
    sendNativeMessage('copyText', { text: agentConsoleSetupText() });
  };
  document.addEventListener('keydown', event => {
    if (event.ctrlKey && event.key === 'Tab') {
      event.preventDefault(); cycleTab(event.shiftKey ? -1 : 1); return;
    }
    if (event.metaKey && !event.shiftKey && !event.altKey && /^[1-9]$/.test(event.key)) {
      const id = documentTabOrder[Number(event.key) - 1];
      if (id) { event.preventDefault(); switchTab(id); }
    }
  });

  function restoreSettings() {
    if (localStorage.editorSize) {
      const fontSizeControl = document.getElementById('font-size');
      fontSizeControl.value = localStorage.editorSize;
      fontSizeControl.oninput({ target: fontSizeControl });
    }
    if (localStorage.readingWidth) {
      const readingWidthControl = document.getElementById('reading-width');
      readingWidthControl.value = localStorage.readingWidth;
      readingWidthControl.oninput({ target: readingWidthControl });
    }
    if (localStorage.lineNumbers) {
      const lineNumbersControl = document.getElementById('line-numbers');
      lineNumbersControl.checked = localStorage.lineNumbers === 'true';
      lineNumbersControl.onchange({ target: lineNumbersControl });
    }
    if (localStorage.syncScroll) {
      document.getElementById('sync-scroll').checked = localStorage.syncScroll === 'true';
    }
    const historyDepthControl = document.getElementById('history-depth');
    historyDepthControl.value = String(historyLimit);
    historyDepthControl.oninput({ target: historyDepthControl });
    if (localStorage.liquidGlass) {
      const liquidGlassControl = document.getElementById('liquid-glass');
      liquidGlassControl.checked = localStorage.liquidGlass === 'true';
      liquidGlassControl.onchange({ target: liquidGlassControl });
    } else {
      sendNativeMessage('liquidGlass', { enabled:false });
    }
  }

  window.dotmd = {
    addDocument,
    addDocuments,
    removeTab,
    activateTab(id) { switchTab(id); },
    cycleTab,
    markSaved(id, title) { const tab=tabs.get(id); if (!tab) return; tab.title=title; tab.dirty=false; renderTabs(); },
    replaceDocumentFromAgent(id, text) { if(tabs.has(id)) switchTab(id); editor.setValue(text); editor.focus(); },
    configureAgentConsole(configuration) {
      agentConsoleHelperPath = configuration.helperPath || '';
      document.getElementById('agent-console-enabled').checked = !!configuration.enabled;
      document.getElementById('agent-console-access').value = configuration.access === 'edit' ? 'edit' : 'read';
      refreshAgentConsoleSetup();
    },
    configureAgents(profiles) { agentProfiles=profiles; renderAgentProfiles(); refreshWorkflowEditor(); window.dotmdDocx.updateAgents(); },
    setAgentBusy(value) { document.getElementById('agent-dialog').classList.toggle('busy',value); document.getElementById('search-dialog').classList.toggle('busy',value); document.getElementById('agent-run').textContent=value?'Agent 运行中…':'运行 Agent'; },
    setWorkflowPlanning(value) { document.getElementById('workflow-generate').disabled=value; document.getElementById('workflow-generate').textContent=value?'设计中…':'✦ Agent 设计流程'; if(!value) renderWorkflowPlanner(); },
    showWorkflowProposal,
    showWorkflowResults,
    showAgentResults,
    showToast,
    openDocxTools() { window.dotmdDocx.open(); },
    showDocxAgentSuggestion(text, error) { window.dotmdDocx.receiveAgent(text, error); },
    docxExported() { window.dotmdDocx.exported(); },
    openAgentTools,
    openFormulaTools,
    openSearchTools,
    clearSelection,
    copySelection,
    insertClipboardText,
    stepHistory,
    openHistoryTools,
    setContent(text) { suppressChanges = true; editor.setValue(text); editor.clearHistory(); editor.setCursor(0,0); renderMarkdownPreview(); suppressChanges = false; },
    getContent() { return editor.getValue(); },
    setMode,
    toggleOutline,
    openSettings() { document.getElementById('settings-dialog').showModal(); },
    preparePrint() { renderMarkdownPreview(); document.body.classList.add('printing'); },
    finishPrint() { document.body.classList.remove('printing'); },
    exportHTML() {
      renderMarkdownPreview();
      const css = [...document.styleSheets].map(sheet => { try { return [...sheet.cssRules].map(rule => rule.cssText).join('\n'); } catch (_) { return ''; } }).join('\n');
      return `<!doctype html><html><head><meta charset="utf-8"><title>Markdown 文稿</title><style>${css}</style></head><body><article class="markdown-body">${preview.innerHTML}</article></body></html>`;
    }
  };

  window.dotmdDocx.bind({
    getID: () => activeDocumentID,
    getTitle: () => tabs.get(activeDocumentID)?.title || '未命名.md',
    getArticle: () => { renderMarkdownPreview(); return preview; },
    getAgents: () => agentProfiles,
    post: sendNativeMessage,
    showToast
  });

  restoreSettings();
  document.querySelectorAll('#settings-dialog input[type="range"]').forEach(updateRangeProgress);
  editor.setValue(initial);
  const initialID = `welcome-${Date.now()}`;
  activeDocumentID = initialID;
  tabs.set(initialID, { id: initialID, title: '欢迎.md', doc: editor.getDoc(), dirty: false, editorScroll: 0, previewScroll: 0,
    timeline: [createHistoryEntry('初始状态', initial, { line: 0, ch: 0 })], timelineIndex: 0 });
  documentTabOrder.push(initialID);
  renderTabs();
  renderMarkdownPreview();
  sendNativeMessage('ready', { id: initialID, title: '欢迎.md', content: initial });
  suppressChanges = false;
})();
