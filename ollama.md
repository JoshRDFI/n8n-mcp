# Ollama Integration Migration Plan

## Overview

This document outlines the step-by-step plan to migrate n8n-MCP from Claude Desktop integration to Ollama (local LLM) integration. The goal is to maintain all existing MCP functionality while adapting the client-side integration to work with Ollama instead of Claude.

## Current Architecture Analysis

### Current Claude Integration Points

1. **MCP Server (No Changes Needed)**
   - The MCP server itself is LLM-agnostic
   - Uses standard MCP protocol (stdio/HTTP)
   - All tools and functionality remain unchanged
   - Database and node information stays the same

2. **Client Integration Points (Need Changes)**
   - Claude Desktop configuration files
   - Documentation references to Claude
   - Setup instructions for Claude Desktop
   - Error messages mentioning Claude

3. **Transport Methods (No Changes Needed)**
   - Stdio mode: Works with any MCP client
   - HTTP mode: Works with any HTTP client
   - Both transport methods are LLM-agnostic

## Migration Strategy

### Phase 1: Client-Side Integration (Primary Focus)

#### 1.1 Ollama MCP Client Setup
**Goal**: Create Ollama-compatible MCP client configuration

**Research Findings**:
- ✅ **Ollama supports MCP servers natively**
- ✅ **Qwen3:8b model** is recommended for this integration
  - Supports both tool use and thinking
  - 40k context window (excellent for large n8n node databases)
  - Already downloaded and available on test system
  - Optimized for NVIDIA 5080 with custom PyTorch builds
- ✅ **Multiple integration methods available**

**Steps**:
1. **Startup Script Requirements**:
   - Ensure Ollama service is running
   - Load Qwen3:8b model before starting MCP server
   - Start n8n-MCP Docker container
   - Verify MCP connection

2. Create Ollama MCP client configuration:

   **For Cursor IDE Integration**:
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
           "-e", "LOG_LEVEL=error",
           "-e", "DISABLE_CONSOLE_OUTPUT=true",
           "ghcr.io/czlonkowski/n8n-mcp:latest"
         ]
       }
     }
   }
   ```

   **For Cursor with Full n8n Integration**:
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
           "-e", "LOG_LEVEL=error",
           "-e", "DISABLE_CONSOLE_OUTPUT=true",
           "-e", "N8N_API_URL=http://localhost:5678",
           "-e", "N8N_API_KEY=your-n8n-api-key-here",
           "ghcr.io/czlonkowski/n8n-mcp:latest"
         ]
       }
     }
   }
   ```

   **Configuration File**: `cursor-mcp-config-docker-full.json`

3. Document Ollama-specific setup instructions

#### 1.2 Startup Script Implementation
**Goal**: Create automated startup process for Ollama + n8n-MCP

**Startup Script Requirements** (Recommended - Host Ollama):
```bash
#!/bin/bash
# ollama-n8n-mcp-startup.sh

echo "🚀 Starting Ollama + n8n-MCP Integration..."

# 1. Ensure Ollama service is running (host installation)
echo "📦 Starting Ollama service..."
if ! systemctl is-active --quiet ollama; then
    sudo systemctl start ollama
    sleep 2
fi

# 2. Load Qwen3:8b model (if not already loaded)
echo "🤖 Loading Qwen3:8b model..."
if ! ollama list | grep -q "qwen3:8b"; then
    echo "Downloading Qwen3:8b model (this may take a while)..."
    ollama pull qwen3:8b
fi

# 3. Verify model is ready
echo "✅ Verifying model availability..."
ollama list | grep qwen3:8b

# 4. Start n8n-MCP Docker container
echo "🐳 Starting n8n-MCP Docker container..."
docker run -d \
    --name n8n-mcp \
    -p 3000:3000 \
    -e MCP_MODE=http \
    -e AUTH_TOKEN=your-secure-token \
    ghcr.io/czlonkowski/n8n-mcp:latest

# 5. Wait for MCP server to be ready
echo "⏳ Waiting for MCP server to start..."
sleep 5

# 6. Test MCP connection
echo "🔍 Testing MCP connection..."
curl -f http://localhost:3000/health || {
    echo "❌ MCP server health check failed"
    exit 1
}

echo "✅ Ollama + n8n-MCP integration ready!"
echo "🌐 MCP Server: http://localhost:3000"
echo "🤖 Ollama Model: qwen3:8b (Host Installation)"
```

