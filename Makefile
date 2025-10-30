# ============================================
# ValueCell Makefile
# 简化 Docker 和开发操作
# ============================================

.PHONY: help build run stop clean logs shell test dev prod

# 默认目标
.DEFAULT_GOAL := help

# 颜色定义
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

# 变量定义
IMAGE_NAME := valuecell
IMAGE_TAG := latest
CONTAINER_NAME := valuecell
DEV_CONTAINER_NAME := valuecell-dev

##@ 帮助

help: ## 显示帮助信息
	@echo "$(BLUE)ValueCell Makefile 命令$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "使用方法: make $(GREEN)<target>$(NC)\n\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(BLUE)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ 生产环境

build: ## 构建生产镜像（使用 Node.js 构建前端）
	@echo "$(BLUE)构建生产镜像...$(NC)"
	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
	@echo "$(GREEN)✓ 镜像构建完成$(NC)"

build-optimized: ## 优化构建（需要预构建前端）
	@echo "$(BLUE)检查前端构建产物...$(NC)"
	@if [ ! -d "frontend/build" ]; then \
		echo "$(YELLOW)前端未构建，正在构建...$(NC)"; \
		cd frontend && npm install && npm run build && cd ..; \
	fi
	@echo "$(BLUE)构建优化镜像...$(NC)"
	docker build -f Dockerfile.optimized -t $(IMAGE_NAME):$(IMAGE_TAG) .
	@echo "$(GREEN)✓ 优化镜像构建完成$(NC)"

build-no-cache: ## 无缓存构建生产镜像
	@echo "$(BLUE)无缓存构建生产镜像...$(NC)"
	docker build --no-cache -t $(IMAGE_NAME):$(IMAGE_TAG) .
	@echo "$(GREEN)✓ 镜像构建完成$(NC)"

build-frontend: ## 本地构建前端
	@echo "$(BLUE)构建前端...$(NC)"
	cd frontend && npm install && npm run build
	@echo "$(GREEN)✓ 前端构建完成$(NC)"

run: ## 运行生产容器
	@echo "$(BLUE)启动生产容器...$(NC)"
	docker run -d \
		--name $(CONTAINER_NAME) \
		--restart unless-stopped \
		-p 8000:8000 \
		-v $(PWD)/.env:/app/.env:ro \
		-v valuecell-logs:/app/logs \
		-v valuecell-db:/app/lancedb \
		-v valuecell-knowledge:/app/.knowledgebase \
		$(IMAGE_NAME):$(IMAGE_TAG)
	@echo "$(GREEN)✓ 容器已启动$(NC)"
	@echo "$(YELLOW)访问: http://localhost:8000$(NC)"

up: ## 使用 docker-compose 启动生产环境
	@echo "$(BLUE)启动生产环境...$(NC)"
	docker-compose up -d
	@echo "$(GREEN)✓ 服务已启动$(NC)"
	@echo "$(YELLOW)访问: http://localhost:8000$(NC)"

down: ## 停止 docker-compose 服务
	@echo "$(BLUE)停止服务...$(NC)"
	docker-compose down
	@echo "$(GREEN)✓ 服务已停止$(NC)"

stop: ## 停止生产容器
	@echo "$(BLUE)停止容器...$(NC)"
	docker stop $(CONTAINER_NAME) || true
	@echo "$(GREEN)✓ 容器已停止$(NC)"

restart: stop run ## 重启生产容器

##@ 开发环境

dev-build: ## 构建开发镜像
	@echo "$(BLUE)构建开发镜像...$(NC)"
	docker build -f Dockerfile.dev -t $(IMAGE_NAME):dev .
	@echo "$(GREEN)✓ 开发镜像构建完成$(NC)"

dev-up: ## 启动开发环境
	@echo "$(BLUE)启动开发环境...$(NC)"
	docker-compose -f docker-compose.dev.yml up -d
	@echo "$(GREEN)✓ 开发环境已启动$(NC)"
	@echo "$(YELLOW)进入容器: make dev-shell$(NC)"

dev-down: ## 停止开发环境
	@echo "$(BLUE)停止开发环境...$(NC)"
	docker-compose -f docker-compose.dev.yml down
	@echo "$(GREEN)✓ 开发环境已停止$(NC)"

dev-shell: ## 进入开发容器 shell
	@echo "$(BLUE)进入开发容器...$(NC)"
	docker exec -it $(DEV_CONTAINER_NAME) /bin/bash

dev-logs: ## 查看开发环境日志
	docker-compose -f docker-compose.dev.yml logs -f

##@ 日志和调试

logs: ## 查看生产容器日志
	docker logs -f $(CONTAINER_NAME)

logs-tail: ## 查看最近 100 行日志
	docker logs --tail 100 $(CONTAINER_NAME)

shell: ## 进入生产容器 shell
	@echo "$(BLUE)进入容器 shell...$(NC)"
	docker exec -it $(CONTAINER_NAME) /bin/bash

ps: ## 查看容器状态
	@echo "$(BLUE)容器状态:$(NC)"
	@docker ps -a | grep $(IMAGE_NAME) || echo "$(YELLOW)没有运行的容器$(NC)"

