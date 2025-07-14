#!/bin/bash
# benchmark-ollama-performance.sh
#
# Comprehensive performance benchmarking for Ollama + n8n-MCP integration
# Optimized for NVIDIA 5080 testing
#
# Usage: ./scripts/benchmark-ollama-performance.sh [OPTIONS]
# Options:
#   --iterations N    Number of test iterations (default: 5)
#   --warmup N        Number of warmup runs (default: 3)
#   --output FILE     Output results to file
#   --compare         Compare with baseline results
#   --gpu-only        Only run GPU-related tests
#   --mcp-only        Only run MCP-related tests
#   --help            Show this help message

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
OLLAMA_MODEL="qwen3:8b"
MCP_PORT="3000"
AUTH_TOKEN="${AUTH_TOKEN:-your-secure-token-here}"
ITERATIONS=5
WARMUP_RUNS=3
OUTPUT_FILE=""
COMPARE_MODE=false
GPU_ONLY=false
MCP_ONLY=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --iterations)
            ITERATIONS="$2"
            shift 2
            ;;
        --warmup)
            WARMUP_RUNS="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --compare)
            COMPARE_MODE=true
            shift
            ;;
        --gpu-only)
            GPU_ONLY=true
            shift
            ;;
        --mcp-only)
            MCP_ONLY=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --iterations N    Number of test iterations (default: 5)"
            echo "  --warmup N        Number of warmup runs (default: 3)"
            echo "  --output FILE     Output results to file"
            echo "  --compare         Compare with baseline results"
            echo "  --gpu-only        Only run GPU-related tests"
            echo "  --mcp-only        Only run MCP-related tests"
            echo "  --help            Show this help message"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Results storage
declare -A RESULTS
declare -A GPU_STATS
declare -A MCP_STATS

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

# Header function
header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Get current timestamp
get_timestamp() {
    date +%s.%N
}

# Calculate duration
calculate_duration() {
    local start=$1
    local end=$2
    echo "$end - $start" | bc -l
}

# Calculate statistics
calculate_stats() {
    local values=("$@")
    local count=${#values[@]}
    
    if [ $count -eq 0 ]; then
        echo "0,0,0,0"
        return
    fi
    
    # Sort values
    IFS=$'\n' sorted=($(sort -n <<<"${values[*]}"))
    unset IFS
    
    # Calculate min, max, sum
    local min=${sorted[0]}
    local max=${sorted[-1]}
    local sum=0
    
    for val in "${values[@]}"; do
        sum=$(echo "$sum + $val" | bc -l)
    done
    
    # Calculate mean and median
    local mean=$(echo "scale=3; $sum / $count" | bc -l)
    local median
    
    if [ $((count % 2)) -eq 0 ]; then
        local mid1=$((count / 2 - 1))
        local mid2=$((count / 2))
        median=$(echo "scale=3; (${sorted[mid1]} + ${sorted[mid2]}) / 2" | bc -l)
    else
        local mid=$((count / 2))
        median=${sorted[mid]}
    fi
    
    echo "$min,$max,$mean,$median"
}

# Get GPU stats
get_gpu_stats() {
    if ! command_exists nvidia-smi; then
        echo "0,0,0,0"
        return
    fi
    
    local memory_used=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
    local memory_total=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits)
    local utilization=$(nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits)
    local temperature=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits)
    
    echo "$memory_used,$memory_total,$utilization,$temperature"
}

