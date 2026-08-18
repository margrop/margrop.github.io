(function () {
  var widgetId = 'LA-DATA-WIDGET';
  var hostSelector = '[data-51la-widget]';
  var storageKey = 'margrop-theme';
  var baseUrl = 'https://v6-widget.51.la/v6/1vVTUWl7zoRjnKXi/quote.js';
  var display = '0,0,0,1,0,0,1,1';
  var lightTheme = '#1690FF,#333333,#999999,#333333,#FFFFFF,#1690FF,14';
  var darkTheme = '#60A5FA,#F3F4F6,#9CA3AF,#F9FAFB,#1D2126,#60A5FA,14';
  var media = window.matchMedia('(prefers-color-scheme: dark)');
  var lastSrc = '';
  var refreshTimer = 0;

  function isDark() {
    var selectedTheme = document.documentElement.dataset.theme;
    if (selectedTheme === 'dark') return true;
    if (selectedTheme === 'light') return false;
    return media.matches;
  }

  function buildSrc() {
    var theme = isDark() ? darkTheme : lightTheme;
    return baseUrl + '?theme=' + encodeURIComponent(theme) + '&f=14&display=' + display;
  }

  function refresh() {
    var host = document.querySelector(hostSelector);
    var src = buildSrc();
    if (!host || src === lastSrc) return;
    lastSrc = src;
    host.innerHTML = '';
    var script = document.createElement('script');
    script.id = widgetId;
    script.crossOrigin = 'anonymous';
    script.charset = 'UTF-8';
    script.src = src;
    host.appendChild(script);
  }

  function scheduleRefresh() {
    window.clearTimeout(refreshTimer);
    refreshTimer = window.setTimeout(refresh, 0);
  }

  document.addEventListener('DOMContentLoaded', refresh);
  media.addEventListener('change', function () {
    if (!document.documentElement.dataset.theme) scheduleRefresh();
  });
  new MutationObserver(function (mutations) {
    for (var i = 0; i < mutations.length; i += 1) {
      if (mutations[i].attributeName === 'data-theme') {
        scheduleRefresh();
        break;
      }
    }
  }).observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
})();
