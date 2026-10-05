/* Loaded by the iPhone/iPad host, after app.js. Keep the shared editor bridge intact. */
(() => {
  'use strict';
  const t = (key, args) => (globalThis.DotMDI18n || (typeof require === 'function' ? require('./i18n.js') : null))?.t(key, args) ?? key;
  const bindText = (element, render) => globalThis.DotMDI18n.bindText(element, render);
  const bindAttribute = (element, attribute, render) => globalThis.DotMDI18n.bindAttribute(element, attribute, render);


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
    bindText(button, label);
    bindAttribute(button, 'aria-label', accessibleLabel);
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
  bindText(menuTitle, () => t("web.f569701965"));
  const menuClose = createButton('×', () => fileMenu.close(), t("web.44f7556e75"));
  menuClose.className = 'icon-close';
  menuHeader.append(menuTitle, menuClose);
  const menuActions = document.createElement('div');
  menuActions.className = 'ipad-menu-actions';
  const menuItems = [
    [t("web.748571e33e"), () => sendNativeMessage('new')],
    [t("web.b7e867ed8c"), () => sendNativeMessage('open')],
    [t("web.a3030bf8f1"), () => sendNativeMessage('save')],
    [t("web.9016c46397"), () => sendNativeMessage('saveAs')],
    [t("web.f0600a0531"), () => window.dotmd.openDocxTools()],
    [t("web.9ec4c7bf99"), () => sendNativeMessage('exportPDF')],
    [t("web.663f6864e5"), () => sendNativeMessage('exportHTML')],
    [t("web.69311783ce"), () => sendNativeMessage('share')],
    [t("web.e15ea19da5"), () => window.dotmd.openSettings()]
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
  bindAttribute(fileTools, 'aria-label', () => t("web.606b4b2701"));
  const fileButton = createButton(t("web.271f734980"), () => fileMenu.showModal(), t("web.5254a5ca7c"));
  fileButton.setAttribute('aria-haspopup', 'dialog');
  fileButton.setAttribute('aria-controls', fileMenu.id);
  fileTools.append(fileButton, createButton(t("web.a3030bf8f1"), () => sendNativeMessage('save'), t("web.a70e86e337")));
  const formatToggle = createButton(t("web.0e8b1c78c5"), () => {
    const isOpen = document.body.classList.toggle('mobile-format-open');
    formatToggle.setAttribute('aria-expanded', String(isOpen));
    editor.refresh();
  }, t("web.100d547ad4"));
  formatToggle.id = 'mobile-format-toggle';
  formatToggle.setAttribute('aria-expanded', 'false');
  const formatTools = document.querySelector('.format-tools');
  formatTools.id = 'mobile-format-tools';
  bindAttribute(formatTools, 'aria-label', () => t("web.2bcdacfac9"));
  formatTools.tabIndex = 0;
  formatToggle.setAttribute('aria-controls', formatTools.id);
  fileTools.append(formatToggle);
  topbar.insertBefore(fileTools, document.querySelector('.format-tools'));
  const viewLabels = { editor: t("web.0518365699"), split: t("web.e02531a7e0"), preview: t("web.13d61fea9f") };
  document.querySelectorAll('[data-mode]').forEach(button => {
    bindText(button, viewLabels[button.dataset.mode] || button.textContent);
  });

  const hideKeyboard = createButton(t("web.d826c4ece4"), () => {
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
      bindAttribute(close, 'aria-label', () => t("web.780bce343c", { p0: tab.querySelector('.tab-title')?.textContent || t("web.f569701965") }));
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
  document.querySelector('[data-privacy-console]')?.setAttribute('hidden', '');
  function adaptAgentProfiles() {
    document.querySelectorAll('#agent-profiles input:not([type="checkbox"])').forEach(input => {
      input.autocapitalize = 'none';
      input.setAttribute('autocorrect', 'off');
      input.spellcheck = false;
    });
  }
  new MutationObserver(adaptAgentProfiles).observe(document.getElementById('agent-profiles'), { childList: true });
  adaptAgentProfiles();

  editor.setOption('autofocus', false);
  bindAttribute(editor.getInputField(), 'aria-label', () => t("web.2bcb89b816"));
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
