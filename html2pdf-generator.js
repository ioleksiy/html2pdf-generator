// API Keys are going with header "Authorization: Bearer key"

const express = require('express');
const bodyParser = require('body-parser');
const bearerToken = require('express-bearer-token');
const util = require('util');
const { program } = require('commander');

const options = program
  .version('1.0.0', '-v, --version')
  .usage('[OPTIONS]...')
  .option('-k, --keys <key,key,key>', 'Specify list of allowed API keys separated by comma and without spaces', '')
  .option('-h, --host <value>', 'Binding host', '0.0.0.0')
  .option('-p, --port <value>', 'Binding port', 3000)
  .option('-t, --threads <value>', 'Maximum browser threads', 5)
  .option('-c, --chromium <value>', 'Chromium browser path')
  .parse(process.argv).opts();

var keys = options.keys.split(',').filter(function(i) {
  return i.trim();
});

const pool = ((require('./puppet-pool'))({
  max: options.threads,
  acquireTimeoutMillis: 30000,
  priorityRange: 3
}, options.chromium));

/* For high load future
async function withPage(pageFunction) {
  const b = await pool.acquire();
  let context = null;
  if (b.createBrowserContext) {
    context = await b.createBrowserContext();
  } else if (b.createIncognitoBrowserContext) {
    context = await b.createIncognitoBrowserContext();
  }
  const page = await ((context || b).newPage());
  try {
    return await pageFunction(page);
  } finally {
    await page?.close();
    await context?.close();
    await pool.release(b);
  }
}
*/

async function withPage(pageFunction) {
  const b = await pool.acquire();
  const page = await b.newPage();
  try {
    return await pageFunction(page);
  } finally {
    await page?.close();
    await pool.release(b);
  }
}

const app = express();
app.use(bearerToken());
app.use(bodyParser.json());