# Test Ollama model loading
test_model_loading() {
    if [ "$GPU_ONLY" = true ] && [ "$MCP_ONLY" = true ]; then
        return
    fi
    
    header "Model Loading Test"
    
    log "Testing model loading performance..."
    
    # Warmup runs
    for i in $(seq 1 $WARMUP_RUNS); do
        log "Warmup run $i/$WARMUP_RUNS"
        ollama list | grep -q "$OLLAMA_MODEL" || {
            error "Model $OLLAMA_MODEL not found"
            return 1
        }
        sleep 1
    done
    
    # Actual test runs
    local times=()
    for i in $(seq 1 $ITERATIONS); do
        log "Test run $i/$ITERATIONS"
        
        start_time=$(get_timestamp)
        ollama list | grep -q "$OLLAMA_MODEL"
        end_time=$(get_timestamp)
        
        duration=$(calculate_duration $start_time $end_time)
        times+=($duration)
        
        log "Run $i: ${duration}s"
        sleep 1
    done
    
    # Calculate statistics
    local stats=$(calculate_stats "${times[@]}")
    IFS=',' read -r min max mean median <<< "$stats"
    
    RESULTS["model_loading_min"]=$min
    RESULTS["model_loading_max"]=$max
    RESULTS["model_loading_mean"]=$mean
    RESULTS["model_loading_median"]=$median
    
    echo -e "${GREEN}Model Loading Results:${NC}"
    echo "  Min: ${min}s"
    echo "  Max: ${max}s"
    echo "  Mean: ${mean}s"
    echo "  Median: ${median}s"
}

# Test Ollama inference
test_ollama_inference() {
    if [ "$MCP_ONLY" = true ]; then
        return
    fi
    
    header "Ollama Inference Test"
    
    log "Testing Ollama inference performance..."
    
    # Test prompts
    local prompts=(
        "Hello"
        "What is n8n?"
        "Create a simple workflow"
        "Explain workflow automation"
        "How to use webhooks in n8n"
    )
    
    # Warmup runs
    for i in $(seq 1 $WARMUP_RUNS); do
        log "Warmup run $i/$WARMUP_RUNS"
        echo '{"model": "'$OLLAMA_MODEL'", "prompt": "Hello", "stream": false}' | \
        curl -s -X POST http://localhost:11434/api/generate >/dev/null 2>&1
        sleep 1
    done
    
    # Test each prompt
    for prompt_idx in "${!prompts[@]}"; do
        local prompt="${prompts[$prompt_idx]}"
        log "Testing prompt: $prompt"
        
        local times=()
        for i in $(seq 1 $ITERATIONS); do
            start_time=$(get_timestamp)
            
            echo '{"model": "'$OLLAMA_MODEL'", "prompt": "'$prompt'", "stream": false}' | \
            curl -s -X POST http://localhost:11434/api/generate >/dev/null 2>&1
            
            end_time=$(get_timestamp)
            duration=$(calculate_duration $start_time $end_time)
            times+=($duration)
            
            log "  Run $i: ${duration}s"
            sleep 1
        done
        
        # Calculate statistics
        local stats=$(calculate_stats "${times[@]}")
        IFS=',' read -r min max mean median <<< "$stats"
        
        local key="inference_${prompt_idx}"
        RESULTS["${key}_min"]=$min
        RESULTS["${key}_max"]=$max
        RESULTS["${key}_mean"]=$mean
        RESULTS["${key}_median"]=$median
        
        echo -e "${GREEN}Prompt $((prompt_idx + 1)) Results:${NC}"
        echo "  Min: ${min}s"
        echo "  Max: ${max}s"
        echo "  Mean: ${mean}s"
        echo "  Median: ${median}s"
    done
}

