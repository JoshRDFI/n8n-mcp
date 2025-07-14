#!/bin/bash
# ollama-n8n-mcp-startup.sh
# 
# Startup script for Ollama + n8n-MCP integration
# Optimized for NVIDIA 5080 with host Ollama installation
#
# Usage: ./scripts/ollama-n8n-mcp-startup.sh [OPTIONS]
# Options:
#   --skip-ollama    Skip Ollama startup (if already running)
#   --skip-model     Skip model loading (if already loaded)
#   --skip-mcp       Skip n8n-MCP startup (for testing Ollama only)
#   --debug          Enable debug output
#   --help           Show this help message

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OLLAMA_MODEL="qwen3:8b"
MCP_CONTAINER_NAME="n8n-mcp"
MCP_PORT="3000"
MCP_IMAGE="ghcr.io/czlonkowski/n8n-mcp:latest"
AUTH_TOKEN="${AUTH_TOKEN:-your-secure-token-here}"

# Parse command line arguments
SKIP_OLLAMA=false
SKIP_MODEL=false
SKIP_MCP=false
DEBUG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-ollama)
            SKIP_OLLAMA=true
            shift
            ;;
        --skip-model)
            SKIP_MODEL=true
            shift
            ;;
        --skip-mcp)
            SKIP_MCP=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --skip-ollama    Skip Ollama startup (if already running)"
            echo "  --skip-model     Skip model loading (if already loaded)"
            echo "  --skip-mcp       Skip n8n-MCP startup (for testing Ollama only)"
            echo "  --debug          Enable debug output"
            echo "  --help           Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Debug function
