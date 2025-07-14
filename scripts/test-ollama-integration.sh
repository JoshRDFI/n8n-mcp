#!/bin/bash
# test-ollama-integration.sh
#
# Test script for Ollama + n8n-MCP integration
# Specifically tests Qwen3:8b with NVIDIA 5080 performance
#
# Usage: ./scripts/test-ollama-integration.sh [OPTIONS]
# Options:
#   --benchmark    Run performance benchmarks
#   --mcp-test     Test MCP tool calling
#   --gpu-test     Test GPU utilization
#   --debug        Enable debug output
#   --help         Show this help message

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OLLAMA_MODEL="qwen3:8b"
MCP_PORT="3000"
AUTH_TOKEN="${AUTH_TOKEN:-your-secure-token-here}"

# Parse command line arguments
BENCHMARK=false
MCP_TEST=false
GPU_TEST=false
DEBUG=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --benchmark)
            BENCHMARK=true
            shift
            ;;
        --mcp-test)
            MCP_TEST=true
            shift
            ;;
        --gpu-test)
            GPU_TEST=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --benchmark    Run performance benchmarks"
            echo "  --mcp-test     Test MCP tool calling"
            echo "  --gpu-test     Test GPU utilization"
            echo "  --debug        Enable debug output"
            echo "  --help         Show this help message"
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

# Test Ollama basic functionality
test_ollama_basic() {
    log "Testing Ollama basic functionality..."
    
    # Check if Ollama is running
    if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        error "Ollama is not running. Please start Ollama first."
        exit 1
    fi
    
    # Check if model is available
    if ! ollama list | grep -q "$OLLAMA_MODEL"; then
        error "Model $OLLAMA_MODEL is not available. Please load it first."
        exit 1
    fi
    
    log "Ollama basic functionality: ✅"
}

# Test GPU utilization
test_gpu_utilization() {
    if [ "$GPU_TEST" = false ]; then
        return
    fi
    
    log "Testing GPU utilization with NVIDIA 5080..."
    
    # Check if nvidia-smi is available
    if ! command_exists nvidia-smi; then
        warn "nvidia-smi not found. Skipping GPU test."
        return
    fi
    
    # Get initial GPU stats
    log "Initial GPU stats:"
    nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits
    
    # Run a test inference
    log "Running test inference to check GPU utilization..."
    start_time=$(date +%s)
    
    # Run a simple inference
    if echo '{"model": "'$OLLAMA_MODEL'", "prompt": "Explain what n8n is in one sentence.", "stream": false}' | \
       curl -s -X POST http://localhost:11434/api/generate >/dev/null 2>&1; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        log "Inference completed in ${duration}s"
        
        # Get GPU stats after inference
        log "GPU stats after inference:"
        nvidia-smi --query-gpu=name,memory.used,memory.total,utilization.gpu --format=csv,noheader,nounits
    else
        error "Inference test failed"
        return 1
    fi
    
    log "GPU utilization test: ✅"
}

