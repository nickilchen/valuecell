#!/bin/bash
# ============================================
# ValueCell Docker 构建脚本
# 解决前端构建兼容性问题
# ============================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
success(){ echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" 1>&2; }

# 默认参数
BUILD_FRONTEND=true
BUILD_TYPE="standard"  # standard, optimized, or no-frontend
IMAGE_TAG="latest"
PLATFORM=""

# 显示帮助
show_help() {
    cat <<EOF
ValueCell Docker 构建脚本

用法: ./build-docker.sh [选项]

选项:
  --no-frontend         跳过前端构建（使用优化版 Dockerfile）
  --optimized           使用优化版 Dockerfile（需要预构建前端）
  --tag TAG             指定镜像标签（默认: latest）
  --platform PLATFORM   指定构建平台（如: linux/amd64）
  -h, --help            显示帮助信息

构建类型:
  1. 标准构建（默认）
     - 在 Docker 中构建前端和后端
     - 使用 Node.js 构建前端（解决 Bun 兼容性问题）
     
  2. 优化构建（--optimized）
     - 需要先在本地构建前端
     - 跳过 Docker 中的前端构建步骤
     - 构建速度更快
     
  3. 无前端构建（--no-frontend）
     - 只构建后端服务
     - 适用于纯 API 部署

示例:
  # 标准构建
  ./build-docker.sh
  
  # 优化构建（先构建前端）
  cd frontend && npm run build && cd ..
  ./build-docker.sh --optimized
  
  # 无前端构建
  ./build-docker.sh --no-frontend
  
  # 指定平台构建
  ./build-docker.sh --platform linux/amd64

EOF
}

# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-frontend)
            BUILD_TYPE="no-frontend"
            shift
            ;;
        --optimized)
            BUILD_TYPE="optimized"
            shift
            ;;
        --tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --platform)
            PLATFORM="--platform $2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error "未知参数: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查 Docker
if ! command -v docker &> /dev/null; then
    error "Docker 未安装，请先安装 Docker"
    exit 1
fi

info "ValueCell Docker 构建开始..."
info "构建类型: $BUILD_TYPE"
info "镜像标签: valuecell:$IMAGE_TAG"

# 根据构建类型选择 Dockerfile
case $BUILD_TYPE in
    standard)
        info "使用标准 Dockerfile（Node.js 构建前端）"
        DOCKERFILE="Dockerfile"
        
        # 检查前端目录
        if [ ! -d "frontend" ]; then
            error "frontend 目录不存在"
            exit 1
        fi
        ;;
        
    optimized)
        info "使用优化版 Dockerfile（跳过前端构建）"
        DOCKERFILE="Dockerfile.optimized"
        
        # 检查前端构建产物
        if [ ! -d "frontend/build" ]; then
            warn "前端构建产物不存在，正在构建..."
            
            if [ ! -d "frontend" ]; then
                error "frontend 目录不存在"
                exit 1
            fi
            
            cd frontend
            
            # 检查并安装依赖
            if [ ! -d "node_modules" ]; then
                info "安装前端依赖..."
                if command -v bun &> /dev/null; then
                    bun install
                elif command -v pnpm &> /dev/null; then
                    pnpm install
                else
                    npm install
                fi
            fi
            
            # 构建前端
            info "构建前端..."
            if command -v bun &> /dev/null; then
                bun run build
            else
                npm run build
            fi
            
            cd ..
            success "前端构建完成"
        else
            success "找到前端构建产物"
        fi
        ;;
        
    no-frontend)
        info "使用无前端版 Dockerfile"
        DOCKERFILE="Dockerfile.optimized"
        
        # 创建空的前端目录
        mkdir -p frontend/build
        echo '{"name":"frontend"}' > frontend/package.json
        warn "跳过前端构建，只构建后端服务"
        ;;
esac

# 检查 Dockerfile
if [ ! -f "$DOCKERFILE" ]; then
    error "Dockerfile 不存在: $DOCKERFILE"
    exit 1
fi

# 构建 Docker 镜像
info "开始构建 Docker 镜像..."
info "Dockerfile: $DOCKERFILE"

if docker build $PLATFORM -f "$DOCKERFILE" -t "valuecell:$IMAGE_TAG" .; then
    success "Docker 镜像构建成功！"
    echo ""
    info "镜像信息:"
    docker images valuecell:$IMAGE_TAG
    echo ""
    success "构建完成！"
    echo ""
    info "运行容器:"
    echo "  docker run -d -p 8000:8000 -v \$(pwd)/.env:/app/.env valuecell:$IMAGE_TAG"
    echo ""
    info "或使用 docker-compose:"
    echo "  docker-compose up -d"
else
    error "Docker 镜像构建失败"
    exit 1
fi
