# Use an official Node.js runtime as a parent image
FROM node:20

# Set the working directory in the container
WORKDIR /usr/src/app

# Clone the repository from GitHub
RUN apt-get update && apt-get install -y git curl netcat-openbsd && \
    git clone https://github.com/hustcc/mcp-mermaid.git .

# Install dependencies
RUN npm install

# Build the project
RUN npm run build

# Expose the port the app runs on
EXPOSE 3033

# Define the command to run the application
CMD ["npm", "run", "start:sse", "--", "--host", "0.0.0.0"]
