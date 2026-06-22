const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: false, slowMo: 300 });
  const page = await browser.newPage();
  await page.setViewportSize({ width: 1400, height: 900 });

  console.log('Navigating to app...');
  await page.goto('http://localhost:9090', { waitUntil: 'networkidle', timeout: 30000 });
  await page.screenshot({ path: 'C:/Users/Jihad/my_clinic_app/screenshot_login.png' });
  console.log('Login page screenshot saved');

  // Wait for any splash/loading
  await page.waitForTimeout(3000);
  await page.screenshot({ path: 'C:/Users/Jihad/my_clinic_app/screenshot_after_load.png' });
  console.log('Done');

  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
