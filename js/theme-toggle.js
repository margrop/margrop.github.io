(function () {
  var storageKey = 'margrop-theme';
  var root = document.documentElement;
  var media = window.matchMedia('(prefers-color-scheme: dark)');

  function getTheme() {
    var stored = window.localStorage.getItem(storageKey);
    return stored === 'light' || stored === 'dark' ? stored : '';
  }

  function isDark() {
    return root.dataset.theme === 'dark' || (!root.dataset.theme && media.matches);
  }

  function render() {
    var button = document.querySelector('[data-theme-toggle]');
    if (!button) return;
    var dark = isDark();
    button.textContent = dark ? '☀️ 普通模式' : '🌙 暗黑模式';
    button.setAttribute('aria-label', dark ? '切换到普通模式' : '切换到暗黑模式');
    button.setAttribute('aria-pressed', dark ? 'true' : 'false');
  }

  var initialTheme = getTheme();
  if (initialTheme) root.dataset.theme = initialTheme;

  document.addEventListener('DOMContentLoaded', function () {
    var button = document.querySelector('[data-theme-toggle]');
    if (!button) return;
    button.addEventListener('click', function () {
      var nextTheme = isDark() ? 'light' : 'dark';
      root.dataset.theme = nextTheme;
      window.localStorage.setItem(storageKey, nextTheme);
      render();
    });
    render();
  });

  media.addEventListener('change', function () {
    if (!root.dataset.theme) render();
  });
})();
