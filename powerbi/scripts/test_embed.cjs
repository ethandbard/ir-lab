const assert = require('node:assert/strict');
const { embedUrl } = require('../../powerbi-embed.js');
const config = {
  embedUrl: 'https://app.powerbi.com/reportEmbed?reportId=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee&ctid=tenant&accessToken=do-not-forward',
  pages: { regression: 'ReportSectionRegression' }
};
const u = new URL(embedUrl(config, 'regression'));
assert.equal(u.searchParams.get('pageName'), 'ReportSectionRegression');
assert.equal(u.searchParams.get('autoAuth'), 'true');
assert.equal(u.searchParams.has('accessToken'), false);
assert.equal(embedUrl({ embedUrl: '' }, 'regression'), null);
for (const embedUrlValue of ['javascript:alert(1)', 'https://evil.example/reportEmbed', 'https://app.powerbi.com.evil.example/reportEmbed', 'https://app.powerbi.com/view?r=public', 'https://app.powerbi.com/reportEmbed?reportId=invalid']) {
  assert.throws(() => embedUrl({ ...config, embedUrl: embedUrlValue }, 'regression'));
}
assert.throws(() => embedUrl(config, 'unknown'));
console.log('Embed URL, missing configuration, page mapping, and token handling checks passed.');
