#!/bin/bash
# Test LSP server diagnostics

# Start the server and send test messages
kira run src/main.ki run src/lsp/server.lisp << 'EOF'
Content-Length: 58

{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
Content-Length: 52

{"jsonrpc":"2.0","method":"initialized","params":{}}
Content-Length: 165

{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///test.lisp","languageId":"lisp","version":1,"text":"(+ 1 2)"}}}
Content-Length: 167

{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///bad.lisp","languageId":"lisp","version":1,"text":"(+ 1 2"}}}
Content-Length: 44

{"jsonrpc":"2.0","id":2,"method":"shutdown"}
Content-Length: 37

{"jsonrpc":"2.0","method":"exit"}
EOF
