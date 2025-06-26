# Build stage
FROM --platform=$BUILDPLATFORM node:22-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install dependencies first for better caching
COPY package*.json ./

# Install Puppeteer with its own Chrome
ARG PUPPETEER_VERSION=latest
RUN if [ "$PUPPETEER_VERSION" != "latest" ]; then \
      npm install puppeteer@$PUPPETEER_VERSION; \
    else \
      npm install puppeteer; \
    fi && \
    npm install --production

# Runtime stage
FROM --platform=$TARGETPLATFORM node:22-slim

# Install fonts
RUN apt-get update && apt-get install -y \
    fonts-ipafont-gothic \
    fonts-wqy-zenhei \
    fonts-thai-tlwg \
    fonts-kacst \
    fonts-freefont-ttf \
    fonts-liberation \
    fonts-open-sans \
    fonts-crosextra-carlito \
    fonts-comic-neue \
    && apt-get clean

# Install tools
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    wget \
    && apt-get clean

# Install Chromium and prerequisites
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    libnss3 \
    libxcomposite1 \
    libxss1 \
    && apt-get install -y chromium

# Cleanup
RUN rm -rf /var/lib/apt/lists/* \
    && rm -rf /src/*.deb \
    && apt-get clean

# Set environment variables
ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0 \
    THREADS=5 \
    NPM_CONFIG_PREFIX=/home/pptruser/.npm-global \
    PATH=$PATH:/home/pptruser/.npm-global/bin \
    CHROME_PATH=/usr/bin/google-chrome-stable \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_TMP_DIR=/home/pptruser/app/tmp \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    CHROME_PATH=/usr/bin/chromium

RUN groupadd -r pptruser && useradd -r -g pptruser pptruser \
    && mkdir -p $PUPPETEER_TMP_DIR \
    && mkdir -p /home/pptruser/Downloads \
    && chown -R pptruser:pptruser /home/pptruser \
    && chmod -R 755 /home/pptruser \
    && usermod -a -G pptruser pptruser


# Set working directory
WORKDIR /home/pptruser/app

# Copy application files with correct ownership
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=pptruser:pptruser . .

# Ensure proper ownership of all files
RUN chown -R pptruser:pptruser /home/pptruser/app

# Switch to non-root user
USER pptruser

# Create a health check script
RUN printf '#!/bin/sh\nset -e\ncurl --fail --no-progress-meter --max-time 3 --show-error --silent "http://localhost:${PORT:-3000}/health" || exit 1\n' > /home/pptruser/healthcheck.sh && \
    chmod +x /home/pptruser/healthcheck.sh

# Expose the port the app runs on
EXPOSE 3000

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD ["/home/pptruser/healthcheck.sh"]

# Run the application
CMD ["node", "html2pdf-generator.js"]
