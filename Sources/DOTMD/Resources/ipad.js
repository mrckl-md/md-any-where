/* Loaded by the iPhone/iPad host, after app.js. Keep the shared editor bridge intact. */
(() => {
  'use strict';

  const editor = document.querySelector('.CodeMirror')?.CodeMirror;
  if (!editor || !window.dotmd) return;

  document.documentElement.classList.add('ipad-app');
  document.body.classList.add('ipad-app');
  document.querySelector('meta[name="viewport"]')?.setAttribute('content',
    'width=device-width, initial-scale=1, viewport-fit=cover');

  const workspace = document.getElementById('workspace');
  const topbar = document.querySelector('.topbar');
  const outlineToggle = document.getElementById('outline-toggle');
  const nativeBridge = window.webkit?.messageHandlers?.editor;

  function sendNativeMessage(type) {
    nativeBridge?.postMessage({ type });
  }

  function createButton(label, action, accessibleLabel = label) {
    const button = document.createElement('button');
    button.type = 'button';
    button.textContent = label;
    button.setAttribute('aria-label', accessibleLabel);
    button.addEventListener('click', action);
    return button;
  }

  // macOS provides these actions in its menu bar; iOS needs visible touch controls.
  const fileMenu = document.createElement('dialog');
  fileMenu.id = 'ipad-file-menu';
  fileMenu.setAttribute('aria-labelledby', 'ipad-file-menu-title');
  const menuHeader = document.createElement('div');
  menuHeader.className = 'dialog-title';
  const menuTitle = document.createElement('h2');
  menuTitle.id = 'ipad-file-menu-title';
  menuTitle.textContent = '文稿';
  const menuClose = createButton('×', () => fileMenu.close(), '关闭文稿菜单');
  menuClose.className = 'icon-close';
  menuHeader.append(menuTitle, menuClose);
  const menuActions = document.createElement('div');
  menuActions.className = 'ipad-menu-actions';
  const menuItems = [
    ['新建文稿', () => sendNativeMessage('new')],
    ['打开文稿…', () => sendNativeMessage('open')],
    ['保存', () => sendNativeMessage('save')],
    ['另存为…', () => sendNativeMessage('saveAs')],
    ['导出 Word / WPS…', () => window.dotmd.openDocxTools()],
    ['导出 PDF…', () => sendNativeMessage('exportPDF')],
    ['导出 HTML…', () => sendNativeMessage('exportHTML')],
    ['分享 Markdown…', () => sendNativeMessage('share')],
    ['设置与 Agent…', () => window.dotmd.openSettings()]
  ];
  menuItems.forEach(([label, action]) => {
    menuActions.append(createButton(label, () => {
      fileMenu.close();
      action();
    }));
  });
  fileMenu.append(menuHeader, menuActions);
  document.body.append(fileMenu);

  const fileTools = document.createElement('nav');
  fileTools.className = 'ipad-file-tools';
  fileTools.setAttribute('aria-label', '文稿操作');
  const fileButton = createButton('文稿 ▾', () => fileMenu.showModal(), '打开文稿菜单');
  fileButton.setAttribute('aria-haspopup', 'dialog');
  fileButton.setAttribute('aria-controls', fileMenu.id);
  fileTools.append(fileButton, createButton('保存', () => sendNativeMessage('save'), '保存当前文稿'));
  const formatToggle = createButton('格式', () => {
    const isOpen = document.body.classList.toggle('mobile-format-open');
    formatToggle.setAttribute('aria-expanded', String(isOpen));
    editor.refresh();
  }, '展开或收起格式工具栏');
  formatToggle.id = 'mobile-format-toggle';
  formatToggle.setAttribute('aria-expanded', 'false');
  const formatTools = document.querySelector('.format-tools');
  formatTools.id = 'mobile-format-tools';
  formatTools.setAttribute('aria-label', '格式工具栏，可左右滑动');
  formatTools.tabIndex = 0;
  formatToggle.setAttribute('aria-controls', formatTools.id);
  fileTools.append(formatToggle);
  topbar.insertBefore(fileTools, document.querySelector('.format-tools'));
  const viewLabels = { editor: '编辑', split: '分栏', preview: '预览' };
  document.querySelectorAll('[data-mode]').forEach(button => {
    button.textContent = viewLabels[button.dataset.mode] || button.textContent;
  });

  const hideKeyboard = createButton('收起键盘', () => {
    document.activeElement?.blur();
    editor.getInputField().blur();
  });
  hideKeyboard.id = 'ipad-hide-keyboard';
  document.querySelector('.statusbar').append(hideKeyboard);

  // Preserve the insertion point and keyboard while applying formatting with a tap.
  topbar.addEventListener('pointerdown', event => {
    if (event.pointerType !== 'mouse' && event.target.closest('[data-command], #undo-action, #redo-action')) {
      event.preventDefault();
    }
  });
  hideKeyboard.addEventListener('pointerdown', event => event.preventDefault());

  function updateOutlineAccessibility() {
    const isOpen = workspace.classList.contains('outline-open');
    outlineToggle.setAttribute('aria-expanded', String(isOpen));
    outlineToggle.setAttribute('aria-controls', 'outline');
    document.getElementById('outline').setAttribute('aria-hidden', String(!isOpen));
  }
  workspace.classList.remove('outline-open');
  new MutationObserver(updateOutlineAccessibility).observe(workspace, { attributes: true, attributeFilter: ['class'] });
  updateOutlineAccessibility();
  document.getElementById('outline-list').addEventListener('click', event => {
    if (event.target.closest('.outline-item')) {
      workspace.classList.remove('outline-open');
      editor.refresh();
    }
  });
  workspace.addEventListener('pointerdown', event => {
    if (workspace.classList.contains('outline-open') && !event.target.closest('#outline')) {
      workspace.classList.remove('outline-open');
    }
  });

  const tabList = document.getElementById('tabs-list');
  tabList.setAttribute('role', 'tablist');
  function adaptDocumentTabs() {
    tabList.querySelectorAll('.document-tab').forEach(tab => {
      tab.draggable = false;
      tab.setAttribute('role', 'tab');
      tab.setAttribute('aria-selected', String(tab.classList.contains('active')));
      tab.tabIndex = 0;
      const close = tab.querySelector('.tab-close');
      close?.setAttribute('aria-label', `关闭 ${tab.querySelector('.tab-title')?.textContent || '文稿'}`);
    });
  }
  new MutationObserver(adaptDocumentTabs).observe(tabList, { childList: true });
  adaptDocumentTabs();
  tabList.addEventListener('keydown', event => {
    if (event.target.matches('.document-tab') && ['Enter', ' '].includes(event.key)) {
      event.preventDefault();
      event.target.click();
    }
  });

  // The local macOS MCP console and window material controls do not exist on iOS.
  document.getElementById('settings-console-title')?.closest('.settings-section')?.setAttribute('hidden', '');
  document.getElementById('settings-appearance-title')?.closest('.settings-section')?.setAttribute('hidden', '');
  document.querySelectorAll('.settings-section-hint, .privacy-policy-content p, #agent-dialog .format-hint').forEach(element => {
    element.textContent = element.textContent.replaceAll('macOS 钥匙串', 'iOS 钥匙串')
      .replaceAll('不离开电脑', '在所配置的本地服务上处理')
      .replaceAll('，或关闭本机控制台', '');
  });
  document.querySelectorAll('.privacy-policy-content h3').forEach(heading => {
    if (heading.textContent === '本机控制台') {
      heading.nextElementSibling?.setAttribute('hidden', '');
      heading.hidden = true;
    }
  });
  function adaptAgentProfiles() {
    document.querySelectorAll('#agent-profiles .key').forEach(input => {
      input.placeholder = input.placeholder.replace('macOS 钥匙串', 'iOS 钥匙串');
    });
    document.querySelectorAll('#agent-profiles input:not([type="checkbox"])').forEach(input => {
      input.autocapitalize = 'none';
      input.setAttribute('autocorrect', 'off');
      input.spellcheck = false;
    });
  }
  new MutationObserver(adaptAgentProfiles).observe(document.getElementById('agent-profiles'), { childList: true });
  adaptAgentProfiles();

  editor.setOption('autofocus', false);
  editor.getInputField().setAttribute('aria-label', 'Markdown 编辑器');
  editor.getInputField().setAttribute('autocapitalize', 'off');
  editor.getInputField().setAttribute('autocorrect', 'off');
  editor.getInputField().setAttribute('spellcheck', 'false');
  // Opening a document should not immediately cover half the screen with a keyboard.
  editor.getInputField().blur();
  window.dotmd.setMode(window.innerWidth >= 1000 ? 'split' : 'editor');

  let viewportUpdate = null;
  let previousViewportHeight = null;
  let previousViewportWidth = null;
  function updateViewport() {
    if (viewportUpdate !== null) return;
    viewportUpdate = requestAnimationFrame(() => {
      viewportUpdate = null;
      const viewport = window.visualViewport;
      // Do not reflow the editor when the user magnifies the page with a pinch.
      const isMagnified = viewport && viewport.scale > 1.01;
      const height = Math.round(!isMagnified && viewport?.height || window.innerHeight);
      const width = window.innerWidth;
      document.documentElement.style.setProperty('--ipad-viewport-height', `${height}px`);
      document.documentElement.style.setProperty('--ipad-viewport-top', `${Math.round(viewport?.offsetTop || 0)}px`);
      document.body.classList.toggle('mobile-compact-height', height <= 360);
      if (height !== previousViewportHeight || width !== previousViewportWidth) {
        previousViewportHeight = height;
        previousViewportWidth = width;
        editor.refresh();
        if (editor.hasFocus()) editor.scrollIntoView(editor.getCursor(), 24);
        else if (document.activeElement?.closest('dialog[open]')) {
          document.activeElement.scrollIntoView({ block: 'nearest' });
        }
      }
    });
  }
  window.addEventListener('resize', updateViewport);
  window.visualViewport?.addEventListener('resize', updateViewport);
  window.visualViewport?.addEventListener('scroll', updateViewport);
  updateViewport();
})();
