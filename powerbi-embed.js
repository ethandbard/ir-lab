/* Static Quarto integration: public configuration only; Power BI handles sign-in. */
(function () {
  'use strict';
  function embedUrl(config, key) {
    if (!config || !config.embedUrl) return null;
    const url = new URL(config.embedUrl);
    if (url.protocol !== 'https:' || url.hostname !== 'app.powerbi.com' ||
        url.pathname !== '/reportEmbed' || url.username || url.password ||
        !/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/i.test(url.searchParams.get('reportId') || '')) {
      throw new Error('Expected a Power BI Website or portal embed URL.');
    }
    // Accept only public, documented configuration. Never forward access tokens.
    const clean = new URL('https://app.powerbi.com/reportEmbed');
    for (const name of ['reportId', 'groupId', 'ctid']) {
      const value = url.searchParams.get(name);
      if (value) clean.searchParams.set(name, value);
    }
    const pageName = config.pages && config.pages[key];
    if (typeof pageName !== 'string' || !/^[A-Za-z0-9_-]{1,50}$/.test(pageName)) {
      throw new Error('Missing or invalid report page mapping.');
    }
    clean.searchParams.set('autoAuth', 'true');
    clean.searchParams.set('pageName', pageName);
    clean.searchParams.set('filterPaneEnabled', 'false');
    return clean.href;
  }
  async function init() {
    const slots = Array.from(document.querySelectorAll('[data-powerbi-page]'));
    if (!slots.length) return;
    try {
      const response = await fetch('powerbi-embed.json');
      if (!response.ok) throw new Error('Report configuration could not be loaded.');
      const config = await response.json();
      slots.forEach(slot => {
        try {
          const url = embedUrl(config, slot.dataset.powerbiPage);
          if (!url) return; // Keep the authored, accessible not-connected fallback.
          const button = document.createElement('button');
          button.type = 'button';
          button.className = 'btn btn-primary';
          button.textContent = 'Load interactive Power BI report';
          const help = document.createElement('p');
          help.textContent = 'Opens Microsoft Power BI. Sign in with an account that has report access.';
          const link = document.createElement('a');
          link.href = url;
          link.target = '_blank';
          link.rel = 'noopener noreferrer';
          link.textContent = 'Open report in a new tab';
          button.addEventListener('click', () => {
            const frame = document.createElement('iframe');
            frame.src = url;
            frame.title = slot.dataset.powerbiTitle || 'IR Lab Power BI report';
            frame.allowFullscreen = true;
            frame.loading = 'lazy';
            frame.referrerPolicy = 'strict-origin-when-cross-origin';
            frame.className = 'ir-powerbi-frame';
            button.replaceWith(frame);
          }, { once: true });
          slot.replaceChildren(button, help, link);
        } catch (error) {
          console.warn('IR Lab Power BI:', error.message);
        }
      });
    } catch (error) {
      console.warn('IR Lab Power BI:', error.message);
    }
  }
  if (typeof module !== 'undefined' && module.exports) module.exports = { embedUrl };
  if (typeof document !== 'undefined') {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init);
    else init();
  }
})();
