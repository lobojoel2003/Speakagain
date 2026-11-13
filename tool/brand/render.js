// Renders the brand SVGs to PNG: node tool/brand/render.js
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 }, deviceScaleFactor: 1 });
  const out = path.resolve(__dirname, '../../assets/brand');
  for (const [svg, png, transparent] of [
    ['icon.svg', 'icon.png', false],
    ['foreground.svg', 'icon-foreground.png', true],
    ['monochrome.svg', 'icon-monochrome.png', true],
  ]) {
    const markup = fs.readFileSync(path.join(__dirname, svg), 'utf8');
    await page.setContent(`<html><body style="margin:0;background:transparent">${markup.replace('<svg ', '<svg width="1024" height="1024" ')}</body></html>`);
    await page.screenshot({ path: path.join(out, png), omitBackground: transparent, clip: { x: 0, y: 0, width: 1024, height: 1024 } });
  }
  await browser.close();
})();
