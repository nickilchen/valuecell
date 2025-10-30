# ValueCell Docker 部署指南

本文档介绍如何使用 Docker 部署 ValueCell 项目。

## 📋 目录

- [前置要求](#前置要求)
- [快速开始](#快速开始)
- [构建镜像](#构建镜像)
- [运行容器](#运行容器)
- [Docker Compose](#docker-compose)
- [配置说明](#配置说明)
- [数据持久化](#数据持久化)
- [常见问题](#常见问题)
- [高级用法](#高级用法)

## 前置要求

### 系统要求
- Docker Engine 20.10+ 或 Docker Desktop
- Docker Compose 2.0+ (可选，用于 docker-compose 部署)
- 至少 8GB 可用内存
- 至少 20GB 可用磁盘空间

### 安装 Docker

**Linux:**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
```

**macOS / Windows:**
下载并安装 [Docker Desktop](https://www.docker.com/products/docker-desktop)

## 快速开始

### 1. 准备配置文件

复制环境变量模板并配置：

```bash
cp .env.example .env
```

编辑 `.env` 文件，至少配置以下必需项：

```bash
# 必需：至少配置一个 LLM 提供商
OPENROUTER_API_KEY=your_api_key_here
# 或
GOOGLE_API_KEY=your_api_key_here
# 或
SILICONFLOW_API_KEY=your_api_key_here

# 可选：金融数据 API
FINNHUB_API_KEY=your_finnhub_key
SEC_EMAIL=your_email@example.com
```

### 2. 使用 Docker Compose (推荐)

最简单的方式：

```bash
# 启动所有服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

### 3. 访问应用

- **Web 界面**: http://localhost:8000
- **API 文档**: http://localhost:8000/docs
- **健康检查**: http://localhost:8000/health

## 构建镜像

### 基础构建

```bash
docker build -t valuecell:latest .
```

### 指定平台构建

```bash
# 构建 AMD64 架构
docker build --platform linux/amd64 -t valuecell:amd64 .

# 构建 ARM64 架构 (Apple Silicon)
docker build --platform linux/arm64 -t valuecell:arm64 .

# 多平台构建
docker buildx build --platform linux/amd64,linux/arm64 -t valuecell:latest .
```

### 构建参数

```bash
# 使用构建缓存加速
docker build --cache-from valuecell:latest -t valuecell:latest .

# 不使用缓存重新构建
docker build --no-cache -t valuecell:latest .
```

## 运行容器

### 基础运行

```bash
docker run -d \
  --name valuecell \
  -p 8000:8000 \
  -v $(pwd)/.env:/app/.env \
  valuecell:latest
```

### 完整配置运行

```bash
docker run -d \
  --name valuecell \
  --restart unless-stopped \
  -p 8000:8000 \
  -v $(pwd)/.env:/app/.env:ro \
  -v valuecell-logs:/app/logs \
  -v valuecell-db:/app/lancedb \
  -v valuecell-knowledge:/app/.knowledgebase \
  -e APP_ENVIRONMENT=production \
  valuecell:latest
```

### 运行特定服务

```bash
# 只运行后端
docker run -d -p 8000:8000 -v $(pwd)/.env:/app/.env valuecell:latest backend

# 只运行 Research Agent
docker run -d -v $(pwd)/.env:/app/.env valuecell:latest research-agent

# 只运行 Auto Trading Agent
docker run -d -v $(pwd)/.env:/app/.env valuecell:latest trading-agent
```

### 交互式运行 (调试)

```bash
# 进入容器 shell
docker run -it --rm -v $(pwd)/.env:/app/.env valuecell:latest bash

# 查看日志
docker logs -f valuecell

# 实时查看容器内日志文件
docker exec -it valuecell tail -f /app/logs/*/backend.log
```

## Docker Compose

### 基础使用

```bash
# 启动服务
docker-compose up -d

# 查看状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose stop

# 停止并删除容器
docker-compose down

# 停止并删除容器和数据卷
docker-compose down -v
```

### 自定义 docker-compose.yml

创建 `docker-compose.override.yml` 来覆盖默认配置：

```yaml
version: '3.8'

services:
  valuecell:
    # 自定义端口
    ports:
      - "9000:8000"
    
    # 添加额外环境变量
    environment:
      - CUSTOM_VAR=value
    
    # 调整资源限制
    deploy:
      resources:
        limits:
          cpus: '8'
          memory: 16G
```

## 配置说明

### 环境变量

所有配置通过 `.env` 文件管理。主要配置项：

#### 应用设置
```bash
APP_NAME=ValueCell
APP_ENVIRONMENT=production  # development, staging, production
API_HOST=0.0.0.0
API_PORT=8000
```

#### LLM 提供商 (至少配置一个)
```bash
OPENROUTER_API_KEY=sk-or-v1-xxxxx
GOOGLE_API_KEY=AIzaSyD-xxxxx
SILICONFLOW_API_KEY=sk-xxxxx
```

#### 金融数据源
```bash
FINNHUB_API_KEY=xxxxx
SEC_EMAIL=your_email@example.com
XUEQIU_TOKEN=xxxxx  # 可选
```

#### 调试选项
```bash
API_DEBUG=false
AGENT_DEBUG_MODE=false
```

### 端口映射

| 容器端口 | 说明 | 推荐映射 |
|---------|------|---------|
| 8000 | 后端 API + 前端 | 8000:8000 |

### 数据卷

| 容器路径 | 说明 | 推荐挂载 |
|---------|------|---------|
| /app/.env | 配置文件 | 必需 |
| /app/logs | 应用日志 | 推荐 |
| /app/lancedb | 向量数据库 | 推荐 |
| /app/.knowledgebase | 知识库存储 | 推荐 |
| /app/python/*.db | SQLite 数据库 | 推荐 |

## 数据持久化

### 使用命名卷 (推荐)

```bash
docker volume create valuecell-logs
docker volume create valuecell-db
docker volume create valuecell-knowledge

docker run -d \
  -v valuecell-logs:/app/logs \
  -v valuecell-db:/app/lancedb \
  -v valuecell-knowledge:/app/.knowledgebase \
  valuecell:latest
```

### 使用主机目录

```bash
mkdir -p ./data/{logs,lancedb,knowledgebase}

docker run -d \
  -v $(pwd)/data/logs:/app/logs \
  -v $(pwd)/data/lancedb:/app/lancedb \
  -v $(pwd)/data/knowledgebase:/app/.knowledgebase \
  valuecell:latest
```

### 备份数据

```bash
# 备份所有数据卷
docker run --rm \
  -v valuecell-logs:/data/logs \
  -v valuecell-db:/data/db \
  -v valuecell-knowledge:/data/knowledge \
  -v $(pwd)/backup:/backup \
  alpine tar czf /backup/valuecell-backup-$(date +%Y%m%d).tar.gz /data

# 恢复数据
docker run --rm \
  -v valuecell-logs:/data/logs \
  -v valuecell-db:/data/db \
  -v valuecell-knowledge:/data/knowledge \
  -v $(pwd)/backup:/backup \
  alpine tar xzf /backup/valuecell-backup-20240101.tar.gz -C /
```

## 常见问题

### 1. 容器启动失败

**检查日志：**
```bash
docker logs valuecell
```

**常见原因：**
- `.env` 文件未配置或配置错误
- API Key 无效
- 端口被占用
- 内存不足

### 2. 无法访问 Web 界面

**检查容器状态：**
```bash
docker ps
docker port valuecell
```

**检查健康状态：**
```bash
docker inspect valuecell | grep -A 10 Health
```

**测试连接：**
```bash
curl http://localhost:8000/health
```

### 3. 性能问题

**增加资源限制：**
```bash
docker run -d \
  --cpus="4" \
  --memory="8g" \
  valuecell:latest
```

**查看资源使用：**
```bash
docker stats valuecell
```

### 4. 数据库初始化失败

**手动初始化：**
```bash
docker exec -it valuecell bash
cd /app/python
uv run valuecell/server/db/init_db.py
```

### 5. 依赖安装失败

**重新构建镜像：**
```bash
docker build --no-cache -t valuecell:latest .
```

## 高级用法

详见 [Docker故障排查指南](Docker故障排查指南.md)

## 支持

如遇问题，请：
1. 查看 [GitHub Issues](https://github.com/ValueCell-ai/valuecell/issues)
2. 加入 [Discord 社区](https://discord.com/invite/84Kex3GGAh)
3. 查看 [Docker故障排查指南](Docker故障排查指南.md)

## 许可证

Apache 2.0 License - 详见 [LICENSE](../LICENSE) 文件