# Test GPU utilization
test_gpu_utilization() {
    if [ "$MCP_ONLY" = true ]; then
        return
    fi
    
    header "GPU Utilization Test"
    
    if ! command_exists nvidia-smi; then
        warn "nvidia-smi not found. Skipping GPU tests."
        return
    fi
    
    log "Testing GPU utilization during inference..."
    
    # Get initial GPU stats
    local initial_stats=$(get_gpu_stats)
    IFS=',' read -r initial_memory_used initial_memory_total initial_utilization initial_temperature <<< "$initial_stats"
    
    log "Initial GPU stats:"
    log "  Memory: ${initial_memory_used}MB / ${initial_memory_total}MB"
    log "  Utilization: ${initial_utilization}%"
    log "  Temperature: ${initial_temperature}°C"
    
    # Run inference with GPU monitoring
    local memory_usage=()
    local utilization_usage=()
    local temperature_usage=()
    
    for i in $(seq 1 $ITERATIONS); do
        log "GPU test run $i/$ITERATIONS"
        
        # Start inference
        start_time=$(get_timestamp)
        
        echo '{"model": "'$OLLAMA_MODEL'", "prompt": "Write a detailed explanation of n8n workflow automation", "stream": false}' | \
        curl -s -X POST http://localhost:11434/api/generate >/dev/null 2>&1 &
        
        local pid=$!
        
        # Monitor GPU during inference
        local max_memory=0
        local max_utilization=0
        local max_temperature=0
        
        while kill -0 $pid 2>/dev/null; do
            local current_stats=$(get_gpu_stats)
            IFS=',' read -r current_memory current_total current_util current_temp <<< "$current_stats"
            
            if (( $(echo "$current_memory > $max_memory" | bc -l) )); then
                max_memory=$current_memory
            fi
            if (( $(echo "$current_util > $max_utilization" | bc -l) )); then
                max_utilization=$current_util
            fi
            if (( $(echo "$current_temp > $max_temperature" | bc -l) )); then
                max_temperature=$current_temp
            fi
            
            sleep 0.5
        done
        
        wait $pid
        end_time=$(get_timestamp)
        duration=$(calculate_duration $start_time $end_time)
        
        memory_usage+=($max_memory)
        utilization_usage+=($max_utilization)
        temperature_usage+=($max_temperature)
        
        log "  Run $i: ${duration}s, Memory: ${max_memory}MB, GPU: ${max_utilization}%, Temp: ${max_temperature}°C"
        sleep 2
    done
    
    # Calculate GPU statistics
    local memory_stats=$(calculate_stats "${memory_usage[@]}")
    local utilization_stats=$(calculate_stats "${utilization_usage[@]}")
    local temperature_stats=$(calculate_stats "${temperature_usage[@]}")
    
    IFS=',' read -r mem_min mem_max mem_mean mem_median <<< "$memory_stats"
    IFS=',' read -r util_min util_max util_mean util_median <<< "$utilization_stats"
    IFS=',' read -r temp_min temp_max temp_mean temp_median <<< "$temperature_stats"
    
    GPU_STATS["memory_min"]=$mem_min
    GPU_STATS["memory_max"]=$mem_max
    GPU_STATS["memory_mean"]=$mem_mean
    GPU_STATS["memory_median"]=$mem_median
    GPU_STATS["utilization_min"]=$util_min
    GPU_STATS["utilization_max"]=$util_max
    GPU_STATS["utilization_mean"]=$util_mean
    GPU_STATS["utilization_median"]=$util_median
    GPU_STATS["temperature_min"]=$temp_min
    GPU_STATS["temperature_max"]=$temp_max
    GPU_STATS["temperature_mean"]=$temp_mean
    GPU_STATS["temperature_median"]=$temp_median
    
    echo -e "${GREEN}GPU Utilization Results:${NC}"
    echo "  Memory Usage:"
    echo "    Min: ${mem_min}MB"
    echo "    Max: ${mem_max}MB"
    echo "    Mean: ${mem_mean}MB"
    echo "    Median: ${mem_median}MB"
    echo "  GPU Utilization:"
    echo "    Min: ${util_min}%"
    echo "    Max: ${util_max}%"
    echo "    Mean: ${util_mean}%"
    echo "    Median: ${util_median}%"
    echo "  Temperature:"
    echo "    Min: ${temp_min}°C"
    echo "    Max: ${temp_max}°C"
    echo "    Mean: ${temp_mean}°C"
    echo "    Median: ${temp_median}°C"
}

