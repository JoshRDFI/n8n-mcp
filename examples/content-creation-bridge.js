#!/usr/bin/env node

/**
 * E-commerce Automation Bridge
 * 
 * Specialized Ollama-MCP integration for e-commerce automation including:
 * - Social media content creation and posting
 * - E-commerce workflow management
 * - Content scheduling and file management
 * - Integration testing
 */

const OLLAMA_HOST = process.env.OLLAMA_HOST || 'localhost';
const OLLAMA_PORT = process.env.OLLAMA_PORT || '11434';
const MCP_HOST = process.env.MCP_HOST || 'localhost';
const MCP_PORT = process.env.MCP_PORT || '3000';
const AUTH_TOKEN = process.env.AUTH_TOKEN;

// Check if AUTH_TOKEN is provided
if (!AUTH_TOKEN) {
  console.error('❌ AUTH_TOKEN environment variable is required');
  console.log('💡 Set AUTH_TOKEN in your .env file or export it:');
  console.log('   export AUTH_TOKEN=your-token-here');
  process.exit(1);
}

class ContentCreationBridge {
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
   * Content creation and ad posting functions for Ollama
   */
  getContentCreationFunctions() {
    return [
      {
        name: 'search_content_nodes',
        description: 'Find content creation and management nodes (HTTP, file operations, etc.)',
        parameters: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Search terms like "http", "file", "content", "blog", "post"'
            },
            limit: {
              type: 'number',
              description: 'Maximum number of results',
              default: 20
            }
          }
        }
      },
      {
        name: 'search_blog_nodes',
        description: 'Find blog and long-form content creation nodes',
        parameters: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Search terms like "blog", "wordpress", "content", "article", "markdown"'
            },
            limit: {
              type: 'number',
              description: 'Maximum number of results',
              default: 20
            }
          }
        }
      },
      {
        name: 'search_ad_posting_nodes',
        description: 'Find advertising and ad posting nodes',
        parameters: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Search terms like "facebook", "google", "ads", "advertising", "campaign"'
            },
            limit: {
              type: 'number',
              description: 'Maximum number of results',
              default: 20
            }
          }
        }
      },
      {
        name: 'get_node_info',
        description: 'Get detailed information about a specific node for configuration',
        parameters: {
          type: 'object',
          properties: {
            node_type: {
              type: 'string',
              description: 'The node type to get information for (e.g., "nodes-base.httpRequest")',
              required: true
            }
          }
        }
      },
      {
        name: 'validate_workflow',
        description: 'Validate a content creation workflow before deployment',
        parameters: {
          type: 'object',
          properties: {
            workflow: {
              type: 'object',
              description: 'The complete workflow JSON to validate',
              required: true
            },
            options: {
              type: 'object',
              properties: {
                validateNodes: {
                  type: 'boolean',
                  description: 'Validate individual node configurations',
                  default: true
                },
                validateConnections: {
                  type: 'boolean',
                  description: 'Validate node connections and flow',
                  default: true
                }
              }
            }
          }
        }
      },
      {
        name: 'get_templates_for_task',
        description: 'Get pre-built templates for content creation tasks',
        parameters: {
          type: 'object',
          properties: {
            task: {
              type: 'string',
              enum: ['ai_automation', 'data_sync', 'webhook_processing', 'email_automation', 'slack_integration', 'data_transformation', 'file_processing', 'scheduling', 'api_integration', 'database_operations'],
              description: 'The type of task to get templates for'
            }
          },
          required: ['task']
        }
      },
      {
        name: 'search_templates',
        description: 'Search for content creation and blog workflow templates',
        parameters: {
          type: 'object',
          properties: {
            query: {
              type: 'string',
              description: 'Search query for templates (e.g., "blog", "content", "marketing", "ads")'
            },
            limit: {
              type: 'number',
              description: 'Maximum number of results',
              default: 20
            }
          },
          required: ['query']
        }
      }
    ];
  }

  /**
   * Call Ollama with e-commerce specialized functions
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
   * Content creation and ad posting workflow with AI
   */
  async createContentWorkflow(description) {
    const functions = this.getContentCreationFunctions();
    
    const prompt = `You are an AI assistant specialized in content creation, blog writing, and ad posting automation.

    The user wants to create a content creation workflow with the following description:
    "${description}"

    Please help them by:
    1. First, search for content creation nodes (HTTP, file operations, etc.)
    2. Then, search for blog and long-form content nodes
    3. Find advertising and ad posting nodes
    4. Find scheduling nodes for automation
    5. Suggest a workflow structure based on the available nodes
    6. Validate the workflow before finalizing

    Focus on:
    - Content creation (blog posts, articles, product descriptions)
    - Ad posting (Facebook Ads, Google Ads, etc.)
    - File management for content storage
    - Scheduling and automation
    - Integration with AliDropship/Sellvia (via HTTP APIs)
    - SEO optimization for blog content

    The user uses AliDropship/Sellvia for e-commerce, so focus on HTTP-based integrations rather than specific e-commerce platforms.

    Use the available functions to interact with the n8n-MCP system and create a comprehensive content creation and ad posting workflow.`;

    console.log('🤖 Asking Ollama to help create content workflow...');
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
   * Blog post creation workflow
   */
  async createBlogPostWorkflow(productInfo, blogPlatform, seoKeywords) {
    const functions = this.getContentCreationFunctions();
    
    const prompt = `Create a blog post creation workflow for:
    - Product Info: ${productInfo}
    - Blog Platform: ${blogPlatform}
    - SEO Keywords: ${seoKeywords}

    The workflow should:
    1. Fetch product information from AliDropship/Sellvia (via HTTP API)
    2. Generate SEO-optimized blog content using AI
    3. Create product descriptions and reviews
    4. Save content to files (markdown, HTML, etc.)
    5. Post to blog platform or save for manual posting
    6. Include meta tags and SEO optimization

    Use the available functions to find the right nodes and create this workflow.`;

    return await this.callOllamaWithFunctions(prompt, functions);
  }

  /**
   * Ad posting workflow
   */
  async createAdPostingWorkflow(adPlatform, adType, targetAudience) {
    const functions = this.getContentCreationFunctions();
    
    const prompt = `Create an ad posting workflow for:
    - Ad Platform: ${adPlatform}
    - Ad Type: ${adType}
    - Target Audience: ${targetAudience}

    The workflow should:
    1. Generate ad copy and creatives using AI
    2. Create compelling ad content based on product data
    3. Save ad content to files for review
    4. Post ads to the specified platform (via HTTP API)
    5. Track ad performance and results
    6. Schedule ad campaigns

    Use the available functions to find the right nodes and create this workflow.`;

    return await this.callOllamaWithFunctions(prompt, functions);
  }

  /**
   * Example: Complete content creation automation
   */
  async exampleContentAutomation() {
    try {
      console.log('🚀 Starting Content Creation Automation Example...\n');

      // Step 1: Find content creation nodes
      console.log('📝 Finding content creation nodes...');
      const contentNodes = await this.callMCPTool('search_nodes', {
        query: 'http file content blog article',
        limit: 10
      });
      console.log(`Found ${contentNodes.content ? JSON.parse(contentNodes.content.text).results.length : 0} content creation nodes\n`);

      // Step 2: Find blog nodes
      console.log('📖 Finding blog nodes...');
      const blogNodes = await this.callMCPTool('search_nodes', {
        query: 'blog wordpress content article markdown',
        limit: 10
      });
      console.log(`Found ${blogNodes.content ? JSON.parse(blogNodes.content.text).results.length : 0} blog nodes\n`);

      // Step 3: Find ad posting nodes
      console.log('📢 Finding ad posting nodes...');
      const adNodes = await this.callMCPTool('search_nodes', {
        query: 'facebook google ads advertising campaign',
        limit: 10
      });
      console.log(`Found ${adNodes.content ? JSON.parse(adNodes.content.text).results.length : 0} ad posting nodes\n`);

      // Step 4: Create a complete workflow with AI
      console.log('🤖 Creating complete content creation workflow...');
      const workflowResult = await this.createContentWorkflow(
        'A complete content creation automation that: 1) Fetches product data from AliDropship/Sellvia, 2) Generates SEO-optimized blog posts, 3) Creates ad copy for Facebook/Google Ads, 4) Saves content to files, 5) Schedules posts and ad campaigns'
      );

      console.log('✅ Content creation automation example completed successfully!');
      return workflowResult;

    } catch (error) {
      console.error('❌ Example failed:', error.message);
      throw error;
    }
  }

  /**
   * Interactive chat interface
   */
  async startInteractiveChat() {
    const readline = require('readline');
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    console.log('💬 Content Creation & Ad Posting Chat Interface');
    console.log('Type your requests and I\'ll help create workflows!');
    console.log('Examples:');
    console.log('- "Create a workflow to generate blog posts about my products"');
    console.log('- "Set up Facebook Ads automation for new products"');
    console.log('- "Create a content calendar workflow for my blog"');
    console.log('- "Generate ad copy for Google Ads campaigns"');
    console.log('- "exit" to quit\n');

    const askQuestion = () => {
      rl.question('🤖 You: ', async (input) => {
        if (input.toLowerCase() === 'exit') {
          console.log('👋 Goodbye!');
          rl.close();
          return;
        }

        try {
          console.log('🤖 AI: Processing your request...');
          const result = await this.createContentWorkflow(input);
          console.log('🤖 AI: Here\'s what I found/created:', result);
        } catch (error) {
          console.error('❌ Error:', error.message);
        }

        console.log('');
        askQuestion();
      });
    };

    askQuestion();
  }
}

// Example usage
async function main() {
  const bridge = new ContentCreationBridge();

  // Check command line arguments
  const args = process.argv.slice(2);
  
  if (args.includes('--interactive') || args.includes('-i')) {
    await bridge.startInteractiveChat();
  } else if (args.includes('--example') || args.includes('-e')) {
    await bridge.exampleContentAutomation();
  } else {
    console.log('Content Creation & Ad Posting Bridge');
    console.log('Usage:');
    console.log('  node ecommerce-automation-bridge.js --interactive  # Start chat interface');
    console.log('  node ecommerce-automation-bridge.js --example      # Run example workflow');
  }
}

// Export for use as module
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ContentCreationBridge;
}

// Run if called directly
if (require.main === module) {
  main().catch(console.error);
} 