const { spawn } = require('child_process');

// 引数から実行するコマンドと引数を取得
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

process.stdin.pipe(child.stdin);

let buffer = '';

child.stdout.on('data', (data) => {
  buffer += data.toString();
  
  // 改行で分割
  const lines = buffer.split('\n');
  
  // 最後の要素は不完全な行かもしれないのでバッファに戻す
  // ただし、最後の要素が空文字の場合は完全に分割できている
  if (buffer.endsWith('\n')) {
      buffer = '';
  } else {
      buffer = lines.pop();
  }

  for (const line of lines) {
    if (line.trim() === '') continue;
    
    try {
      const msg = JSON.parse(line);
      
      // tools/list のレスポンスを検出して修正
      if (msg.result && Array.isArray(msg.result.tools)) {
        msg.result.tools.forEach(tool => {
          if (tool.inputSchema) {
            // typeプロパティがない、あるいは不正な場合は 'object' に強制
            if (!tool.inputSchema.type || tool.inputSchema.type !== 'object') {
                // エラーログを出しておくとデバッグに役立つかも
                // console.error(`[wrapper] Fixing schema for tool: ${tool.name}`);
                tool.inputSchema.type = 'object';
            }
          }
        });
      }
      
      process.stdout.write(JSON.stringify(msg) + '\n');
    } catch (e) {
      // JSONパースできない行はそのまま出力
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
