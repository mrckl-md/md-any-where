/* UI messages use stable web.<SHA256(source)[0:10]> IDs. Never translate document data.
 * Catalog JSON is the source of truth; catalogs.js is its offline browser bundle.
 */
(function (root) {
  'use strict';
  const codes = ['ar-SA','bn-BD','ca','zh-Hans','zh-Hant','hr','cs','da','nl-NL','en-AU','en-CA','en-GB','en-US','fi','fr-FR','fr-CA','de-DE','el','gu-IN','he','hi','hu','id','it','ja','kn-IN','ko','ms','ml-IN','mr-IN','no','or-IN','pl','pt-BR','pt-PT','pa-IN','ro','ru','sk','sl-SI','es-MX','es-ES','sv','ta-IN','te-IN','th','tr','uk','ur-PK','vi'];
  const names = ['العربية','বাংলা','Català','简体中文','繁體中文','Hrvatski','Čeština','Dansk','Nederlands','English (Australia)','English (Canada)','English (UK)','English (US)','Suomi','Français (France)','Français (Canada)','Deutsch','Ελληνικά','ગુજરાતી','עברית','हिन्दी','Magyar','Bahasa Indonesia','Italiano','日本語','ಕನ್ನಡ','한국어','Bahasa Melayu','മലയാളം','मराठी','Norsk','ଓଡ଼ିଆ','Polski','Português (Brasil)','Português (Portugal)','ਪੰਜਾਬੀ','Română','Русский','Slovenčina','Slovenščina','Español (México)','Español (España)','Svenska','தமிழ்','తెలుగు','ไทย','Türkçe','Українська','اردو','Tiếng Việt'];
  const catalogs = root.MDAnyWhereLocaleCatalogs || (typeof module === 'object' && module.exports ? {en:require('./locales/en.json'), 'zh-Hans':require('./locales/zh-Hans.json')} : {});
  const preferenceKey = 'mdanywhere.interfaceLanguage';
  const preferences = root.mdAnyWhereLocalePreferences || {};
  let systemLanguages = preferences.systemLanguages || root.navigator?.languages || ['en-US'];
  let storedLanguage;
  try { storedLanguage = root.localStorage?.getItem(preferenceKey); } catch (_) {}
  let language = preferences.language || storedLanguage || 'system';
  const baseAliases = {ar:'ar-SA',bn:'bn-BD',nl:'nl-NL',de:'de-DE',gu:'gu-IN',kn:'kn-IN',ml:'ml-IN',mr:'mr-IN',or:'or-IN',pa:'pa-IN',sl:'sl-SI',ta:'ta-IN',te:'te-IN',ur:'ur-PK',nb:'no',nn:'no',iw:'he',in:'id'};
  function matchLocale(value) {
    if (!value || typeof value !== 'string') return null;
    const code = value.replaceAll('_', '-').toLowerCase();
    const exact = codes.find(item => item.toLowerCase() === code);
    if (exact) return exact;
    const parts = code.split('-'), base = parts[0];
    if (base === 'zh') {
      if (parts.includes('hans')) return 'zh-Hans';
      if (parts.includes('hant')) return 'zh-Hant';
      return parts.some(item => ['tw','hk','mo'].includes(item)) ? 'zh-Hant' : 'zh-Hans';
    }
    if (base === 'en') {
      if (parts.includes('au')) return 'en-AU';
      if (parts.includes('ca')) return 'en-CA';
      if (parts.includes('gb') || parts.includes('nz')) return 'en-GB';
      return 'en-US';
    }
    if (base === 'pt') return parts.includes('br') ? 'pt-BR' : 'pt-PT';
    if (base === 'es') return parts.length === 1 || parts.slice(1).includes('es') ? 'es-ES' : 'es-MX';
    if (base === 'fr') return parts.includes('ca') ? 'fr-CA' : 'fr-FR';
    return baseAliases[base] || codes.find(item => item.toLowerCase().split('-')[0] === base) || null;
  }
  function resolveLocale(value) {
    const values = value === 'system' || value == null ? systemLanguages : (Array.isArray(value) ? value : [value]);
    for (const candidate of values) { const matched = matchLocale(candidate); if (matched) return matched; }
    return 'en-US';
  }
  if (language !== 'system') language = matchLocale(language) || 'en-US';
  let locale = resolveLocale(language);
  let numberFormatter;
  const bindings = new Set();
  const elementBindings = new WeakMap();
  // Only explicitly bound application labels are retranslated. User text is never scanned.
  const renderedMessages = new Map();
  function lookup(key) { return catalogs[locale]?.[key] ?? (locale.startsWith('en-') ? catalogs.en?.[key] : undefined) ?? catalogs.en?.[key] ?? key; }
  function formatNumber(value, options) {
    if (!options) { numberFormatter ||= new Intl.NumberFormat(locale); return numberFormatter.format(value); }
    return new Intl.NumberFormat(locale, options).format(value);
  }
  function t(key, args = {}) {
    const message = lookup(key).replace(/\{([A-Za-z][\w]*|\d+)\}/g, (token, name) => {
      if (!Object.prototype.hasOwnProperty.call(args, name)) return token;
      const value = args[name];
      return typeof value === 'number' ? formatNumber(value) : String(value ?? '');
    });
    renderedMessages.set(message, {key, args});
    if (renderedMessages.size > 2048) renderedMessages.delete(renderedMessages.keys().next().value);
    return message;
  }
  function bind(element, attribute, render) {
    if (!element) return '';
    const remembered = typeof render === 'string' && renderedMessages.get(render);
    const renderText = typeof render === 'function' ? render : remembered ? () => t(remembered.key, remembered.args) : () => render;
    let records = elementBindings.get(element);
    if (!records) { records = new Map(); elementBindings.set(element, records); }
    let record = records.get(attribute);
    if (!record) { record = {element, attribute, render:renderText}; records.set(attribute, record); bindings.add(record); }
    else record.render = renderText;
    const value = String(renderText() ?? '');
    record.lastValue = value;
    if (attribute === 'textContent') element.textContent = value;
    else element.setAttribute(attribute, value);
    if (bindings.size > 2048) {
      for (const existing of bindings) if (!existing.element.isConnected && existing.element !== element) {
        bindings.delete(existing); elementBindings.get(existing.element)?.delete(existing.attribute);
      }
    }
    return value;
  }
  function apply(container = root.document) {
    if (!container?.querySelectorAll) return;
    for (const element of container.querySelectorAll('[data-i18n], [data-i18n-title], [data-i18n-aria-label], [data-i18n-placeholder], [data-i18n-value]')) {
      if (element.dataset.i18n) element.textContent = t(element.dataset.i18n);
      for (const attr of ['title','aria-label','placeholder','value']) {
        const key = element.getAttribute('data-i18n-' + attr);
        if (key) element.setAttribute(attr, t(key));
      }
    }
  }
  function refresh() {
    const document = root.document;
    if (!document) return;
    document.documentElement.lang = locale;
    document.documentElement.dir = /^(ar|he|ur)(-|$)/.test(locale) ? 'rtl' : 'ltr';
    apply(document);
    for (const record of bindings) {
      const currentValue = record.attribute === 'textContent' ? record.element.textContent : record.element.getAttribute(record.attribute);
      const wasReplaced = currentValue !== record.lastValue || (record.attribute === 'textContent' && record.element.children.length > 0);
      if (!record.element.isConnected || wasReplaced) {
        bindings.delete(record);
        elementBindings.get(record.element)?.delete(record.attribute);
        continue;
      }
      bind(record.element, record.attribute, record.render);
    }
    const select = document.getElementById('interface-language');
    if (select) {
      if (!select.options.length) {
        select.add(new Option('', 'system'));
        codes.forEach((code, index) => select.add(new Option(names[index], code)));
        select.addEventListener('change', () => setLanguage(select.value, {notify:true}));
      }
      select.setAttribute('aria-label', t('language.label'));
      select.options[0].textContent = t('language.system');
      select.value = language;
    }
  }
  function setLanguage(value, options = {}) {
    language = value === 'system' ? 'system' : matchLocale(value) || 'en-US';
    locale = resolveLocale(language);
    numberFormatter = null;
    try { root.localStorage?.setItem(preferenceKey, language); } catch (_) {}
    refresh();
    root.dispatchEvent?.(new CustomEvent('mdanywherelanguagechange', {detail:{language,locale}}));
    if (options.notify) root.webkit?.messageHandlers?.editor?.postMessage({type:'changeInterfaceLanguage',language});
    return locale;
  }
  const api = {t, resolveLocale, setLanguage, apply, formatNumber,
    formatDate:(value, options) => new Intl.DateTimeFormat(locale, options).format(new Date(value)),
    list:values => new Intl.ListFormat(locale, {style:'long',type:'conjunction'}).format(values),
    setSystemLanguages(values) { systemLanguages = Array.isArray(values) && values.length ? values : ['en-US']; if (language === 'system') setLanguage('system'); },
    describeMessage:value => renderedMessages.get(value),
    bindText:(element, render) => bind(element, 'textContent', render),
    bindAttribute:(element, attribute, render) => bind(element, attribute, render),
    languages:codes.map((code,index)=>({code,name:names[index]})),
    get locale() { return locale; }, get language() { return language; }
  };
  root.MDAnyWhereI18n = api;
  root.setInterfaceLanguage = (value, languages) => { if (Array.isArray(languages) && languages.length) systemLanguages = languages; return setLanguage(value); };
  if (typeof module === 'object' && module.exports) module.exports = api;
  root.addEventListener?.('languagechange', () => api.setSystemLanguages(root.navigator?.languages || ['en-US']));
  if (root.document) refresh();
})(typeof window === 'object' ? window : globalThis);
