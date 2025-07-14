# Ollama + n8n-MCP Examples

This document provides practical examples of how to use Ollama with n8n-MCP for various workflow automation scenarios.

## Quick Start Examples

### Example 1: List Available AI Nodes

**Goal**: Get a list of all available AI nodes in n8n

**Using HTTP Integration**:
```bash
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-secure-token" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "list_nodes",
      "arguments": {
        "category": "AI"
      }
    },
    "id": 1
  }'
```

**Using JavaScript**:
```javascript
const integration = new OllamaMCPIntegration();
const aiNodes = await integration.getAvailableNodes('AI');
console.log('Available AI nodes:', aiNodes.content);
```

**Expected Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": [
      {
        "name": "OpenAI",
        "type": "n8n-nodes-base.openAi",
        "description": "Interact with OpenAI API"
      },
      {
        "name": "Hugging Face",
        "type": "n8n-nodes-base.huggingFace",
        "description": "Use Hugging Face models"
      }
    ]
  },
  "id": 1
}
```

### Example 2: Get Node Information

**Goal**: Get detailed information about the HTTP Request node

**Using HTTP Integration**:
```bash
curl -X POST http://localhost:3000/mcp \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your-secure-token" \
  -d '{
    "jsonrpc": "2.0",
    "method": "tools/call",
    "params": {
      "name": "get_node_info",
      "arguments": {
        "node_type": "n8n-nodes-base.httpRequest"
      }
    },
    "id": 2
  }'
```

**Using JavaScript**:
```javascript
const httpNodeInfo = await integration.getNodeInfo('n8n-nodes-base.httpRequest');
console.log('HTTP Request properties:', httpNodeInfo.content.properties);
```

**Expected Response**:
```json
{
  "jsonrpc": "2.0",
  "result": {
    "content": {
      "name": "HTTP Request",
      "type": "n8n-nodes-base.httpRequest",
      "description": "Make HTTP requests",
      "properties": [
        {
          "name": "url",
          "type": "string",
          "required": true,
          "description": "The URL to make the request to"
        },
        {
          "name": "method",
          "type": "string",
          "default": "GET",
          "description": "HTTP method to use"
        }
      ]
    }
  },
  "id": 2
}
```

## Workflow Creation Examples

### Example 3: Create a Simple API Workflow

**Goal**: Create a workflow that fetches data from an API and processes it

**Using Ollama with Function Calling**:
```javascript
const workflowDescription = `
Create a workflow that:
1. Fetches user data from https://jsonplaceholder.typicode.com/users
2. Filters users by city
3. Sends filtered results to a webhook
`;

const result = await integration.createWorkflowWithAI(workflowDescription);
```

**Expected Workflow Structure**:
```json
{
  "name": "API Data Processing Workflow",
  "description": "Fetches user data, filters by city, and sends to webhook",
  "nodes": [
    {
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "url": "https://jsonplaceholder.typicode.com/users",
        "method": "GET"
      }
    },
    {
      "type": "n8n-nodes-base.filter",
      "parameters": {
        "conditions": {
          "string": [
            {
              "value1": "={{ $json.address.city }}",
              "operation": "contains",
              "value2": "London"
            }
          ]
        }
      }
    },
    {
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "httpMethod": "POST",
        "path": "filtered-users"
      }
    }
  ]
}
```

### Example 4: AI-Powered Data Processing

**Goal**: Create a workflow that uses AI to analyze and categorize data

**Using n8n Workflow Integration**:
```json
{
  "name": "AI Data Analysis Workflow",
  "description": "Uses AI to analyze and categorize incoming data",
  "nodes": [
    {
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "httpMethod": "POST",
        "path": "data-input"
      }
    },
    {
      "type": "n8n-nodes-base.openAi",
      "parameters": {
        "operation": "completion",
        "model": "gpt-3.5-turbo",
        "prompt": "Analyze and categorize this data: {{ $json.data }}"
      }
    },
    {
      "type": "n8n-nodes-base.switch",
      "parameters": {
        "rules": {
          "rules": [
            {
              "conditions": {
                "string": [
                  {
                    "value1": "={{ $json.category }}",
                    "operation": "contains",
                    "value2": "urgent"
                  }
                ]
              }
            }
          ]
        }
      }
    }
  ]
}
```

## Advanced Examples

### Example 5: Multi-Step AI Workflow

**Goal**: Create a complex workflow with multiple AI nodes and conditional logic

**Workflow Description**:
```javascript
const complexWorkflow = `
Create a workflow that:
1. Receives customer feedback via webhook
2. Uses sentiment analysis to determine if feedback is positive/negative
3. If negative, routes to customer service team
4. If positive, generates a thank you email
5. Stores all interactions in a database
6. Sends analytics report to management
`;

