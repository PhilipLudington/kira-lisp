#!/bin/bash
# Integration test for Kira Lisp LSP server
# Tests the full lifecycle: initialize, document sync, shutdown, exit

cd /Users/mrphil/Fun/kira-lisp

echo "=== Kira Lisp LSP Server Integration Test ==="
echo ""

# Create test input with correct Content-Length values
# Note: Each JSON body must be followed by a newline for the line-based reader
cat > /tmp/lsp-test-input.txt << 'EOF'
Content-Length: 58

{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}
Content-Length: 52

{"jsonrpc":"2.0","method":"initialized","params":{}}
Content-Length: 152

{"jsonrpc":"2.0","method":"textDocument/didOpen","params":{"textDocument":{"uri":"file:///test.lisp","languageId":"lisp","version":1,"text":"(+ 1 2)"}}}
Content-Length: 44

{"jsonrpc":"2.0","id":2,"method":"shutdown"}
Content-Length: 36

{"jsonrpc":"2.0","method":"exit"}
EOF

echo "Sending messages to LSP server..."
echo ""

# Run the server and capture output
output=$(cat /tmp/lsp-test-input.txt | kira run src/main.ki run src/lsp/server.lisp 2>&1)

echo "Server output:"
echo "$output"
echo ""

# Check for expected responses
if echo "$output" | grep -q '"textDocumentSync":1'; then
    echo "✓ Initialize response received with capabilities"
else
    echo "✗ Missing initialize response"
    exit 1
fi

if echo "$output" | grep -q '"id":2.*"result":null'; then
    echo "✓ Shutdown response received"
else
    echo "✗ Missing shutdown response"
    exit 1
fi

echo ""
echo "=== All integration tests passed ==="
