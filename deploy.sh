#!/bin/bash

# Socialize Project Rails API Deployment Script for Kamal 2
source .kamal/secrets-common

set -e

echo "🚀 Starting Socialize Project Rails API Deployment with Kamal 2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if required environment variables are set
check_env_vars() {
    echo -e "${YELLOW}Checking environment variables...${NC}"
    
    if [ -z "$KAMAL_REGISTRY_PASSWORD" ]; then
        echo -e "${RED}Error: KAMAL_REGISTRY_PASSWORD is not set${NC}"
        echo -e "${YELLOW}Please set it with one of these methods:${NC}"
        echo "  export KAMAL_REGISTRY_PASSWORD=\"your_docker_registry_password\""
        echo "  or create a .env file and source it"
        echo "  or add it to your ~/.bashrc"
        exit 1
    fi
    
    if [ -z "$POSTGRES_PASSWORD" ]; then
        echo -e "${RED}Error: POSTGRES_PASSWORD is not set${NC}"
        echo -e "${YELLOW}Please set it with:${NC}"
        echo "  export POSTGRES_PASSWORD=\"your_secure_postgres_password\""
        exit 1
    fi
    
    if [ -z "$RAILS_MASTER_KEY" ]; then
        echo -e "${RED}Error: RAILS_MASTER_KEY is not set${NC}"
        echo -e "${YELLOW}Please set it with:${NC}"
        echo "  export RAILS_MASTER_KEY=\"$(cat config/master.key 2>/dev/null || echo 'your_rails_master_key')\""
        exit 1
    fi
    
    echo -e "${GREEN}Environment variables check passed!${NC}"
    echo -e "${GREEN}✓ KAMAL_REGISTRY_PASSWORD is set${NC}"
    echo -e "${GREEN}✓ POSTGRES_PASSWORD is set${NC}"
    echo -e "${GREEN}✓ RAILS_MASTER_KEY is set${NC}"
}

# Build frontend first (if needed for static assets)
build_frontend() {
    echo -e "${YELLOW}Building frontend assets...${NC}"
    if [ -d "frontend" ]; then
        cd frontend
        npm install
        npm run build
        cd ..
    else
        echo -e "${BLUE}No frontend directory found, skipping frontend build${NC}"
    fi
    echo -e "${GREEN}Frontend build completed!${NC}"
}

# First-time setup - deploys Rails API with accessories (PostgreSQL and Redis)
setup() {
    echo -e "${YELLOW}Running Kamal setup (first deployment)...${NC}"
    check_env_vars
    
    echo -e "${BLUE}Setting up Rails API with PostgreSQL and Redis...${NC}"
    kamal setup
    
    echo -e "${YELLOW}Waiting for services to be ready...${NC}"
    sleep 10
    
    echo -e "${BLUE}Running database migrations...${NC}"
    kamal app exec "bin/rails db:create db:migrate" || {
        echo -e "${RED}Migration failed. Trying again in 10 seconds...${NC}"
        sleep 10
        kamal app exec "bin/rails db:create db:migrate"
    }
    
    echo -e "${GREEN}Setup completed successfully!${NC}"
    echo -e "${YELLOW}Your Rails API should now be running at:${NC}"
    echo -e "  API: http://91.98.71.82:3000/api"
    echo -e "  Health check: http://91.98.71.82:3000/up"
}

# Setup frontend
setup_frontend() {
    echo -e "${YELLOW}Running frontend setup...${NC}"
    check_env_vars
    build_frontend
    
    echo -e "${BLUE}Setting up frontend (React app)...${NC}"
    kamal setup -c config/deploy.frontend.yml
    
    echo -e "${GREEN}Frontend setup completed successfully!${NC}"
    echo -e "${YELLOW}Your frontend should now be running at:${NC}"
    echo -e "  Frontend: http://91.98.71.82"
}

# Deploy only backend
deploy_backend() {
    echo -e "${YELLOW}Deploying backend (Rails API) only...${NC}"
    check_env_vars
    kamal deploy
    echo -e "${GREEN}Backend deployed successfully!${NC}"
}

# Deploy only frontend
deploy_frontend() {
    echo -e "${YELLOW}Deploying frontend (React) only...${NC}"
    check_env_vars
    build_frontend
    kamal deploy -c config/deploy.frontend.yml
    echo -e "${GREEN}Frontend deployed successfully!${NC}"
}

