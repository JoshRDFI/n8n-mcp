#!/bin/bash
# content-creation-startup.sh
# 
# Complete startup script for Content Creation & Ad Posting with Ollama + n8n-MCP
# Includes blog writing, ad creation, and content management
#
# Usage: ./scripts/ecommerce-automation-startup.sh [OPTIONS]
# Options:
#   --skip-ollama    Skip Ollama startup (if already running)
#   --skip-model     Skip model loading (if already loaded)
#   --skip-mcp       Skip n8n-MCP startup (for testing Ollama only)
#   --interactive    Start interactive chat interface after setup
#   --example        Run e-commerce automation example
#   --debug          Enable debug output
#   --help           Show this help message

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
OLLAMA_MODEL="qwen3:8b"
MCP_CONTAINER_NAME="n8n-mcp"
MCP_PORT="3000"
MCP_IMAGE="ghcr.io/czlonkowski/n8n-mcp:latest"
# Load AUTH_TOKEN from .env file if it exists
if [ -f .env ]; then
    # Source the .env file to load environment variables
    set -a  # automatically export all variables
    source .env
    set +a  # stop automatically exporting
fi

# Use AUTH_TOKEN from environment or prompt user
if [ -z "$AUTH_TOKEN" ]; then
    echo -e "${RED}❌ AUTH_TOKEN not found in .env file${NC}"
    echo "Please add AUTH_TOKEN=your-token to your .env file"
    exit 1
fi

# Parse command line arguments
SKIP_OLLAMA=false
SKIP_MODEL=false
SKIP_MCP=false
INTERACTIVE=false
EXAMPLE=false
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
        --interactive)
            INTERACTIVE=true
            shift
            ;;
        --example)
            EXAMPLE=true
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
            echo "  --interactive    Start interactive chat interface after setup"
            echo "  --example        Run e-commerce automation example"
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

# Success function
success() {
    echo -e "${PURPLE}[SUCCESS]${NC} $1"
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

    log "Loading Qwen3:8b model for content creation and ad posting..."
    
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
        log "Model $OLLAMA_MODEL is ready for content creation and ad posting"
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

    log "Starting n8n-MCP Docker container for content creation and ad posting..."
    
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
    
    # Test content creation nodes availability
    log "Testing content creation nodes availability..."
    if curl -s -H "Authorization: Bearer $AUTH_TOKEN" -H "Content-Type: application/json" \
       -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"search_nodes","arguments":{"query":"http file content","limit":5}},"id":1}' \
       http://localhost:$MCP_PORT/mcp >/dev/null 2>&1; then
        log "Content creation nodes are accessible"
    else
        warn "Content creation nodes test failed (this might be normal for some endpoints)"
    fi
}

# Start content creation bridge
start_content_bridge() {
    log "Starting Content Creation & Ad Posting Bridge..."
    
    # Check if the bridge script exists
    if [ ! -f "examples/content-creation-bridge.js" ]; then
        error "Content creation bridge not found. Please ensure the script exists."
        exit 1
    fi
    
    # Set environment variables
    export AUTH_TOKEN="$AUTH_TOKEN"
    export OLLAMA_HOST="localhost"
    export OLLAMA_PORT="11434"
    export MCP_HOST="localhost"
    export MCP_PORT="$MCP_PORT"
    
    if [ "$INTERACTIVE" = true ]; then
        log "Starting interactive chat interface..."
        node examples/content-creation-bridge.js --interactive
    elif [ "$EXAMPLE" = true ]; then
        log "Running content creation example..."
        node examples/content-creation-bridge.js --example
    else
        log "Content creation bridge is ready!"
        echo ""
        echo -e "${PURPLE}💡 Next Steps:${NC}"
        echo "1. Start interactive chat: node examples/content-creation-bridge.js --interactive"
        echo "2. Run example: node examples/content-creation-bridge.js --example"
        echo "3. Create custom workflows using the bridge"
    fi
}

# Display final status
show_status() {
    echo ""
    echo -e "${PURPLE}🎉 Content Creation & Ad Posting System Ready!${NC}"
    echo ""
    echo -e "${BLUE}🌐 MCP Server:${NC} http://localhost:$MCP_PORT"
    echo -e "${BLUE}🤖 Ollama Model:${NC} $OLLAMA_MODEL (Host Installation)"
    echo -e "${BLUE}🔑 Auth Token:${NC} $AUTH_TOKEN"
    echo ""
    echo -e "${YELLOW}📋 Available Capabilities:${NC}"
    echo "✅ Blog post creation (SEO-optimized, long-form content)"
    echo "✅ Ad copy generation (Facebook Ads, Google Ads)"
    echo "✅ Content scheduling and automation"
    echo "✅ File management for content storage"
    echo "✅ AliDropship/Sellvia integration (via HTTP APIs)"
    echo ""
    echo -e "${YELLOW}🔧 Useful Commands:${NC}"
    echo "  Interactive Chat: node examples/ecommerce-automation-bridge.js --interactive"
    echo "  Run Example: node examples/ecommerce-automation-bridge.js --example"
    echo "  Stop MCP: docker stop $MCP_CONTAINER_NAME"
    echo "  View logs: docker logs -f $MCP_CONTAINER_NAME"
    echo "  Test Ollama: ollama run $OLLAMA_MODEL 'Hello'"
    echo "  Test MCP: curl http://localhost:$MCP_PORT/health"
    echo ""
    echo -e "${GREEN}💬 Example Chat Commands:${NC}"
    echo "  \"Create a workflow to generate blog posts about my products\""
    echo "  \"Set up Facebook Ads automation for new products\""
    echo "  \"Create a content calendar workflow for my blog\""
    echo "  \"Generate ad copy for Google Ads campaigns\""
}

# Main execution
main() {
    echo -e "${PURPLE}🚀 Starting Content Creation & Ad Posting System...${NC}"
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
    
    # Start content creation bridge if requested
    if [ "$INTERACTIVE" = true ] || [ "$EXAMPLE" = true ]; then
        start_content_bridge
    else
        # Show final status
        show_status
    fi
}

# Run main function
main "$@" 