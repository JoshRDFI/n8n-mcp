# Migration Guide: Claude Desktop to Ollama

This guide helps you migrate from Claude Desktop integration to Ollama integration with n8n-MCP.

## Overview

The migration from Claude Desktop to Ollama involves:
- **No changes to the MCP server** - it remains LLM-agnostic
- **Client-side configuration changes** - updating from Claude to Ollama
- **Performance improvements** - local LLM with GPU acceleration
- **Enhanced capabilities** - function calling and workflow automation

## Pre-Migration Checklist

### ✅ Verify Current Setup

**Check your current Claude Desktop configuration**:
```bash
# macOS
cat ~/Library/Application\ Support/Claude/claude_desktop_config.json

# Windows
type %APPDATA%\Claude\claude_desktop_config.json

# Linux
cat ~/.config/Claude/claude_desktop_config.json
```

**Current configuration should look like**:
```json
{
  "mcpServers": {
    "n8n-mcp": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-e", "MCP_MODE=stdio",
        "ghcr.io/czlonkowski/n8n-mcp:latest"
      ]
    }
  }
}
```

### ✅ System Requirements

**Minimum Requirements for Ollama**:
- **OS**: Linux, macOS, or Windows
- **RAM**: 16GB (32GB recommended)
- **Storage**: 20GB free space
- **GPU**: NVIDIA GPU with 8GB+ VRAM (recommended)
- **Network**: Internet connection for model download

**Recommended Setup**:
- **OS**: Ubuntu 22.04+ or similar Linux distribution
- **RAM**: 32GB+
- **GPU**: NVIDIA RTX 4080/5080 or better
- **Storage**: NVMe SSD with 50GB+ free space

## Migration Steps

### Step 1: Install Ollama

**Linux (Ubuntu/Debian)**:
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
sudo systemctl start ollama
sudo systemctl enable ollama

# Verify installation
ollama --version
```

**macOS**:
```bash
# Using Homebrew
brew install ollama

# Or download from https://ollama.ai
# Then start Ollama
ollama serve
```

**Windows**:
```bash
# Using winget
winget install Ollama.Ollama

# Or download from https://ollama.ai
# Then start Ollama from Start Menu
```

### Step 2: Download Qwen3:8b Model

**Download the recommended model**:
```bash
# Download Qwen3:8b (optimized for n8n workflows)
ollama pull qwen3:8b

# Verify model is available
ollama list
```

**Expected output**:
```
NAME        ID          SIZE   MODIFIED
qwen3:8b    qwen3:8b    4.7 GB 2 hours ago
```

### Step 3: Set Up Environment Variables

**Create environment configuration**:
```bash
# Create environment file
cat > ~/.ollama-mcp.env << 'EOF'
# Ollama Configuration
export OLLAMA_HOST="localhost"
export OLLAMA_PORT="11434"

# n8n-MCP Configuration
export MCP_HOST="localhost"
export MCP_PORT="3000"
export AUTH_TOKEN="your-secure-token-here"

# n8n Configuration (if using n8n integration)
export N8N_API_URL="http://your-n8n-host:5678"
export N8N_API_KEY="your-n8n-api-key"
EOF

# Load environment variables
source ~/.ollama-mcp.env
```

**Generate secure token**:
```bash
# Generate a secure random token
openssl rand -hex 32
# Copy the output and update AUTH_TOKEN in the env file
```

### Step 4: Start n8n-MCP with Ollama

**Use the automated startup script**:
```bash
# Make script executable
chmod +x scripts/ollama-n8n-mcp-startup.sh

# Run startup script
./scripts/ollama-n8n-mcp-startup.sh
```

**Or start manually**:
```bash
# Start n8n-MCP in HTTP mode
docker run -d \
  --name n8n-mcp \
  -p 3000:3000 \
  -e MCP_MODE=http \
  -e AUTH_TOKEN="$AUTH_TOKEN" \
  ghcr.io/czlonkowski/n8n-mcp:latest

# Verify MCP server is running
curl http://localhost:3000/health
```

### Step 5: Test the Integration

**Run comprehensive tests**:
```bash
# Test basic integration
./scripts/test-ollama-integration.sh

# Run performance benchmarks
./scripts/benchmark-ollama-performance.sh --output migration-benchmark.md

