// A deliberately small, linear workflow model. Imported by the editor and Node tests.
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.dotmdWorkflow = api;
})(typeof globalThis === 'object' ? globalThis : this, function () {

  const t = (key, args) => (globalThis.DotMDI18n || (typeof require === 'function' ? require('./i18n.js') : null))?.t(key, args) ?? key;
  const MAX_STAGES = 5;
  const MAX_PROMPT = 1200;

  function normalize(raw, enabledIDs) {
    if (!raw || !Array.isArray(raw.stages) || !raw.stages.length || raw.stages.length > MAX_STAGES) {
      throw new Error(t("web.f76e452a4d"));
    }
    const allowed = new Set(enabledIDs);
    const stages = raw.stages.map((stage, index) => {
      const title = String(stage.title || t("web.c2e5810502", { p0: index + 1 })).trim().slice(0, 60);
      const prompt = String(stage.prompt || '').trim();
      const mode = stage.mode === 'parallel' ? 'parallel' : 'single';
      const profileIDs = [...new Set(Array.isArray(stage.profileIDs) ? stage.profileIDs : [])]
        .filter(id => typeof id === 'string' && allowed.has(id));
      if (!prompt || prompt.length > MAX_PROMPT) throw new Error(t("web.fae08f6648", { p0: index + 1, p1: MAX_PROMPT }));
      if (!profileIDs.length) throw new Error(t("web.57d0a878f7", { p0: index + 1 }));
      return { title, prompt, mode, profileIDs: mode === 'single' ? profileIDs.slice(0, 1) : profileIDs };
    });
    return { title: String(raw.title || t("web.7f53134a4f")).trim().slice(0, 80),
      goal: String(raw.goal || '').trim().slice(0, 1500), stages };
  }

  function template(ids, goal = '') {
    const first = ids[0] || '';
    const reviewers = ids.slice(0, Math.min(3, ids.length));
    return { title: t("web.65c8c758e8"), goal, stages: [
      { title: t("web.2b166c072c"), mode: 'single', profileIDs: [first], prompt: t("web.66a093f604", { p0: goal ? t("web.3fd135997e", { p0: goal }) : '' }) },
      { title: t("web.193a0c4bf7"), mode: 'parallel', profileIDs: reviewers, prompt: t("web.e9475d3ba2") },
      { title: t("web.e4fba209e1"), mode: 'single', profileIDs: [first], prompt: t("web.ee8b92833d") }
    ] };
  }

  function parseProposal(text, enabledIDs) {
    if (typeof text !== 'string' || text.length > 30000) throw new Error(t("web.aa57f27eb1"));
    const cleaned = text.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
    let value;
    try { value = JSON.parse(cleaned); } catch (_) { throw new Error(t("web.807958baf5")); }
    return normalize(value, enabledIDs);
  }

  return { MAX_STAGES, normalize, template, parseProposal };
});
