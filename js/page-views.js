(function () {
  var namespace = 'margrop-blog-com';
  var apiBase = 'https://api.counterapi.dev/v1/' + namespace + '/';
  var path = window.location.pathname.replace(/^\/+|\/+$/g, '') || 'home';
  var pageKey = path.replace(/[^a-zA-Z0-9_-]+/g, '-').replace(/^-+|-+$/g, '') || 'home';

  function update(selector, value) {
    document.querySelectorAll(selector).forEach(function (element) {
      element.textContent = typeof value === 'number' ? value.toLocaleString('zh-CN') : value;
    });
  }

  function increment(key, selector) {
    return fetch(apiBase + encodeURIComponent(key) + '/up', {
      cache: 'no-store',
      credentials: 'omit'
    }).then(function (response) {
      if (!response.ok) {
        throw new Error('counter request failed: ' + response.status);
      }
      return response.json();
    }).then(function (data) {
      update(selector, data.count);
    }).catch(function () {
      update(selector, '暂不可用');
    });
  }

  increment('site', '[data-site-view-count]');
  if (document.querySelector('[data-page-view-count]')) {
    increment('page-' + pageKey, '[data-page-view-count]');
  }
})();
