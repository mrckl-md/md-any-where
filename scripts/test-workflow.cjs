const assert = require('node:assert/strict');
const workflow = require('../Sources/DOTMD/Resources/workflow-core.js');

const twoAgents = ['first', 'second'];
const normal = workflow.normalize(workflow.template(twoAgents, '润色摘要'), twoAgents);
assert.equal(normal.stages.length, 3);
assert.deepEqual(normal.stages[1].profileIDs, twoAgents);
assert.equal(normal.stages[1].mode, 'parallel');

const proposal = workflow.parseProposal('```json\n{"title":"润色","stages":[{"title":"评审","mode":"parallel","profileIDs":["first","second"],"prompt":"独立检查"}]}\n```', twoAgents);
assert.equal(proposal.stages[0].title, '评审');
assert.throws(() => workflow.parseProposal('{"stages":[]}', twoAgents), /1 至 5/);
assert.throws(() => workflow.normalize({ stages: [{ title: '错误', mode: 'single', profileIDs: ['unknown'], prompt: '试一下' }] }, twoAgents), /没有可用/);
assert.throws(() => workflow.normalize({ stages: [{ title: '错误', mode: 'single', profileIDs: ['first'], prompt: 'x'.repeat(1201) }] }, twoAgents), /不超过/);
assert.deepEqual(workflow.normalize({ stages: [{ title: '安全', mode: 'single', profileIDs: ['first', 'second'], prompt: '检查' }] }, twoAgents).stages[0].profileIDs, ['first']);
console.log('Workflow model and Agent proposal validation passed.');
