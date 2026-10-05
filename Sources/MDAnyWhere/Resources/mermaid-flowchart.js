(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.mdAnyWhereMermaid = api;
})(typeof window === 'undefined' ? globalThis : window, function () {
  'use strict';
  const t = (key, args) => (globalThis.MDAnyWhereI18n || (typeof require === 'function' ? require('./i18n.js') : null))?.t(key, args) ?? key;


  const escapeHTML = value => String(value).replace(/[&<>"']/g, character => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
  })[character]);

  function parseNode(expression) {
    const value = expression.trim().replace(/;$/, '');
    const match = value.match(/^([A-Za-z_][\w-]*)(?:\[\[([\s\S]*?)\]\]|\(\(([\s\S]*?)\)\)|\{([\s\S]*?)\}|\[([\s\S]*?)\]|\(([\s\S]*?)\))?$/);
    if (!match) return null;
    const label = [match[2], match[3], match[4], match[5], match[6]].find(item => item !== undefined);
    const shape = match[4] !== undefined ? 'diamond' : match[3] !== undefined ? 'circle' :
      match[2] !== undefined || match[6] !== undefined ? 'rounded' : 'rect';
    return { id: match[1], label: (label ?? match[1]).replace(/^['"]|['"]$/g, ''), shape };
  }

  function splitStatements(source) {
    return source.split(/\r?\n/).flatMap(line => line.split(';')).map(line => line.trim())
      .filter(line => line && !line.startsWith('%%'));
  }

  function parse(source) {
    const lines = splitStatements(source);
    const header = lines.shift() || '';
    const headerMatch = header.match(/^(?:flowchart|graph)\s+(TD|TB|BT|LR|RL)$/i);
    if (!headerMatch) throw new Error(t("web.3b944a8672"));
    const direction = headerMatch[1].toUpperCase() === 'TB' ? 'TD' : headerMatch[1].toUpperCase();
    const nodes = new Map();
    const edges = [];
    const remember = node => {
      const existing = nodes.get(node.id);
      nodes.set(node.id, existing && node.label === node.id ? existing : { ...existing, ...node });
    };
    for (const line of lines) {
      let match = line.match(/^(.+?)\s*--\s*([^>|]+?)\s*-->\s*(.+)$/);
      let fromExpression, toExpression, style, label = '';
      if (match) {
        [fromExpression, label, toExpression, style] = [match[1], match[2], match[3], '-->'];
      } else {
        match = line.match(/^(.+?)\s*(-->|---|==>|-\.->)\s*(?:\|([^|]+)\|\s*)?(.+)$/);
        if (match) [fromExpression, style, label, toExpression] = [match[1], match[2], match[3] || '', match[4]];
      }
      if (match) {
        const from = parseNode(fromExpression), to = parseNode(toExpression);
        if (!from || !to) throw new Error(t("web.bd0cf2d880", { p0: line }));
        remember(from); remember(to); edges.push({ from: from.id, to: to.id, style, label });
        continue;
      }
      const node = parseNode(line);
      if (!node) throw new Error(t("web.ce559e2395", { p0: line }));
      remember(node);
    }
    if (!nodes.size) throw new Error(t("web.7bc8e8bd62"));
    if (nodes.size > 120 || edges.length > 240) throw new Error(t("web.b7c93625d6"));
    return { direction, nodes: [...nodes.values()], edges };
  }

  function renderSVG(source) {
    const graph = parse(source);
    const incoming = new Map(graph.nodes.map(node => [node.id, 0]));
    const outgoing = new Map(graph.nodes.map(node => [node.id, []]));
    graph.edges.forEach(edge => { incoming.set(edge.to, (incoming.get(edge.to) || 0) + 1); outgoing.get(edge.from)?.push(edge.to); });
    // First-discovery breadth-first ranking keeps loop-back edges from pushing
    // an entire cyclic workflow into arbitrary columns.
    const levels = new Map();
    const roots = graph.nodes.filter(node => incoming.get(node.id) === 0).map(node => node.id);
    if (!roots.length) roots.push(graph.nodes[0].id);
    for (const root of [...roots, ...graph.nodes.map(node => node.id)]) {
      if (levels.has(root)) continue;
      levels.set(root, 0);
      const queue = [root];
      for (let cursor = 0; cursor < queue.length; cursor++) {
        const id = queue[cursor];
        for (const next of outgoing.get(id) || []) {
          if (levels.has(next)) continue;
          levels.set(next, levels.get(id) + 1);
          queue.push(next);
        }
      }
    }
    const columns = new Map();
    graph.nodes.forEach(node => {
      const level = levels.get(node.id) || 0;
      if (!columns.has(level)) columns.set(level, []);
      columns.get(level).push(node.id);
    });
    const horizontal = graph.direction === 'LR' || graph.direction === 'RL';
    const nodeWidth = 182, nodeHeight = 68, primaryGap = 112, secondaryGap = 54, margin = 86;
    const maxLevel = Math.max(...columns.keys()), maxItems = Math.max(...[...columns.values()].map(items => items.length));
    const width = horizontal ? margin * 2 + (maxLevel + 1) * nodeWidth + maxLevel * primaryGap : margin * 2 + maxItems * nodeWidth + Math.max(0, maxItems - 1) * secondaryGap;
    const height = horizontal ? margin * 2 + maxItems * nodeHeight + Math.max(0, maxItems - 1) * secondaryGap : margin * 2 + (maxLevel + 1) * nodeHeight + maxLevel * primaryGap;
    const positions = new Map();
    columns.forEach((ids, level) => ids.forEach((id, index) => {
      let x = horizontal ? margin + level * (nodeWidth + primaryGap) : margin + index * (nodeWidth + secondaryGap) + (maxItems - ids.length) * (nodeWidth + secondaryGap) / 2;
      let y = horizontal ? margin + index * (nodeHeight + secondaryGap) + (maxItems - ids.length) * (nodeHeight + secondaryGap) / 2 : margin + level * (nodeHeight + primaryGap);
      if (graph.direction === 'RL') x = width - margin - nodeWidth - level * (nodeWidth + primaryGap);
      if (graph.direction === 'BT') y = height - margin - nodeHeight - level * (nodeHeight + primaryGap);
      positions.set(id, { x, y });
    }));
    const markerID = `mdanywhere-arrow-${Math.random().toString(36).slice(2)}`;
    const edgeSVG = graph.edges.map(edge => {
      const from = positions.get(edge.from), to = positions.get(edge.to);
      const fromNode = graph.nodes.find(node => node.id === edge.from);
      const toNode = graph.nodes.find(node => node.id === edge.to);
      const fromCenterX = from.x + nodeWidth / 2, toCenterX = to.x + nodeWidth / 2;
      const fromCenterY = from.y + nodeHeight / 2, toCenterY = to.y + nodeHeight / 2;
      const fromExtra = fromNode.shape === 'diamond' ? 12 : 0;
      const toExtra = toNode.shape === 'diamond' ? 12 : 0;
      const backwards = levels.get(edge.to) <= levels.get(edge.from);
      let path, labelX, labelY;
      if (backwards) {
        if (horizontal) {
          const outsideY = Math.max(25, Math.min(from.y, to.y) - 48);
          const x1 = fromCenterX, x2 = toCenterX;
          const y1 = from.y, y2 = to.y;
          path = `M ${x1} ${y1} C ${x1} ${outsideY}, ${x2} ${outsideY}, ${x2} ${y2}`;
          labelX = (x1 + x2) / 2; labelY = outsideY - 9;
        } else {
          const outsideX = Math.max(25, Math.min(from.x, to.x) - 50);
          const x1 = from.x, x2 = to.x;
          const y1 = fromCenterY, y2 = toCenterY;
          path = `M ${x1} ${y1} C ${outsideX} ${y1}, ${outsideX} ${y2}, ${x2} ${y2}`;
          labelX = outsideX - 10; labelY = (y1 + y2) / 2;
        }
      } else if (horizontal) {
        const sign = graph.direction === 'RL' ? -1 : 1;
        const x1 = fromCenterX + sign * (nodeWidth / 2 + fromExtra);
        const x2 = toCenterX - sign * (nodeWidth / 2 + toExtra);
        const middle = (x1 + x2) / 2;
        path = `M ${x1} ${fromCenterY} C ${middle} ${fromCenterY}, ${middle} ${toCenterY}, ${x2} ${toCenterY}`;
        labelX = middle; labelY = (fromCenterY + toCenterY) / 2 - 10;
      } else {
        const sign = graph.direction === 'BT' ? -1 : 1;
        const y1 = fromCenterY + sign * (nodeHeight / 2 + fromExtra);
        const y2 = toCenterY - sign * (nodeHeight / 2 + toExtra);
        const middle = (y1 + y2) / 2;
        path = `M ${fromCenterX} ${y1} C ${fromCenterX} ${middle}, ${toCenterX} ${middle}, ${toCenterX} ${y2}`;
        labelX = (fromCenterX + toCenterX) / 2; labelY = middle - 9;
      }
      const dashed = edge.style === '-.->' ? ' stroke-dasharray="7 6"' : '';
      const heavy = edge.style === '==>' ? ' stroke-width="3"' : '';
      const arrow = edge.style === '---' ? '' : ` marker-end="url(#${markerID})"`;
      const label = edge.label ? `<text class="mdanywhere-flow-edge-label" x="${labelX}" y="${labelY}" text-anchor="middle">${escapeHTML(edge.label.trim())}</text>` : '';
      return `<path class="mdanywhere-flow-edge" d="${path}"${arrow}${dashed}${heavy}/>${label}`;
    }).join('');
    const nodeSVG = graph.nodes.map(node => {
      const { x, y } = positions.get(node.id), cx = x + nodeWidth / 2, cy = y + nodeHeight / 2;
      let shape;
      if (node.shape === 'diamond') shape = `<polygon points="${cx},${y - 12} ${x + nodeWidth + 12},${cy} ${cx},${y + nodeHeight + 12} ${x - 12},${cy}"/>`;
      else if (node.shape === 'circle') shape = `<ellipse cx="${cx}" cy="${cy}" rx="${nodeWidth / 2}" ry="${nodeHeight / 2}"/>`;
      else shape = `<rect x="${x}" y="${y}" width="${nodeWidth}" height="${nodeHeight}" rx="${node.shape === 'rounded' ? 25 : 10}"/>`;
      const label = node.label.length > 26 ? node.label.slice(0, 25) + '…' : node.label;
      return `<g class="mdanywhere-flow-node" data-node-id="${escapeHTML(node.id)}">${shape}<text x="${cx}" y="${cy}" text-anchor="middle" dominant-baseline="middle">${escapeHTML(label)}</text></g>`;
    }).join('');
    return `<svg class="mdanywhere-flowchart-svg" role="img" aria-label="${escapeHTML(t('diagram.accessibleName'))}" viewBox="0 0 ${width} ${height}" style="min-width:${width}px" xmlns="http://www.w3.org/2000/svg"><defs><marker id="${markerID}" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto"><path d="M0,0 L0,6 L9,3 z" class="mdanywhere-flow-arrow"/></marker></defs>${edgeSVG}${nodeSVG}</svg>`;
  }

  function installMarkdownIt(markdown) {
    const originalFence = markdown.renderer.rules.fence ||
      ((tokens, index, options, env, self) => self.renderToken(tokens, index, options));
    markdown.renderer.rules.fence = (tokens, index, options, env, self) => {
      const token = tokens[index];
      const language = (token.info || '').trim().split(/\s+/)[0].toLowerCase();
      if (language !== 'mermaid') return originalFence(tokens, index, options, env, self);
      const encoded = markdown.utils.escapeHtml(token.content).replace(/\n/g, '&#10;');
      return `<div class="mdanywhere-mermaid" data-mermaid-source="${encoded}"></div>`;
    };
  }

  function renderInto(container) {
    container.querySelectorAll('.mdanywhere-mermaid[data-mermaid-source]').forEach(element => {
      try { element.innerHTML = renderSVG(element.dataset.mermaidSource || ''); element.classList.remove('mdanywhere-mermaid-error'); }
      catch (error) { element.classList.add('mdanywhere-mermaid-error'); element.innerHTML = `<strong>${escapeHTML(t('diagram.syntaxError'))}</strong><span>${escapeHTML(error.message)}</span>`; }
    });
  }

  return { parse, renderSVG, renderInto, installMarkdownIt };
});
