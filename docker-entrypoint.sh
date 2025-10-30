#!/bin/bash
# ============================================
# ValueCell Docker 入口脚本
# ============================================

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
success(){ echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" 1>&2; }

# 检查 .env 文件
check_env_file() {
    if [ ! -f "/app/.env" ]; then
        warn ".env file not found. Creating from .env.example..."
        if [ -f "/app/.env.example" ]; then
            cp /app/.env.example /app/.env
            warn "Please configure /app/.env with your API keys and settings."
            warn "You can mount your .env file using: -v /path/to/.env:/app/.env"
        else
            error ".env.example not found!"
            exit 1
        fi
    fi
    success ".env file found"
}

# 初始化数据库
init_database() {
    info "Initializing database..."
    cd /app/python
    if uv run valuecell/server/db/init_db.py; then
        success "Database initialized"
    else
        warn "Database initialization failed or already initialized"
    fi
}

# 启动后端服务
start_backend() {
    info "Starting backend service..."
    cd /app/python
    exec uv run --env-file /app/.env -m valuecell.server.main
}

# 启动 Research Agent
start_research_agent() {
    info "Starting Research Agent..."
    cd /app/python
    exec uv run --env-file /app/.env -m valuecell.agents.research_agent
}

# 启动 Auto Trading Agent
start_auto_trading_agent() {
    info "Starting Auto Trading Agent..."
    cd /app/python
    exec uv run --env-file /app/.env -m valuecell.agents.auto_trading_agent
}

# 启动所有服务
start_all() {
    info "Starting all services..."
    
    # 创建日志目录
    TIMESTAMP=$(date +%Y%m%d%H%M%S)
    LOG_DIR="/app/logs/${TIMESTAMP}"
    mkdir -p "${LOG_DIR}"
    info "Logs will be saved to ${LOG_DIR}/"
    
    cd /app/python
    
    # 启动 Research Agent (后台)
    info "Starting Research Agent in background..."
    uv run --env-file /app/.env -m valuecell.agents.research_agent \
        > "${LOG_DIR}/research_agent.log" 2>&1 &
    RESEARCH_PID=$!
    success "Research Agent started (PID: ${RESEARCH_PID})"
    
    # 启动 Auto Trading Agent (后台)
    info "Starting Auto Trading Agent in background..."
    uv run --env-file /app/.env -m valuecell.agents.auto_trading_agent \
        > "${LOG_DIR}/auto_trading_agent.log" 2>&1 &
    TRADING_PID=$!
    success "Auto Trading Agent started (PID: ${TRADING_PID})"
    
    # 等待 agents 启动
    sleep 5
    
    # 启动后端 (前台)
    info "Starting backend service..."
    info "Frontend available at http://localhost:8000"
    info "API documentation at http://localhost:8000/docs"
    
    # 设置信号处理
    trap 'info "Stopping services..."; kill ${RESEARCH_PID} ${TRADING_PID} 2>/dev/null; exit 0' SIGTERM SIGINT
    
    # 启动后端并等待
    uv run --env-file /app/.env -m valuecell.server.main \
        > "${LOG_DIR}/backend.log" 2>&1 &
    BACKEND_PID=$!
    
    success "All services started!"
    info "Monitor logs at: ${LOG_DIR}/"
    info "  - Backend: ${LOG_DIR}/backend.log"
    info "  - Research Agent: ${LOG_DIR}/research_agent.log"
    info "  - Auto Trading Agent: ${LOG_DIR}/auto_trading_agent.log"
    
    # 等待所有进程
    wait ${BACKEND_PID}
}

# 显示帮助信息
show_help() {
    cat <<EOF
ValueCell Docker Container

Usage: docker run [OPTIONS] valuecell [COMMAND]

Commands:
  all                 Start all services (default)
  backend             Start backend API server only
  research-agent      Start Research Agent only
  trading-agent       Start Auto Trading Agent only
  bash                Open bash shell
  help                Show this help message

Examples:
  # Start all services
  docker run -p 8000:8000 -v ./my.env:/app/.env valuecell

  # Start backend only
  docker run -p 8000:8000 -v ./my.env:/app/.env valuecell backend

  # Open shell for debugging
  docker run -it valuecell bash

Environment Variables:
  See .env.example for all available configuration options.
  Mount your .env file: -v /path/to/.env:/app/.env

Ports:
  8000    Backend API and Frontend

Volumes:
  /app/.env           Configuration file
  /app/logs           Application logs
  /app/lancedb        Vector database
  /app/.knowledgebase Knowledge base storage

EOF
}

# 主函数
main() {
    info "ValueCell Container Starting..."
    
    # 检查环境文件
    check_env_file
    
    # 初始化数据库
    init_database
    
    # 根据命令执行不同操作
    case "${1:-all}" in
        all)
            start_all
            ;;
        backend)
            start_backend
            ;;
        research-agent)
            start_research_agent
            ;;
        trading-agent)
            start_auto_trading_agent
            ;;
        bash|sh|shell)
            info "Opening bash shell..."
            exec /bin/bash
            ;;
        help|--help|-h)
            show_help
            exit 0
            ;;
        *)
            error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
