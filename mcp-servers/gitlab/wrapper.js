const { spawn } = require('child_process');

/**
 * GitLab MCP Wrapper
 * 
 * Functions:
 * 1. Sanitizes tool descriptions (removes unsafe characters like backticks and '>').
 * 2. Fixes missing or invalid inputSchema.
 */

const args = process.argv.slice(2);
if (args.length === 0) {
  console.error('Usage: node wrapper.js <command> [args...]');
  process.exit(1);
}

const command = args[0];
const commandArgs = args.slice(1);

const child = spawn(command, commandArgs, {
  stdio: ['pipe', 'pipe', process.stderr]
});

const sanitizeDescription = (desc) => {
  if (!desc) return '';
  return desc
    .replace(/`/g, "'")
    .replace(/>/g, "")
    .trim();
};

process.stdin.pipe(child.stdin);

let outputBuffer = '';
child.stdout.on('data', (data) => {
  outputBuffer += data.toString();
  const lines = outputBuffer.split('\n');
  
  if (outputBuffer.endsWith('\n')) {
    outputBuffer = '';
  } else {
    outputBuffer = lines.pop();
  }

  for (const line of lines) {
    if (line.trim() === '') continue;
    try {
      const msg = JSON.parse(line);
      
      // Intercept tools/list response to sanitize
      if (msg.result && Array.isArray(msg.result.tools)) {
        msg.result.tools.forEach(tool => {
          // 1. Sanitize Description
          tool.description = sanitizeDescription(tool.description);

          // 2. Fix inputSchema
          if (!tool.inputSchema || typeof tool.inputSchema !== 'object') {
            tool.inputSchema = { type: 'object', properties: {} };
          } else if (!tool.inputSchema.type || tool.inputSchema.type !== 'object') {
            tool.inputSchema.type = 'object';
          }
        });
      }
      
      process.stdout.write(JSON.stringify(msg) + '\n');
    } catch (e) {
      process.stdout.write(line + '\n');
    }
  }
});

child.on('close', (code) => {
  process.exit(code);
});

child.on('error', (err) => {
  console.error(`Failed to start child process: ${err}`);
  process.exit(1);
});