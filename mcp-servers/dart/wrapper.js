const { spawn } = require('child_process');

/**
 * Universal MCP Wrapper
 * 
 * Functions:
 * 1. Sanitizes tool names (must start with a letter for IBM ContextForge Gateway).
 * 2. Sanitizes tool descriptions (removes unsafe characters like backticks and '>').
 * 3. Fixes missing or invalid inputSchema.
 * 4. Maps tool names back for tools/call requests.
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

// Name mapping for restoration
const nameMap = new Map(); // mappedName -> originalName

const sanitizeDescription = (desc) => {
  if (!desc) return '';
  return desc
    .replace(/`/g, "'")
    .replace(/>/g, "")
    .trim();
};

const sanitizeName = (name) => {
  if (/^\d/.test(name)) {
    const newName = 'm_' + name;
    nameMap.set(newName, name);
    return newName;
  }
  return name;
};

let inputBuffer = '';
process.stdin.on('data', (data) => {
  inputBuffer += data.toString();
  const lines = inputBuffer.split('\n');
  
  if (inputBuffer.endsWith('\n')) {
    inputBuffer = '';
  } else {
    inputBuffer = lines.pop();
  }

  for (const line of lines) {
    if (line.trim() === '') continue;
    try {
      const msg = JSON.parse(line);
      
      // Intercept tools/call request to restore original name
      if (msg.method === 'tools/call' && msg.params && msg.params.name) {
        const originalName = nameMap.get(msg.params.name);
        if (originalName) {
          console.error(`[wrapper] Mapping back tool name: ${msg.params.name} -> ${originalName}`);
          msg.params.name = originalName;
        }
      }
      
      child.stdin.write(JSON.stringify(msg) + '\n');
    } catch (e) {
      child.stdin.write(line + '\n');
    }
  }
});

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
          // 1. Sanitize Name
          const originalName = tool.name;
          tool.name = sanitizeName(tool.name);
          if (originalName !== tool.name) {
            console.error(`[wrapper] Sanitized tool name: ${originalName} -> ${tool.name}`);
          }

          // 2. Sanitize Description
          tool.description = sanitizeDescription(tool.description);

          // 3. Fix inputSchema
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
