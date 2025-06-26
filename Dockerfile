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

# Install minimal runtime dependencies for Puppeteer
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Install minimal required libraries
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
    # Fonts
    fonts-liberation \
    # Other dependencies
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
    libxkbcommon0 \
    xdg-utils \
    # Clean up
    && rm -rf /var/lib/apt/lists/*

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
    THREADS=5

# Create necessary directories with correct permissions
RUN mkdir -p /home/pptruser/app/tmp && \
    chown -R pptruser:pptruser /home/pptruser && \
    chmod -R 755 /home/pptruser

# Set working directory
WORKDIR /home/pptruser/app

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