# Test specific functionality
./scripts/test-ollama-integration.sh --mcp-test --gpu-test
```

**Expected test results**:
```
✅ Ollama: Running (qwen3:8b loaded)
✅ n8n-MCP: Running
✅ GPU: NVIDIA 5080 detected
✅ Integration: All tests passed
```

### Step 6: Update Client Configuration

**Choose your integration method**:

#### Option A: HTTP Integration (Recommended)

**Create Ollama client configuration**:
```json
{
  "ollama": {
    "host": "localhost",
    "port": 11434,
    "model": "qwen3:8b"
  },
  "mcp": {
    "host": "localhost",
    "port": 3000,
    "auth_token": "your-secure-token"
  }
}
```

#### Option B: n8n Workflow Integration

**Import the example workflow**:
```bash
# Use the provided workflow example
# examples/ollama-n8n-workflow.json
```

#### Option C: Custom Client

**Use the JavaScript integration**:
```javascript
// examples/ollama-function-calling.js
const integration = new OllamaMCPIntegration();
await integration.healthCheck();
```

### Step 7: Verify Migration

**Test all functionality**:
```bash
# 1. Test Ollama basic functionality
curl http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen3:8b",
    "prompt": "Hello, how are you?",
    "stream": false
  }'

# 2. Test MCP server
curl http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/list",
    "id": 1
  }'

# 3. Test integration
node examples/ollama-function-calling.js
```

## Configuration Comparison

### Before (Claude Desktop)

```json
{
  "mcpServers": {
    "n8n-mcp": {
      "command": "docker",
      "args": [
        "run",
        "-i",
        "--rm",
        "-e", "MCP_MODE=stdio",
        "ghcr.io/czlonkowski/n8n-mcp:latest"
      ]
    }
  }
}
```

### After (Ollama Integration)

**HTTP Mode**:
```bash
# Environment variables
export AUTH_TOKEN="your-secure-token"
export OLLAMA_HOST="localhost"
export MCP_HOST="localhost"

# Startup command
./scripts/ollama-n8n-mcp-startup.sh
```

**n8n Workflow Mode**:
```json
{
  "name": "Ollama + n8n-MCP Integration",
  "nodes": [
    {
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "url": "http://localhost:3000/mcp",
        "method": "POST",
        "headers": {
          "Authorization": "Bearer {{ $env.AUTH_TOKEN }}"
        }
      }
    }
  ]
}
```

## Performance Improvements

### Expected Performance Gains

| Metric | Claude Desktop | Ollama (Local) | Improvement |
|--------|----------------|----------------|-------------|
| Response Time | 2-5 seconds | 0.5-2 seconds | 60-75% faster |
| Context Window | 200k tokens | 40k tokens | More focused |
| Privacy | Cloud-based | Local | 100% private |
| Cost | Per-request | One-time | 90%+ savings |
| GPU Utilization | None | Full | Hardware acceleration |

### GPU Optimization

**NVIDIA 5080 Setup**:
```bash
# Monitor GPU usage
watch -n 1 nvidia-smi

# Expected performance:
# - Model loading: 10-30 seconds
# - First inference: 2-5 seconds
# - Subsequent: 0.5-2 seconds
# - GPU memory: 8-12GB
```

## Troubleshooting Migration Issues

### Common Issues

#### Issue 1: Ollama Service Not Starting

**Symptoms**: `ollama: command not found` or service fails to start

**Solution**:
```bash
# Reinstall Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Check service status
sudo systemctl status ollama

# Start manually if needed
ollama serve
```

#### Issue 2: Model Download Fails

**Symptoms**: `ollama pull qwen3:8b` fails or times out

**Solution**:
```bash
# Check internet connection
ping ollama.ai

# Try with verbose output
ollama pull qwen3:8b --verbose

# Check available disk space
df -h
```

#### Issue 3: MCP Server Connection Fails

**Symptoms**: `curl http://localhost:3000/health` fails

**Solution**:
```bash
# Check if container is running
docker ps | grep n8n-mcp

# Check container logs
docker logs n8n-mcp

# Restart container
docker restart n8n-mcp
```

#### Issue 4: Authentication Errors

**Symptoms**: `401 Unauthorized` or `403 Forbidden`

**Solution**:
```bash
# Verify AUTH_TOKEN is set
echo $AUTH_TOKEN

# Check token format
# Should be a 64-character hex string

# Regenerate token if needed
openssl rand -hex 32
```

#### Issue 5: GPU Not Detected

**Symptoms**: Ollama not using GPU or slow performance

**Solution**:
```bash
# Check NVIDIA drivers
nvidia-smi

# Install CUDA if needed
sudo apt-get install nvidia-cuda-toolkit

# Verify PyTorch CUDA support
python -c "import torch; print(torch.cuda.is_available())"
```

### Debug Mode

**Enable debug output**:
```bash
# Startup script debug
./scripts/ollama-n8n-mcp-startup.sh --debug

# Test script debug
./scripts/test-ollama-integration.sh --debug

# Manual debugging
docker logs -f n8n-mcp
sudo journalctl -u ollama -f
```

