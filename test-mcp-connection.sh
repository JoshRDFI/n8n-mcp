#!/bin/bash

# Load environment variables from .env file
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

# Check if AUTH_TOKEN is set
if [ -z "$AUTH_TOKEN" ]; then
    echo "❌ AUTH_TOKEN environment variable is required"
    echo "💡 Set AUTH_TOKEN in your .env file or export it:"
    echo "   export AUTH_TOKEN=your-token-here"
    exit 1
fi

# Run the test script
echo "Running MCP connection test with AUTH_TOKEN from .env file..."
node test-mcp-connection.js 