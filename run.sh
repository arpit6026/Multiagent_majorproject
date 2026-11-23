#!/usr/bin/env bash
# ==============================================================================
# AgentTeams - One-Click Launcher & Management Script
# ==============================================================================
set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

CONTAINERS=(
  "agentteams-ollama"
  "agentteams-controller"
  "agentteams-manager"
  "agentteams-dashboard"
)

DASHBOARD_URL="http://127.0.0.1:13000"
MANAGER_URL="http://127.0.0.1:18888"
OLLAMA_URL="http://127.0.0.1:11434"
CONTROLLER_URL="http://127.0.0.1:18001"

print_banner() {
  echo -e "${CYAN}${BOLD}"
  echo "╔════════════════════════════════════════════════════════════════════╗"
  echo "║                       🤖 AgentTeams Launcher                       ║"
  echo "╚════════════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
}

check_docker() {
  echo -e "${BLUE}▶ Checking Docker environment...${NC}"
  if ! command -v docker >/dev/null 2>&1; then
    echo -e "${RED}✗ Error: docker CLI is not installed or not in PATH.${NC}"
    exit 1
  fi

  if ! docker info >/dev/null 2>&1; then
    echo -e "${YELLOW}⚡ Docker daemon is not running. Attempting to start Docker Desktop...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
      if [ -d "/Applications/Docker.app" ]; then
        open -a Docker
      elif [ -d "$HOME/Applications/Docker.app" ]; then
        open -a "$HOME/Applications/Docker.app"
      fi
    fi

    # Wait for Docker daemon to become responsive
    local max_retries=30
    local count=0
    echo -n "Waiting for Docker daemon to start"
    while ! docker info >/dev/null 2>&1; do
      sleep 2
      echo -n "."
      count=$((count + 1))
      if [ $count -ge $max_retries ]; then
        echo ""
        echo -e "${RED}✗ Error: Docker did not start within 60 seconds.${NC}"
        echo -e "Please start Docker manually and run this script again."
        exit 1
      fi
    done
    echo ""
    echo -e "${GREEN}✓ Docker is now running!${NC}"
  else
    echo -e "${GREEN}✓ Docker daemon is active.${NC}"
  fi
}

start_services() {
  print_banner
  check_docker

  echo -e "\n${BLUE}▶ Starting AgentTeams containers...${NC}"

  for c in "${CONTAINERS[@]}"; do
    if docker ps -a --format '{{.Names}}' | grep -Eq "^${c}\$"; then
      local status
      status=$(docker inspect --format '{{.State.Status}}' "$c" 2>/dev/null || echo "unknown")
      if [ "$status" == "running" ]; then
        echo -e "  ${GREEN}✓${NC} $c is already running."
      else
        echo -e "  ${YELLOW}⟳${NC} Starting $c..."
        docker start "$c" >/dev/null
        echo -e "  ${GREEN}✓${NC} $c started."
      fi
    else
      echo -e "  ${RED}✗ Warning: Container $c not found.${NC}"
    fi
  done

  echo -e "\n${BLUE}▶ Checking service health...${NC}"
  local wait_count=0
  local max_wait=30
  local dashboard_ready=false

  while [ $wait_count -lt $max_wait ]; do
    if curl -s -f -m 2 "$DASHBOARD_URL" >/dev/null 2>&1; then
      dashboard_ready=true
      break
    fi
    sleep 1
    wait_count=$((wait_count + 1))
  done

  echo -e "\n${GREEN}${BOLD}════════════════════════════════════════════════════════════════════${NC}"
  echo -e "${GREEN}${BOLD}  ✓ AgentTeams is up and running!${NC}"
  echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════════${NC}"
  echo -e "  ${BOLD}🖥️  Dashboard UI :${NC} ${CYAN}${BOLD}${DASHBOARD_URL}${NC}"
  echo -e "  ${BOLD}👤 Username     :${NC} admin"
  echo -e "  ${BOLD}🔑 Password     :${NC} AdminPassword123"
  echo -e "  ------------------------------------------------------------------"
  echo -e "  ${BOLD}⚙️  Manager API  :${NC} ${MANAGER_URL}"
  echo -e "  ${BOLD}🦙 Ollama Model :${NC} ${OLLAMA_URL}"
  echo -e "  ${BOLD}🌐 Controller   :${NC} ${CONTROLLER_URL}"
  echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════════════${NC}\n"

  # Open dashboard in browser on macOS unless disabled
  if [ "${NO_OPEN:-0}" != "1" ] && [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${CYAN}Opening Dashboard in your default browser...${NC}"
    open "$DASHBOARD_URL"
  fi
}

stop_services() {
  print_banner
  check_docker
  echo -e "${YELLOW}▶ Stopping AgentTeams containers...${NC}"
  for c in "${CONTAINERS[@]}"; do
    if docker ps --format '{{.Names}}' | grep -Eq "^${c}\$"; then
      echo -e "  Stopping $c..."
      docker stop "$c" >/dev/null
      echo -e "  ${GREEN}✓${NC} $c stopped."
    else
      echo -e "  ${BLUE}•${NC} $c is not running."
    fi
  done
  echo -e "\n${GREEN}✓ All AgentTeams services stopped.${NC}\n"
}

restart_services() {
  stop_services
  sleep 2
  start_services
}

status_services() {
  print_banner
  check_docker
  echo -e "\n${BLUE}▶ Container Status:${NC}"
  docker ps -a --filter "name=agentteams-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
  echo ""
  echo -e "${BLUE}▶ Endpoint Health:${NC}"
  if curl -s -f -m 2 "$DASHBOARD_URL" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Dashboard is responsive ($DASHBOARD_URL)"
  else
    echo -e "  ${RED}✗${NC} Dashboard is unreachable ($DASHBOARD_URL)"
  fi

  if curl -s -f -m 2 "$MANAGER_URL" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Manager is responsive ($MANAGER_URL)"
  else
    echo -e "  ${RED}✗${NC} Manager is unreachable ($MANAGER_URL)"
  fi

  if curl -s -f -m 2 "$OLLAMA_URL/api/tags" >/dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Ollama is responsive ($OLLAMA_URL)"
  else
    echo -e "  ${RED}✗${NC} Ollama is unreachable ($OLLAMA_URL)"
  fi
  echo ""
}

show_logs() {
  check_docker
  local target="${1:-agentteams-dashboard}"
  echo -e "${BLUE}▶ Streaming logs for $target (Ctrl+C to exit)...${NC}"
  docker logs -f "$target"
}

# Main routing
case "${1:-start}" in
  start)
    start_services
    ;;
  stop)
    stop_services
    ;;
  restart)
    restart_services
    ;;
  status)
    status_services
    ;;
  logs)
    show_logs "$2"
    ;;
  help|-h|--help)
    echo "Usage: $0 [start|stop|restart|status|logs [service]|help]"
    echo ""
    echo "Commands:"
    echo "  start     Start all AgentTeams containers and open dashboard (default)"
    echo "  stop      Stop all AgentTeams containers"
    echo "  restart   Restart all AgentTeams containers"
    echo "  status    Show current container status and health checks"
    echo "  logs      Follow logs (e.g. ./run.sh logs agentteams-dashboard)"
    echo ""
    ;;
  *)
    echo -e "${RED}Unknown command: $1${NC}"
    echo "Usage: $0 [start|stop|restart|status|logs|help]"
    exit 1
    ;;
esac
