#!/usr/bin/env node

/**
 * Demo: Create a workflow in n8n via MCP
 */

// Load environment variables from .env file
const fs = require('fs');
const path = require('path');

// Simple .env loader
function loadEnv() {
  const envPath = path.join(__dirname, '.env');
  if (fs.existsSync(envPath)) {
    const envContent = fs.readFileSync(envPath, 'utf8');
    envContent.split('\n').forEach(line => {
      const [key, ...valueParts] = line.split('=');
      if (key && valueParts.length > 0) {
        process.env[key.trim()] = valueParts.join('=').trim();
      }
    });
  }
}

loadEnv();

const MCP_HOST = process.env.MCP_HOST || 'localhost';
const MCP_PORT = process.env.MCP_PORT || '3000';
const AUTH_TOKEN = process.env.AUTH_TOKEN;

const MCP_URL = `http://${MCP_HOST}:${MCP_PORT}/mcp`;

if (!AUTH_TOKEN) {
  console.error('❌ AUTH_TOKEN environment variable is required');
  process.exit(1);
}

async function makeMCPCall(method, params = {}) {
  const response = await fetch(MCP_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json,text/event-stream',
      'Authorization': `Bearer ${AUTH_TOKEN}`
    },
    body: JSON.stringify({
      jsonrpc: '2.0',
      method,
      params,
      id: Date.now()
    })
  });

  if (!response.ok) {
    throw new Error(`MCP call failed: ${response.status} ${response.statusText}`);
  }

  return response.json();
}

async function demoWorkflow() {
  console.log('🚀 n8n-MCP Workflow Demo\n');

  try {
    // Step 1: List existing workflows
    console.log('1. Checking existing workflows...');
    const listResult = await makeMCPCall('tools/call', {
      name: 'n8n_list_workflows',
      arguments: {}
    });
    
    console.log('✅ Workflows listed successfully');
    const workflows = listResult.result?.content || [];
    console.log(`   Found ${workflows.length} existing workflows\n`);

    // Step 2: Create a demo workflow
    console.log('2. Creating demo workflow...');
    
    const demoWorkflow = {
      name: "MCP Demo - Simple Webhook Workflow",
      nodes: [
        {
          parameters: {
            path: "mcp-demo",
            httpMethod: "POST",
            responseMode: "onReceived",
            responseData: "allEntries"
          },
          id: "webhook-trigger",
          name: "Webhook Trigger",
          type: "n8n-nodes-base.webhook",
          position: [240, 300],
          typeVersion: 1
        },
        {
          parameters: {
            values: {
              string: [
                {
                  name: "message",
                  value: "Hello from MCP! This workflow was created programmatically."
                },
                {
                  name: "timestamp",
                  value: "={{ new Date().toISOString() }}"
                }
              ]
            }
          },
          id: "set-data",
          name: "Set Data",
          type: "n8n-nodes-base.set",
          position: [460, 300],
          typeVersion: 3.4
        }
      ],
      connections: {
        "Webhook Trigger": {
          main: [
            [
              {
                node: "Set Data",
                type: "main",
                index: 0
              }
            ]
          ]
        }
      },
      active: false,
      settings: {
        executionOrder: "v1"
      },
      versionId: "",
      tags: []
    };

    const createResult = await makeMCPCall('tools/call', {
      name: 'n8n_create_workflow',
      arguments: demoWorkflow
    });

    if (createResult.result?.content?.id) {
      console.log('✅ Demo workflow created successfully!');
      console.log(`   Workflow ID: ${createResult.result.content.id}`);
      console.log(`   Name: ${createResult.result.content.name}`);
      console.log('\n📋 What this workflow does:');
      console.log('   - Triggers via webhook at /content-request');
      console.log('   - Fetches sample data from JSONPlaceholder API');
      console.log('   - Transforms the data into content format');
      console.log('   - Returns the processed content');
      
      console.log('\n🌐 To test the workflow:');
      console.log('   1. Go to your n8n interface');
      console.log('   2. Find the "MCP Demo - Content Creation Workflow"');
      console.log('   3. Activate it and use the webhook URL');
      console.log('   4. Send a POST request to trigger it');
      
    } else {
      console.log('❌ Failed to create workflow');
      console.log('   Error:', createResult.error || createResult.result);
    }

  } catch (error) {
    console.error('❌ Demo failed:', error.message);
  }
}

// Run the demo
demoWorkflow(); 