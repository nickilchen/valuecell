# Docker 构建故障排查指南

## 前端构建失败问题

### 问题描述

构建 Docker 镜像时，前端构建阶段失败，错误信息：

```
SyntaxError: Export named 'renderToPipeableStream' not found in module 
'/app/frontend/node_modules/react-dom/server.bun.js'.
```

### 原因分析

这是因为：
1. React Router 7 使用了 Node.js 特定的 SSR API (`renderToPipeableStream`)
2. Bun 的 React DOM 实现还不完全兼容这些 API
3. 原 Dockerfile 使用 Bun 构建前端导致兼容性问题

### 解决方案

我们提供了三种解决方案：

#### 方案 1: 使用修复后的标准 Dockerfile（推荐）

**特点**: 在 Docker 中使用 Node.js 构建前端

**步骤**:
```bash
# 直接构建（已修复）
docker build -t valuecell:latest .

# 或使用构建脚本
bash build-docker.sh
```

**优点**:
- 一键构建，无需额外步骤
- 完全兼容 React Router 7
- 适合 CI/CD 自动化

**缺点**:
- 构建时间较长（首次约 5-10 分钟）
- 需要较多内存（建议 4GB+）

#### 方案 2: 使用优化版 Dockerfile

**特点**: 先在本地构建前端，然后只在 Docker 中构建后端

**步骤**:
```bash
# 1. 在本地构建前端
cd frontend

# 使用 npm（推荐）
npm install
npm run build

# 或使用 bun（如果本地环境支持）
bun install
bun run build

cd ..

# 2. 使用优化版 Dockerfile 构建
docker build -f Dockerfile.optimized -t valuecell:latest .

# 或使用构建脚本
bash build-docker.sh --optimized
```

**优点**:
- Docker 构建速度快（约 2-3 分钟）
- 可以利用本地缓存
- 适合频繁构建

**缺点**:
- 需要本地安装 Node.js 或 Bun
- 需要手动构建前端

#### 方案 3: 纯后端部署（无前端）

**特点**: 只部署后端 API，不包含前端

**步骤**:
```bash
# 使用构建脚本
bash build-docker.sh --no-frontend

# 或手动构建
docker build -f Dockerfile.optimized -t valuecell:latest .
```

**适用场景**:
- 前后端分离部署
- 只需要 API 服务
- 前端单独部署到 CDN 或其他服务器

## 其他常见问题

### 1. 内存不足

**症状**:
```
error: script "build" was killed by signal SIGKILL
```

**解决方案**:
```bash
# 增加 Docker 内存限制
# Docker Desktop: Settings -> Resources -> Memory (建议 8GB+)

# 或在构建时限制并发
docker build --memory=8g -t valuecell:latest .
```

### 2. 网络问题

**症状**:
```
error: failed to fetch package
```

**解决方案**:
```bash
# 使用国内镜像源
# 在 Dockerfile 中添加：
RUN npm config set registry https://registry.npmmirror.com

# 或使用代理
docker build --build-arg HTTP_PROXY=http://proxy:port -t valuecell:latest .
```

### 3. 平台兼容性问题

**症状**:
```
exec format error
```

**解决方案**:
```bash
# 指定目标平台
docker build --platform linux/amd64 -t valuecell:latest .

# Apple Silicon (M1/M2) 用户
docker build --platform linux/arm64 -t valuecell:latest .
```

### 4. 依赖安装失败

**症状**:
```
error: failed to solve: process "/bin/sh -c uv sync" did not complete successfully
```

**解决方案**:
```bash
# 清理缓存重新构建
docker build --no-cache -t valuecell:latest .

# 检查 pyproject.toml 和 package.json 是否正确
```

### 5. Playwright 安装失败

**症状**:
```
error: Failed to install browsers
```

**解决方案**:
```bash
# 在 Dockerfile 中确保安装了系统依赖
# 已在修复后的 Dockerfile 中包含

# 或跳过 Playwright（如果不需要网页爬取功能）
# 注释掉 Dockerfile 中的这一行：
# RUN uv run playwright install --with-deps chromium
```

## 构建脚本使用

### 基础用法

```bash
# 标准构建（使用 Node.js）
bash build-docker.sh

# 优化构建（需要预构建前端）
bash build-docker.sh --optimized

# 无前端构建
bash build-docker.sh --no-frontend

# 指定标签
bash build-docker.sh --tag v1.0.0

# 指定平台
bash build-docker.sh --platform linux/amd64
```

### Windows 用户

```powershell
# 使用 PowerShell 或 Git Bash
bash build-docker.sh

# 或直接使用 docker 命令
docker build -t valuecell:latest .
```

## 验证构建

### 检查镜像

```bash
# 查看镜像
docker images valuecell

# 查看镜像详情
docker inspect valuecell:latest

# 查看镜像大小
docker images valuecell:latest --format "{{.Size}}"
```

### 测试运行

```bash
# 快速测试
docker run --rm -it valuecell:latest bash

# 检查文件结构
docker run --rm valuecell:latest ls -la /app

# 检查前端构建产物
docker run --rm valuecell:latest ls -la /app/frontend/build
```

### 健康检查

```bash
# 启动容器
docker run -d --name test-valuecell -p 8000:8000 valuecell:latest

# 等待启动
sleep 30

# 检查健康状态
curl http://localhost:8000/health

# 查看日志
docker logs test-valuecell

# 清理
docker stop test-valuecell
docker rm test-valuecell
```

## 性能优化建议

### 1. 使用 BuildKit

```bash
# 启用 BuildKit（更快的构建）
export DOCKER_BUILDKIT=1
docker build -t valuecell:latest .
```

### 2. 使用构建缓存

```bash
# 使用之前的镜像作为缓存
docker build --cache-from valuecell:latest -t valuecell:latest .
```

### 3. 多阶段构建优化

当前 Dockerfile 已经使用了多阶段构建：
- 阶段 1: 前端构建
- 阶段 2: Python 依赖
- 阶段 3: 第三方 Agent 依赖
- 阶段 4: 最终运行镜像

这样可以：
- 减小最终镜像大小
- 提高构建速度（并行构建）
- 更好的缓存利用

### 4. 减小镜像大小

```bash
# 查看镜像层
docker history valuecell:latest

# 使用 dive 分析镜像
# https://github.com/wagoodman/dive
dive valuecell:latest
```

## 生产环境建议

### 1. 使用优化版构建

```bash
# 在 CI/CD 中
cd frontend && npm ci && npm run build && cd ..
docker build -f Dockerfile.optimized -t valuecell:latest .
```

### 2. 多平台构建

```bash
# 使用 buildx 构建多平台镜像
docker buildx create --use
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t your-registry/valuecell:latest \
  --push .
```

### 3. 安全扫描

```bash
# 使用 Trivy 扫描漏洞
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image valuecell:latest
```

## 获取帮助

如果问题仍未解决：

1. **查看详细日志**:
   ```bash
   docker build --progress=plain -t valuecell:latest . 2>&1 | tee build.log
   ```

2. **检查系统资源**:
   ```bash
   docker system df
   docker system info
   ```

3. **清理 Docker 环境**:
   ```bash
   docker system prune -a
   docker volume prune
   ```

4. **提交 Issue**:
   - GitHub: https://github.com/ValueCell-ai/valuecell/issues
   - 包含完整的错误日志
   - 说明操作系统和 Docker 版本

5. **加入社区**:
   - Discord: https://discord.com/invite/84Kex3GGAh
