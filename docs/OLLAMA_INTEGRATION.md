# Ollama Integration Patterns with n8n-MCP

This document provides comprehensive guidance on different ways to integrate Ollama with n8n-MCP for workflow automation.

## Overview

Ollama + n8n-MCP integration enables local LLMs to understand and work with n8n's 525+ workflow automation nodes. This guide covers multiple integration patterns to suit different use cases and technical requirements.

## Integration Patterns

### 1. HTTP-First Integration (Recommended)

**Best for**: Direct integration, maximum performance, simple setup

**Architecture**:
```
Ollama (qwen3:8b) ←→ n8n-MCP (HTTP) ←→ n8n Instance
```

**Setup**:
```bash
# 1. Start Ollama with qwen3:8b
ollama pull qwen3:8b
ollama serve

# 2. Start n8n-MCP in HTTP mode
docker run -d \
  -p 3000:3000 \
  -e MCP_MODE=http \
  -e AUTH_TOKEN=your-secure-token \
  ghcr.io/czlonkowski/n8n-mcp:latest

# 3. Use automated startup script
./scripts/ollama-n8n-mcp-startup.sh
```

**Configuration**:
```json
{
  "ollama": {
    "host": "localhost",
    "port": 11434,
    "model": "qwen3:8b"
  },
  "n8n-mcp": {
    "host": "localhost", 
    "port": 3000,
    "auth_token": "your-secure-token"
  }
}
```

**Example Usage**:
```javascript
// Direct HTTP calls to n8n-MCP
const response = await fetch('http://localhost:3000/mcp', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer your-token'
  },
  body: JSON.stringify({
    jsonrpc: '2.0',
    method: 'tools/call',
    params: {
      name: 'list_nodes',
      arguments: { category: 'AI' }
    },
    id: 1
  })
});
```

### 2. n8n-Centric Integration

**Best for**: Complex workflows, existing n8n users, workflow automation

**Architecture**:
```
Ollama ←→ n8n Workflow ←→ n8n-MCP ←→ n8n Instance
```

**Setup**:
```bash
# 1. Start all services
./scripts/ollama-n8n-mcp-startup.sh

# 2. Import workflow example
# Use examples/ollama-n8n-workflow.json
```

**Workflow Structure**:
1. **Webhook Trigger**: Receives requests from Ollama
2. **HTTP Request Node**: Calls n8n-MCP tools
3. **Conditional Logic**: Handles success/error cases
4. **Response Node**: Returns results to Ollama

**Benefits**:
- Leverages existing n8n workflow capabilities
- Built-in error handling and retry logic
- Visual workflow design
- Integration with other n8n nodes

### 3. Function Calling Integration

**Best for**: Advanced AI interactions, structured responses, tool usage

**Architecture**:
```
Ollama (with functions) ←→ Custom Client ←→ n8n-MCP
```

**Setup**:
```javascript
// Use examples/ollama-function-calling.js
const integration = new OllamaMCPIntegration();

// Define functions for Ollama
const functions = integration.getMCPFunctions();

// Call Ollama with function definitions
const response = await integration.callOllamaWithFunctions(
  "Create a workflow for API data processing",
  functions
);
```

**Function Definitions**:
```json
[
  {
    "name": "list_nodes",
    "description": "List available n8n nodes",
    "parameters": {
      "type": "object",
      "properties": {
        "category": {
          "type": "string",
          "description": "Filter by category"
        }
      }
    }
  }
]
```

## Performance Considerations

### Host vs Docker Ollama

**Host Installation (Recommended)**:
- ✅ Better performance with NVIDIA GPUs
- ✅ Direct hardware access
- ✅ Lower latency
- ✅ More memory available

**Docker Installation**:
- ✅ Easier deployment
- ✅ Isolated environment
- ❌ Performance overhead
- ❌ Limited GPU access

### Model Selection

**Qwen3:8b (Recommended)**:
- ✅ Excellent tool use capabilities
- ✅ 40k context window
- ✅ Optimized for NVIDIA 5080
- ✅ Good balance of speed/quality

**Other Models**:
- `llama3.2:8b`: Good alternative
- `mistral:7b`: Smaller, faster
- `codellama:7b`: Code-focused

### GPU Optimization

**NVIDIA 5080 Setup**:
```bash
# Install CUDA-enabled PyTorch
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Monitor GPU usage
watch -n 1 nvidia-smi

# Expected performance:
# - Model loading: 10-30 seconds
# - First inference: 2-5 seconds
# - Subsequent: 0.5-2 seconds
# - GPU memory: 8-12GB
```

## Security Considerations

### Authentication

**MCP Server**:
```bash
# Use secure token
export AUTH_TOKEN="your-secure-random-token"

# Rotate tokens regularly
# Store tokens securely (not in code)
```

