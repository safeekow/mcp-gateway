FROM python:3.11-slim

RUN apt-get update && apt-get install -y netcat-openbsd curl nodejs npm \
    && npm install -g supergateway \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip install mcp-server-sentry

EXPOSE 8000

# SENTRY_AUTH_TOKEN 等が必要
CMD ["sh", "-c", "supergateway --port 8000 --stdio 'mcp-server-sentry'"]
