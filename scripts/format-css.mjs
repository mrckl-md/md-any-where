#!/usr/bin/env node
// Dependency-free formatter for DOT MD's own CSS. It only changes whitespace
// outside quoted strings and preserves comments, parentheses and rule order.
import { readFileSync, writeFileSync } from 'node:fs';

const stylesheetPath = process.argv[2];
if (!stylesheetPath) throw new Error('Usage: node scripts/format-css.mjs <stylesheet.css>');

const stylesheetSource = readFileSync(stylesheetPath, 'utf8');
const formattedLines = [];
let currentSegment = '';
let nestingDepth = 0;
let parenthesisDepth = 0;
let quoteDelimiter = null;
let isInsideComment = false;

function writeBufferedLine(suffix = '') {
  const value = currentSegment.trim();
  if (value) formattedLines.push(`${'  '.repeat(nestingDepth)}${value}${suffix}`);
  currentSegment = '';
}

function appendCSSCharacter(character) {
  if (/\s/.test(character) && !quoteDelimiter && !isInsideComment) {
    if (currentSegment && !/\s/.test(currentSegment.at(-1))) currentSegment += ' ';
  } else {
    currentSegment += character;
  }
}

for (let index = 0; index < stylesheetSource.length; index++) {
  const character = stylesheetSource[index];
  const next = stylesheetSource[index + 1];
  if (isInsideComment) {
    currentSegment += character;
    if (character === '*' && next === '/') {
      currentSegment += '/';
      index++;
      isInsideComment = false;
    }
    continue;
  }
  if (quoteDelimiter) {
    currentSegment += character;
    if (character === '\\' && next) currentSegment += stylesheetSource[++index];
    else if (character === quoteDelimiter) quoteDelimiter = null;
    continue;
  }
  if (character === '/' && next === '*') {
    currentSegment += '/*';
    index++;
    isInsideComment = true;
  } else if (character === '"' || character === "'") {
    quoteDelimiter = character;
    currentSegment += character;
  } else if (character === '(') {
    parenthesisDepth++;
    currentSegment += character;
  } else if (character === ')') {
    parenthesisDepth--;
    currentSegment += character;
  } else if (parenthesisDepth === 0 && character === '{') {
    writeBufferedLine(' {');
    nestingDepth++;
  } else if (parenthesisDepth === 0 && character === ';') {
    writeBufferedLine(';');
  } else if (parenthesisDepth === 0 && character === '}') {
    writeBufferedLine();
    nestingDepth--;
    formattedLines.push(`${'  '.repeat(nestingDepth)}}`);
  } else {
    appendCSSCharacter(character);
  }
}
writeBufferedLine();
if (quoteDelimiter || isInsideComment || parenthesisDepth || nestingDepth) throw new Error('Stylesheet has unbalanced syntax');
writeFileSync(stylesheetPath, `${formattedLines.join('\n')}\n`);
