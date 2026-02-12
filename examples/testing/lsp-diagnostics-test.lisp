; Test LSP diagnostics
(import "src/lsp/diagnostics.lisp")
(import "src/json.lisp")

(test-reset)

(test-begin "analyze-document - valid input")
(let ((diags (analyze-document "(define (x) (+ 1 2))")))
  (assert-true (null? diags) "no diagnostics for balanced expression"))
(test-end)

(test-begin "analyze-document - ignores parens in line comments")
(let ((diags (analyze-document "(define x 1) ; ) unmatched only in comment\n(+ x 1)")))
  (assert-true (null? diags) "ignores closing paren in comment"))
(let ((diags2 (analyze-document "(define x 1) ; ( open only in comment\n(+ x 1)")))
  (assert-true (null? diags2) "ignores opening paren in comment"))
(test-end)

(test-begin "analyze-document - unmatched close paren")
(let ((diags (analyze-document "(+ 1 2))")))
  (assert-false (null? diags) "returns diagnostic")
  (let ((d (car diags)))
    (assert-eq "Unmatched ')'" (json-get d "message") "diagnostic message")))
(test-end)

(test-begin "analyze-document - unclosed open paren")
(let ((diags (analyze-document "(define (x) (+ 1 2)")))
  (assert-false (null? diags) "returns diagnostic")
  (let ((d (car diags)))
    (assert-eq "Unclosed '('" (json-get d "message") "diagnostic message")))
(test-end)

(test-begin "analyze-document - unterminated string")
(let ((diags (analyze-document "(display \"hello)")))
  (assert-false (null? diags) "returns diagnostic")
  (let ((d (car diags)))
    (assert-eq "Unterminated string literal" (json-get d "message") "diagnostic message")))
(test-end)

(test-summary)
