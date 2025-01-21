#!/bin/bash
set -e

# Colors and formatting
BOLD='\033[1m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'
CHECKMARK="${GREEN}✓${NC}"
ARROW="${BLUE}→${NC}"

# Store PIDs and ports of port-forwarding processes
FORWARD_PIDS=()
FORWARD_PORTS=()
FORWARD_NAMES=()

# Helper functions
log_info() { echo -e "${ARROW} $1"; }
log_success() { echo -e "${CHECKMARK} $1"; }
log_error() { echo -e "${RED}✗ $1${NC}" >&2; }
log_warning() { echo -e "${YELLOW}! $1${NC}"; }

check_prerequisites() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is required but not installed"
        exit 1
    fi
}

# Open URL in default browser
open_url() {
    local url=$1
    case "$(uname -s)" in
        Darwin)  open "$url" ;;
        Linux)   xdg-open "$url" 2>/dev/null || sensible-browser "$url" 2>/dev/null || {
                    log_warning "Could not open browser automatically. Please visit: $url"
                } ;;
        *)       log_warning "Please open manually: $url" ;;
    esac
}

# Find service index
find_service_index() {
    local service=$1
    for i in "${!FORWARD_NAMES[@]}"; do
        if [[ "${FORWARD_NAMES[$i]}" == "$service" ]]; then
            echo $i
            return 0
        fi
    done
    echo -1
}

# Cleanup function
cleanup() {
    echo
    log_info "Cleaning up port forwards..."
    for i in "${!FORWARD_PIDS[@]}"; do
        stop_forward "${FORWARD_NAMES[$i]}"
    done
}

# Start port forwarding
start_forward() {
    local service=$1
    local command=$2
    local port=$3

    # Check if service is already running
    if [[ $(find_service_index "$service") != -1 ]]; then
        log_warning "Port-forward for $service is already running"
        return
    fi

    log_info "Starting port-forward for $service..."
    eval "$command &"
    local pid=$!
    
    # Wait briefly to ensure port-forward is established
    sleep 2
    if ! ps -p $pid > /dev/null; then
        log_error "Failed to start port-forward for $service"
        return 1
    fi

    FORWARD_NAMES+=("$service")
    FORWARD_PIDS+=($pid)
    FORWARD_PORTS+=($port)

    log_success "$service port-forward started on port $port"
}

# Stop port forwarding
stop_forward() {
    local service=$1
    local idx=$(find_service_index "$service")
    
    if [[ $idx != -1 ]]; then
        kill ${FORWARD_PIDS[$idx]} 2>/dev/null || true
        unset 'FORWARD_NAMES[$idx]'
        unset 'FORWARD_PIDS[$idx]'
        unset 'FORWARD_PORTS[$idx]'
        # Repack arrays
        FORWARD_NAMES=("${FORWARD_NAMES[@]}")
        FORWARD_PIDS=("${FORWARD_PIDS[@]}")
        FORWARD_PORTS=("${FORWARD_PORTS[@]}")
        log_success "Stopped $service port-forward"
    fi
}

# Service-specific functions
start_argocd() {
    start_forward "ArgoCD" "kubectl port-forward svc/argocd-server -n argocd 8080:443" 8080
    if [[ $? -eq 0 ]]; then
        local password=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
        echo -e "\n${BOLD}ArgoCD Credentials:${NC}"
        echo -e "URL:      ${BLUE}https://localhost:8080${NC}"
        echo -e "Username: ${BLUE}admin${NC}"
        echo -e "Password: ${BLUE}$password${NC}"
        open_url "https://localhost:8080"
    fi
}

start_app1() {
    start_forward "App1" "kubectl port-forward svc/app1 -n dev 8081:80" 8081
    if [[ $? -eq 0 ]]; then
        echo -e "\n${BOLD}App1:${NC}"
        echo -e "URL: ${BLUE}http://localhost:8081${NC}"
        open_url "http://localhost:8081"
    fi
}

start_app2() {
    start_forward "App2" "kubectl port-forward svc/app2 -n dev 8082:80" 8082
    if [[ $? -eq 0 ]]; then
        echo -e "\n${BOLD}App2:${NC}"
        echo -e "URL: ${BLUE}http://localhost:8082${NC}"
        open_url "http://localhost:8082"
    fi
}

# Service definitions
SERVICES=(
    "ArgoCD"
    "App1"
    "App2"
)

# Display active forwards
show_status() {
    if [[ ${#FORWARD_PIDS[@]} -eq 0 ]]; then
        echo -e "\n${YELLOW}No active port forwards${NC}"
        return
    fi

    echo -e "\n${BOLD}Active Port Forwards:${NC}"
    printf "${BOLD}%-20s %-10s %-10s${NC}\n" "Service" "Port" "PID"
    echo "----------------------------------------"
    for i in "${!FORWARD_NAMES[@]}"; do
        printf "%-20s %-10s %-10s\n" \
            "${FORWARD_NAMES[$i]}" \
            "${FORWARD_PORTS[$i]}" \
            "${FORWARD_PIDS[$i]}"
    done
}

# Menu
show_menu() {
    echo -e "\n${BOLD}Port Forward Menu${NC}"
    echo "----------------------------------------"
    for i in "${!SERVICES[@]}"; do
        local service="${SERVICES[$i]}"
        local status=""
        if [[ $(find_service_index "$service") != -1 ]]; then
            status="${GREEN}(active)${NC}"
        fi
        echo -e "$((i+1)). Start $service $status"
    done
    echo "----------------------------------------"
    echo "s. Show status"
    echo "x. Stop all and exit"
    echo
}

# Main
main() {
    check_prerequisites
    trap cleanup EXIT

    while true; do
        show_menu
        read -p "Enter choice: " choice
        echo

        case $choice in
            [1-3])
                local idx=$((choice-1))
                local service="${SERVICES[$idx]}"
                # Convert to lowercase using tr instead of ${,,}
                local service_lower=$(echo "$service" | tr '[:upper:]' '[:lower:]')
                start_${service_lower}
                ;;
            s)
                show_status
                ;;
            x)
                exit 0
                ;;
            *)
                log_error "Invalid choice"
                ;;
        esac

        echo
        read -p "Press enter to continue..."
    done
}

main 