**Note**: This setup uses **Host Ollama** for optimal performance, especially with NVIDIA 5080 and custom PyTorch builds.

#### 1.3 Cursor IDE Integration (Recommended)
**Goal**: Provide seamless integration with Cursor IDE for n8n workflow development

**Configuration Options**:
1. **Basic Configuration** (Documentation tools only):
   - Uses Docker to run n8n-MCP in stdio mode
   - Provides access to all n8n node documentation and validation tools
   - No n8n instance connection required
   - File: `cursor-mcp-config-docker.json`

2. **Full Configuration** (With n8n workflow management):
   - Includes n8n API credentials for workflow management
   - Can create, update, and execute workflows directly
   - Requires n8n API key configuration
   - File: `cursor-mcp-config-docker-full.json`

**Setup Instructions**:
1. Copy the appropriate configuration to Cursor's settings
2. Restart Cursor to load the MCP server
3. Test with simple queries like "Show me available n8n nodes for sending emails"
4. For full integration, configure n8n API key in the configuration

**Benefits**:
- **Native MCP Support**: Uses stdio communication as expected by Cursor
- **Docker Integration**: Leverages existing Docker setup
- **Isolated Sessions**: Each Cursor session gets a fresh MCP server instance
- **No HTTP Dependencies**: Doesn't rely on HTTP server staying running
- **Full Tool Access**: All 525+ n8n nodes and validation tools available

#### 1.4 Alternative Integration Methods
**Goal**: Provide multiple ways to integrate with Ollama

**Options**:
1. **Direct HTTP Integration**:
   - Use n8n-MCP HTTP mode
   - Create Ollama workflow that calls n8n-MCP API
   - Build custom Ollama function calling

2. **n8n Workflow Integration**:
   - Use n8n as middleware between Ollama and n8n-MCP
   - Create n8n workflow that connects Ollama to MCP tools
   - Leverage existing n8n-nodes-mcp community node

3. **Custom MCP Client**:
   - Build lightweight MCP client for Ollama
   - Use Ollama's function calling capabilities
   - Create bridge between Ollama and MCP protocol

### Phase 2: Documentation Updates

#### 2.1 Update README.md
**Changes Needed**:
- Replace Claude-specific instructions with Ollama instructions
- Update quick start guide for Ollama
- Modify configuration examples
- Update testimonials and references

**Files to Update**:
- `README.md` - Main documentation
- `docs/README_CLAUDE_SETUP.md` → `docs/README_OLLAMA_SETUP.md`
- `docs/INSTALLATION.md` - Update installation instructions
- `docs/HTTP_DEPLOYMENT.md` - Add Ollama HTTP integration

#### 2.2 Update Configuration Examples
**Current Claude Config**:
```json
{
  "mcpServers": {
    "n8n-mcp": {
      "command": "docker",
      "args": ["run", "-i", "--rm", "ghcr.io/czlonkowski/n8n-mcp:latest"]
    }
  }
}
```

**New Ollama Config Options**:
1. **HTTP Mode**:
   ```bash
   # Start n8n-MCP in HTTP mode
   docker run -d -p 3000:3000 -e MCP_MODE=http ghcr.io/czlonkowski/n8n-mcp:latest
   
   # Ollama can then make HTTP requests to http://localhost:3000/mcp
   ```

2. **n8n Integration**:
   ```json
   // n8n workflow configuration
   {
     "nodes": [
       {
         "type": "n8n-nodes-mcp.mcpClient",
         "parameters": {
           "mcpServerUrl": "http://n8n-mcp:3000/mcp",
           "tool": "list_nodes"
         }
       }
     ]
   }
   ```

### Phase 3: Code Changes

