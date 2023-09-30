# html2pdf-generator
Web application which is using headless Puppeteer to generate PDF out of HTML

Make a post request to `/generate` with JSON object where only `html` field is mandatory. Other fields are optional. `options` field proxies https://pptr.dev/api/puppeteer.pdfoptions information. `filename` - if you would like to get back the file with filename on it.

JSON Example:

{
    "options": {
      "format": "A4",
      "displayHeaderFooter": true,
      "headerTemplate": "<span style=\"font-size: 30px; width: 200px; height: 200px; background-color: black; color: white; margin: 20px;\">Header</span>",
      "footerTemplate": "<span style=\"font-size: 30px; width: 50px; height: 50px; background-color: red; color:black; margin: 20px;\">Footer <span class=\"pageNumber\">a</span></span>"
    },
    "filename": "my.pdf",
    "html": "HTML encoded content"
}
