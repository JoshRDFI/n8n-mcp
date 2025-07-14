# Ollama + n8n-MCP Setup Guide

This guide provides step-by-step instructions for setting up Ollama with n8n-MCP integration, optimized for NVIDIA 5080 GPUs.

## Prerequisites

- **NVIDIA GPU**: NVIDIA 5080 or compatible GPU
- **Docker**: Installed and running
- **Ollama**: Host installation (not Docker)
- **n8n**: Existing n8n Docker container running
- **Linux**: Ubuntu/Debian recommended

## Quick Start

### 1. Install Ollama (Host Installation)

```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
sudo systemctl start ollama
sudo systemctl enable ollama

# Verify installation
ollama --version
```

### 2. Download Qwen3:8b Model

```bash
# Download the model (this may take a while)
ollama pull qwen3:8b

# Verify model is available
ollama list
```

### 3. Set Environment Variables

```bash
# Set a secure auth token for MCP server
export AUTH_TOKEN="your-secure-token-here"

# Optional: Add to your shell profile
echo 'export AUTH_TOKEN="your-secure-token-here"' >> ~/.bashrc
```

### 4. Run the Startup Script

```bash
# Make script executable (if not already)
chmod +x scripts/ollama-n8n-mcp-startup.sh

# Run the startup script
./scripts/ollama-n8n-mcp-startup.sh
```

## Detailed Setup

### Step 1: Ollama Installation

#### Ubuntu/Debian
```bash
# Install dependencies
sudo apt update
sudo apt install -y curl

# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Start and enable service
sudo systemctl start ollama
sudo systemctl enable ollama
```

#### Manual Installation (Alternative)
```bash
# Download binary
wget https://github.com/ollama/ollama/releases/latest/download/ollama-linux-amd64

# Install
sudo mv ollama-linux-amd64 /usr/local/bin/ollama
sudo chmod +x /usr/local/bin/ollama

# Create systemd service
sudo tee /etc/systemd/system/ollama.service > /dev/null <<EOF
[Unit]
Description=Ollama Service
After=network.target

[Service]
Type=simple
User=ollama
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Create user and start service
sudo useradd -r -s /bin/false ollama
sudo systemctl daemon-reload
sudo systemctl start ollama
sudo systemctl enable ollama
```

### Step 2: Model Setup

#### Download Qwen3:8b
```bash
# Download model
ollama pull qwen3:8b

# Verify download
ollama list | grep qwen3:8b
```

#### Test Model
```bash
# Simple test
ollama run qwen3:8b "Hello, can you help me with n8n workflows?"

# Test with GPU
nvidia-smi  # Check GPU utilization during inference
```

### Step 3: n8n-MCP Setup

#### Using the Startup Script
```bash
# Basic startup
./scripts/ollama-n8n-mcp-startup.sh

# Skip Ollama startup (if already running)
./scripts/ollama-n8n-mcp-startup.sh --skip-ollama

# Skip model loading (if already loaded)
./scripts/ollama-n8n-mcp-startup.sh --skip-model

# Debug mode
./scripts/ollama-n8n-mcp-startup.sh --debug
```

#### Manual Setup
```bash
# Pull n8n-MCP image
docker pull ghcr.io/czlonkowski/n8n-mcp:latest

# Start n8n-MCP container
docker run -d \
  --name n8n-mcp \
  -p 3000:3000 \
  -e MCP_MODE=http \
  -e AUTH_TOKEN="$AUTH_TOKEN" \
  -e LOG_LEVEL=info \
  ghcr.io/czlonkowski/n8n-mcp:latest

# Verify container is running
docker ps | grep n8n-mcp

# Check logs
docker logs n8n-mcp
```

### Step 4: Integration Testing

#### Run Integration Tests
```bash
# Basic tests
./scripts/test-ollama-integration.sh

# Full benchmark tests
./scripts/test-ollama-integration.sh --benchmark --gpu-test --mcp-test

# Debug mode
./scripts/test-ollama-integration.sh --debug
```

#### Manual Testing
```bash
# Test Ollama API
curl http://localhost:11434/api/tags

# Test MCP health
curl http://localhost:3000/health

# Test MCP tools
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d '{"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}}'
```

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `AUTH_TOKEN` | MCP server authentication token | `your-secure-token-here` | Yes |
| `OLLAMA_HOST` | Ollama server host | `localhost` | No |
| `OLLAMA_PORT` | Ollama server port | `11434` | No |
| `MCP_PORT` | MCP server port | `3000` | No |

### Ollama Configuration

#### GPU Configuration
```bash
# Check GPU availability
nvidia-smi

# Verify CUDA support
ollama run qwen3:8b "Test GPU acceleration"

# Monitor GPU usage
watch -n 1 nvidia-smi
```

#### Model Configuration
```bash
# List available models
ollama list

# Remove unused models
ollama rm model-name

# Show model info
ollama show qwen3:8b
```

### n8n Integration