# Deploy both services
deploy_all() {
    echo -e "${YELLOW}Deploying both frontend and backend...${NC}"
    check_env_vars
    build_frontend
    
    echo -e "${BLUE}Deploying frontend (React app)...${NC}"
    kamal deploy -c config/deploy.frontend.yml
    
    echo -e "${BLUE}Deploying backend (Rails API)...${NC}"
    kamal deploy
    
    echo -e "${GREEN}Both services deployed successfully!${NC}"
    echo -e "${YELLOW}Services are now running at:${NC}"
    echo -e "  Frontend: http://91.98.71.82"
    echo -e "  Backend API: http://91.98.71.82:3000/api"
}

# Deploy with fresh accessories (if having database issues)
deploy_fresh() {
    echo -e "${YELLOW}Deploying with fresh accessories...${NC}"
    check_env_vars
    
    echo -e "${BLUE}Stopping and removing accessories...${NC}"
    kamal accessory remove postgres || true
    kamal accessory remove redis || true
    
    echo -e "${BLUE}Booting fresh accessories...${NC}"
    kamal accessory boot postgres
    kamal accessory boot redis
    
    # Wait for PostgreSQL to be ready
    echo -e "${YELLOW}Waiting for PostgreSQL to be ready...${NC}"
    sleep 15
    
    echo -e "${BLUE}Deploying Rails API...${NC}"
    kamal deploy
    
    echo -e "${GREEN}Fresh deployment completed successfully!${NC}"
}

# Show status
status() {
    echo -e "${YELLOW}Checking deployment status...${NC}"
    echo -e "${BLUE}Backend status:${NC}"
    kamal details
    echo -e "${BLUE}Frontend status:${NC}"
    kamal details -c config/deploy.frontend.yml 2>/dev/null || echo "Frontend not deployed or configuration missing"
    echo -e "${BLUE}Accessories status:${NC}"
    kamal accessory details postgres
    kamal accessory details redis
}

# View logs
logs() {
    if [ "$1" = "postgres" ]; then
        echo -e "${YELLOW}Fetching PostgreSQL logs...${NC}"
        kamal accessory logs postgres
    elif [ "$1" = "redis" ]; then
        echo -e "${YELLOW}Fetching Redis logs...${NC}"
        kamal accessory logs redis
    elif [ "$1" = "app" ] || [ "$1" = "backend" ]; then
        echo -e "${YELLOW}Fetching backend application logs...${NC}"
        kamal app logs
    elif [ "$1" = "frontend" ]; then
        echo -e "${YELLOW}Fetching frontend logs...${NC}"
        kamal app logs -c config/deploy.frontend.yml
    else
        echo -e "${YELLOW}Fetching all logs...${NC}"
        echo -e "${BLUE}Backend logs (last 20 lines):${NC}"
        kamal app logs --lines 20
        echo -e "${BLUE}Frontend logs (last 20 lines):${NC}"
        kamal app logs --lines 20 -c config/deploy.frontend.yml 2>/dev/null || echo "Frontend logs not available"
        echo -e "${BLUE}PostgreSQL logs (last 20 lines):${NC}"
        kamal accessory logs postgres --lines 20 2>/dev/null || echo "PostgreSQL logs not available"
        echo -e "${BLUE}Redis logs (last 20 lines):${NC}"
        kamal accessory logs redis --lines 20 2>/dev/null || echo "Redis logs not available"
    fi
}

# Rollback
rollback() {
    echo -e "${YELLOW}Rolling back Rails API...${NC}"
    kamal rollback
    echo -e "${GREEN}Rollback completed!${NC}"
}

# Open Rails console
console() {
    echo -e "${YELLOW}Opening Rails console...${NC}"
    kamal app exec --interactive --reuse "bin/rails console"
}

# Database operations
db_migrate() {
    echo -e "${YELLOW}Running database migrations...${NC}"
    kamal app exec "bin/rails db:migrate"
    echo -e "${GREEN}Migrations completed!${NC}"
}

db_seed() {
    echo -e "${YELLOW}Seeding database...${NC}"
    kamal app exec "bin/rails db:seed"
    echo -e "${GREEN}Database seeded!${NC}"
}

db_reset() {
    echo -e "${RED}This will destroy all data in your database!${NC}"
    read -p "Are you sure you want to reset the database? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Resetting database...${NC}"
        kamal app exec "bin/rails db:drop db:create db:migrate db:seed"
        echo -e "${GREEN}Database reset completed!${NC}"
    else
        echo -e "${YELLOW}Database reset cancelled.${NC}"
    fi
}

