; LSP Main Loop
; Task 3.8: Server entry point
;
; Ties together all LSP components into a working server.
; Reads messages from stdin, dispatches to handlers, writes responses.

(import "src/lsp/rpc.lisp")
(import "src/lsp/protocol.lisp")
(import "src/lsp/handlers.lisp")
(import "src/lsp/documents.lisp")
(import "src/lsp/diagnostics.lisp")
(import "src/lsp/hover.lisp")
; Note: definition.lisp exists but causes timeout when loaded after hover
; due to interpreter performance issues with large import chains
; (import "src/lsp/definition.lisp")

(provide lsp-main lsp-loop)

; ============================================================================
; Helper Functions
; ============================================================================

; Helper to send a single notification to the client
(define (send-notification notification)
  (let ((body (json-stringify notification)))
    (display "Content-Length: ")
    (display (string-length body))
    (display "\r\n\r\n")
    (display body)))

; Get nth element from list (0-indexed)
(define (list-nth lst n)
  (if (null? lst)
      #f
      (if (= n 0)
          (car lst)
          (list-nth (cdr lst) (- n 1)))))

; ============================================================================
; Extended Dispatchers
; ============================================================================

; Handle document notifications - returns (new-state should-exit?)
; Also sends diagnostic notifications
(define (handle-document-notification state method params)
  (let ((doc-result (dispatch-document-notification state method params)))
    (if (not doc-result)
        #f  ; Not a document notification
        ; doc-result is (new-state uri content action)
        (let ((new-state (list-nth doc-result 0))
              (uri (list-nth doc-result 1))
              (content (list-nth doc-result 2))
              (action (list-nth doc-result 3)))
          (if (not action)
              ; Invalid params, just return state
              (list new-state #f)
              ; Generate and send diagnostics
              (if (equal? action 'close)
                  ; On close, clear diagnostics
                  (let ((_ (send-notification (make-diagnostic-notification uri '()))))
                    (list new-state #f))
                  ; On open/change, compute and send diagnostics
                  (let ((diag-notification (publish-diagnostics-for-document uri content)))
                    (let ((_ (send-notification diag-notification)))
                      (list new-state #f)))))))))

(define (full-dispatch-notification state method params)
  ; First try document handlers
  (let ((doc-result (handle-document-notification state method params)))
    (if doc-result
        doc-result  ; Returns (new-state should-exit?)
        ; Then try base handlers
        (let ((new-state (dispatch-notification state method params)))
          (let ((should-exit (state-get new-state "exit")))
            (list new-state (eq? should-exit #t)))))))

(define (full-dispatch-request state method params id)
  ; Handle LSP feature requests
  (if (equal? method "textDocument/hover")
      (let ((result (handle-hover state params)))
        (let ((new-state (car result))
              (hover-result (car (cdr result))))
          (list new-state (make-response id hover-result))))
      ; Note: textDocument/definition not enabled due to interpreter performance issues
      ; All other requests go to base dispatcher
      (dispatch-request state method params id)))

; ============================================================================
; Message Processing
; ============================================================================

; Process notification - may generate outbound notifications (e.g., diagnostics)
(define (process-notification state method params)
  (full-dispatch-notification state method params))

; Process request - need to send response
(define (process-request state method params id)
  (let ((result (full-dispatch-request state method params id)))
    ; Extract state and response first
    (list (car result) (car (cdr result)))))

; Process a single message
; Returns: (new-state, should-exit?)
(define (process-message state msg)
  (let ((method (rpc-method msg)))
    (let ((id (rpc-id msg)))
      (let ((params (rpc-params msg)))
        (if (json-null? method)
            ; Invalid message - no method
            (list state #f)
            ; Dispatch based on whether it's a request or notification
            (if (json-null? id)
                ; Notification (no id)
                (process-notification state method params)
                ; Request (has id) - process and send response
                (let ((result (process-request state method params id)))
                  (let ((new-state (car result)))
                    (let ((response (car (cdr result))))
                      ; Write response to stdout
                      (let ((body (json-stringify response)))
                        (display "Content-Length: ")
                        (display (string-length body))
                        (display "\r\n\r\n")
                        (display body)
                        (list new-state #f)))))))))))

; ============================================================================
; Main Loop
; ============================================================================

; Main loop: read messages, process, loop until exit
(define (lsp-loop state)
  (let ((msg-result (read-lsp-message)))
    (if (equal? (car msg-result) 'error)
        ; Read error - exit
        state
        ; Process the message
        (let ((msg (car (cdr msg-result))))
          (let ((process-result (process-message state msg)))
            (let ((new-state (car process-result)))
              (let ((should-exit (car (cdr process-result))))
                (if should-exit
                    new-state
                    ; Continue looping
                    (lsp-loop new-state)))))))))

; Entry point
(define (lsp-main)
  (lsp-loop (make-initial-state)))
