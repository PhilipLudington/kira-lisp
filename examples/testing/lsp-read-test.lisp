; Test reading an LSP message
(import "src/lsp/rpc.lisp")

(display "Reading LSP message from stdin...\n")
(let ((result (read-lsp-message)))
  (display "Result: ")
  (display result)
  (newline))