stats: ## 查看容器资源使用
	docker stats $(CONTAINER_NAME)

inspect: ## 查看容器详细信息
	docker inspect $(CONTAINER_NAME)

health: ## 检查容器健康状态
	@echo "$(BLUE)健康检查:$(NC)"
	@curl -f http://localhost:8000/health && echo "$(GREEN)✓ 服务正常$(NC)" || echo "$(YELLOW)✗ 服务异常$(NC)"

##@ 清理

clean: ## 清理容器和镜像
	@echo "$(BLUE)清理容器和镜像...$(NC)"
	docker stop $(CONTAINER_NAME) 2>/dev/null || true
	docker rm $(CONTAINER_NAME) 2>/dev/null || true
	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	@echo "$(GREEN)✓ 清理完成$(NC)"

clean-all: ## 清理所有（包括数据卷）
	@echo "$(YELLOW)警告: 这将删除所有数据！$(NC)"
	@read -p "确认删除所有数据? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		echo "$(BLUE)清理所有资源...$(NC)"; \
		docker-compose down -v; \
		docker stop $(CONTAINER_NAME) 2>/dev/null || true; \
		docker rm $(CONTAINER_NAME) 2>/dev/null || true; \
		docker rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true; \
		docker volume rm valuecell-logs valuecell-db valuecell-knowledge 2>/dev/null || true; \
		echo "$(GREEN)✓ 清理完成$(NC)"; \
	else \
		echo "$(YELLOW)已取消$(NC)"; \
	fi

prune: ## 清理 Docker 系统
	@echo "$(BLUE)清理 Docker 系统...$(NC)"
	docker system prune -f
	@echo "$(GREEN)✓ 系统清理完成$(NC)"

##@ 数据管理

backup: ## 备份数据
	@echo "$(BLUE)备份数据...$(NC)"
	@mkdir -p ./backups
	docker run --rm \
		-v valuecell-logs:/data/logs \
		-v valuecell-db:/data/db \
		-v valuecell-knowledge:/data/knowledge \
		-v $(PWD)/backups:/backup \
		alpine tar czf /backup/valuecell-backup-$$(date +%Y%m%d-%H%M%S).tar.gz /data
	@echo "$(GREEN)✓ 备份完成: ./backups/$(NC)"

restore: ## 恢复数据 (需要指定 BACKUP_FILE)
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "$(YELLOW)用法: make restore BACKUP_FILE=./backups/valuecell-backup-20240101-120000.tar.gz$(NC)"; \
		exit 1; \
	fi
	@echo "$(BLUE)恢复数据: $(BACKUP_FILE)$(NC)"
	docker run --rm \
		-v valuecell-logs:/data/logs \
		-v valuecell-db:/data/db \
		-v valuecell-knowledge:/data/knowledge \
		-v $(PWD)/backups:/backup \
		alpine tar xzf /backup/$$(basename $(BACKUP_FILE)) -C /
	@echo "$(GREEN)✓ 数据恢复完成$(NC)"

volumes: ## 列出所有数据卷
	@echo "$(BLUE)数据卷列表:$(NC)"
	@docker volume ls | grep valuecell || echo "$(YELLOW)没有找到数据卷$(NC)"

##@ 测试

test: ## 运行测试
	@echo "$(BLUE)运行测试...$(NC)"
	docker exec $(CONTAINER_NAME) uv run pytest
	@echo "$(GREEN)✓ 测试完成$(NC)"

test-dev: ## 在开发环境运行测试
	@echo "$(BLUE)运行开发环境测试...$(NC)"
	docker exec $(DEV_CONTAINER_NAME) uv run pytest
	@echo "$(GREEN)✓ 测试完成$(NC)"

##@ 其他

env-check: ## 检查环境配置
	@echo "$(BLUE)检查环境配置...$(NC)"
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)⚠ .env 文件不存在$(NC)"; \
		echo "$(YELLOW)创建 .env 文件: cp .env.example .env$(NC)"; \
	else \
		echo "$(GREEN)✓ .env 文件存在$(NC)"; \
	fi
	@if ! command -v docker &> /dev/null; then \
		echo "$(YELLOW)⚠ Docker 未安装$(NC)"; \
	else \
		echo "$(GREEN)✓ Docker 已安装: $$(docker --version)$(NC)"; \
	fi
	@if ! command -v docker-compose &> /dev/null; then \
		echo "$(YELLOW)⚠ Docker Compose 未安装$(NC)"; \
	else \
		echo "$(GREEN)✓ Docker Compose 已安装: $$(docker-compose --version)$(NC)"; \
	fi

update: ## 更新镜像
	@echo "$(BLUE)更新镜像...$(NC)"
	git pull
	$(MAKE) build
	$(MAKE) down
	$(MAKE) up
	@echo "$(GREEN)✓ 更新完成$(NC)"

version: ## 显示版本信息
	@echo "$(BLUE)ValueCell 版本信息:$(NC)"
	@echo "镜像: $(IMAGE_NAME):$(IMAGE_TAG)"
	@docker images $(IMAGE_NAME):$(IMAGE_TAG) --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}"
