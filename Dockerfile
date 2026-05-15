FROM node:22-slim

# ── System tools ──────────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # core utils
    git curl wget ca-certificates gnupg \
    # build tools
    build-essential make cmake pkg-config \
    # Python
    python3 python3-pip python3-venv python3-dev \
    # shell tools
    bash zsh fish jq yq ripgrep fd-find fzf \
    # file tools
    unzip zip tar gzip bzip2 \
    # network
    openssh-client httpie netcat-openbsd dnsutils \
    # editors
    vim nano \
    # db clients
    sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# ── python3 → python alias ────────────────────────────────────────────────────
RUN ln -sf /usr/bin/python3 /usr/local/bin/python \
 && ln -sf /usr/bin/pip3    /usr/local/bin/pip

# ── Common Python packages ────────────────────────────────────────────────────
RUN pip install --no-cache-dir --break-system-packages \
    requests httpx aiohttp \
    flask fastapi uvicorn gunicorn \
    sqlalchemy alembic \
    pandas numpy matplotlib seaborn \
    pytest black ruff mypy pylint \
    python-dotenv pydantic \
    rich typer click \
    boto3 google-cloud-storage \
    openai anthropic \
    beautifulsoup4 lxml \
    pillow

# ── Global Node.js packages ───────────────────────────────────────────────────
RUN npm install -g \
    @anthropic-ai/claude-code \
    typescript ts-node tsx \
    eslint prettier \
    nodemon \
    http-server serve \
    pnpm

# ── Rust (for blazing-fast tools) ─────────────────────────────────────────────
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --no-modify-path
ENV PATH="/root/.cargo/bin:${PATH}"

# ── Go ────────────────────────────────────────────────────────────────────────
RUN curl -fsSL https://go.dev/dl/go1.22.4.linux-amd64.tar.gz \
    | tar -C /usr/local -xz
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/root/go"
ENV PATH="${GOPATH}/bin:${PATH}"

# ── Docker CLI (so the model can talk to the host Docker if needed) ───────────
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker.gpg \
 && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" \
    > /etc/apt/sources.list.d/docker.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends docker-ce-cli \
 && rm -rf /var/lib/apt/lists/*

# ── Browser automation (Playwright + Puppeteer) ──────────────────────────────
# Install Chromium and its dependencies for headless browser use
RUN apt-get update && apt-get install -y --no-install-recommends     chromium     chromium-driver     fonts-liberation     fonts-noto     libnss3 libatk1.0-0 libatk-bridge2.0-0     libcups2 libxcomposite1 libxdamage1     libxrandr2 libgbm1 libxkbcommon0 libasound2     && rm -rf /var/lib/apt/lists/*

ENV CHROME_BIN=/usr/bin/chromium
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
ENV PLAYWRIGHT_BROWSERS_PATH=/usr/bin

# Python browser libs
RUN pip install --no-cache-dir --break-system-packages     playwright     selenium     pyppeteer     mechanize     scrapy

# Playwright installs its own browser binaries — point it at system Chromium
RUN python3 -m playwright install-deps chromium 2>/dev/null || true

# Node browser libs
RUN npm install -g puppeteer-core

# ── Proxy + entrypoint ────────────────────────────────────────────────────────
RUN mkdir -p /proxy
COPY proxy.js /proxy/proxy.js
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /workspace
ENTRYPOINT ["/entrypoint.sh"]
