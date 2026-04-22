#!/bin/bash
# =============================================================================
# initMAX Zabbix MCP Server - OpenShift Deploy Script
# https://github.com/initMAX/zabbix-mcp-server
# =============================================================================
set -e

NAMESPACE="zabbix-mcp-server"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    cat << EOF
Usage: $0 <command>

Commands:
  deploy      Deploy/update all resources
  build       Start a new build
  status      Show deployment status
  logs        Show server logs
  secret      Update secret interactively
  config      Edit configmap
  restart     Restart deployment
  delete      Delete all resources

Examples:
  $0 deploy
  $0 build
  $0 logs -f
EOF
}

check_oc() {
    if ! command -v oc &> /dev/null; then
        log_error "oc CLI not found. Install OpenShift CLI first."
        exit 1
    fi
    if ! oc whoami &> /dev/null; then
        log_error "Not logged in to OpenShift. Run: oc login"
        exit 1
    fi
}

deploy() {
    log_info "Deploying to namespace: $NAMESPACE"
    
    # Apply with kustomize
    oc apply -k "$SCRIPT_DIR/base"
    
    # Wait for build if ImageStream is empty
    if ! oc get istag "$NAMESPACE/zabbix-mcp-server:latest" -n "$NAMESPACE" &> /dev/null; then
        log_info "Starting initial build..."
        oc start-build zabbix-mcp-server -n "$NAMESPACE" --follow
    fi
    
    log_info "Waiting for deployment..."
    oc rollout status deployment/zabbix-mcp-server -n "$NAMESPACE" --timeout=300s
    
    log_info "Deployment complete!"
    status
}

build() {
    log_info "Starting build..."
    oc start-build zabbix-mcp-server -n "$NAMESPACE" --follow
}

status() {
    echo ""
    log_info "=== Deployment Status ==="
    oc get deployment,pods,svc,route -n "$NAMESPACE"
    
    echo ""
    log_info "=== Routes ==="
    oc get route -n "$NAMESPACE" -o custom-columns='NAME:.metadata.name,HOST:.spec.host,PORT:.spec.port.targetPort'
}

logs() {
    oc logs -f deployment/zabbix-mcp-server -n "$NAMESPACE" "$@"
}

update_secret() {
    log_info "Updating secret..."
    
    read -p "Zabbix Production API Token: " -s ZABBIX_TOKEN
    echo ""
    
    oc create secret generic zabbix-mcp-secret \
        --from-literal=ZABBIX_PRODUCTION_TOKEN="$ZABBIX_TOKEN" \
        --dry-run=client -o yaml | oc apply -n "$NAMESPACE" -f -
    
    log_info "Secret updated. Restarting deployment..."
    oc rollout restart deployment/zabbix-mcp-server -n "$NAMESPACE"
}

edit_config() {
    oc edit configmap zabbix-mcp-config -n "$NAMESPACE"
    log_warn "ConfigMap updated. Run '$0 restart' to apply changes."
}

restart() {
    log_info "Restarting deployment..."
    oc rollout restart deployment/zabbix-mcp-server -n "$NAMESPACE"
    oc rollout status deployment/zabbix-mcp-server -n "$NAMESPACE"
}

delete_all() {
    read -p "Delete all resources in $NAMESPACE? (yes/no): " confirm
    if [[ "$confirm" == "yes" ]]; then
        log_warn "Deleting all resources..."
        oc delete -k "$SCRIPT_DIR/base" --ignore-not-found
        log_info "Done."
    else
        log_info "Cancelled."
    fi
}

# Main
check_oc

case "${1:-}" in
    deploy)  deploy ;;
    build)   build ;;
    status)  status ;;
    logs)    shift; logs "$@" ;;
    secret)  update_secret ;;
    config)  edit_config ;;
    restart) restart ;;
    delete)  delete_all ;;
    *)       usage; exit 1 ;;
esac
