// Evaluated as an async function by test-editor-safety.swift in the real editor.
const problems = [];
const expect = (condition, message) => { if (!condition) problems.push(message); };
const app = window.mdAnyWhere;
const editor = document.querySelector('.CodeMirror').CodeMirror;
const byID = id => document.getElementById(id);
const pause = () => new Promise(resolve => setTimeout(resolve, 40));
const closeDialogs = () => document.querySelectorAll('dialog[open]').forEach(dialog => dialog.close());
const select = (from, to) => editor.setSelection({line:0,ch:from}, {line:0,ch:to});
let nextID = 0;
const add = text => {
  closeDialogs();
  const id = `safety-${++nextID}`;
  app.addDocument(id, `${id}.md`, text);
  return id;
};
app.configureAgents([{id:'local-test',name:'Test',kind:'local',endpoint:'http://127.0.0.1:1',model:'unused',enabled:true,keyPresent:false}]);
const requestEdit = async () => {
  closeDialogs();
  app.openAgentTools();
  byID('cluster-mode').value = 'single';
  byID('agent-action').value = 'custom';
  byID('agent-instruction').value = 'Use the synthetic replacement';
  byID('agent-run').click();
  await pause();
  const request = window.__testRequests.at(-1);
  expect(request?.type === 'agentRun', 'Synthetic Agent request must reach the test-only bridge');
  return request?.requestID;
};
const result = requestID => app.showAgentResults([{name:'Test',text:'REPLACED'}], 'edit', requestID);
const replaceResult = () => byID('agent-results').querySelector('footer button').click();

// Snapshot a request target instead of consulting a later global selection.
add('alpha beta'); select(0, 5);
let requestID = await requestEdit();
result(requestID);
closeDialogs(); select(6, 10); app.openAgentTools();
replaceResult();
expect(app.getContent() === 'REPLACED beta', 'Reopening Agent tools must not retarget a completed result to a later selection');

add('alpha beta'); select(0, 5);
requestID = await requestEdit();
add('other document');
result(requestID); replaceResult();
expect(app.getContent() === 'other document', 'An Agent result must never replace text in another document');

add('alpha beta'); select(0, 5);
requestID = await requestEdit();
closeDialogs(); editor.replaceRange('new ', {line:0,ch:0});
const changed = app.getContent();
result(requestID); replaceResult();
expect(app.getContent() === changed, 'An Agent result must not use stale offsets after source edits');

add('alpha beta'); select(6, 6);
requestID = await requestEdit();
closeDialogs(); select(0, 5);
result(requestID); replaceResult();
expect(app.getContent() === 'alpha REPLACEDbeta', 'A request with no selection must retain its original insertion point');

add('alpha beta'); select(0, 5);
const firstRequest = await requestEdit();
closeDialogs(); select(6, 10);
const secondRequest = await requestEdit();
expect(!!firstRequest && firstRequest !== secondRequest, 'Concurrent Agent requests need distinct, nonempty request identifiers');
result(secondRequest); result(firstRequest); replaceResult();
expect(app.getContent() === 'REPLACED beta', 'Out-of-order responses must retain their individual request targets');

add('alpha beta'); select(0, 5);
await requestEdit();
result('unknown-request'); replaceResult();
expect(app.getContent() === 'alpha beta', 'A response without a recognized request must remain read-only');

add('alpha beta'); select(0, 5); app.openAgentTools();
byID('cluster-mode').value = 'workflow'; byID('cluster-mode').dispatchEvent(new Event('change'));
byID('workflow-template').click(); byID('agent-run').click(); await pause();
const workflowRequest = window.__testRequests.at(-1);
expect(workflowRequest?.type === 'agentWorkflowRun' && !!workflowRequest.requestID, 'Workflow requests need a target identifier');
app.showWorkflowResults([{title:'Test step',answers:[{name:'Test',text:'REPLACED'}]}], 'edit', workflowRequest?.requestID);
replaceResult();
expect(app.getContent() === 'REPLACED beta', 'A valid workflow response must replace its original selection');

