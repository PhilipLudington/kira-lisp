; Test JSON-RPC message framing
(import "src/lsp/rpc.lisp")

; Test parse-content-length
(display "Testing parse-content-length:\n")

(let ((result (parse-content-length "Content-Length: 42")))
  (display "  'Content-Length: 42' => ")
  (display result)
  (newline))

(let ((result (parse-content-length "Content-Length: 123\r")))
  (display "  'Content-Length: 123\\r' => ")
  (display result)
  (newline))

(let ((result (parse-content-length "Other-Header: value")))
  (display "  'Other-Header: value' => ")
  (display result)
  (newline))

(let ((result (parse-content-length "")))
  (display "  '' => ")
  (display result)
  (newline))

; Test write-lsp-message
(display "\nTesting write-lsp-message:\n")
(display "Output: ")
(write-lsp-message (list (list "jsonrpc" "2.0")
                         (list "id" 1)
                         (list "result" "test")))
(newline)

(display "\nAll tests complete!\n")
