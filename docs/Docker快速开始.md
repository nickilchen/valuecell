# Docker 快速开始指南

## 🚀 5 分钟快速部署

### 前置条件

- ✅ 已安装 Docker（20.10+）
- ✅ 已安装 Docker Compose（2.0+）
- ✅ 至少 8GB 可用内存

### 步骤 1: 克隆项目

```bash
git clone https://github.com/ValueCell-ai/valuecell.git
cd valuecell
```

### 步骤 2: 配置环境变量

```bash
# 复制环境变量模板
cp .env.example .env

# 编辑 .env 文件，配置至少一个 LLM API Key
# 使用你喜欢的编辑器
nano .env
# 或
vim .env
```

**必需配置**（至少选择一个）:
```bash
# OpenRouter (推荐，支持多种模型)
OPENROUTER_API_KEY=sk-or-v1-xxxxx

# 或 Google Gemini
GOOGLE_API_KEY=AIzaSyD-xxxxx

# 或 SiliconFlow (中文模型)
SILICONFLOW_API_KEY=sk-xxxxx
```

### 步骤 3: 构建并启动

**方法 A: 使用 Docker Compose（最简单）**

```bash
docker-compose up -d
```

**方法 B: 使用构建脚本**

```bash
# Linux/Mac
bash build-docker.sh
docker run -d -p 8000:8000 -v $(pwd)/.env:/app/.env valuecell:latest

# Windows (PowerShell)
bash build-docker.sh
docker run -d -p 8000:8000 -v ${PWD}/.env:/app/.env valuecell:latest
```

**方法 C: 使用 Makefile**

```bash
make build
make run
```

### 步骤 4: 访问应用

等待约 30-60 秒让服务启动，然后访问：

- 🌐 **Web 界面**: http://localhost:8000
- 📚 **API 文档**: http://localhost:8000/docs
- ❤️ **健康检查**: http://localhost:8000/health

## 📊 查看状态

```bash
# 查看容器状态
docker ps

# 查看日志
docker logs -f valuecell

# 或使用 docker-compose
docker-compose logs -f
```

## 🛑 停止服务

```bash
# 使用 docker-compose
docker-compose down

# 或直接停止容器
docker stop valuecell
```

## 🔧 常见问题

### 问题 1: 前端构建失败

**错误信息**: `Export named 'renderToPipeableStream' not found`

**解决方案**: 已在最新的 Dockerfile 中修复，使用 Node.js 代替 Bun 构建前端。

如果仍有问题，使用优化构建：
```bash
# 先在本地构建前端
cd frontend
npm install
npm run build
cd ..

# 使用优化版 Dockerfile
docker build -f Dockerfile.optimized -t valuecell:latest .
```

### 问题 2: 端口被占用

**错误信息**: `port is already allocated`

**解决方案**: 更改端口映射
```bash
# 使用其他端口，如 9000
docker run -d -p 9000:8000 -v $(pwd)/.env:/app/.env valuecell:latest

# 访问 http://localhost:9000
```

### 问题 3: 内存不足

**错误信息**: `signal SIGKILL`

**解决方案**: 增加 Docker 内存限制
- Docker Desktop: Settings → Resources → Memory (设置为 8GB+)

### 问题 4: API Key 未配置

**错误信息**: 服务启动但无法使用

**解决方案**: 检查 .env 文件
```bash
# 查看容器内的环境变量
docker exec valuecell env | grep API_KEY

# 确保至少配置了一个 LLM 提供商的 API Key
```

## 🎯 下一步

### 配置更多功能

编辑 `.env` 文件添加更多配置：

```bash
# 金融数据 API
FINNHUB_API_KEY=your_key_here
SEC_EMAIL=your_email@example.com

# 雪球 Token（可选，用于更稳定的中国市场数据）
XUEQIU_TOKEN=your_token_here
```

### 数据持久化

使用数据卷保存数据：

```bash
docker run -d \
  -p 8000:8000 \
  -v $(pwd)/.env:/app/.env \
  -v valuecell-logs:/app/logs \
  -v valuecell-db:/app/lancedb \
  -v valuecell-knowledge:/app/.knowledgebase \
  valuecell:latest
```

### 查看详细日志

```bash
# 查看所有日志
docker exec valuecell ls -la /app/logs/

# 查看特定日志
docker exec valuecell tail -f /app/logs/*/backend.log
```

## 📖 更多文档

- [完整 Docker 部署指南](Docker部署指南.md)
- [故障排查指南](Docker故障排查指南.md)
- [配置指南](CONFIGURATION_GUIDE.md)

## 💬 获取帮助

- 💬 [Discord 社区](https://discord.com/invite/84Kex3GGAh)
- 🐛 [GitHub Issues](https://github.com/ValueCell-ai/valuecell/issues)

## 🎉 完成！

现在你已经成功部署了 ValueCell！开始探索多智能体金融平台的强大功能吧！
