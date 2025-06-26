# HTML to PDF Generator

A lightweight, stateless microservice that converts HTML to PDF using Puppeteer. Designed for internal network use within containerized environments.

## Features

- 🚀 Fast HTML to PDF conversion using headless Chrome
- 🐳 Container-first design with multi-architecture support
- ⚡ Stateless operation - no database or persistent storage
- 🔄 Automatic retry support in case of failures
- 🛡️ Simple API key authentication

## Docker Image

```bash
docker pull ioleksiy/html2pdf-generator:latest
```

### Tags
- `latest` - Latest stable version with the most recent Puppeteer
- `{puppeteer-version}` - Specific Puppeteer version (e.g., `21.3.6`)

## Usage

### Run with Docker

```bash
docker run -p 3000:3000 -e KEYS=your-api-key ioleksiy/html2pdf-generator:latest
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 3000 | Port to listen on |
| `HOST` | 0.0.0.0 | Host to bind to |
| `THREADS` | 5 | Maximum number of concurrent PDF generations |
| `KEYS` | (none) | Comma-separated list of API keys (if empty, no auth required) |

### API

#### Generate PDF

```
POST /generate
Content-Type: application/json
Authorization: Bearer your-api-key

{
  "html": "<h1>Hello World</h1>",
  "options": {
    "format": "A4",
    "margin": {
      "top": "20mm",
      "right": "20mm",
      "bottom": "20mm",
      "left": "20mm"
    }
  },
  "filename": "document.pdf"
}
```

**Response**
- `200 OK` - PDF file with `Content-Type: application/pdf`
- `400 Bad Request` - Invalid input
- `401 Unauthorized` - Missing or invalid API key
- `500 Internal Server Error` - Generation failed

### Options

All [Puppeteer PDF options](https://pptr.dev/api/puppeteer.pdfoptions) are supported in the `options` field.

## Development

```bash
# Install dependencies
npm install

# Start development server
npm run dev
```

## Building

```bash
# Build Docker image
docker build -t html2pdf-generator .

# Run tests
npm test
```

## License

ISC
