const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');

const source = fs.readFileSync(path.join(__dirname, '../web/input_diagnostics.js'), 'utf8');
function load(platform, search = platform ? '?diagnostics=1' : '') {
  const handlers = new Map();
  class Element {
    constructor(tag) { this.nodeName = tag.toUpperCase(); this.children = []; this.style = {}; }
    append(child) { this.children.push(child); }
    setAttribute() {}
    addEventListener(type, fn) { this[type] = fn; }
    focus() { this.focused = true; }
    select() { this.selected = true; }
  }
  const document = {body: new Element('body'), createElement: tag => new Element(tag)};
  const window = {
    Telegram: platform ? {WebApp: {platform, version: '9.0', initData: 'DO_NOT_REPORT_INIT_DATA'}} : undefined,
    location: {search, hash: 'DO_NOT_REPORT_HASH'},
    navigator: {userAgent: 'Test WebView'}, innerWidth: 800, innerHeight: 600,
    addEventListener: (type, fn) => handlers.set(type, fn),
  };
  vm.runInNewContext(source, {window, document, URLSearchParams});
  const panel = document.body.children[0];
  return {window, panel, fire: (type, event = {}) => handlers.get(type)?.(event),
    report: () => JSON.parse(panel.children[2].value)};
}

test('ordinary browser has no diagnostic overlay and pointer hook is harmless', () => {
  const app = load();
  assert.equal(app.panel, undefined);
  assert.doesNotThrow(() => app.window.firstcaseRecordPointer('down'));
});

test('Telegram report distinguishes DOM input from Flutter input without credentials', () => {
  const app = load('tdesktop');
  app.fire('flutter-first-frame');
  app.fire('pointerdown', {target: {nodeName: 'FLUTTER-VIEW'}, composedPath: () => [{nodeName: 'CANVAS'}]});
  app.fire('pointerup', {target: {nodeName: 'FLUTTER-VIEW'}});
  app.fire('click', {target: {nodeName: 'FLUTTER-VIEW'}});
  assert.equal(app.report().domDown, 1);
  assert.equal(app.report().flutterDown, 0);
  app.window.firstcaseRecordPointer('down');
  app.window.firstcaseRecordPointer('up');
  app.fire('error', {message: 'DO_NOT_REPORT_EXCEPTION_CONTENT'});
  const report = app.report();
  assert.equal(report.flutterUp, 1);
  assert.equal(report.firstFrame, true);
  assert.equal(report.errors, 1);
  assert.doesNotMatch(JSON.stringify(report), /DO_NOT_REPORT/);
  assert.deepEqual(Object.keys(report).sort(), ['build', 'telegramPlatform', 'telegramVersion', 'userAgent', 'firstFrame', 'viewport', 'lastTarget', 'navigation', 'domDown', 'domUp', 'domClick', 'flutterDown', 'flutterUp', 'errors'].sort());
});

test('navigation report separates requested, redirected and displayed routes without IDs or secrets', () => {
  const app = load('tdesktop');
  app.window.firstcaseRecordNavigation('mode', 'embedded');
  app.window.firstcaseRecordNavigation('requested', '/tasks/928/edit');
  app.window.firstcaseRecordNavigation('redirect', '/onboarding');
  app.window.firstcaseRecordNavigation('current', '/onboarding');
  app.window.firstcaseRecordNavigation('error', '/tasks/928');
  assert.deepEqual(app.report().navigation, {mode: 'embedded', requested: '/tasks/:id/edit', redirect: '/onboarding', current: '/onboarding', failures: 1});
  app.window.firstcaseRecordNavigation('requested', '/tasks?token=DO_NOT_REPORT_QUERY');
  assert.equal(app.report().navigation.requested, 'unknown');
  assert.doesNotMatch(JSON.stringify(app.report()), /DO_NOT_REPORT|928/);
});

test('clicking the panel does not count as app input; report can be selected', () => {
  const app = load('tdesktop');
  app.fire('pointerdown', {target: {closest: selector => selector === '#firstcase-input-check'}});
  assert.equal(app.report().domDown, 0);
  const select = app.panel.children[3];
  select.click();
  assert.equal(app.panel.children[2].selected, true);
});

test('diagnostics can be explicitly opened in a browser for comparison', () => {
  const app = load(undefined, '?diagnostics=1');
  assert.equal(app.report().telegramPlatform, 'browser');
});
