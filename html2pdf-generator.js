// API Keys are going with header "Authorization: Bearer key"

const express = require('express');
const bodyParser = require('body-parser');
const bearerToken = require('express-bearer-token');
// Removed fs and path as they're no longer needed
const commander = require('commander');

const options = commander
  .version('1.0.0', '-v, --version')
  .usage('[OPTIONS]...')
  .option('-k, --keys <key,key,key>', 'Specify list of allowed API keys separated by comma and without spaces', '')
  .option('-h, --host <value>', 'Binding host', '0.0.0.0')
  .option('-p, --port <value>', 'Binding port', 3000)
  .option('-t, --threads <value>', 'Maximum browser threads', 5)
  .option('-ch, --chromium <value>', 'Chromium browser path')
  .parse(process.argv).opts();

var keys = options.keys.split(',').filter(function(i) {
  return i.trim();
});

const pool = ((require('./puppet-pool'))({
  max: options.threads,
  acquireTimeoutMillis: 120000,
  priorityRange: 3
}, options.chromium));

const app = express();
app.use(bearerToken());
app.use(bodyParser.json());

async function generatePdf(browser, text, params) {
  try {
    if (!text) {
      throw 'Wrong text';
    }
    const page = await browser.newPage();
    try {
      await page.setContent(text);
      return await page.pdf(params);
    } finally {
      await page.close();
    }
  } catch (e) {
    console.log(e);
  }
  return false;
}

app.post('/generate', function(req, res) {
  if (keys.length > 0 && !keys.includes(req.token)) {
    res.sendStatus(401);
    return;
  }
  pool.acquire().then((browser) => {
    var pdfOptions = {};
    if (req.body.options) {
      pdfOptions = req.body.options;
    }
    generatePdf(browser, req.body.html, pdfOptions).then((pdf) => {
      pool.release(browser);
      if (!Buffer.isBuffer(pdf)) {
        res.sendStatus(400);
        res.end(pdf);
      } else {
        res.setHeader('Content-Length', Buffer.byteLength(pdf));
        res.setHeader('Content-Type', 'application/pdf');
        if (req.body.filename) {
          res.setHeader('Content-Disposition', 'attachment; filename='+req.body.filename);
        }
        res.write(pdf);
        res.end();
      }
    });
    /*
    const page = browser.newPage().then((page) => {
      page.setContent(req.body.html).then(() => {
        page.pdf(pdfOptions).then((pdf) => {
          pool.release(browser);
          res.end();
        });
      });
    });*/
  });
});

app.get('/health', function(req, res) {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

var server = app.listen(options.port, options.host, function() {
  var host = server.address().address
  var port = server.address().port
  console.log("App listening at http://%s:%s", host, port)
});