const result = await integration.createWorkflowWithAI(complexWorkflow);
```

**Expected Workflow**:
```json
{
  "name": "Customer Feedback Processing",
  "description": "AI-powered customer feedback analysis and response system",
  "nodes": [
    {
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "httpMethod": "POST",
        "path": "customer-feedback"
      }
    },
    {
      "type": "n8n-nodes-base.openAi",
      "parameters": {
        "operation": "completion",
        "model": "gpt-3.5-turbo",
        "prompt": "Analyze the sentiment of this customer feedback: {{ $json.feedback }}"
      }
    },
    {
      "type": "n8n-nodes-base.switch",
      "parameters": {
        "rules": {
          "rules": [
            {
              "conditions": {
                "string": [
                  {
                    "value1": "={{ $json.sentiment }}",
                    "operation": "contains",
                    "value2": "negative"
                  }
                ]
              }
            }
          ]
        }
      }
    },
    {
      "type": "n8n-nodes-base.slack",
      "parameters": {
        "operation": "postMessage",
        "channel": "customer-service",
        "text": "New negative feedback received: {{ $json.feedback }}"
      }
    },
    {
      "type": "n8n-nodes-base.openAi",
      "parameters": {
        "operation": "completion",
        "model": "gpt-3.5-turbo",
        "prompt": "Generate a thank you email for this positive feedback: {{ $json.feedback }}"
      }
    },
    {
      "type": "n8n-nodes-base.postgres",
      "parameters": {
        "operation": "insert",
        "table": "customer_interactions",
        "columns": "feedback, sentiment, response, timestamp"
      }
    }
  ]
}
```

### Example 6: Real-time Data Processing

**Goal**: Create a workflow that processes real-time data streams

**Using n8n Workflow**:
```json
{
  "name": "Real-time Data Stream Processing",
  "description": "Processes real-time data with AI analysis",
  "nodes": [
    {
      "type": "n8n-nodes-base.rabbitmq",
      "parameters": {
        "operation": "consume",
        "queue": "data-stream"
      }
    },
    {
      "type": "n8n-nodes-base.openAi",
      "parameters": {
        "operation": "completion",
        "model": "gpt-3.5-turbo",
        "prompt": "Analyze this real-time data for anomalies: {{ $json.data }}"
      }
    },
    {
      "type": "n8n-nodes-base.if",
      "parameters": {
        "conditions": {
          "string": [
            {
              "value1": "={{ $json.anomaly_detected }}",
              "operation": "equals",
              "value2": "true"
            }
          ]
        }
      }
    },
    {
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "httpMethod": "POST",
        "url": "https://alerting-service.com/alert",
        "body": "Anomaly detected in data stream"
      }
    }
  ]
}
```

## Integration Examples

### Example 7: Ollama + n8n-MCP + External API

**Goal**: Integrate Ollama with external APIs through n8n-MCP

**JavaScript Implementation**:
```javascript
class ExtendedIntegration extends OllamaMCPIntegration {
  async analyzeWithExternalAPI(data) {
    // First, get available nodes
    const nodes = await this.getAvailableNodes('HTTP');
    
    // Create workflow that uses external API
    const workflow = await this.createWorkflow('External API Analysis', '', [
      {
        type: 'n8n-nodes-base.httpRequest',
        parameters: {
          url: 'https://api.external-service.com/analyze',
          method: 'POST',
          body: JSON.stringify(data)
        }
      },
      {
        type: 'n8n-nodes-base.openAi',
        parameters: {
          operation: 'completion',
          model: 'gpt-3.5-turbo',
          prompt: 'Analyze this external API response: {{ $json.result }}'
        }
      }
    ]);
    
    return workflow;
  }
}