#### 3.1 Remove Claude-Specific References
**Files to Update**:
- `src/mcp/index.ts` - Remove Claude-specific error messages
- `src/mcp/server.ts` - Update logging messages
- `src/mcp/handlers-n8n-manager.ts` - Update error messages
- All documentation files

**Changes**:
```typescript
// Before
console.error('Claude Desktop configuration:');

// After  
console.error('Ollama MCP client configuration:');
```

#### 3.2 Add Ollama-Specific Features
**New Features to Consider**:
1. **Ollama Model Detection**:
   ```typescript
   // Detect if running with Ollama
   const isOllama = process.env.OLLAMA_HOST || process.env.OLLAMA_MODEL;
   ```

2. **Ollama-Optimized Responses**:
   ```typescript
   // Adjust response format for Ollama
   if (isOllama) {
     // Use more concise responses
     // Optimize for local LLM context limits
   }
   ```

3. **Ollama Function Calling**:
   ```typescript
   // Export tools in Ollama function calling format
   export function getOllamaFunctions() {
     return n8nDocumentationToolsFinal.map(tool => ({
       name: tool.name,
       description: tool.description,
       parameters: tool.inputSchema
     }));
   }
   ```

### Phase 4: Testing and Validation

#### 4.1 Test Ollama Integration
**Test Scenarios**:
1. **HTTP Mode Testing**:
   ```bash
   # Test HTTP endpoint
   curl -X POST http://localhost:3000/mcp \
     -H "Content-Type: application/json" \
     -d '{"jsonrpc": "2.0", "method": "tools/list", "id": 1}'
   ```

2. **n8n Integration Testing**:
   - Test n8n-nodes-mcp with Ollama
   - Verify workflow execution
   - Test error handling

3. **Function Calling Testing**:
   - Test Ollama function calling with MCP tools
   - Verify response formats
   - Test error scenarios

#### 4.2 Performance Testing
**Metrics to Measure**:
- Response times with Ollama
- Memory usage
- CPU utilization
- Network latency (if using HTTP)

### Phase 5: Documentation and Examples

#### 5.1 Create Ollama-Specific Examples
**Example Files to Create**:
1. `examples/ollama-http-integration.json` - HTTP mode example
2. `examples/ollama-n8n-workflow.json` - n8n integration example
3. `examples/ollama-function-calling.js` - Function calling example

#### 5.2 Update Documentation Structure
**New Documentation Files**:
- `docs/OLLAMA_SETUP.md` - Ollama setup guide
- `docs/OLLAMA_INTEGRATION.md` - Integration patterns
- `docs/OLLAMA_EXAMPLES.md` - Example workflows
- `docs/MIGRATION_GUIDE.md` - Migration from Claude

## Implementation Steps

### Step 1: Research and Planning (Week 1)
- [x] Research Ollama MCP client options ✅ **COMPLETED**: Ollama supports MCP natively
- [x] Test existing MCP clients with Ollama ✅ **COMPLETED**: Qwen3:8b model confirmed
- [ ] Determine best integration approach
- [ ] Create detailed technical specification

### Step 2: Core Integration (Week 2)
- [ ] Implement Ollama HTTP integration
- [ ] Create Ollama function calling support
- [ ] Test basic functionality
- [ ] Fix any compatibility issues

### Step 3: Documentation Updates (Week 3)
- [ ] Update README.md for Ollama
- [ ] Create Ollama setup documentation
- [ ] Update configuration examples
- [ ] Create migration guide

### Step 4: Testing and Refinement (Week 4)
- [ ] Comprehensive testing with Ollama
- [ ] Performance optimization
- [ ] Error handling improvements
- [ ] User feedback integration

### Step 5: Release and Documentation (Week 5)
- [ ] Final testing and validation
- [ ] Update version and changelog
- [ ] Create release notes
- [ ] Update all documentation

## Technical Considerations

### 1. Ollama Compatibility
**Challenges**:
- ~~Ollama may not have native MCP support~~ ✅ **RESOLVED**: Ollama supports MCP natively
- Function calling format differences
- Response format variations