# Test MCP server performance
test_mcp_performance() {
    if [ "$GPU_ONLY" = true ]; then
        return
    fi
    
    header "MCP Server Performance Test"
    
    log "Testing MCP server performance..."
    
    # Check if MCP server is running
    if ! curl -f http://localhost:$MCP_PORT/health >/dev/null 2>&1; then
        error "MCP server is not running"
        return 1
    fi
    
    # Test different MCP operations
    local operations=(
        '{"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}}'
        '{"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "get_database_statistics", "arguments": {}}}'
        '{"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "list_nodes", "arguments": {"limit": 10}}}'
        '{"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "search_nodes", "arguments": {"query": "slack"}}}'
    )
    
    # Test each operation
    for op_idx in "${!operations[@]}"; do
        local operation="${operations[$op_idx]}"
        log "Testing MCP operation $((op_idx + 1))"
        
        local times=()
        for i in $(seq 1 $ITERATIONS); do
            start_time=$(get_timestamp)
            
            echo "$operation" | curl -s -X POST http://localhost:$MCP_PORT/mcp \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $AUTH_TOKEN" \
                -d @- >/dev/null 2>&1
            
            end_time=$(get_timestamp)
            duration=$(calculate_duration $start_time $end_time)
            times+=($duration)
            
            log "  Run $i: ${duration}s"
            sleep 0.5
        done
        
        # Calculate statistics
        local stats=$(calculate_stats "${times[@]}")
        IFS=',' read -r min max mean median <<< "$stats"
        
        local key="mcp_op_${op_idx}"
        MCP_STATS["${key}_min"]=$min
        MCP_STATS["${key}_max"]=$max
        MCP_STATS["${key}_mean"]=$mean
        MCP_STATS["${key}_median"]=$median
        
        echo -e "${GREEN}Operation $((op_idx + 1)) Results:${NC}"
        echo "  Min: ${min}s"
        echo "  Max: ${max}s"
        echo "  Mean: ${mean}s"
        echo "  Median: ${median}s"
    done
}

