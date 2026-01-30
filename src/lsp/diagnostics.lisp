; LSP Diagnostics
; Task 3.5: Report parse/eval errors
;
; When a document changes:
;   1. Parse the document content
;   2. Collect any syntax errors with location
;   3. Publish diagnostics via textDocument/publishDiagnostics notification
;
; Uses the check-syntax builtin which returns:
;   - () if valid
;   - ((line col message) ...) if errors

(import "src/lsp/protocol.lisp")
(import "src/lsp/handlers.lisp")

(provide
  check-document compute-diagnostics
  make-diagnostic-notification publish-diagnostics-for-document)

; ============================================================================
; Syntax Checking
; ============================================================================

; Check a document for syntax errors
; Returns: () if valid, or list of ((line col message) ...)
(define (check-document content)
  (check-syntax content))

; ============================================================================
; Diagnostic Building
; ============================================================================

; Convert a single error tuple (line col message) to LSP diagnostic
; LSP uses 0-based line/column, Kira uses 1-based
(define (error-to-diagnostic err)
  (let ((line (- (car err) 1))                     ; Convert to 0-based
        (col (- (car (cdr err)) 1))                ; Convert to 0-based
        (message (car (cdr (cdr err)))))
    ; Create range: from error position to end of line
    ; (We don't know the actual error span, so highlight to column + 10)
    (make-diagnostic
      (make-range line col line (+ col 10))
      message
      diagnostic-error)))

; Convert errors list to diagnostics list
(define (errors-to-diagnostics-acc errors acc)
  (if (null? errors)
      acc
      (errors-to-diagnostics-acc
        (cdr errors)
        (cons (error-to-diagnostic (car errors)) acc))))

(define (errors-to-diagnostics errors)
  (errors-to-diagnostics-acc errors '()))

; Compute diagnostics for document content
; Returns: list of LSP diagnostic objects
(define (compute-diagnostics content)
  (let ((errors (check-document content)))
    (if (null? errors)
        '()  ; No errors
        (errors-to-diagnostics errors))))

; ============================================================================
; Publishing Diagnostics
; ============================================================================

; Create a publishDiagnostics notification message
(define (make-diagnostic-notification uri diagnostics)
  (make-notification
    "textDocument/publishDiagnostics"
    (make-publish-diagnostics uri diagnostics)))

; Check document and create notification (returns #f if no publishing needed)
; This always publishes - even empty diagnostics to clear previous errors
(define (publish-diagnostics-for-document uri content)
  (let ((diagnostics (compute-diagnostics content)))
    (make-diagnostic-notification uri diagnostics)))