// Usage
const extended = new ExtendedIntegration();
const result = await extended.analyzeWithExternalAPI({
  text: "Sample data for analysis",
  language: "en"
});
```

### Example 8: Batch Processing with AI

**Goal**: Process large datasets with AI assistance

**Workflow Structure**:
```json
{
  "name": "Batch Data Processing with AI",
  "description": "Process large datasets using AI for categorization",
  "nodes": [
    {
      "type": "n8n-nodes-base.csv",
      "parameters": {
        "operation": "fromFile",
        "filePath": "/data/large-dataset.csv"
      }
    },
    {
      "type": "n8n-nodes-base.splitInBatches",
      "parameters": {
        "batchSize": 100
      }
    },
    {
      "type": "n8n-nodes-base.openAi",
      "parameters": {
        "operation": "completion",
        "model": "gpt-3.5-turbo",
        "prompt": "Categorize this batch of data: {{ $json.data }}"
      }
    },
    {
      "type": "n8n-nodes-base.postgres",
      "parameters": {
        "operation": "insert",
        "table": "processed_data",
        "columns": "original_data, category, confidence_score"
      }
    }
  ]
}
```

## Testing Examples

### Example 9: Integration Testing

**Goal**: Test the complete Ollama + n8n-MCP integration

**Test Script**:
```javascript
async function testIntegration() {
  const integration = new OllamaMCPIntegration();
  
  console.log('🧪 Testing Ollama + n8n-MCP Integration...\n');
  
  // Test 1: Health check
  console.log('1. Health Check');
  await integration.healthCheck();
  
  // Test 2: List nodes
  console.log('2. List AI Nodes');
  const aiNodes = await integration.getAvailableNodes('AI');
  console.log(`Found ${aiNodes.content?.length || 0} AI nodes\n`);
  
  // Test 3: Get node info
  console.log('3. Get Node Information');
  const nodeInfo = await integration.getNodeInfo('n8n-nodes-base.httpRequest');
  console.log(`HTTP Request node has ${nodeInfo.content?.properties?.length || 0} properties\n`);
  
  // Test 4: Create workflow
  console.log('4. Create Workflow with AI');
  const workflow = await integration.createWorkflowWithAI(
    'Simple API data fetching workflow'
  );
  console.log('Workflow created successfully\n');
  
  console.log('✅ All tests passed!');
}

testIntegration().catch(console.error);
```

### Example 10: Performance Testing

**Goal**: Benchmark the integration performance

**Benchmark Script**:
```javascript
async function benchmarkIntegration() {
  const integration = new OllamaMCPIntegration();
  
  console.log('📊 Benchmarking Ollama + n8n-MCP Performance...\n');
  
  const iterations = 10;
  const results = [];
  
  for (let i = 0; i < iterations; i++) {
    const start = Date.now();
    
    try {
      await integration.getAvailableNodes('AI');
      const duration = Date.now() - start;
      results.push(duration);
      
      console.log(`Test ${i + 1}: ${duration}ms`);
    } catch (error) {
      console.error(`Test ${i + 1} failed:`, error.message);
    }
    
    // Wait between tests
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  
  // Calculate statistics
  const avg = results.reduce((a, b) => a + b, 0) / results.length;
  const min = Math.min(...results);
  const max = Math.max(...results);
  
  console.log('\n📈 Results:');
  console.log(`Average: ${avg.toFixed(2)}ms`);
  console.log(`Min: ${min}ms`);
  console.log(`Max: ${max}ms`);
  console.log(`Total tests: ${results.length}`);
}

benchmarkIntegration().catch(console.error);
```

## Best Practices

### 1. Error Handling

**Always include error handling**:
```javascript
try {
  const result = await integration.callMCPTool('list_nodes', { category: 'AI' });
  console.log('Success:', result);
} catch (error) {
  console.error('Error:', error.message);
  // Implement fallback logic
}
```

### 2. Performance Optimization

**Use appropriate batch sizes**:
```javascript
// For large datasets, process in batches
const batchSize = 100;
for (let i = 0; i < data.length; i += batchSize) {
  const batch = data.slice(i, i + batchSize);
  await processBatch(batch);
}
```

### 3. Security

**Always use secure tokens**:
```javascript
// Use environment variables
const AUTH_TOKEN = process.env.AUTH_TOKEN;
if (!AUTH_TOKEN) {
  throw new Error('AUTH_TOKEN environment variable is required');
}
```

## Next Steps

1. **Start Simple**: Begin with basic examples and gradually increase complexity
2. **Test Thoroughly**: Use the provided test scripts to validate your setup
3. **Monitor Performance**: Use benchmark scripts to establish baselines
4. **Scale Gradually**: Start with small workflows and scale as needed

For more examples and advanced usage, refer to:
- [Integration Patterns](OLLAMA_INTEGRATION.md)
- [Setup Documentation](OLLAMA_SETUP.md)
- [Example Files](../examples/)
- [Performance Benchmarks](../scripts/benchmark-ollama-performance.sh) 