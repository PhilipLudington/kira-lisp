; Test LSP protocol types
(import "src/lsp/protocol.lisp")

(test-reset)

(test-begin "Response constructors")
(let ((resp (make-response 1 "hello")))
  (assert-eq "2.0" (json-get resp "jsonrpc") "response has jsonrpc 2.0")
  (assert-eq 1 (json-get resp "id") "response has correct id")
  (assert-eq "hello" (json-get resp "result") "response has correct result"))

(let ((err (make-error 2 -32600 "Invalid request")))
  (assert-eq "2.0" (json-get err "jsonrpc") "error has jsonrpc 2.0")
  (assert-eq 2 (json-get err "id") "error has correct id")
  (assert-eq -32600 (json-get-in err '("error" "code")) "error has correct code")
  (assert-eq "Invalid request" (json-get-in err '("error" "message")) "error has correct message"))

(let ((notif (make-notification "textDocument/didOpen" '())))
  (assert-eq "2.0" (json-get notif "jsonrpc") "notification has jsonrpc 2.0")
  (assert-eq "textDocument/didOpen" (json-get notif "method") "notification has correct method"))
(test-end)

(test-begin "Request accessors")
(let ((req '(("jsonrpc" "2.0") ("id" 42) ("method" "initialize") ("params" (("a" 1))))))
  (assert-eq 42 (rpc-id req) "rpc-id extracts id")
  (assert-eq "initialize" (rpc-method req) "rpc-method extracts method")
  (assert-eq '(("a" 1)) (rpc-params req) "rpc-params extracts params"))
(test-end)

(test-begin "Type checks")
(let ((req '(("jsonrpc" "2.0") ("id" 1) ("method" "test"))))
  (assert-true (rpc-request? req) "request with id and method is request"))
(let ((notif '(("jsonrpc" "2.0") ("method" "test"))))
  (assert-true (rpc-notification? notif) "message with method but no id is notification"))
(test-end)

(test-begin "LSP helpers")
(let ((pos (make-position 10 5)))
  (assert-eq 10 (json-get pos "line") "position line")
  (assert-eq 5 (json-get pos "character") "position character"))

(let ((range (make-range 1 0 1 10)))
  (assert-eq 1 (json-get-in range '("start" "line")) "range start line")
  (assert-eq 10 (json-get-in range '("end" "character")) "range end character"))

(let ((diag (make-diagnostic (make-range 1 0 1 5) "Error message" diagnostic-error)))
  (assert-eq "Error message" (json-get diag "message") "diagnostic message")
  (assert-eq 1 (json-get diag "severity") "diagnostic severity"))
(test-end)

(test-summary)
