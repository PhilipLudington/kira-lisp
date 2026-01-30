; Test LSP diagnostics integration
; Tests that document handlers correctly work with diagnostics

(import "src/lsp/documents.lisp")
(import "src/lsp/diagnostics.lisp")
(import "src/json.lisp")

(display "=== LSP Diagnostics Test ===\n\n")

; Helper to get nth element from list
(define (list-nth lst n)
  (if (null? lst)
      #f
      (if (= n 0)
          (car lst)
          (list-nth (cdr lst) (- n 1)))))

; ============================================================================
; Test 1: compute-diagnostics with valid code - should return empty list
; ============================================================================
(display "Test 1 - compute-diagnostics with valid code:\n")

(let ((diags (compute-diagnostics "(+ 1 2)")))
  (if (null? diags)
      (display "  PASS: No diagnostics for valid code\n")
      (display "  FAIL: Should have empty diagnostics\n")))

; ============================================================================
; Test 2: compute-diagnostics with invalid code - should return diagnostics
; ============================================================================
(display "Test 2 - compute-diagnostics with syntax error:\n")

(let ((diags (compute-diagnostics "(+ 1 2")))  ; Missing closing paren
  (if (pair? diags)
      (let ((diag (car diags)))
        (let ((msg (json-get diag "message")))
          (display "  PASS: Got diagnostic with message: ")
          (display msg)
          (display "\n")))
      (display "  FAIL: Should have diagnostics for invalid code\n")))

; ============================================================================
; Test 3: publish-diagnostics-for-document creates notification
; ============================================================================
(display "Test 3 - publish-diagnostics-for-document creates notification:\n")

(let ((notification (publish-diagnostics-for-document "file:///test.lisp" "(+ 1)")))
  (let ((method (json-get notification "method"))
        (params (json-get notification "params")))
    (if (equal? method "textDocument/publishDiagnostics")
        (let ((uri (json-get params "uri")))
          (if (equal? uri "file:///test.lisp")
              (display "  PASS: Notification has correct method and uri\n")
              (display "  FAIL: Wrong uri in notification\n")))
        (display "  FAIL: Wrong method in notification\n"))))

; ============================================================================
; Test 4: Document handlers return correct format (state uri content action)
; ============================================================================
(display "Test 4 - handle-did-open returns (state uri content action):\n")

(let ((state (make-initial-state)))
  (let ((params (list (list "textDocument"
                            (list (list "uri" "file:///test.lisp")
                                  (list "text" "(+ 1 2)"))))))
    (let ((result (handle-did-open state params)))
      (let ((new-state (list-nth result 0))
            (uri (list-nth result 1))
            (content (list-nth result 2))
            (action (list-nth result 3)))
        (if (and (equal? uri "file:///test.lisp")
                 (equal? content "(+ 1 2)")
                 (equal? action 'open))
            (display "  PASS: didOpen returns correct format\n")
            (display "  FAIL: Wrong return format\n"))))))

(display "Test 5 - handle-did-close returns (state uri #f close):\n")

(let ((state (make-initial-state)))
  (let ((state-with-doc (set-document state "file:///test.lisp" "(+ 1 2)")))
    (let ((params (list (list "textDocument"
                              (list (list "uri" "file:///test.lisp"))))))
      (let ((result (handle-did-close state-with-doc params)))
        (let ((uri (list-nth result 1))
              (content (list-nth result 2))
              (action (list-nth result 3)))
          (if (and (equal? uri "file:///test.lisp")
                   (eq? content #f)
                   (equal? action 'close))
              (display "  PASS: didClose returns correct format\n")
              (display "  FAIL: Wrong return format\n")))))))

(display "\n=== All diagnostics tests completed ===\n")
