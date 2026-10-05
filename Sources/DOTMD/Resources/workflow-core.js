// A deliberately small, linear workflow model. Imported by the editor and Node tests.
(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  else root.dotmdWorkflow = api;
})(typeof globalThis === 'object' ? globalThis : this, function () {
  const MAX_STAGES = 5;
  const MAX_PROMPT = 1200;

  function normalize(raw, enabledIDs) {
    if (!raw || !Array.isArray(raw.stages) || !raw.stages.length || raw.stages.length > MAX_STAGES) {
      throw new Error('流程需要 1 至 5 个步骤。');
    }
    const allowed = new Set(enabledIDs);
    const stages = raw.stages.map((stage, index) => {
      const title = String(stage.title || `第 ${index + 1} 步`).trim().slice(0, 60);
      const prompt = String(stage.prompt || '').trim();
      const mode = stage.mode === 'parallel' ? 'parallel' : 'single';
      const profileIDs = [...new Set(Array.isArray(stage.profileIDs) ? stage.profileIDs : [])]
        .filter(id => typeof id === 'string' && allowed.has(id));
      if (!prompt || prompt.length > MAX_PROMPT) throw new Error(`第 ${index + 1} 步需要填写不超过 ${MAX_PROMPT} 字的要求。`);
      if (!profileIDs.length) throw new Error(`第 ${index + 1} 步没有可用的 Agent；请先启用并选择。`);
      return { title, prompt, mode, profileIDs: mode === 'single' ? profileIDs.slice(0, 1) : profileIDs };
    });
    return { title: String(raw.title || '我的文字工作流程').trim().slice(0, 80),
      goal: String(raw.goal || '').trim().slice(0, 1500), stages };
  }

  function template(ids, goal = '') {
    const first = ids[0] || '';
    const reviewers = ids.slice(0, Math.min(3, ids.length));
    return { title: '起草 · 评审 · 定稿', goal, stages: [
      { title: '整理初稿', mode: 'single', profileIDs: [first], prompt: `按用户目标整理文字，保持原意，不虚构事实或引用。${goal ? `目标：${goal}` : ''}` },
      { title: '并行评审', mode: 'parallel', profileIDs: reviewers, prompt: '独立审查上一稿的逻辑、措辞和公式；指出具体问题并提出修订意见。' },
      { title: '综合定稿', mode: 'single', profileIDs: [first], prompt: '综合上一轮评审意见，给出一份完整、可直接使用的最终 Markdown 文稿；不要编造引用。' }
    ] };
  }

  function parseProposal(text, enabledIDs) {
    if (typeof text !== 'string' || text.length > 30000) throw new Error('Agent 返回的流程过长。');
    const cleaned = text.trim().replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '');
    let value;
    try { value = JSON.parse(cleaned); } catch (_) { throw new Error('Agent 没有返回可编辑的流程；请重试或手动添加步骤。'); }
    return normalize(value, enabledIDs);
  }

  return { MAX_STAGES, normalize, template, parseProposal };
});
