FROM node:20-slim

RUN apt-get update && apt-get install -y netcat-openbsd \
    && npm install -g supergateway \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

EXPOSE 8000

# POSTGRES_URL は docker-compose から args として渡す
CMD ["sh", "-c", "supergateway --port 8000 --stdio 'npx -y @modelcontextprotocol/server-postgres ${POSTGRES_URL}'"]
