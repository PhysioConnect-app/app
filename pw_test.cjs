const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: false, slowMo: 200 });
  const page = await browser.newPage();
  await page.setViewportSize({ width: 1400, height: 900 });

  console.log('Opening app...');
  await page.goto('http://localhost:9090', { waitUntil: 'networkidle', timeout: 30000 });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'C:/Users/Jihad/my_clinic_app/screenshot_01_initial.png', fullPage: false });
  console.log('Screenshot 1 saved');
  await browser.close();
})().catch(e => { console.error(e.message); process.exit(1); });