async function generatePdf(page, html, options = {}) {
  try {
    if (!html) {
      throw new Error('HTML content is required');
    }

    // Set default viewport and user agent
    await page.setViewport({ width: 1200, height: 800, deviceScaleFactor: 1 });
    await page.setUserAgent('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    
    // Set content with proper timeout
    console.log('Setting page content...');
    await page.setContent(html, { 
      waitUntil: ['domcontentloaded', 'networkidle0'],
      timeout: 30000 
    });
    
    // Add some delay to ensure all resources are loaded
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Generate PDF with default options if none provided
    const pdfOptions = {
      format: 'A4',
      printBackground: true,
      margin: { top: '1cm', right: '1cm', bottom: '1cm', left: '1cm' },
      preferCSSPageSize: true,
      timeout: 30000,
      ...options
    };
    
    console.log('Generating PDF with options:', JSON.stringify(pdfOptions, null, 2));
    const pdf = await page.pdf(pdfOptions);
    
    // Handle different response formats
    if (pdf instanceof Buffer) {
      console.log('PDF generated successfully (Buffer)');
      return pdf;
    } else if (pdf && pdf.buffer instanceof ArrayBuffer) {
      console.log('PDF generated successfully (ArrayBuffer)');
      return Buffer.from(pdf.buffer);
    } else if (pdf && pdf.pdf instanceof ArrayBuffer) {
      console.log('PDF generated successfully (PDF ArrayBuffer)');
      return Buffer.from(pdf.pdf);
    } else if (pdf instanceof ArrayBuffer) {
      console.log('PDF generated successfully (Direct ArrayBuffer)');
      return Buffer.from(pdf);
    } else {
      console.error('Unexpected PDF format:', typeof pdf, Object.keys(pdf || {}));
      throw new Error('Unexpected PDF format received from page.pdf()');
    }
  } catch (error) {
    console.error('Error in generatePdf:', error);
    throw error; // Re-throw to be handled by the caller
  }
}

app.post('/generate', async function(req, res) {
  // Validate request
  if (keys.length > 0 && !keys.includes(req.token)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  if (!req.body || !req.body.html) {
    return res.status(400).json({ error: 'Missing required field: html' });
  }

  return withPage(async (page) => {
    try {
      // Set default PDF options if none provided
      const pdfOptions = req.body.options || {};
      
      // Generate PDF
      const pdf = await generatePdf(page, req.body.html, pdfOptions);
      
      // Validate PDF
      if (!Buffer.isBuffer(pdf) || pdf.length === 0) {
        throw new Error('Failed to generate PDF: Empty or invalid PDF buffer');
      }
      
      // Set response headers
      res.setHeader('Content-Type', 'application/pdf');
      res.setHeader('Content-Length', pdf.length);
      
      // Add filename to Content-Disposition if provided
      if (req.body.filename) {
        const filename = encodeURIComponent(req.body.filename);
        res.setHeader('Content-Disposition', `attachment; filename="${filename}"`);
      }
      
      // Send the PDF
      res.end(pdf);
      
    } catch (error) {
      console.error('Error generating PDF:', error);
      
      // Only send error response if headers haven't been sent yet
      if (!res.headersSent) {
        res.status(500).json({
          error: 'Failed to generate PDF',
          message: error.message,
          ...(process.env.NODE_ENV === 'development' ? { stack: error.stack } : {})
        });
      }
    }
  }); 
});

async function checkChromeAndPuppeteer() {
  return withPage(async (page) => {
  try {
    console.log('Health check: Attempting to acquire browser from pool...');
    console.log('Health check: Browser acquired, creating new page...');
    
    console.log('Health check: Page created, setting content...');
    
    // Set a timeout for page operations
    page.setDefaultNavigationTimeout(60000);
    page.setDefaultTimeout(30000);
    
    // Enable request/response logging
    page.on('request', request => console.log(`Request: ${request.method()} ${request.url()}`));
    page.on('response', response => console.log(`Response: ${response.status()} ${response.url()}`));
    page.on('console', msg => console.log('Page console:', msg.text()));
    page.on('pageerror', error => console.error('Page error:', error.message));
    page.on('error', error => console.error('Error event:', error.message));
    
    // Set viewport and user agent
    await page.setViewport({ width: 1200, height: 800, deviceScaleFactor: 1 });
    await page.setUserAgent('Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
    
    // Set content with a simple HTML that should definitely work
    const testHtml = `
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <title>Health Check</title>
          <style>
            body { font-family: Arial, sans-serif; margin: 0; padding: 20px; }
            h1 { color: #333; }
          </style>
        </head>
        <body>
          <h1>Health Check</h1>
          <p>This is a test PDF generated by the health check.</p>
          <p>Current time: ${new Date().toISOString()}</p>
        </body>
      </html>
    `;
    
    console.log('Health check: Setting content...');
    await page.setContent(testHtml, { 
      waitUntil: ['domcontentloaded', 'networkidle0'],
      timeout: 30000 
    });
    
    console.log('Health check: Taking screenshot for debugging...');
    await page.screenshot({ path: '/tmp/health-check-screenshot.png' });
    
    console.log('Health check: Generating PDF...');
    let pdf;
    try {
      const pdfResult = await page.pdf({ 
        format: 'A4',
        printBackground: true,
        margin: { top: '1cm', right: '1cm', bottom: '1cm', left: '1cm' },
        preferCSSPageSize: true,
        timeout: 30000
      });
      
      // Handle different response formats from page.pdf()
      if (pdfResult) {
        if (Buffer.isBuffer(pdfResult)) {
          // Already a Buffer
          pdf = pdfResult;
          console.log('PDF is already a Buffer');
        } else if (pdfResult.buffer && Buffer.isBuffer(pdfResult.buffer)) {
          // Has a .buffer property that's a Buffer
          pdf = pdfResult.buffer;
          console.log('Found PDF buffer in result.buffer');
        } else if (pdfResult.pdf && pdfResult.pdf instanceof ArrayBuffer) {
          // Has a .pdf property that's an ArrayBuffer
          console.log('Found PDF as ArrayBuffer in result.pdf');
          pdf = Buffer.from(pdfResult.pdf);
        } else if (pdfResult instanceof ArrayBuffer) {
          // The result itself is an ArrayBuffer
          console.log('PDF result is an ArrayBuffer');
          pdf = Buffer.from(pdfResult);
        } else {
          // Try to convert whatever we got to a Buffer
          console.log('Attempting to convert result to Buffer');
          pdf = Buffer.from(JSON.stringify(pdfResult));
        }
      } else {
        throw new Error('PDF result is null or undefined');
      }
      
      if (!Buffer.isBuffer(pdf)) {
        console.error(`PDF is not a Buffer after conversion, got type: ${typeof pdf}`, { 
          pdfType: typeof pdf,
          pdfResultType: typeof pdfResult,
          pdfResultKeys: pdfResult ? Object.keys(pdfResult) : 'null',
          isBuffer: Buffer.isBuffer(pdfResult),
          isArrayBuffer: pdfResult instanceof ArrayBuffer
        });
        throw new Error(`Failed to convert PDF to Buffer, got: ${typeof pdf}`);
      }
      
      if (pdf.length === 0) {
        throw new Error('Generated PDF is empty (0 bytes)');
      }
      
      console.log(`Health check: PDF generated successfully (${pdf.length} bytes)`);
    } catch (pdfError) {
      console.error('Error generating PDF:', pdfError);
      
      // Try to get more details about the page
      try {
        const pageContent = await page.content();
        console.log('Page content length:', pageContent.length);
        
        const pageTitle = await page.title();
        console.log('Page title:', pageTitle);
        
        const pageText = await page.evaluate(() => document.body.innerText);
        console.log('Page text length:', pageText.length);
      } catch (e) {
        console.error('Error getting page details:', e);
      }
      
      throw pdfError;
    }
    return { 
      success: true, 
      pdfSize: pdf.length,
      timestamp: new Date().toISOString() 
    };
  } catch (error) {
    console.error('Health check failed with error:', error);
    console.error('Error stack:', error.stack);
    
    return { 
      success: false, 
      error: error.message || 'Unknown error during health check',
      errorType: error.constructor.name,
      timestamp: new Date().toISOString(),
      nodeVersion: process.version,
      platform: process.platform,
      arch: process.arch
    };
  }
});
}

app.get('/health', async function(req, res) {
  try {
    console.log('Starting health check...');
    const healthCheck = await checkChromeAndPuppeteer();
    
    if (healthCheck.success) {
      console.log('Health check completed successfully');
      res.json({ 
        status: 'ok', 
        timestamp: healthCheck.timestamp,
        components: {
          chrome: 'ok',
          puppeteer: 'ok',
          pdf_generation: 'ok'
        },
        details: {
          pdfSize: healthCheck.pdfSize,
          nodeVersion: process.version,
          platform: process.platform,
          arch: process.arch
        }
      });
    } else {
      console.error('Health check failed:', healthCheck.error);
      res.status(500).json({
        status: 'error',
        timestamp: healthCheck.timestamp,
        error: healthCheck.error,
        errorType: healthCheck.errorType,
        components: {
          chrome: 'error',
          puppeteer: 'error',
          pdf_generation: 'error'
        },
        system: {
          nodeVersion: healthCheck.nodeVersion,
          platform: healthCheck.platform,
          arch: healthCheck.arch
        }
      });
    }
  } catch (error) {
    console.error('Health check endpoint error:', error);
    res.status(500).json({
      status: 'error',
      timestamp: new Date().toISOString(),
      error: 'Internal server error during health check',
      errorType: error.constructor.name,
      details: error.message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined,
      system: {
        nodeVersion: process.version,
        platform: process.platform,
        arch: process.arch
      }
    });
  }
});

var server = app.listen(options.port, options.host, function() {
  var host = server.address().address
  var port = server.address().port
  console.log("App listening at http://%s:%s", host, port)
});
