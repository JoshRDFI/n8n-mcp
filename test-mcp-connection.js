#!/usr/bin/env node

/**
 * Simple MCP Connection Test
 * Tests the n8n-MCP server connection and initialization
 */

const MCP_HOST = process.env.MCP_HOST || 'localhost';
const MCP_PORT = process.env.MCP_PORT || '3000';
const AUTH_TOKEN = process.env.AUTH_TOKEN;

const MCP_URL = `http://${MCP_HOST}:${MCP_PORT}/mcp`;

// Check if AUTH_TOKEN is provided
if (!AUTH_TOKEN) {
  console.error('❌ AUTH_TOKEN environment variable is required');
  console.log('💡 Set AUTH_TOKEN in your .env file or export it:');
  console.log('   export AUTH_TOKEN=your-token-here');
  process.exit(1);
}

async function testMCPConnection() {
  console.log('🔍 Testing MCP Server Connection...\n');

  try {
    // Step 1: Initialize the MCP server
    console.log('1. Initializing MCP server...');
    const initResponse = await fetch(MCP_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json,text/event-stream',
        'Authorization': `Bearer ${AUTH_TOKEN}`
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'initialize',
        params: {
          protocolVersion: '2024-11-05',
          capabilities: {
            tools: {}
          }
        },
        id: 1
      })
    });

    if (!initResponse.ok) {
      throw new Error(`Initialization failed: ${initResponse.status} ${initResponse.statusText}`);
    }

    const initResult = await initResponse.json();
    console.log('✅ MCP server initialized successfully');
    console.log('   Server info:', initResult.result?.serverInfo || 'No server info');

    // Step 2: List available tools
    console.log('\n2. Listing available tools...');
    const toolsResponse = await fetch(MCP_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json,text/event-stream',
        'Authorization': `Bearer ${AUTH_TOKEN}`
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'tools/list',
        id: 2
      })
    });

    if (!toolsResponse.ok) {
      throw new Error(`Tools list failed: ${toolsResponse.status} ${toolsResponse.statusText}`);
    }

    const toolsResult = await toolsResponse.json();
    console.log('✅ Tools listed successfully');
    console.log(`   Found ${toolsResult.result?.tools?.length || 0} tools`);

    // Step 3: Test a specific tool
    console.log('\n3. Testing list_nodes tool...');
    const testResponse = await fetch(MCP_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json,text/event-stream',
        'Authorization': `Bearer ${AUTH_TOKEN}`
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        method: 'tools/call',
        params: {
          name: 'list_nodes',
          arguments: {
            category: 'AI'
          }
        },
        id: 3
      })
    });

    if (!testResponse.ok) {
      throw new Error(`Tool call failed: ${testResponse.status} ${testResponse.statusText}`);
    }

    const testResult = await testResponse.json();
    console.log('✅ Tool call successful');
    console.log(`   Found ${testResult.result?.content?.length || 0} AI nodes`);

    console.log('\n🎉 MCP server is working correctly!');
    console.log('\n📋 Next Steps:');
    console.log('1. Use the JavaScript integration: node examples/ollama-function-calling.js');
    console.log('2. Or create your own client using the patterns shown above');
    console.log('3. The MCP server is ready for Ollama integration');

  } catch (error) {
    console.error('❌ MCP connection test failed:', error.message);
    console.log('\n🔧 Troubleshooting:');
    console.log('1. Check if MCP server is running: docker ps | grep n8n-mcp');
    console.log('2. Check MCP server logs: docker logs n8n-mcp');
    console.log('3. Verify AUTH_TOKEN is correct');
  }
}

// Run the test
testMCPConnection(); 