**Network Security**:
```bash
# Local network only (recommended)
# Use firewall rules
# Consider VPN for remote access
```

**Model Security**:
```bash
# Use trusted model sources
# Verify model checksums
# Monitor model activity
```

## Error Handling

### Common Issues

**Ollama Service**:
```bash
# Check if running
systemctl status ollama

# Restart if needed
sudo systemctl restart ollama

# Check logs
sudo journalctl -u ollama -f
```

**MCP Server**:
```bash
# Check container status
docker ps | grep n8n-mcp

# View logs
docker logs n8n-mcp

# Restart container
docker restart n8n-mcp
```

**Network Connectivity**:
```bash
# Test Ollama
curl http://localhost:11434/api/tags

# Test MCP server
curl http://localhost:3000/health

# Check ports
netstat -tlnp | grep -E '11434|3000'
```

### Debugging

**Enable Debug Mode**:
```bash
# Startup script debug
./scripts/ollama-n8n-mcp-startup.sh --debug

# Test script debug
./scripts/test-ollama-integration.sh --debug

# Benchmark debug
./scripts/benchmark-ollama-performance.sh --debug
```

**Log Analysis**:
```bash
# Monitor real-time logs
docker logs -f n8n-mcp

# Check system resources
htop
iotop
nvidia-smi
```

## Monitoring and Maintenance

### Health Checks

**Automated Monitoring**:
```bash
# Create health check script
cat > /usr/local/bin/ollama-mcp-health.sh << 'EOF'
#!/bin/bash
# Check Ollama
curl -f http://localhost:11434/api/tags > /dev/null 2>&1 || echo "Ollama down"
# Check MCP
curl -f http://localhost:3000/health > /dev/null 2>&1 || echo "MCP down"
EOF

chmod +x /usr/local/bin/ollama-mcp-health.sh

# Add to crontab
echo "*/5 * * * * /usr/local/bin/ollama-mcp-health.sh" | crontab -
```

**Performance Monitoring**:
```bash
# GPU monitoring
watch -n 1 nvidia-smi

# System monitoring
htop
iotop

# Network monitoring
iftop
```

### Backup and Recovery

**Model Backup**:
```bash
# Backup Ollama models
sudo cp -r /root/.ollama /backup/ollama-$(date +%Y%m%d)

# Backup MCP data
docker cp n8n-mcp:/app/data /backup/mcp-$(date +%Y%m%d)
```

**Recovery**:
```bash
# Restore models
sudo cp -r /backup/ollama-20240101 /root/.ollama

# Restore MCP data
docker cp /backup/mcp-20240101 n8n-mcp:/app/data
```

## Best Practices

### 1. Environment Setup

**Use Environment Variables**:
```bash
export OLLAMA_HOST="localhost"
export OLLAMA_PORT="11434"
export MCP_HOST="localhost"
export MCP_PORT="3000"
export AUTH_TOKEN="your-secure-token"
```

**Consistent Configuration**:
```bash
# Use startup script for consistency
./scripts/ollama-n8n-mcp-startup.sh

# Test integration regularly
./scripts/test-ollama-integration.sh
```

### 2. Performance Optimization

**Model Management**:
```bash
# Keep only needed models
ollama list
ollama rm unused-model

# Use model aliases
ollama cp qwen3:8b n8n-ai
```

**Resource Management**:
```bash
# Monitor memory usage
free -h
nvidia-smi

# Optimize for your hardware
# Adjust batch sizes and context lengths
```

### 3. Security

**Token Management**:
```bash
# Generate secure tokens
openssl rand -hex 32

# Use environment variables
# Never commit tokens to version control
```

**Network Security**:
```bash
# Use local network
# Implement firewall rules
# Consider VPN for remote access
```

## Troubleshooting

### Performance Issues

**Slow Response Times**:
1. Check GPU utilization
2. Verify model is loaded
3. Monitor system resources
4. Check network latency

**Memory Issues**:
1. Monitor GPU memory usage
2. Check system memory
3. Consider smaller models
4. Restart services if needed

### Integration Issues

**Connection Problems**:
1. Verify services are running
2. Check port availability
3. Test network connectivity
4. Review firewall settings

**Authentication Errors**:
1. Verify AUTH_TOKEN is set
2. Check token format
3. Ensure token is valid
4. Review authorization headers

## Next Steps

1. **Choose Integration Pattern**: Select the approach that best fits your needs
2. **Set Up Environment**: Use the provided scripts and documentation
3. **Test Integration**: Run comprehensive tests
4. **Monitor Performance**: Establish baselines and monitor
5. **Scale as Needed**: Optimize for your specific use case

For additional help, refer to:
- [Ollama Setup Documentation](OLLAMA_SETUP.md)
- [Main README](../README.md)
- [Integration Examples](../examples/)
- [Performance Benchmarks](../scripts/benchmark-ollama-performance.sh) 