# Generate benchmark report
generate_report() {
    header "Benchmark Report"
    
    local report=""
    report+="# Ollama + n8n-MCP Performance Benchmark Report\n"
    report+="Generated: $(date)\n"
    report+="Model: $OLLAMA_MODEL\n"
    report+="Iterations: $ITERATIONS\n"
    report+="Warmup Runs: $WARMUP_RUNS\n\n"
    
    # System information
    report+="## System Information\n"
    if command_exists nvidia-smi; then
        local gpu_info=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits)
        report+="GPU: $gpu_info\n"
    fi
    report+="CPU: $(lscpu | grep 'Model name' | cut -f 2 -d ":")"
    report+="Memory: $(free -h | grep Mem | awk '{print $2}')\n\n"
    
    # Ollama results
    report+="## Ollama Performance Results\n"
    if [ -n "${RESULTS[model_loading_mean]}" ]; then
        report+="### Model Loading\n"
        report+="- Min: ${RESULTS[model_loading_min]}s\n"
        report+="- Max: ${RESULTS[model_loading_max]}s\n"
        report+="- Mean: ${RESULTS[model_loading_mean]}s\n"
        report+="- Median: ${RESULTS[model_loading_median]}s\n\n"
    fi
    
    # Inference results
    for i in {0..4}; do
        local key="inference_${i}"
        if [ -n "${RESULTS[${key}_mean]}" ]; then
            report+="### Inference Test $((i + 1))\n"
            report+="- Min: ${RESULTS[${key}_min]}s\n"
            report+="- Max: ${RESULTS[${key}_max]}s\n"
            report+="- Mean: ${RESULTS[${key}_mean]}s\n"
            report+="- Median: ${RESULTS[${key}_median]}s\n\n"
        fi
    done
    
    # GPU results
    if [ -n "${GPU_STATS[memory_mean]}" ]; then
        report+="## GPU Utilization Results\n"
        report+="### Memory Usage\n"
        report+="- Min: ${GPU_STATS[memory_min]}MB\n"
        report+="- Max: ${GPU_STATS[memory_max]}MB\n"
        report+="- Mean: ${GPU_STATS[memory_mean]}MB\n"
        report+="- Median: ${GPU_STATS[memory_median]}MB\n\n"
        
        report+="### GPU Utilization\n"
        report+="- Min: ${GPU_STATS[utilization_min]}%\n"
        report+="- Max: ${GPU_STATS[utilization_max]}%\n"
        report+="- Mean: ${GPU_STATS[utilization_mean]}%\n"
        report+="- Median: ${GPU_STATS[utilization_median]}%\n\n"
        
        report+="### Temperature\n"
        report+="- Min: ${GPU_STATS[temperature_min]}°C\n"
        report+="- Max: ${GPU_STATS[temperature_max]}°C\n"
        report+="- Mean: ${GPU_STATS[temperature_mean]}°C\n"
        report+="- Median: ${GPU_STATS[temperature_median]}°C\n\n"
    fi
    
    # MCP results
    report+="## MCP Server Performance Results\n"
    for i in {0..3}; do
        local key="mcp_op_${i}"
        if [ -n "${MCP_STATS[${key}_mean]}" ]; then
            report+="### MCP Operation $((i + 1))\n"
            report+="- Min: ${MCP_STATS[${key}_min]}s\n"
            report+="- Max: ${MCP_STATS[${key}_max]}s\n"
            report+="- Mean: ${MCP_STATS[${key}_mean]}s\n"
            report+="- Median: ${MCP_STATS[${key}_median]}s\n\n"
        fi
    done
    
    # Performance summary
    report+="## Performance Summary\n"
    report+="### Recommendations\n"
    
    # Analyze results and provide recommendations
    if [ -n "${RESULTS[inference_0_mean]}" ]; then
        local avg_inference=${RESULTS[inference_0_mean]}
        if (( $(echo "$avg_inference < 1" | bc -l) )); then
            report+="- ✅ Excellent inference performance (< 1s average)\n"
        elif (( $(echo "$avg_inference < 3" | bc -l) )); then
            report+="- ⚠️  Good inference performance (1-3s average)\n"
        else
            report+="- ❌ Slow inference performance (> 3s average)\n"
        fi
    fi
    
    if [ -n "${MCP_STATS[mcp_op_0_mean]}" ]; then
        local avg_mcp=${MCP_STATS[mcp_op_0_mean]}
        if (( $(echo "$avg_mcp < 0.1" | bc -l) )); then
            report+="- ✅ Excellent MCP response time (< 100ms average)\n"
        elif (( $(echo "$avg_mcp < 0.5" | bc -l) )); then
            report+="- ⚠️  Good MCP response time (100-500ms average)\n"
        else
            report+="- ❌ Slow MCP response time (> 500ms average)\n"
        fi
    fi
    
    if [ -n "${GPU_STATS[memory_mean]}" ]; then
        local avg_memory=${GPU_STATS[memory_mean]}
        if (( $(echo "$avg_memory < 10000" | bc -l) )); then
            report+="- ✅ Good GPU memory usage (< 10GB average)\n"
        else
            report+="- ⚠️  High GPU memory usage (> 10GB average)\n"
        fi
    fi
    
    # Output report
    if [ -n "$OUTPUT_FILE" ]; then
        echo -e "$report" > "$OUTPUT_FILE"
        log "Benchmark report saved to: $OUTPUT_FILE"
    else
        echo -e "$report"
    fi
}

# Main execution
main() {
    echo -e "${BLUE}🚀 Starting Ollama + n8n-MCP Performance Benchmark...${NC}"
    echo ""
    
    # Check prerequisites
    if ! command_exists ollama; then
        error "Ollama is not installed"
        exit 1
    fi
    
    if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        error "Ollama is not running"
        exit 1
    fi
    
    # Run tests
    test_model_loading
    test_ollama_inference
    test_gpu_utilization
    test_mcp_performance
    
    # Generate report
    generate_report
    
    echo ""
    echo -e "${GREEN}✅ Benchmark completed!${NC}"
}

# Run main function
main "$@" 