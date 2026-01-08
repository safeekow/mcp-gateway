FROM python:3.12-slim-bookworm

COPY --from=ghcr.io/astral-sh/uv:latest /uv /bin/

RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    git \
    netcat-openbsd \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g supergateway \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN uv pip install --system awslabs.aws-documentation-mcp-server

EXPOSE 8000

CMD ["supergateway", "--port", "8000", "--stdio", "awslabs.aws-documentation-mcp-server"]

