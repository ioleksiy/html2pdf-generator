const puppeteer = require('puppeteer');
const genericPool = require("generic-pool");

module.exports = function(opts, chromiumPath) {
  var params = {
    headless: 'new',
    args: [
      "--disable-gpu", // usually not available on containers
      "--disable-dev-shm-usage", // This flag is necessary to avoid running into issues with Docker’s default low shared memory space of 64MB. Chrome will write into /tmp instead
      // disable sandbox when using ROOT user (not recommended)
      "--disable-setuid-sandbox",
      "--no-sandbox",
      "--single-process" // FATAL:zygote_main_linux.cc(162)] Check failed: sandbox::ThreadHelpers::IsSingleThreaded()
      //'--no-sandbox',
      //'--disable-setuid-sandbox',
      //'--ignore-certificate-errors'
    ]
  };
  if (chromiumPath) {
    params.executablePath = chromiumPath;
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