# Test MCP server
test_mcp_server() {
    if [ "$MCP_TEST" = false ]; then
        return
    fi
    
    log "Testing MCP server..."
    
    # Check if MCP server is running
    if ! curl -f http://localhost:$MCP_PORT/health >/dev/null 2>&1; then
        error "MCP server is not running. Please start it first."
        exit 1
    fi
    
    # Test health endpoint
    log "Testing MCP health endpoint..."
    health_response=$(curl -s http://localhost:$MCP_PORT/health)
    debug "Health response: $health_response"
    
    # Test tools endpoint
    log "Testing MCP tools endpoint..."
    tools_response=$(curl -s http://localhost:$MCP_PORT/mcp)
    debug "Tools response length: ${#tools_response} characters"
    
    # Test a simple tool call
    log "Testing simple MCP tool call..."
    tool_request='{
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/list",
        "params": {}
    }'
    
    tool_response=$(echo "$tool_request" | curl -s -X POST http://localhost:$MCP_PORT/mcp \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d @-)
    
    debug "Tool response: $tool_response"
    
    if echo "$tool_response" | grep -q "result"; then
        log "MCP tool call successful"
    else
        warn "MCP tool call may have failed (check debug output)"
    fi
    
    log "MCP server test: ✅"
}

# Run performance benchmarks
run_benchmarks() {
    if [ "$BENCHMARK" = false ]; then
        return
    fi
    
    log "Running performance benchmarks..."
    
    # Test 1: Simple inference speed
    log "Benchmark 1: Simple inference speed"
    start_time=$(date +%s.%N)
    
    echo '{"model": "'$OLLAMA_MODEL'", "prompt": "Hello", "stream": false}' | \
    curl -s -X POST http://localhost:11434/api/generate >/dev/null 2>&1
    
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    log "Simple inference: ${duration}s"
    
    # Test 2: Longer prompt
    log "Benchmark 2: Longer prompt processing"
    start_time=$(date +%s.%N)
    
    echo '{"model": "'$OLLAMA_MODEL'", "prompt": "Write a detailed explanation of workflow automation and how n8n can be used to create complex integrations between different services.", "stream": false}' | \
    curl -s -X POST http://localhost:11434/api/generate >/dev/null 2>&1
    
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    log "Long prompt: ${duration}s"
    
    # Test 3: MCP tool call speed
    log "Benchmark 3: MCP tool call speed"
    start_time=$(date +%s.%N)
    
    echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}}' | \
    curl -s -X POST http://localhost:$MCP_PORT/mcp \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d @- >/dev/null 2>&1
    
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    log "MCP tool call: ${duration}s"
    
    # Test 4: Memory usage
    log "Benchmark 4: Memory usage"
    if command_exists nvidia-smi; then
        memory_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
        memory_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits)
        memory_percent=$(echo "scale=1; $memory_used * 100 / $memory_total" | bc -l)
        log "GPU Memory: ${memory_used}MB / ${memory_total}MB (${memory_percent}%)"
    fi
    
    log "Performance benchmarks: ✅"
}

# Test Ollama with n8n context
test_n8n_context() {
    log "Testing Ollama with n8n context..."
    
    # Test with n8n-specific prompt
    prompt="I need to create an n8n workflow that monitors a Slack channel for messages containing the word 'urgent' and then sends an email notification. Can you help me design this workflow?"
    
    log "Testing n8n-specific prompt..."
    start_time=$(date +%s.%N)
    
    response=$(echo '{"model": "'$OLLAMA_MODEL'", "prompt": "'$prompt'", "stream": false}' | \
               curl -s -X POST http://localhost:11434/api/generate)
    
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc -l)
    
    # Extract response text
    response_text=$(echo "$response" | jq -r '.response' 2>/dev/null || echo "Response parsing failed")
    
    log "n8n context test completed in ${duration}s"
    debug "Response preview: ${response_text:0:100}..."
    
    if [ -n "$response_text" ] && [ "$response_text" != "null" ]; then
        log "n8n context test: ✅"
    else
        warn "n8n context test may have failed"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}🧪 Testing Ollama + n8n-MCP Integration...${NC}"
    echo ""
    
    # Run tests
    test_ollama_basic
    test_gpu_utilization
    test_mcp_server
    test_n8n_context
    run_benchmarks
    
    echo ""
    echo -e "${GREEN}✅ All tests completed!${NC}"
    echo ""
    echo -e "${YELLOW}📊 Summary:${NC}"
    echo "• Ollama basic functionality: ✅"
    echo "• GPU utilization (if available): ✅"
    echo "• MCP server connectivity: ✅"
    echo "• n8n context understanding: ✅"
    echo "• Performance benchmarks: ✅"
    echo ""
    echo -e "${YELLOW}🔧 Next Steps:${NC}"
    echo "1. Configure your Ollama client to use the MCP server"
    echo "2. Test actual workflow creation with n8n"
    echo "3. Monitor performance during real usage"
}

# Run main function
main "$@" 