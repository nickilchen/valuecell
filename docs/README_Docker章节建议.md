# README Docker 章节建议

建议在 README.zh.md 中添加以下 Docker 部署章节：

---

## 🐳 Docker 部署

### 快速开始

使用 Docker 部署 ValueCell 是最简单的方式，无需安装 Python、Node.js 或其他依赖。

#### 前置条件

- Docker 20.10+
- Docker Compose 2.0+
- 至少 8GB 可用内存

#### 一键部署

```bash
# 1. 克隆项目
git clone https://github.com/ValueCell-ai/valuecell.git
cd valuecell

# 2. 配置环境变量
cp .env.example .env
# 编辑 .env 文件，添加至少一个 LLM API Key

# 3. 启动服务
docker-compose up -d

# 4. 访问应用
# Web 界面: http://localhost:8000
# API 文档: http://localhost:8000/docs
```

### 构建选项

#### 标准构建（推荐）

```bash
docker build -t valuecell:latest .
```

#### 优化构建（更快）

```bash
# 先构建前端
cd frontend && npm run build && cd ..

# 使用优化版 Dockerfile
docker build -f Dockerfile.optimized -t valuecell:latest .
```

#### 使用 Makefile

```bash
# 查看所有命令
make help

# 构建并运行
make build
make run

# 或使用 docker-compose
make up
```

### 配置说明

#### 必需配置

在 `.env` 文件中至少配置一个 LLM 提供商：

```bash
# OpenRouter (推荐)
OPENROUTER_API_KEY=sk-or-v1-xxxxx

# 或 Google Gemini
GOOGLE_API_KEY=AIzaSyD-xxxxx

# 或 SiliconFlow
SILICONFLOW_API_KEY=sk-xxxxx
```

#### 可选配置

```bash
# 金融数据 API
FINNHUB_API_KEY=your_key
SEC_EMAIL=your_email@example.com

# 雪球 Token（可选）
XUEQIU_TOKEN=your_token
```

### 数据持久化

使用数据卷保存重要数据：

```bash
docker run -d \
  --name valuecell \
  -p 8000:8000 \
  -v $(pwd)/.env:/app/.env \
  -v valuecell-logs:/app/logs \
  -v valuecell-db:/app/lancedb \
  -v valuecell-knowledge:/app/.knowledgebase \
  valuecell:latest
```

### 常用命令

```bash
# 查看日志
docker logs -f valuecell

# 进入容器
docker exec -it valuecell bash

# 停止服务
docker stop valuecell

# 重启服务
docker restart valuecell

# 查看状态
docker ps
```

### 详细文档

- [Docker 快速开始](docs/Docker快速开始.md)
- [Docker 完整部署指南](docs/Docker部署指南.md)
- [Docker 故障排查指南](docs/Docker故障排查指南.md)

或加入我们的 [Discord 社区](https://discord.com/invite/84Kex3GGAh) 获取帮助。

### 系统要求

| 组件 | 最低要求 | 推荐配置 |
|------|---------|---------|
| CPU | 2 核 | 4 核+ |
| 内存 | 4GB | 8GB+ |
| 磁盘 | 10GB | 20GB+ |
| Docker | 20.10+ | 最新版 |

---

## 传统部署方式

如果你不想使用 Docker，也可以使用传统方式部署：

### Linux / macOS
```bash
bash start.sh
```

### Windows (PowerShell)
```powershell
.\start.ps1
```

详见下方的[快速开始](#快速开始)章节。
