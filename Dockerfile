# syntax=docker/dockerfile:1.4

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

# Install Chromium and dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    libx11-6 \
    libxcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxrandr2 \
    libxrender1 \
    libxshmfence1 \
    libxtst6 \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libglib2.0-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libxkbcommon0 \
    wget \
    # Install Chromium
    && apt-get install -y chromium \
    # Clean up
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /src/*.deb \
    && apt-get clean

# Set Puppeteer to use the correct browser
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV CHROME_PATH=/usr/bin/chromium

# Create non-root user and set up directories
RUN groupadd -r pptruser && useradd -r -g pptruser -G audio,video pptruser \
    && mkdir -p /home/pptruser/app/tmp \
    && mkdir -p /home/pptruser/Downloads \
    && chown -R pptruser:pptruser /home/pptruser \
    && chmod -R 755 /home/pptruser

# Set environment variables
ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0 \
    THREADS=5 \
    NPM_CONFIG_PREFIX=/home/pptruser/.npm-global \
    PATH=$PATH:/home/pptruser/.npm-global/bin \
    CHROME_PATH=/usr/bin/google-chrome-stable

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
