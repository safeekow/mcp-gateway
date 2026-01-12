FROM python:3.11-slim

RUN apt-get update && apt-get install -y netcat-openbsd curl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install supergateway (binary or via npm if node is installed, but for python base we can use uv/pip if available, 
# or simpler: install nodejs to get supergateway easily)
RUN apt-get update && apt-get install -y nodejs npm && npm install -g supergateway

# Install the MCP server
RUN pip install mcp-server-fetch

EXPOSE 8000

CMD ["sh", "-c", "supergateway --port 8000 --stdio 'mcp-server-fetch'"]
