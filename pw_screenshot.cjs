const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({
    headless: true,
    executablePath: String.raw`C:\Users\Jihad\AppData\Local\ms-playwright\chromium-1228\chrome-win\chrome.exe`
  });
  const page = await browser.newPage();
  await page.setViewportSize({ width: 1400, height: 900 });

  console.log('Opening app...');
  await page.goto('http://localhost:9090', { waitUntil: 'domcontentloaded', timeout: 20000 });
  await page.waitForTimeout(5000);
  await page.screenshot({ path: 'screenshot_01_initial.png' });
  console.log('Screenshot 1 saved');
  await browser.close();
})().catch(e => { console.error(e.message); process.exit(1); });
