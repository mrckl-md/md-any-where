#!/usr/bin/env node
'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const resources = path.resolve(__dirname, '../Sources/MDAnyWhere/Resources');
const source = fs.readFileSync(path.join(resources, 'i18n.js'), 'utf8');
const catalog = code => JSON.parse(fs.readFileSync(path.join(resources, 'locales', `${code}.json`), 'utf8'));

function createRuntime({stored, native, languages = ['en-US'], failStorage = false} = {}) {
  const storage = new Map(stored ? [['mdanywhere.interfaceLanguage', stored]] : []);
  const messages = [];
  const context = {
    Intl, console, navigator:{languages},
    MDAnyWhereLocaleCatalogs:{en:catalog('en'), 'zh-Hans':catalog('zh-Hans')},
    mdAnyWhereLocalePreferences:native,
    localStorage:{
      getItem(key) { if (failStorage) throw Error('unavailable'); return storage.get(key); },
      setItem(key,value) { if (failStorage) throw Error('unavailable'); storage.set(key,value); }
    },
    webkit:{messageHandlers:{editor:{postMessage:value=>messages.push(value)}}}
  };
  vm.createContext(context);
  vm.runInContext(source, context);
  return {api:context.MDAnyWhereI18n, context, storage, messages};
}

const r = createRuntime({languages:['xx-YY','zh-Hant-HK']});
assert.equal(r.api.locale, 'zh-Hant');
for (const [input, expected] of Object.entries({
  'zh-TW':'zh-Hant','zh-HK':'zh-Hant','zh-MO':'zh-Hant','zh-Hans-HK':'zh-Hans',
  'zh-Hant-CN':'zh-Hant','zh-CN':'zh-Hans','en-Latn-AU':'en-AU','en-Latn-GB':'en-GB',
  'en-Latn-CA':'en-CA','en-NZ':'en-GB','es-419':'es-MX','es-AR':'es-MX',
  'es-Latn-ES':'es-ES','es-Latn-MX':'es-MX',
  'pt-AO':'pt-PT','pt-BR':'pt-BR','fr-BE':'fr-FR','fr-CA':'fr-CA',
  'nb-NO':'no','nn-NO':'no','iw-IL':'he','in-ID':'id','ar-EG':'ar-SA',
  'ur-IN':'ur-PK','bn-IN':'bn-BD','unknown':'en-US'
})) assert.equal(r.api.resolveLocale(input), expected, input);
for (const {code} of r.api.languages) assert.equal(r.api.resolveLocale(code), code);
assert.equal(r.api.languages.length, 50);
const officialLocales = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../Support/Localization/locales.json'), 'utf8'));
const storeLocales = JSON.parse(fs.readFileSync(path.resolve(__dirname, '../Docs/AppStore/localizations/manifest.json'), 'utf8')).locales.map(item => item.app_store_locale);
assert.deepEqual(Array.from(r.api.languages, item => item.code).sort(), [...officialLocales].sort(), 'Runtime and native languages must match');
assert.deepEqual([...storeLocales].sort(), [...officialLocales].sort(), 'Store metadata must cover every supported locale');
assert.equal(r.api.resolveLocale(['xx','ja-JP','en-US']), 'ja');
assert.equal(createRuntime({stored:'ja',languages:['zh-CN']}).api.locale, 'ja');
assert.equal(createRuntime({stored:'ja',native:{language:'system',systemLanguages:['de-DE']}}).api.locale, 'de-DE');
assert.equal(createRuntime({stored:'../../secret',languages:['zh-CN']}).api.locale, 'en-US');
assert.equal(createRuntime({failStorage:true,languages:['ja']}).api.locale, 'ja');

r.api.setLanguage('zh-Hans', {notify:true});
assert.equal(r.storage.get('mdanywhere.interfaceLanguage'), 'zh-Hans');
assert.equal(r.messages.length, 1);
assert.equal(r.messages[0].type, 'changeInterfaceLanguage');
r.context.setInterfaceLanguage('system', ['de-DE']);
assert.equal(r.messages.length, 1, 'Native synchronization must not echo back');
assert.equal(r.api.locale, 'de-DE');
r.api.setSystemLanguages(['fr-CA']);
assert.equal(r.api.locale, 'fr-CA', 'System language follows updated OS preferences');
r.api.setLanguage('ja'); r.api.setSystemLanguages(['zh-Hans']);
assert.equal(r.api.locale, 'ja', 'Explicit selection must survive OS language changes');
r.api.setLanguage('en-US');
assert.equal(r.api.t('error.preview',{error:'<img src=x> {p0}'}), catalog('en')['error.preview'].replace('{error}','<img src=x> {p0}'));
assert.equal(r.api.t('not.a.real.key'), 'not.a.real.key');
assert.equal(r.api.formatNumber(12345), new Intl.NumberFormat('en-US').format(12345));
r.api.setLanguage('ar-SA');
assert.equal(r.api.formatNumber(12345), new Intl.NumberFormat('ar-SA').format(12345));
assert.equal(r.api.formatDate('2026-10-05T12:00:00Z', {year:'numeric',timeZone:'UTC'}), new Intl.DateTimeFormat('ar-SA',{year:'numeric',timeZone:'UTC'}).format(new Date('2026-10-05T12:00:00Z')));
console.log('Locale runtime passed: 50 exact locales, regional/script aliases, preference priority, unavailable storage, native bridge and formatting.');
