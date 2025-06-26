const puppeteer = require('puppeteer');
const genericPool = require("generic-pool");

module.exports = function(opts, chromiumPath) {
  var params = {
    headless: 'new',
    args: [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-accelerated-2d-canvas',
      '--disable-gpu',
      '--window-size=1920x1080',
      '--single-process'
    ],
    ignoreHTTPSErrors: true,
    defaultViewport: {
      width: 1920,
      height: 1080,
      deviceScaleFactor: 1,
    },
    dumpio: false
  };
  
  // Use Chromium by default if no path is provided
  params.executablePath = chromiumPath || '/usr/bin/chromium';
  
  // Additional arguments for better stability
  if (process.env.NO_SANDBOX) {
    params.args.push('--no-sandbox');
    params.args.push('--disable-setuid-sandbox');
  }
  var pool = genericPool.createPool({
    create: function() {
      //open an instance of the Chrome headless browser - Heroku buildpack requires these args
      return puppeteer.launch(params);
    },
    destroy: function(client) {
      //close the browser
      client.close();
    }
  }, opts);

  pool.on('factoryCreateError', function(err) {
    console.log(err);
  });

  pool.on('factoryDestroyError', function(err) {
    console.log(err);
  });
  return pool;
};
/*
async function destroyChromePool() {
  // Only call this once in your application -- at the point you want to shutdown and stop using this pool.
  global.chromepool.drain().then(function() {
    global.chromepool.clear();
  });

}*/
