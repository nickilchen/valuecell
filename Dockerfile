# ============================================
# ValueCell Docker 镜像
# 多阶段构建，优化镜像大小和构建速度
# ============================================

# ============================================
# 阶段 1: 前端构建
# ============================================
FROM node:20-alpine AS frontend-builder

WORKDIR /app/frontend

# 安装 pnpm (更快的包管理器)
#RUN npm install -g pnpm

# 复制前端依赖文件
COPY frontend/package.json ./

RUN npm install 

# 复制前端源代码
COPY frontend/ ./

# 设置 Node.js 环境变量以增加内存限制
ENV NODE_OPTIONS="--max-old-space-size=4096"

# 构建前端生产版本
RUN npm run build

# ============================================
# 阶段 2: Python 依赖安装
# ============================================
FROM python:3.12-slim AS python-builder

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# 安装 uv (Python 包管理器)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# 复制 Python 项目文件
COPY python/pyproject.toml python/uv.lock* /app/python/

# 切换到 python 目录
WORKDIR /app/python

# 创建虚拟环境并安装依赖
RUN uv venv --python 3.12 && \
    uv sync --no-dev

# 安装 Playwright 浏览器 (用于 crawl4ai)
RUN uv run playwright install --with-deps chromium

# ============================================
# 阶段 3: 第三方 Agent 依赖安装
# ============================================
FROM python:3.12-slim AS third-party-builder

WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# 安装 uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# 复制第三方 Agent 项目文件
COPY python/third_party/ /app/python/third_party/

# 安装 ai-hedge-fund 依赖
WORKDIR /app/python/third_party/ai-hedge-fund
RUN if [ -f "pyproject.toml" ]; then \
        uv venv --python 3.12 && \
        uv sync --no-dev; \
    fi

# 安装 TradingAgents 依赖
WORKDIR /app/python/third_party/TradingAgents
RUN if [ -f "pyproject.toml" ]; then \
        uv venv --python 3.12 && \
        uv sync --no-dev; \
    fi

# ============================================
# 阶段 4: 最终运行镜像
# ============================================
FROM python:3.12-slim

LABEL maintainer="ValueCell Team"
LABEL description="ValueCell - Community-driven multi-agent financial platform"
LABEL version="0.1.0"

WORKDIR /app

# 安装运行时系统依赖
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    # Playwright 运行时依赖
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdrm2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpango-1.0-0 \
    libcairo2 \
    && rm -rf /var/lib/apt/lists/*

# 安装 uv
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# 复制 Python 虚拟环境和依赖
COPY --from=python-builder /app/python/.venv /app/python/.venv
COPY --from=python-builder /root/.cache/ms-playwright /root/.cache/ms-playwright

# 复制第三方 Agent 虚拟环境
COPY --from=third-party-builder /app/python/third_party /app/python/third_party

# 复制 Python 源代码
COPY python/ /app/python/

# 复制前端构建产物
COPY --from=frontend-builder /app/frontend/build /app/frontend/build
COPY --from=frontend-builder /app/frontend/package.json /app/frontend/

# 复制配置文件
COPY .env.example /app/.env.example

# 创建必要的目录
RUN mkdir -p /app/logs /app/lancedb /app/.knowledgebase

# 设置环境变量
ENV PYTHONUNBUFFERED=1 \
    PYTHONIOENCODING=utf-8 \
    PATH="/app/python/.venv/bin:$PATH" \
    APP_ENVIRONMENT=production \
    API_HOST=0.0.0.0 \
    API_PORT=8000

# 切换到 python 目录
WORKDIR /app/python

# 初始化数据库
RUN uv run valuecell/server/db/init_db.py || true

# 暴露端口
# 8000: 后端 API
# 1420: 前端 (如果需要单独运行)
EXPOSE 8000 1420

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# 创建启动脚本
COPY docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

# 设置入口点
ENTRYPOINT ["/app/docker-entrypoint.sh"]

# 默认命令：启动所有服务
CMD ["all"]
