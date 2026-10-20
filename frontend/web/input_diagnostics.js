// Temporary, local-only diagnostics for the Telegram Desktop input failure.
// Never include initData, URLs, form contents, API responses or credentials in reports.
(() => {
  'use strict';
  const telegram = window.Telegram?.WebApp;
  const enabled = new URLSearchParams(window.location.search).get('diagnostics') === '1';
  const counters = {domDown: 0, domUp: 0, domClick: 0, flutterDown: 0, flutterUp: 0, errors: 0};
  const navigation = {mode: '', requested: '', redirect: '', current: '', failures: 0};
  const routeName = (path) => {
    // Only expose route names: never query parameters, fragments or object IDs.
    if (typeof path !== 'string' || !/^\/(?:[a-z]+|\d+)*(?:\/(?:[a-z]+|\d+))*$/.test(path)) return 'unknown';
    return path.replace(/\/\d+(?=\/|$)/g, '/:id');
  };
  let target = '';
  let firstFrame = false;
  let output;

  const report = () => ({
    build: '2026-10-19-navigation-v2',
    telegramPlatform: telegram?.platform || 'browser',
    telegramVersion: telegram?.version || '',
    userAgent: window.navigator.userAgent,
    firstFrame,
    viewport: [window.innerWidth, window.innerHeight],
    lastTarget: target,
    navigation: {...navigation},
    ...counters,
  });
  const refresh = () => {
    if (output) output.value = JSON.stringify(report(), null, 2);
  };
  window.firstcaseRecordPointer = (phase) => {
    if (!enabled) return;
    if (phase === 'down') counters.flutterDown++;
    if (phase === 'up') counters.flutterUp++;
    refresh();
  };
  window.firstcaseRecordNavigation = (phase, path) => {
    if (!enabled) return;
    if (phase === 'mode' && ['embedded', 'browser'].includes(path)) navigation.mode = path;
    if (['requested', 'redirect', 'current'].includes(phase)) navigation[phase] = routeName(path);
    if (phase === 'error') navigation.failures++;
    refresh();
  };
  if (!enabled) return;

  for (const [type, counter] of [['pointerdown', 'domDown'], ['pointerup', 'domUp'], ['click', 'domClick']]) {
    window.addEventListener(type, (event) => {
      // Ignore the panel itself: only count interactions with the actual app.
      if (event.target?.closest?.('#firstcase-input-check')) return;
      counters[counter]++;
      target = event.composedPath?.()[0]?.nodeName || event.target?.nodeName || '';
      refresh();
    }, true);
  }
  window.addEventListener('flutter-first-frame', () => { firstFrame = true; refresh(); }, {once: true});
  window.addEventListener('error', () => { counters.errors++; refresh(); });
  window.addEventListener('unhandledrejection', () => { counters.errors++; refresh(); });

  const panel = document.createElement('details');
  panel.id = 'firstcase-input-check';
  panel.style.cssText = 'position:fixed;right:8px;bottom:86px;z-index:2147483647;max-width:calc(100vw - 16px);background:#fff;color:#17202a;border:1px solid #808891;border-radius:8px;padding:8px;font:13px/1.4 system-ui;box-shadow:0 2px 8px #0003';
  const summary = document.createElement('summary');
  summary.textContent = 'Проверка переходов';
  summary.style.cursor = 'pointer';
  panel.append(summary);
  const instructions = document.createElement('p');
  instructions.textContent = 'Нажмите «Задачи» или «Главная», затем скопируйте этот отчёт в чат Codex. Данные входа в отчёт не попадают.';
  instructions.style.maxWidth = '280px';
  panel.append(instructions);
  output = document.createElement('textarea');
  output.readOnly = true;
  output.rows = 13;
  output.style.cssText = 'display:block;box-sizing:border-box;width:280px;max-width:calc(100vw - 48px);font:12px/1.3 monospace';
  output.setAttribute('aria-label', 'Отчёт о нажатиях');
  panel.append(output);
  const select = document.createElement('button');
  select.type = 'button';
  select.textContent = 'Выделить отчёт';
  select.addEventListener('click', () => { output.focus(); output.select(); });
  panel.append(select);
  panel.addEventListener('toggle', refresh);
  document.body.append(panel);
  refresh();
})();