add('alpha beta'); select(0, 5);
requestID = await requestEdit();
result(requestID);
byID('agent-results').querySelectorAll('footer button')[1].click();
byID('formula-source').value = 'x^2'; byID('formula-replace').click();
expect(app.getContent() === '$x^2$ beta', 'Formula conversion of a valid result must retain the request target');

const closedID = add('alpha beta'); select(0, 5);
requestID = await requestEdit();
add('other document'); app.removeTab(closedID);
app.addDocument(closedID, 'reopened.md', 'reopened content');
result(requestID); replaceResult();
expect(app.getContent() === 'reopened content', 'A reopened ID must not accept an old document instance result');

add('alpha beta'); select(0, 5); app.openFormulaTools();
add('other document'); byID('formula-source').value = 'x^2'; byID('formula-replace').click();
expect(app.getContent() === 'other document', 'Formula replacement must remain bound to its original document');

add('keep current');
app.replaceDocumentFromAgent('does-not-exist', 'unexpected');
expect(app.getContent() === 'keep current', 'A closed or unknown document ID must never overwrite the active document');

add('needle remains'); editor.setCursor(0,0);
byID('search-query').value = 'needle'; byID('search-mode').value = 'exact'; app.openSearchTools();
byID('replace-value').value = 'changed';
// Preserve the open search dialog as a keyboard tab switch does.
app.addDocument('search-target', 'other.md', 'unrelated text');
byID('replace-current').click();
expect(app.getContent() === 'unrelated text', 'Switching tabs must discard search positions from the previous document');

add('İABC tail'); editor.setCursor(0,0);
byID('search-query').value = 'abc'; byID('search-mode').value = 'case-insensitive'; app.openSearchTools();
byID('replace-value').value = 'OK'; byID('replace-current').click();
expect(app.getContent() === 'İOK tail', 'Case-insensitive matching must use original UTF-16 positions after expanding Unicode case folds');

add('a[b].* and a[b].*'); editor.setCursor(0,0);
byID('search-query').value = 'a[b].*'; byID('search-mode').value = 'case-insensitive'; app.openSearchTools();
byID('replace-value').value = 'literal'; byID('replace-all').click();
expect(app.getContent() === 'literal and literal', 'Literal search must not interpret regular expression metacharacters');

add('alpha beta'); editor.setCursor(0,0);
byID('search-query').value = 'alpha'; app.openSearchTools(); byID('agent-find').click(); await pause();
const searchRequest = window.__testRequests.at(-1)?.requestID;
app.addDocument('search-ai-target', 'other.md', 'alpha unrelated');
app.showAgentResults([{name:'Test',text:JSON.stringify({matches:[{quote:'alpha'}]})}], 'agent-find', searchRequest);
expect(!byID('search-results').querySelector('button'), 'A delayed Agent search must not apply to another document');

add('[script](javascript:alert%281%29)\n\n[data](data:text/html;base64,PHNjcmlwdD4=)\n\n[file](file:///private/example)\n\n[anchor](#safe)\n\n![remote](https://example.invalid/image.png)\n\n<script>alert(1)</script>');
const exported = new DOMParser().parseFromString(app.exportHTML(), 'text/html');
expect(![...exported.querySelectorAll('[href]')].some(link => /^(javascript|vbscript|data|file):/i.test(link.getAttribute('href'))), 'Untrusted Markdown must not export executable or local-file links');
expect(!exported.querySelector('script'), 'Raw HTML must remain escaped in Markdown exports');
expect(![...exported.querySelectorAll('img')].some(image => /^https?:/i.test(image.getAttribute('src'))), 'Markdown must not introduce remote image requests');
expect(!!exported.querySelector('a[href="#safe"]'), 'Safe fragment links must remain usable');
return problems;
