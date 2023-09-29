const puppeteer = require('puppeteer');
const genericPool = require("generic-pool");

module.exports = function(opts) {
  var pool = genericPool.createPool({
    create: function() {
      //open an instance of the Chrome headless browser - Heroku buildpack requires these args
      return puppeteer.launch({
        headless: 'new',
        args: ['--no-sandbox', '--disable-setuid-sandbox', '--ignore-certificate-errors']
      });
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
