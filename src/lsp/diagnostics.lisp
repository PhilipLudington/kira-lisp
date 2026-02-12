; LSP Diagnostics
; Task 3.5: Parse-like diagnostics for open documents
;
; Publishes textDocument/publishDiagnostics notifications on:
; - textDocument/didOpen
; - textDocument/didChange
; - textDocument/didClose (clears diagnostics)

(import "src/lsp/protocol.lisp")
(import "src/lsp/rpc.lisp")
(import "src/lsp/documents.lisp")
(import "src/json.lisp")

(provide
  analyze-document
  make-simple-diagnostic
  maybe-publish-diagnostics
  publish-diagnostics-for-uri)

; ============================================================================
; Diagnostic Construction
; ============================================================================

(define (make-simple-diagnostic line col message)
  (make-diagnostic
    (make-range line col line (+ col 1))
    message
    diagnostic-error))

; ============================================================================
; Lightweight Syntax Analysis
; ============================================================================
; We do lightweight structural checks:
; - unmatched closing parenthesis
; - unclosed opening parenthesis
; - unterminated string literal

(define (advance-line line col c)
  (if (equal? c "\n")
      (list (+ line 1) 0)
      (list line (+ col 1))))

(define (skip-line-comment s idx len line col)
  (if (>= idx len)
      (list idx line col)
      (let ((c (string-ref s idx)))
        (let ((next-pos (advance-line line col c)))
          (if (equal? c "\n")
              (list (+ idx 1) (car next-pos) (car (cdr next-pos)))
              (skip-line-comment s (+ idx 1) len
                                 (car next-pos) (car (cdr next-pos))))))))

(define (scan-syntax s idx len line col depth open-line open-col in-string escaped)
  (if (>= idx len)
      (if in-string
          (list (make-simple-diagnostic line col "Unterminated string literal"))
          (if (> depth 0)
              (list (make-simple-diagnostic open-line open-col "Unclosed '('"))
              '()))
      (let ((c (string-ref s idx)))
        (if in-string
            (if escaped
                (let ((next-pos (advance-line line col c)))
                  (scan-syntax s (+ idx 1) len
                               (car next-pos) (car (cdr next-pos))
                               depth open-line open-col #t #f))
                (if (equal? c "\\")
                    (let ((next-pos (advance-line line col c)))
                      (scan-syntax s (+ idx 1) len
                                   (car next-pos) (car (cdr next-pos))
                                   depth open-line open-col #t #t))
                    (if (equal? c "\"")
                        (let ((next-pos (advance-line line col c)))
                          (scan-syntax s (+ idx 1) len
                                       (car next-pos) (car (cdr next-pos))
                                       depth open-line open-col #f #f))
                        (let ((next-pos (advance-line line col c)))
                          (scan-syntax s (+ idx 1) len
                                       (car next-pos) (car (cdr next-pos))
                                       depth open-line open-col #t #f)))))
            ; Not in string
            (if (equal? c "\"")
                (let ((next-pos (advance-line line col c)))
                  (scan-syntax s (+ idx 1) len
                               (car next-pos) (car (cdr next-pos))
                               depth open-line open-col #t #f))
                (if (equal? c ";")
                    (let ((after-comment (skip-line-comment s idx len line col)))
                      (scan-syntax s
                                   (car after-comment)
                                   len
                                   (car (cdr after-comment))
                                   (car (cdr (cdr after-comment)))
                                   depth open-line open-col #f #f))
                (if (equal? c "(")
                    (let ((next-pos (advance-line line col c)))
                      (if (= depth 0)
                          (scan-syntax s (+ idx 1) len
                                       (car next-pos) (car (cdr next-pos))
                                       (+ depth 1) line col #f #f)
                          (scan-syntax s (+ idx 1) len
                                       (car next-pos) (car (cdr next-pos))
                                       (+ depth 1) open-line open-col #f #f)))
                    (if (equal? c ")")
                        (if (= depth 0)
                            (list (make-simple-diagnostic line col "Unmatched ')'"))
                            (let ((next-pos (advance-line line col c)))
                              (if (= depth 1)
                                  (scan-syntax s (+ idx 1) len
                                               (car next-pos) (car (cdr next-pos))
                                               0 -1 -1 #f #f)
                                  (scan-syntax s (+ idx 1) len
                                               (car next-pos) (car (cdr next-pos))
                                               (- depth 1) open-line open-col #f #f))))
                        (let ((next-pos (advance-line line col c)))
                          (scan-syntax s (+ idx 1) len
                                       (car next-pos) (car (cdr next-pos))
                                       depth open-line open-col #f #f))))))))))

(define (analyze-document text)
  (scan-syntax text 0 (string-length text) 0 0 0 -1 -1 #f #f))

; ============================================================================
; Publish Helpers
; ============================================================================

(define (publish-diagnostics-for-uri uri diagnostics)
  (let ((params (make-publish-diagnostics uri diagnostics)))
    (write-lsp-message (make-notification "textDocument/publishDiagnostics" params))))

(define (publish-for-open-document state uri)
  (let ((text (get-document state uri)))
    (if (or (not text) (json-null? text))
        'ok
        (publish-diagnostics-for-uri uri (analyze-document text)))))

(define (maybe-publish-diagnostics state method params)
  (if (equal? method "textDocument/didOpen")
      (let ((uri (text-document-uri params)))
        (if (json-null? uri)
            'ok
            (publish-for-open-document state uri)))
      (if (equal? method "textDocument/didChange")
          (let ((uri (text-document-uri params)))
            (if (json-null? uri)
                'ok
                (publish-for-open-document state uri)))
          (if (equal? method "textDocument/didClose")
              (let ((uri (text-document-uri params)))
                (if (json-null? uri)
                    'ok
                    (publish-diagnostics-for-uri uri '())))
              'ok))))