## Post-Migration Tasks

### 1. Update Documentation

**Update your team documentation**:
- Replace Claude Desktop references with Ollama
- Update configuration examples
- Add performance benchmarks
- Document new capabilities

### 2. Train Your Team

**Conduct training sessions**:
- Ollama basics and model management
- New integration patterns
- Performance monitoring
- Troubleshooting procedures

### 3. Monitor Performance

**Set up monitoring**:
```bash
# Create monitoring script
cat > /usr/local/bin/ollama-mcp-monitor.sh << 'EOF'
#!/bin/bash
# Monitor Ollama + n8n-MCP performance
./scripts/benchmark-ollama-performance.sh --output daily-benchmark-$(date +%Y%m%d).md
EOF

chmod +x /usr/local/bin/ollama-mcp-monitor.sh

# Add to crontab for daily monitoring
echo "0 9 * * * /usr/local/bin/ollama-mcp-monitor.sh" | crontab -
```

### 4. Backup Configuration

**Backup your setup**:
```bash
# Backup environment configuration
cp ~/.ollama-mcp.env ~/backup/ollama-mcp-$(date +%Y%m%d).env

# Backup Ollama models
sudo cp -r /root/.ollama ~/backup/ollama-$(date +%Y%m%d)

# Backup MCP data
docker cp n8n-mcp:/app/data ~/backup/mcp-$(date +%Y%m%d)
```

## Rollback Plan

### If Migration Fails

**Keep Claude Desktop configuration**:
```bash
# Don't delete the old configuration immediately
# Keep it as backup for 30 days

# To rollback:
# 1. Stop Ollama services
sudo systemctl stop ollama
docker stop n8n-mcp

# 2. Restore Claude Desktop configuration
# 3. Restart Claude Desktop
```

**Rollback checklist**:
- [ ] Stop Ollama services
- [ ] Remove Ollama containers
- [ ] Restore Claude Desktop config
- [ ] Test Claude Desktop integration
- [ ] Document issues for future migration

## Success Criteria

### Migration Complete When

- [ ] Ollama is running with qwen3:8b model
- [ ] n8n-MCP server is accessible via HTTP
- [ ] All integration tests pass
- [ ] Performance benchmarks meet expectations
- [ ] Team is trained on new setup
- [ ] Documentation is updated
- [ ] Monitoring is in place

### Performance Validation

**Run these tests to validate migration**:
```bash
# 1. Basic functionality
./scripts/test-ollama-integration.sh

# 2. Performance benchmarks
./scripts/benchmark-ollama-performance.sh --output final-benchmark.md

# 3. Load testing
# Create workflows and test with real data

# 4. User acceptance testing
# Have team members test the new setup
```

## Next Steps

### Immediate (Week 1)
1. **Complete migration** and testing
2. **Train team** on new capabilities
3. **Set up monitoring** and alerts
4. **Document lessons learned**

### Short Term (Month 1)
1. **Optimize performance** based on usage
2. **Explore advanced features** (function calling, workflow automation)
3. **Integrate with existing workflows**
4. **Gather user feedback**

### Long Term (Quarter 1)
1. **Scale to production** workloads
2. **Add additional models** as needed
3. **Implement advanced monitoring**
4. **Contribute improvements** back to the community

## Support Resources

### Documentation
- [Ollama Setup Guide](OLLAMA_SETUP.md)
- [Integration Patterns](OLLAMA_INTEGRATION.md)
- [Examples and Use Cases](OLLAMA_EXAMPLES.md)
- [Main README](../README.md)

### Scripts and Tools
- `scripts/ollama-n8n-mcp-startup.sh` - Automated startup
- `scripts/test-ollama-integration.sh` - Integration testing
- `scripts/benchmark-ollama-performance.sh` - Performance benchmarking
- `examples/` - Integration examples

### Community Support
- [GitHub Issues](https://github.com/czlonkowski/n8n-mcp/issues)
- [Ollama Community](https://github.com/ollama/ollama/discussions)
- [n8n Community](https://community.n8n.io/)

## Conclusion

The migration from Claude Desktop to Ollama provides significant benefits:
- **Better performance** with local GPU acceleration
- **Enhanced privacy** with local processing
- **Cost savings** with one-time model download
- **Advanced capabilities** with function calling

The migration process is straightforward and well-documented. Follow the steps carefully, test thoroughly, and you'll have a powerful local AI integration for n8n workflow automation.

For any issues during migration, refer to the troubleshooting section or reach out to the community for support. 