#### Connect to Existing n8n Instance
```bash
# If your n8n is running on a different host/port
export N8N_API_URL="http://your-n8n-host:5678"
export N8N_API_KEY="your-n8n-api-key"

# Restart n8n-MCP with n8n credentials
docker stop n8n-mcp
docker rm n8n-mcp

docker run -d \
  --name n8n-mcp \
  -p 3000:3000 \
  -e MCP_MODE=http \
  -e AUTH_TOKEN="$AUTH_TOKEN" \
  -e N8N_API_URL="$N8N_API_URL" \
  -e N8N_API_KEY="$N8N_API_KEY" \
  -e LOG_LEVEL=info \
  ghcr.io/czlonkowski/n8n-mcp:latest
```

## Troubleshooting

### Common Issues

#### Ollama Not Starting
```bash
# Check service status
sudo systemctl status ollama

# Check logs
sudo journalctl -u ollama -f

# Manual start
ollama serve
```

#### Model Not Loading
```bash
# Check available models
ollama list

# Re-download model
ollama rm qwen3:8b
ollama pull qwen3:8b

# Check disk space
df -h
```

#### MCP Server Not Responding
```bash
# Check container status
docker ps | grep n8n-mcp

# Check container logs
docker logs n8n-mcp

# Restart container
docker restart n8n-mcp

# Check port availability
netstat -tlnp | grep 3000
```

#### GPU Issues
```bash
# Check NVIDIA drivers
nvidia-smi

# Check CUDA installation
nvcc --version

# Test GPU with simple model
ollama run llama2 "Test GPU"
```

### Performance Optimization

#### GPU Memory Management
```bash
# Monitor GPU memory
watch -n 1 'nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader,nounits'

# Clear GPU memory
sudo fuser -v /dev/nvidia*
```

#### System Resources
```bash
# Monitor system resources
htop

# Check disk I/O
iotop

# Monitor network
iftop
```

## Usage Examples

### Basic Workflow Creation
```bash
# Test with Ollama
ollama run qwen3:8b "Create an n8n workflow that monitors a webhook and sends a Slack notification"

# Test with MCP tools
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "list_nodes",
      "arguments": {"package": "n8n-nodes-base", "limit": 10}
    }
  }'
```

### Advanced Integration
```bash
# Create a workflow using MCP tools
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AUTH_TOKEN" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "tools/call",
    "params": {
      "name": "get_node_for_task",
      "arguments": {"task": "receive_webhook"}
    }
  }'
```

## Monitoring and Maintenance

### Health Checks
```bash
# Create health check script
cat > /usr/local/bin/ollama-mcp-health.sh << 'EOF'
#!/bin/bash
# Check Ollama
if ! curl -s http://localhost:11434/api/tags >/dev/null; then
    echo "Ollama is down"
    exit 1
fi

# Check MCP
if ! curl -s http://localhost:3000/health >/dev/null; then
    echo "MCP is down"
    exit 1
fi

echo "All services healthy"
EOF

chmod +x /usr/local/bin/ollama-mcp-health.sh

# Add to crontab for monitoring
echo "*/5 * * * * /usr/local/bin/ollama-mcp-health.sh" | crontab -
```

### Log Management
```bash
# View Ollama logs
sudo journalctl -u ollama -f

# View MCP logs
docker logs -f n8n-mcp

# Rotate logs
sudo logrotate /etc/logrotate.d/ollama
```

### Backup and Recovery
```bash
# Backup Ollama models
sudo cp -r /root/.ollama /backup/ollama-$(date +%Y%m%d)

# Backup MCP data
docker cp n8n-mcp:/app/data /backup/mcp-$(date +%Y%m%d)

# Restore from backup
sudo cp -r /backup/ollama-20231201 /root/.ollama
```

## Security Considerations

### Authentication
- Use strong, unique AUTH_TOKEN values
- Rotate tokens regularly
- Use HTTPS in production environments

### Network Security
- Restrict access to MCP server (port 3000)
- Use firewall rules to limit connections
- Consider VPN for remote access

### Model Security
- Only download models from trusted sources
- Verify model checksums
- Monitor for suspicious activity

## Performance Benchmarks

### Expected Performance (NVIDIA 5080)

| Metric | Expected Value | Notes |
|--------|----------------|-------|
| Model Loading | 10-30 seconds | Depends on disk speed |
| First Inference | 2-5 seconds | Cold start |
| Subsequent Inference | 0.5-2 seconds | Warm cache |
| GPU Memory Usage | 8-12 GB | For qwen3:8b |
| MCP Response Time | < 100ms | Local network |

### Optimization Tips
- Use SSD storage for models
- Ensure adequate RAM (16GB+ recommended)
- Monitor GPU temperature
- Use appropriate batch sizes

## Support and Resources

### Documentation
- [Ollama Documentation](https://ollama.ai/docs)
- [n8n Documentation](https://docs.n8n.io)
- [MCP Specification](https://modelcontextprotocol.io)

### Community
- [Ollama Discord](https://discord.gg/ollama)
- [n8n Community](https://community.n8n.io)
- [GitHub Issues](https://github.com/czlonkowski/n8n-mcp/issues)

### Troubleshooting Resources
- [Ollama Troubleshooting](https://ollama.ai/docs/troubleshooting)
- [n8n Troubleshooting](https://docs.n8n.io/hosting/troubleshooting/)
- [GPU Troubleshooting](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/) 