// A bounded, anchored fuzzy match for one Markdown line. It returns the first
// acceptable match rather than comparing every substring in the entire line.
// The limit keeps an unusually long/minified line from blocking the editor.
(function (root) {
  'use strict';

  const MAX_CANDIDATES_PER_LINE = 3_000;

  function boundedEditDistance(candidateText, queryText, maxEdits) {
    if (Math.abs(candidateText.length - queryText.length) > maxEdits) return maxEdits + 1;
    let previous = Array.from({ length: queryText.length + 1 }, (_, index) => index);
    let current = new Array(queryText.length + 1);
    for (let row = 1; row <= candidateText.length; row++) {
      current.fill(maxEdits + 1);
      current[0] = row;
      let smallestDistance = maxEdits + 1;
      const first = Math.max(1, row - maxEdits);
      const last = Math.min(queryText.length, row + maxEdits);
      for (let column = first; column <= last; column++) {
        const cost = candidateText[row - 1] === queryText[column - 1] ? 0 : 1;
        current[column] = Math.min(current[column - 1] + 1,
          previous[column] + 1, previous[column - 1] + cost);
        smallestDistance = Math.min(smallestDistance, current[column]);
      }
      if (smallestDistance > maxEdits) return maxEdits + 1;
      [previous, current] = [current, previous];
    }
    return previous[queryText.length];
  }

  function findInLine(line, query) {
    const normalizedLine = line.toLocaleLowerCase();
    const normalizedQuery = query.toLocaleLowerCase();
    const exactPosition = normalizedLine.indexOf(normalizedQuery);
    if (exactPosition >= 0) return { match: { ch: exactPosition, length: query.length, score: 1 }, limited: false };
    if (normalizedQuery.length < 3 || normalizedQuery.length > 64) return { match: null, limited: false };

    const similarityThreshold = normalizedQuery.length === 3 ? 0.66 : (normalizedQuery.length <= 5 ? 0.72 : 0.66);
    const maxEdits = Math.min(3, Math.floor((1 - similarityThreshold) * normalizedQuery.length + 0.00001));
    const lengthVariance = Math.min(maxEdits, Math.max(1, Math.floor(normalizedQuery.length * 0.18)));
    const checkedWindows = new Set();
    let checkedCandidateCount = 0;

    // With at most k edits, one of k+1 non-overlapping query fragments must
    // remain unchanged. Searching those anchors prunes most candidate windows.
    for (let fragmentIndex = 0; fragmentIndex <= maxEdits; fragmentIndex++) {
      const fragmentStart = Math.floor(fragmentIndex * normalizedQuery.length / (maxEdits + 1));
      const fragmentEnd = Math.floor((fragmentIndex + 1) * normalizedQuery.length / (maxEdits + 1));
      const anchor = normalizedQuery.slice(fragmentStart, fragmentEnd);
      for (let anchorPosition = normalizedLine.indexOf(anchor); anchorPosition >= 0;
           anchorPosition = normalizedLine.indexOf(anchor, anchorPosition + 1)) {
        for (let shift = -maxEdits; shift <= maxEdits; shift++) {
          const candidateStart = anchorPosition - fragmentStart + shift;
          for (let candidateLength = normalizedQuery.length - lengthVariance;
               candidateLength <= normalizedQuery.length + lengthVariance; candidateLength++) {
            if (candidateStart < 0 || candidateStart + candidateLength > normalizedLine.length) continue;
            const windowKey = `${candidateStart}:${candidateLength}`;
            if (checkedWindows.has(windowKey)) continue;
            checkedWindows.add(windowKey);
            if (++checkedCandidateCount > MAX_CANDIDATES_PER_LINE) return { match: null, limited: true };
            const distance = boundedEditDistance(
              normalizedLine.slice(candidateStart, candidateStart + candidateLength), normalizedQuery, maxEdits);
            const score = 1 - distance / Math.max(candidateLength, normalizedQuery.length);
            if (distance <= maxEdits && score >= similarityThreshold) {
              return { match: { ch: candidateStart, length: candidateLength, score }, limited: false };
            }
          }
        }
      }
    }
    return { match: null, limited: false };
  }

  root.dotmdFuzzySearch = { findInLine };
  if (typeof module !== 'undefined') module.exports = { findInLine, boundedEditDistance };
})(globalThis);
