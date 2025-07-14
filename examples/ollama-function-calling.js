/**
 * Ollama Function Calling with n8n-MCP Integration
 * 
 * This example demonstrates how to use Ollama's function calling capabilities
 * to interact with n8n-MCP tools for workflow automation.
 * 
 * Prerequisites:
 * - Ollama running with qwen3:8b model
 * - n8n-MCP server running on port 3000
 * - Node.js with fetch support
 */

const OLLAMA_HOST = process.env.OLLAMA_HOST || 'localhost';
const OLLAMA_PORT = process.env.OLLAMA_PORT || '11434';
const MCP_HOST = process.env.MCP_HOST || 'localhost';
const MCP_PORT = process.env.MCP_PORT || '3000';
const AUTH_TOKEN = process.env.AUTH_TOKEN || 'your-secure-token-here';

class OllamaMCPIntegration {
  constructor() {
    this.ollamaUrl = `http://${OLLAMA_HOST}:${OLLAMA_PORT}`;
    this.mcpUrl = `http://${MCP_HOST}:${MCP_PORT}`;
    this.model = 'qwen3:8b';
  }

  /**
   * Call n8n-MCP tools via HTTP
   */
  async callMCPTool(toolName, toolArguments = {}) {
    try {
      const response = await fetch(`${this.mcpUrl}/mcp`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${AUTH_TOKEN}`
        },
        body: JSON.stringify({
          jsonrpc: '2.0',
          method: 'tools/call',
          params: {
            name: toolName,
            arguments: toolArguments
          },
          id: Date.now()
        })
      });

      if (!response.ok) {
        throw new Error(`MCP request failed: ${response.status} ${response.statusText}`);
      }

      const result = await response.json();
      
      if (result.error) {
        throw new Error(`MCP error: ${result.error.message}`);
      }

      return result.result;
    } catch (error) {
      console.error(`Error calling MCP tool ${toolName}:`, error.message);
      throw error;
    }
  }

  /**
   * Get available n8n nodes
   */
  async getAvailableNodes(category = null, search = null) {
    const args = {};
    if (category) args.category = category;
    if (search) args.search = search;

    return await this.callMCPTool('list_nodes', args);
  }

  /**
   * Get detailed information about a specific node
   */
  async getNodeInfo(nodeType) {
    return await this.callMCPTool('get_node_info', { node_type: nodeType });
  }

  /**
   * Create a new n8n workflow
   */
  async createWorkflow(name, description = '', nodes = []) {
    return await this.callMCPTool('create_workflow', {
      name,
      description,
      nodes
    });
  }

  /**
   * Call Ollama with function calling
   */
  async callOllamaWithFunctions(prompt, functions = []) {
    try {
      const response = await fetch(`${this.ollamaUrl}/api/generate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          model: this.model,
          prompt,
          stream: false,
          functions: functions.length > 0 ? functions : undefined
        })
      });

      if (!response.ok) {
        throw new Error(`Ollama request failed: ${response.status} ${response.statusText}`);
      }

      const result = await response.json();
      return result;
    } catch (error) {
      console.error('Error calling Ollama:', error.message);
      throw error;
    }
  }

  /**
   * Define n8n-MCP functions for Ollama
   */
  getMCPFunctions() {
    return [
      {
        name: 'list_nodes',
        description: 'List available n8n nodes with their properties and documentation',
        parameters: {
          type: 'object',
          properties: {
            category: {
              type: 'string',
              description: 'Filter nodes by category (e.g., "AI", "HTTP", "Database")'
            },
            search: {
              type: 'string',
              description: 'Search for nodes by name or description'
            }
          }
        }
      },
      {
        name: 'get_node_info',
        description: 'Get detailed information about a specific n8n node',
        parameters: {
          type: 'object',
          properties: {
            node_type: {
              type: 'string',
              description: 'The node type to get information for (e.g., "n8n-nodes-base.httpRequest")',
              required: true
            }
          }
        }
      },
      {
        name: 'create_workflow',
        description: 'Create a new n8n workflow',
        parameters: {
          type: 'object',
          properties: {
            name: {
              type: 'string',
              description: 'Name of the workflow',
              required: true
            },
            description: {
              type: 'string',
              description: 'Description of the workflow'
            },
            nodes: {
              type: 'array',
              description: 'Array of nodes to include in the workflow'
            }
          }
        }
      }
    ];
  }

  /**
   * Interactive workflow creation with Ollama
   */
  async createWorkflowWithAI(workflowDescription) {
    const functions = this.getMCPFunctions();
    
    const prompt = `You are an AI assistant that helps create n8n workflows. 
    
    The user wants to create a workflow with the following description:
    "${workflowDescription}"
    
    Please help them by:
    1. First, listing available AI nodes to understand what's available
    2. Then, suggesting a workflow structure based on the available nodes
    3. Finally, creating the workflow using the create_workflow function
    
    Use the available functions to interact with the n8n-MCP system.`;

    console.log('🤖 Asking Ollama to help create workflow...');
    const ollamaResponse = await this.callOllamaWithFunctions(prompt, functions);
    
    console.log('📝 Ollama Response:', ollamaResponse.response);
    
    // Handle function calls if Ollama decides to use them
    if (ollamaResponse.function_call) {
      console.log('🔧 Ollama wants to call a function:', ollamaResponse.function_call.name);
      
      try {
        const result = await this.callMCPTool(
          ollamaResponse.function_call.name,
          JSON.parse(ollamaResponse.function_call.arguments)
        );
        
        console.log('✅ Function call result:', result);
        return result;
      } catch (error) {
        console.error('❌ Function call failed:', error.message);
        throw error;
      }
    }
    
    return ollamaResponse;
  }

  /**
   * Example: Get AI nodes and create a simple workflow
   */
  async exampleWorkflowCreation() {
    try {
      console.log('🚀 Starting Ollama + n8n-MCP workflow creation example...\n');

      // Step 1: Get available AI nodes
      console.log('📋 Getting available AI nodes...');
      const aiNodes = await this.getAvailableNodes('AI');
      console.log(`Found ${aiNodes.content ? aiNodes.content.length : 0} AI nodes\n`);

      // Step 2: Get info about a specific node
      console.log('🔍 Getting detailed info about HTTP Request node...');
      const httpNodeInfo = await this.getNodeInfo('n8n-nodes-base.httpRequest');
      console.log('HTTP Request node properties:', httpNodeInfo.content?.properties?.length || 0, 'properties\n');

      // Step 3: Create a workflow with AI assistance
      console.log('🤖 Creating workflow with AI assistance...');
      const workflowResult = await this.createWorkflowWithAI(
        'A workflow that fetches data from an API and processes it with AI'
      );

      console.log('✅ Example completed successfully!');
      return workflowResult;

    } catch (error) {
      console.error('❌ Example failed:', error.message);
      throw error;
    }
  }

  /**
   * Health check for both services
   */
  async healthCheck() {
    console.log('🏥 Performing health checks...\n');

    // Check Ollama
    try {
      const ollamaResponse = await fetch(`${this.ollamaUrl}/api/tags`);
      if (ollamaResponse.ok) {
        const models = await ollamaResponse.json();
        const qwenModel = models.models?.find(m => m.name.includes('qwen3:8b'));
        console.log(`✅ Ollama: Running (${qwenModel ? 'qwen3:8b loaded' : 'qwen3:8b not found'})`);
      } else {
        console.log('❌ Ollama: Not responding');
      }
    } catch (error) {
      console.log('❌ Ollama: Connection failed');
    }

    // Check MCP server
    try {
      const mcpResponse = await fetch(`${this.mcpUrl}/health`);
      if (mcpResponse.ok) {
        console.log('✅ n8n-MCP: Running');
      } else {
        console.log('❌ n8n-MCP: Health check failed');
      }
    } catch (error) {
      console.log('❌ n8n-MCP: Connection failed');
    }

    console.log('');
  }
}

// Example usage
async function main() {
  const integration = new OllamaMCPIntegration();

  // Health check
  await integration.healthCheck();

  // Run example
  try {
    await integration.exampleWorkflowCreation();
  } catch (error) {
    console.error('Example failed:', error.message);
    process.exit(1);
  }
}

// Export for use as module
if (typeof module !== 'undefined' && module.exports) {
  module.exports = OllamaMCPIntegration;
}

// Run if called directly
if (require.main === module) {
  main();
} 