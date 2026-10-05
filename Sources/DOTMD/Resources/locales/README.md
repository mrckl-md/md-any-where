# Interface message catalogs

These flat JSON files are the source of truth for the offline interface and native alerts. `en.json` and `zh-Hans.json` are the source catalogs; other catalogs use Apple's App Store locale shortcodes. Regional English variants share the English source unless a regional catalog supplies overrides. `../i18n-sources.json` lists the front-end call sites.

The additional UI locales began as machine translations obtained through the Google Translate website using user-authorized application copy with email addresses and URLs removed before sending. Protected text was restored locally. Placeholder and coverage checks, plus targeted AI review of core actions and consent, have been performed; full native-speaker proofreading has not been completed. Spanish (Spain/Mexico) currently shares neutral Spanish wording, and regional English variants share English. This statement concerns UI catalogs; App Store metadata has a separate translation record.

The initial `web.<hash>` keys use the first ten SHA-256 hex characters of the original Chinese source message, which deduplicates identical labels without touching document data. Keep existing IDs stable when improving translations. Native messages use descriptive `native.*` keys.

Preserve all `{p0}`, `{p1}`, `{error}`, and numbered `{0}` placeholders. Other braces can be literal JSON, LaTeX, or Mermaid syntax. Preserve Markdown fences, math source, diagram grammar, protocol commands, product names, email addresses, and URLs. Translate only labels and explanatory prose within examples.

`../catalogs.js` is the generated browser bundle of these JSON files. Packaging and WebKit test scripts run `scripts/bundle-editor-localizations.py` to regenerate the bundle from the latest catalogs; regenerate the source bundle as well when preparing a release or previewing the resource directory directly. It loads before `../i18n.js`, without fetching resources or changing the app's `connect-src 'none'` policy. Native code reads the JSON directly. The app never contacts a translation service.

Use `DotMDI18n.t(key, args)` for messages and `bindText` / `bindAttribute` for labels that must update when the user switches languages. Use `data-i18n` and `data-i18n-title`, `data-i18n-aria-label`, or `data-i18n-placeholder` in HTML. Only built-in Agent option instructions use `data-i18n-value`; never attach it to user-entered text. Existing document text, names, undo history, model IDs, endpoints, and saved workflows must remain unchanged when language changes.

The shared preference is `dotmd.interfaceLanguage`. Values are `system` or an App Store language code. Native startup injects `window.dotmdLocalePreferences`; subsequent native changes call `window.setInterfaceLanguage(language, systemLanguages)` without an echo message. User selection sends `changeInterfaceLanguage {language}`. RTL applies to the interface; Markdown preview follows its own content and code/math remains LTR.
