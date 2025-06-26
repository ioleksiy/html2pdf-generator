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

# Install Chrome and dependencies
RUN apt-get update && apt-get install -y \
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
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Install Chrome for the target platform
ARG TARGETARCH
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      CHROME_ARCH="x64"; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      CHROME_ARCH="arm64"; \
    elif [ "$TARGETARCH" = "arm" ]; then \
      CHROME_ARCH="arm"; \
    else \
      echo "Unsupported architecture: $TARGETARCH"; exit 1; \
    fi && \
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - && \
    echo "deb [arch=$TARGETARCH] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    apt-get install -y google-chrome-stable --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

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

# Run everything after as non-privileged user
USER pptruser

# Set environment variables
ENV NODE_ENV=production
ENV PORT=3000
ENV HOST=0.0.0.0
ENV THREADS=5

# Expose the port the app runs on
EXPOSE 3000

# Run the application
CMD ["node", "html2pdf-generator.js"]
