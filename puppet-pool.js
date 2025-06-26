const puppeteer = require('puppeteer');
const genericPool = require("generic-pool");

const tmpDir = process.env.PUPPETEER_TMP_DIR || path.join(os.tmpdir(), 'puppeteer');

module.exports = function(opts, chromiumPath) {
  var params = {
    headless: 'new',
    executablePath: chromiumPath || '/usr/bin/chromium',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-accelerated-2d-canvas',
      '--disable-gpu',
      '--window-size=1920x1080',
      '--single-process',
      `--disk-cache-dir=${tmpDir}`,
      '--disable-application-cache',
      '--media-cache-size=0',
      '--disk-cache-size=0'
    ],
    ignoreHTTPSErrors: true,
    defaultViewport: {
      width: 1920,
      height: 1080,
      deviceScaleFactor: 1,
    },
    dumpio: false
  };
  
  var pool = genericPool.createPool({
    create: async function() {
      return await puppeteer.launch(params);
    },
    destroy: async function(browser) {
      //close the browser
      await browser.close();
    }
  }, opts);

  process.on('SIGTERM', async () => {
    await pool.drain();
    await pool.clear();
  });

  pool.on('factoryCreateError', function(err) {
    console.log(err);
  });

  pool.on('factoryDestroyError', function(err) {
    console.log(err);
  });
  return pool;
};