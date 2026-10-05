#!/usr/bin/env node
'use strict';

// Check shipped translation resources, not just the number of language names in a menu.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const read = file => JSON.parse(fs.readFileSync(path.join(root, file), 'utf8'));
const manifest = read('Docs/AppStore/localizations/manifest.json');
const source = read('Sources/DOTMD/Resources/locales/en.json');
const chinese = read('Sources/DOTMD/Resources/locales/zh-Hans.json');
const failures = [];
const check = (condition, message) => { if (!condition) failures.push(message); };
const keys = Object.keys(source).sort();
const placeholders = value => [...value.matchAll(/\{([A-Za-z_][\w]*|\d+)\}/g)].map(match => match[1]).sort();
const codes = manifest.locales.map(entry => entry.app_store_locale);
check(codes.length === 50 && new Set(codes).size === 50, 'Expected the 50 verified Apple metadata locales without duplicates');
check(JSON.stringify(keys) === JSON.stringify(Object.keys(chinese).sort()), 'English and Simplified Chinese catalogs have different keys');

const checked = new Set();
for (const entry of manifest.locales) {
  const code = entry.ui_catalog_locale;
  if (!checked.has(code)) {
    checked.add(code);
    const relative = `Sources/DOTMD/Resources/locales/${code}.json`;
    if (!fs.existsSync(path.join(root, relative))) { failures.push(`${code}: missing catalog`); continue; }
    const catalog = read(relative);
    check(JSON.stringify(Object.keys(catalog).sort()) === JSON.stringify(keys), `${code}: catalog key coverage differs from English`);
    for (const key of keys) {
      const value = catalog[key];
      check(typeof value === 'string' && value.trim().length > 0, `${code}/${key}: empty or missing translation`);
      if (typeof value !== 'string') continue;
      check(JSON.stringify(placeholders(value)) === JSON.stringify(placeholders(source[key])), `${code}/${key}: changed interpolation parameters`);
      check(!/MDI\d{4}|MDIBATCH|MDP\d{3}/.test(value), `${code}/${key}: translation transport marker was not removed`);
      check(!value.includes('\ufffd'), `${code}/${key}: invalid Unicode replacement character`);
    }
    // Technical tokens may legitimately match English; an entire copied catalog may not.
    if (!code.startsWith('en')) {
      const changed = keys.filter(key => catalog[key] !== source[key]).length;
      check(changed > keys.length / 2, `${code}: most messages are untranslated English`);
    }
  }
  const metadataPath = path.join('Docs/AppStore/localizations', entry.metadata_file);
  if (!fs.existsSync(path.join(root, metadataPath))) { failures.push(`${entry.app_store_locale}: missing store metadata`); continue; }
  const metadata = read(metadataPath);
  for (const [field, max] of Object.entries({name:30, subtitle:30, promotional_text:170, keywords:100, description:4000})) {
    const value = metadata[field];
    check(typeof value === 'string' && value.trim(), `${entry.app_store_locale}: missing ${field}`);
    check(typeof value === 'string' && [...value].length <= max, `${entry.app_store_locale}: ${field} exceeds ${max} characters`);
  }
  check(metadata.name === 'md any where', `${entry.app_store_locale}: brand name must stay unchanged`);
}

if (failures.length) {
  failures.forEach(message => console.error(`FAIL: ${message}`));
  process.exit(1);
}
assert(keys.length > 400, 'Catalog unexpectedly small; verify native and web messages are included');
console.log(`Localization resources passed: ${codes.length} store locales, ${checked.size} offline catalogs, ${keys.length} messages per catalog.`);
