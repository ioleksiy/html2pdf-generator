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

# Allow passing Puppeteer version via build arg
ARG PUPPETEER_VERSION=latest
RUN if [ "$PUPPETEER_VERSION" != "latest" ]; then \
      npm install puppeteer@$PUPPETEER_VERSION; \
    else \
      npm install puppeteer; \
    fi && \
    npm install --production

# Runtime stage
FROM --platform=$TARGETPLATFORM node:22-slim

# Install system dependencies first
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    wget \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Chrome and its dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    libxshmfence1 \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Chrome for the target platform
ARG TARGETARCH
RUN if [ "$TARGETARCH" = "amd64" ] || [ "$TARGETARCH" = "arm64" ] || [ "$TARGETARCH" = "arm" ]; then \
        # Update package lists first \
        apt-get update && \
        # Install Chrome dependencies \
        apt-get install -y --no-install-recommends \
            libxss1 \
            libxtst6 \
            libnss3 \
            libx11-xcb1 \
            libxcb1 \
            libx11-2 \
            libxcomposite1 \
            libxdamage1 \
            libxext6 \
            libxfixes3 \
            libxrandr2 \
            libxrender1 \
            libxshmfence1 \
            libxslt1.1 \
            libcups2 \
            libxcb-dri3-0 \
            libdrm2 \
            libgbm1 \
            libasound2 \
            libatk1.0-0 \
            libatk-bridge2.0-0 \
            libgtk-3-0 \
            libnss3-tools \
            xdg-utils \
            fonts-liberation && \
        # Add Google Chrome repository \
        wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-archive-keyring.gpg && \
        echo "deb [arch=$TARGETARCH signed-by=/usr/share/keyrings/google-chrome-archive-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
        # Install Chrome \
        apt-get update && \
        apt-get install -y google-chrome-stable --no-install-recommends && \
        # Clean up \
        rm -rf /var/lib/apt/lists/* \
               /etc/apt/sources.list.d/google-chrome.list \
               /usr/share/keyrings/google-chrome-archive-keyring.gpg; \
    else \
        echo "Unsupported architecture: $TARGETARCH"; exit 1; \
    fi

# Create app directory
WORKDIR /app

# Copy built node_modules and source
COPY --from=builder /app/node_modules ./node_modules
COPY . .

# Create a non-root user
RUN groupadd -r pptruser && useradd -r -g pptruser -G audio,video pptruser \
    && mkdir -p /home/pptruser/Downloads \
    && chown -R pptruser:pptruser /home/pptruser \
    && chown -R pptruser:pptruser /app

# Set environment variables
ENV NODE_ENV=production \
    PORT=3000 \
    HOST=0.0.0.0 \
    THREADS=5 \
    NPM_CONFIG_PREFIX=/home/pptruser/.npm-global \
    PATH=$PATH:/home/pptruser/.npm-global/bin

# Create necessary directories with correct permissions
RUN mkdir -p /home/pptruser/app/tmp && \
    chown -R pptruser:pptruser /home/pptruser && \
    chmod -R 755 /home/pptruser

# Set working directory
WORKDIR /home/pptruser/app

# Copy built node_modules and source
COPY --from=builder /app/node_modules ./node_modules
COPY --chown=pptruser:pptruser . .

# Ensure proper ownership of all files
RUN chown -R pptruser:pptruser /home/pptruser/app

# Run everything after as non-privileged user
USER pptruser

# Create a health check script
RUN echo '#!/bin/sh\n\
set -e\n\
# Check if the health endpoint is responding\nwget --no-verbose --tries=1 --spider http://localhost:${PORT:-3000}/health || exit 1\n' > /healthcheck.sh && \
    chmod +x /healthcheck.sh

# Expose the port the app runs on
EXPOSE 3000

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 CMD ["/healthcheck.sh"]

# Use tini as init process for proper signal handling
ENTRYPOINT ["/tini", "--"]

# Run the application
CMD ["node", "html2pdf-generator.js"]