# Restart accessories
restart_accessories() {
    echo -e "${YELLOW}Restarting accessories...${NC}"
    kamal accessory restart postgres
    kamal accessory restart redis
    echo -e "${GREEN}Accessories restarted!${NC}"
}

# Complete reset (destructive)
reset() {
    echo -e "${RED}This will completely destroy your deployment and all data!${NC}"
    read -p "Are you absolutely sure? Type 'DELETE' to confirm: " confirm
    if [ "$confirm" = "DELETE" ]; then
        echo -e "${RED}Removing everything...${NC}"
        kamal app remove || true
        kamal accessory remove postgres || true
        kamal accessory remove redis || true
        ssh root@91.98.71.82 "docker system prune -af"
        ssh root@91.98.71.82 "docker volume prune -f"
        echo -e "${GREEN}Complete reset finished. Run '$0 setup' to redeploy.${NC}"
    else
        echo -e "${YELLOW}Reset cancelled.${NC}"
    fi
}

# Show help
help() {
    echo "Socialize Project Deployment Script for Kamal 2"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Setup Commands:"
    echo "  setup                  - First-time backend deployment setup"
    echo "  setup-frontend         - First-time frontend deployment setup"
    echo ""
    echo "Deployment Commands:"
    echo "  deploy                 - Deploy backend only (default)"
    echo "  deploy-backend         - Deploy backend (Rails API) explicitly"
    echo "  deploy-frontend        - Deploy frontend (React) only"
    echo "  deploy-all             - Deploy both backend and frontend"
    echo "  deploy-fresh           - Deploy with fresh accessories (fixes DB issues)"
    echo "  rollback               - Rollback backend to previous version"
    echo ""
    echo "Status & Monitoring:"
    echo "  status                 - Show deployment status for all services"
    echo "  logs [backend|frontend|postgres|redis] - View logs (specific service or all)"
    echo ""
    echo "Database Operations:"
    echo "  db-migrate             - Run database migrations"
    echo "  db-seed                - Seed database"
    echo "  db-reset               - Reset database (destructive)"
    echo ""
    echo "Maintenance:"
    echo "  console                - Open Rails console"
    echo "  restart-accessories    - Restart PostgreSQL and Redis"
    echo "  reset                  - Complete reset (destructive)"
    echo "  help                   - Show this help message"
    echo ""
    echo "Environment Variables Required:"
    echo "  KAMAL_REGISTRY_PASSWORD - Docker registry password"
    echo "  POSTGRES_PASSWORD       - PostgreSQL password"
    echo "  RAILS_MASTER_KEY        - Rails master key (from config/master.key)"
    echo ""
    echo "Configuration Files:"
    echo "  config/deploy.yml           - Backend (Rails API) configuration"
    echo "  config/deploy.frontend.yml  - Frontend (React) configuration"
    echo ""
    echo "Quick Start:"
    echo "  1. Set environment variables in .kamal/secrets-common"
    echo "  2. Run: $0 setup                 # Setup backend"
    echo "  3. Run: $0 setup-frontend        # Setup frontend"
    echo "  4. Backend API: http://91.98.71.82:3000/api"
    echo "  5. Frontend: http://91.98.71.82"
    echo ""
}

# Main command handler
case $1 in
    setup)
        setup
        ;;
    setup-frontend)
        setup_frontend
        ;;
    deploy)
        deploy
        ;;
    deploy-backend)
        deploy_backend
        ;;
    deploy-frontend)
        deploy_frontend
        ;;
    deploy-all)
        deploy_all
        ;;
    deploy-fresh)
        deploy_fresh
        ;;
    status)
        status
        ;;
    logs)
        logs $2
        ;;
    rollback)
        rollback
        ;;
    console)
        console
        ;;
    db-migrate)
        db_migrate
        ;;
    db-seed)
        db_seed
        ;;
    db-reset)
        db_reset
        ;;
    restart-accessories)
        restart_accessories
        ;;
    reset)
        reset
        ;;
    help|--help|-h)
        help
        ;;
    *)
        if [ -n "$1" ]; then
            echo -e "${RED}Unknown command: $1${NC}"
            echo ""
        fi
        help
        exit 1
        ;;
esac