debug() {
    if [ "$DEBUG" = true ]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Log function
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Warning function
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Error function
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if Docker is running
check_docker() {
    if ! docker info >/dev/null 2>&1; then
        error "Docker is not running. Please start Docker first."
        exit 1
    fi
    log "Docker is running"
}

# Check if Ollama is installed
check_ollama_installed() {
    if ! command_exists ollama; then
        error "Ollama is not installed. Please install Ollama first:"
        echo "  curl -fsSL https://ollama.ai/install.sh | sh"
        exit 1
    fi
    log "Ollama is installed"
}

# Start Ollama service
start_ollama() {
    if [ "$SKIP_OLLAMA" = true ]; then
        log "Skipping Ollama startup (--skip-ollama flag)"
        return
    fi

    log "Starting Ollama service..."
    
    # Check if Ollama is already running
    if systemctl is-active --quiet ollama 2>/dev/null; then
        log "Ollama service is already running"
        return
    fi
    
    # Try to start Ollama service
    if command_exists systemctl; then
        if sudo systemctl start ollama 2>/dev/null; then
            log "Ollama service started via systemctl"
            sleep 2
        else
            warn "Failed to start Ollama via systemctl, trying direct start..."
            if ollama serve >/dev/null 2>&1 & then
                log "Ollama started directly"
                sleep 5
            else
                error "Failed to start Ollama"
                exit 1
            fi
        fi
    else
        # Fallback for non-systemd systems
        if ollama serve >/dev/null 2>&1 & then
            log "Ollama started directly"
            sleep 5
        else
            error "Failed to start Ollama"
            exit 1
        fi
    fi
}

# Load Qwen3:8b model
load_model() {
    if [ "$SKIP_MODEL" = true ]; then
        log "Skipping model loading (--skip-model flag)"
        return
    fi

    log "Loading Qwen3:8b model..."
    
    # Check if model is already loaded
    if ollama list 2>/dev/null | grep -q "$OLLAMA_MODEL"; then
        log "Model $OLLAMA_MODEL is already loaded"
        return
    fi
    
    # Download and load the model
    log "Downloading $OLLAMA_MODEL model (this may take a while)..."
    if ollama pull "$OLLAMA_MODEL"; then
        log "Model $OLLAMA_MODEL downloaded successfully"
    else
        error "Failed to download model $OLLAMA_MODEL"
        exit 1
    fi
}

# Verify model is ready
verify_model() {
    log "Verifying model availability..."
    if ollama list | grep -q "$OLLAMA_MODEL"; then
        log "Model $OLLAMA_MODEL is ready"
        debug "Available models:"
        if [ "$DEBUG" = true ]; then
            ollama list
        fi
    else
        error "Model $OLLAMA_MODEL is not available"
        exit 1
    fi
}

# Test Ollama functionality
test_ollama() {
    log "Testing Ollama functionality..."
    
    # Simple test to ensure Ollama is responding
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        log "Ollama API is responding"
    else
        error "Ollama API is not responding"
        exit 1
    fi
    
    # Test model inference (simple test)
    log "Testing model inference..."
    if echo '{"model": "'$OLLAMA_MODEL'", "prompt": "Hello", "stream": false}' | \
       curl -s -X POST http://localhost:11434/api/generate >/dev/null 2>&1; then
        log "Model inference test successful"
    else
        warn "Model inference test failed (this might be normal if model is still loading)"
    fi
}

# Start n8n-MCP Docker container
start_mcp() {
    if [ "$SKIP_MCP" = true ]; then
        log "Skipping n8n-MCP startup (--skip-mcp flag)"
        return
    fi

    log "Starting n8n-MCP Docker container..."
    
    # Stop existing container if running
    if docker ps -q -f name="$MCP_CONTAINER_NAME" | grep -q .; then
        log "Stopping existing n8n-MCP container..."
        docker stop "$MCP_CONTAINER_NAME" >/dev/null 2>&1 || true
        docker rm "$MCP_CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
    
    # Pull latest image
    log "Pulling latest n8n-MCP image..."
    if docker pull "$MCP_IMAGE"; then
        log "n8n-MCP image pulled successfully"
    else
        error "Failed to pull n8n-MCP image"
        exit 1
    fi
    
    # Start container
    log "Starting n8n-MCP container..."
    if docker run -d \
        --name "$MCP_CONTAINER_NAME" \
        -p "$MCP_PORT:3000" \
        -e MCP_MODE=http \
        -e AUTH_TOKEN="$AUTH_TOKEN" \
        -e LOG_LEVEL=info \
        "$MCP_IMAGE"; then
        log "n8n-MCP container started successfully"
    else
        error "Failed to start n8n-MCP container"
        exit 1
    fi
}

# Wait for MCP server to be ready
wait_for_mcp() {
    if [ "$SKIP_MCP" = true ]; then
        return
    fi

    log "Waiting for MCP server to start..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -f http://localhost:$MCP_PORT/health >/dev/null 2>&1; then
            log "MCP server is ready"
            return
        fi
        
        debug "Attempt $attempt/$max_attempts: MCP server not ready yet..."
        sleep 2
        attempt=$((attempt + 1))
    done
    
    error "MCP server failed to start within $((max_attempts * 2)) seconds"
    exit 1
}

# Test MCP connection
test_mcp() {
    if [ "$SKIP_MCP" = true ]; then
        return
    fi

    log "Testing MCP connection..."
    
    # Test health endpoint
    if curl -f http://localhost:$MCP_PORT/health >/dev/null 2>&1; then
        log "MCP health check passed"
    else
        error "MCP health check failed"
        exit 1
    fi
    
    # Test tools endpoint
    if curl -s http://localhost:$MCP_PORT/mcp >/dev/null 2>&1; then
        log "MCP endpoint is responding"
    else
        warn "MCP endpoint test failed (this might be normal for some endpoints)"
    fi
}

# Display final status
show_status() {
    echo ""
    echo -e "${GREEN}✅ Ollama + n8n-MCP integration ready!${NC}"
    echo ""
    echo -e "${BLUE}🌐 MCP Server:${NC} http://localhost:$MCP_PORT"
    echo -e "${BLUE}🤖 Ollama Model:${NC} $OLLAMA_MODEL (Host Installation)"
    echo -e "${BLUE}🔑 Auth Token:${NC} $AUTH_TOKEN"
    echo ""
    echo -e "${YELLOW}📋 Next Steps:${NC}"
    echo "1. Configure your Ollama client to use the MCP server"
    echo "2. Test the integration with a simple workflow"
    echo "3. Check logs: docker logs $MCP_CONTAINER_NAME"
    echo ""
    echo -e "${YELLOW}🔧 Useful Commands:${NC}"
    echo "  Stop MCP: docker stop $MCP_CONTAINER_NAME"
    echo "  View logs: docker logs -f $MCP_CONTAINER_NAME"
    echo "  Test Ollama: ollama run $OLLAMA_MODEL 'Hello'"
    echo "  Test MCP: curl http://localhost:$MCP_PORT/health"
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Starting Ollama + n8n-MCP Integration...${NC}"
    echo ""
    
    # Pre-flight checks
    check_docker
    check_ollama_installed
    
    # Start services
    start_ollama
    load_model
    verify_model
    test_ollama
    
    # Start MCP
    start_mcp
    wait_for_mcp
    test_mcp
    
    # Show final status
    show_status
}

# Run main function
main "$@" 