**Solutions**:
- Use HTTP mode as primary integration
- Create adapter layer for function calling
- Standardize response formats
- **Qwen3:8b model** provides excellent tool use capabilities
- **Host installation** ensures optimal performance with NVIDIA 5080

### 2. Performance Optimization
**Considerations**:
- Local LLM context limits
- Response time expectations
- Memory usage patterns

**Optimizations**:
- Use `get_node_essentials` by default
- Implement response caching
- Optimize for smaller context windows

### 3. Error Handling
**New Error Scenarios**:
- Ollama connection failures
- Model loading issues
- Function calling errors

**Solutions**:
- Robust error handling
- Clear error messages
- Fallback mechanisms

## Success Criteria

### Functional Requirements
- [ ] Ollama can successfully connect to n8n-MCP
- [ ] All MCP tools work with Ollama
- [ ] HTTP mode functions correctly
- [ ] n8n integration works seamlessly

### Performance Requirements
- [ ] Response times under 5 seconds
- [ ] Memory usage under 1GB
- [ ] Stable connection handling
- [ ] Error recovery works

### Documentation Requirements
- [ ] Clear setup instructions
- [ ] Working examples
- [ ] Troubleshooting guide
- [ ] Migration path from Claude

## Risk Assessment

### High Risk
- ~~**Ollama MCP Client Availability**: If no suitable MCP client exists~~ ✅ **RESOLVED**: Ollama supports MCP natively
- **Function Calling Compatibility**: If Ollama uses different format
- ~~**Performance Issues**: If local LLM is too slow~~ ✅ **MITIGATED**: Host Ollama + NVIDIA 5080 provides excellent performance

### Medium Risk
- **Documentation Complexity**: Multiple integration methods
- **User Adoption**: Learning curve for new setup
- **Maintenance Overhead**: Supporting multiple clients

### Low Risk
- **MCP Server Changes**: Server itself doesn't need changes
- **Database Compatibility**: Node data remains the same
- **Tool Functionality**: All tools work as-is

## Integration Approaches

### Approach 1: HTTP-First Integration (Recommended)
- Use HTTP mode as primary method
- Create simple HTTP client for Ollama
- Minimal code changes required
- Works well with host Ollama installation

### Approach 2: n8n-Centric Integration
- Use n8n as the integration layer
- Leverage existing n8n-nodes-mcp
- Focus on workflow-based integration
- Good for complex automation scenarios

### Approach 3: Custom MCP Client
- Build lightweight MCP client for Ollama
- Direct stdio integration
- Maximum performance and control
- Best for direct Ollama integration

## Conclusion

The migration from Claude to Ollama is primarily a client-side integration challenge. The n8n-MCP server itself is LLM-agnostic and requires minimal changes. The main work involves:

1. **Creating Ollama-compatible client configurations**
2. **Updating documentation and examples**
3. **Testing and validating integration methods**
4. **Providing clear migration path**

The HTTP mode provides the most straightforward integration path with host Ollama, while n8n integration offers the most powerful workflow capabilities. The host Ollama setup with NVIDIA 5080 will provide excellent performance for this integration.

## Next Steps

1. **Immediate**: Create startup script for Ollama + n8n-MCP
2. **Week 1**: Test Qwen3:8b integration with n8n-MCP
3. **Week 2**: Create basic Ollama setup documentation
4. **Week 3**: Implement and test integration methods
5. **Week 4**: Complete documentation and testing
6. **Week 5**: Release and user feedback

## Updated Implementation Priority

### Immediate Actions (This Week)
1. **Create Host Ollama Startup Script**: `ollama-n8n-mcp-startup.sh`
2. **Test Qwen3:8b Integration**: Verify MCP tool calling works with NVIDIA 5080
3. **Document Setup Process**: Step-by-step Ollama integration guide
4. **Performance Testing**: Benchmark with host Ollama setup

This plan provides a structured approach to successfully migrate n8n-MCP from Claude to Ollama while maintaining all existing functionality and providing a smooth user experience. 