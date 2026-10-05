// Static guardrails for names shared by Swift, JavaScript, and the editor HTML.
// This does not replace a UI smoke test, but catches accidental rename drift.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const projectRoot = path.resolve(__dirname, '..');
const readSource = relativePath => fs.readFileSync(path.join(projectRoot, relativePath), 'utf8');
const nativeSource = readSource('Sources/MDAnyWhere/AppDelegate.swift');
const editorSource = readSource('Sources/MDAnyWhere/Resources/app.js');
const docxSource = readSource('Sources/MDAnyWhere/Resources/docx-export.js');
const editorHTML = readSource('Sources/MDAnyWhere/Resources/index.html');
const entitlements = readSource('Support/MDAnyWhere.entitlements');

const editorBridge = editorSource.split('window.mdAnyWhere = {')[1]?.split('\n  };')[0];
const docxBridge = docxSource.split('window.mdAnyWhereDocx = {')[1]?.split('\n  };')[0];
assert.ok(editorBridge, 'Editor JavaScript bridge must exist');
assert.ok(docxBridge, 'DOCX JavaScript bridge must exist');

for (const [, functionName] of nativeSource.matchAll(/invokeEditorJavaScript\("([A-Za-z][A-Za-z0-9]*)"/g)) {
  assert.match(editorBridge, new RegExp(`\\b${functionName}\\b\\s*(?:[:,(])`),
    `Native command ${functionName} must remain on window.mdAnyWhere`);
}

for (const functionName of ['bind', 'open', 'updateAgents', 'receiveAgent', 'exported']) {
  assert.match(docxBridge, new RegExp(`\\b${functionName}\\s*:`),
    `DOCX bridge must keep its ${functionName} property`);
}

const htmlIDs = new Set([...editorHTML.matchAll(/\bid="([A-Za-z][A-Za-z0-9-]*)"/g)]
  .map(([, id]) => id));
const referencedDocxIDs = new Set([...docxSource.matchAll(/\b(?:elementByID|exportDialog)\('([a-z][a-z0-9-]*)'\)/g)]
  .map(([, id]) => id));
for (const [, id] of docxSource.matchAll(/:\s*'(docx-[a-z-]+)'/g)) referencedDocxIDs.add(id);
for (const id of referencedDocxIDs) {
  assert.ok(htmlIDs.has(id), `DOCX DOM id ${id} must exist in index.html`);
}

assert.match(docxSource, /result\.open\s*=\s*node\.getAttribute\('open'\)/,
  'MathML fence opening must keep the Swift-decoded open field');
for (const [command, key] of [['cut', 'x'], ['copy', 'c'], ['paste', 'v'], ['selectAll', 'a']]) {
  const menuLine = nativeSource.split('\n').find(line => line.includes(`#selector(NSText.${command}(_:)`));
  assert.ok(menuLine?.includes(`"${key}", responderChain: true`),
    `Native ${command} shortcut must follow the focused input responder chain`);
}
for (const key of ['Cmd-C', 'Cmd-X', 'Cmd-V']) {
  assert.match(editorSource, new RegExp(`'${key}'\\s*:`),
    `CodeMirror must retain its ${key} clipboard bridge`);
}
for (const message of ['agentPlanWorkflow', 'agentWorkflowRun']) {
  assert.match(nativeSource, new RegExp(`case "${message}"`), `Native handler ${message} must exist`);
  assert.match(editorSource, new RegExp(`sendNativeMessage\\('${message}'`), `Editor message ${message} must exist`);
}
for (const id of ['workflow-builder', 'workflow-stages', 'workflow-planner', 'workflow-proposal']) {
  assert.ok(htmlIDs.has(id), `Workflow UI ${id} must exist`);
}
for (const id of ['agent-console-enabled', 'agent-console-access', 'agent-console-platform', 'agent-console-command']) {
  assert.ok(htmlIDs.has(id), `Agent console UI ${id} must exist`);
}
const settingsHTML = editorHTML.match(/<dialog id="settings-dialog">([\s\S]*?)<\/dialog>/)?.[1] || '';
const agentHTML = editorHTML.match(/<dialog id="agent-dialog"[\s\S]*?<\/dialog>/)?.[0] || '';
assert.match(settingsHTML, /id="agent-profiles"/, 'Agent model configuration belongs in Settings');
assert.doesNotMatch(agentHTML, /id="agent-profiles"/, 'Agent task dialog should not contain model configuration');
for (const functionName of ['configureAgentConsole', 'replaceDocumentFromAgent']) {
  assert.match(editorBridge, new RegExp(`\\b${functionName}\\b\\s*(?:[:,(])`),
    `Agent console bridge must keep ${functionName}`);
}
assert.match(nativeSource, /st_mode\s*&\s*0o077\s*==\s*0/, 'Agent command file must reject group/world access');
assert.match(nativeSource, /st_nlink\s*==\s*1/, 'Agent command file must reject hard links');
assert.match(nativeSource, /agentConsoleAccess\s*==\s*"edit"/, 'Agent writes must require explicit edit access');
assert.match(nativeSource, /requiredLocalEndpoint\s*=\s*\.hostPort\(host:\s*"127\.0\.0\.1"/,
  'Agent listener must remain bound to the IPv4 loopback address');
assert.match(entitlements, /<key>com\.apple\.security\.network\.server<\/key>\s*<true\/>/,
  'Agent loopback listener requires the sandbox network server entitlement');
assert.match(nativeSource, /func applicationShouldTerminate\(/,
  'Quitting must review unsaved documents, not only closing the window');
assert.match(nativeSource, /if !activeDiskSaves\.isEmpty[\s\S]*?\.terminateLater/,
  'Quitting must wait for background disk saves to finish');
assert.match(nativeSource, /func windowShouldClose\([\s\S]*?await self\.waitForDiskSaves\(\)/,
  'Closing the window must wait for background disk saves to finish');
assert.match(nativeSource, /private func enqueueDiskSave\([\s\S]*?Task\.detached\(priority: \.utility\)/,
  'Autosave disk I/O must not block the main thread');
assert.match(nativeSource, /guard approveAgentConsoleRequest\(command, arguments: arguments\)/,
  'Every local console document command must require user approval');
for (const handler of ['runAgents', 'runAgentWorkflow', 'planAgentWorkflow', 'suggestDOCXLayout']) {
  const method = nativeSource.split(`private func ${handler}(`)[1]?.split('\n    private func ')[0] || '';
  assert.match(method, /confirmThirdPartyAgentTransfer\(/,
    `${handler} must obtain explicit approval before a remote Agent request`);
}
assert.ok(htmlIDs.has('privacy-policy') && htmlIDs.has('open-privacy-policy'),
  'Privacy policy must be reachable from Settings');
const agentEntitlements = readSource('Support/MDAnyWhereAgent.entitlements');
assert.match(agentEntitlements, /com\.apple\.security\.app-sandbox/,
  'The independently launched Agent helper must have its own sandbox');
console.log('Swift/JavaScript bridge and DOCX DOM contract tests passed.');

for (const file of ['Sources/MDAnyWhere/AppDelegate.swift', 'Sources/MDAnyWhereMobile/AppDelegate.swift']) {
  const changeLanguage = readSource(file).split('case "changeInterfaceLanguage":')[1]?.split('case "change":')[0] || '';
  assert.match(changeLanguage, /setLanguage/);
  assert.doesNotMatch(changeLanguage, /sendAgentProfiles|configureAgents/,
    'Changing UI language must preserve unsaved profile fields and API keys');
}
