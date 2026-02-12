; LSP Main Loop
; Task 3.8: Server entry point
;
; Ties together all LSP components into a working server.
; Reads messages from stdin, dispatches to handlers, writes responses.
;
; NOTE: Due to interpreter bug with nested let + function calls,
; we structure code to minimize nested let blocks.

(import "src/lsp/rpc.lisp")
(import "src/lsp/protocol.lisp")
(import "src/lsp/handlers.lisp")
(import "src/lsp/documents.lisp")
(import "src/lsp/diagnostics.lisp")

(provide lsp-main lsp-loop)

; ============================================================================
; Extended Dispatchers
; ============================================================================
; Combine the base handlers with document handlers

(define (full-dispatch-notification state method params)
  ; First try document handlers
  (let ((doc-result (dispatch-document-notification state method params)))
    (if doc-result
        doc-result
        ; Then try base handlers
        (dispatch-notification state method params))))

(define (full-dispatch-request state method params id)
  ; Currently all requests go to base dispatcher
  ; (Future: add hover, definition, etc.)
  (dispatch-request state method params id))

; ============================================================================
; Message Processing
; ============================================================================
; Due to interpreter bug, we extract values first, then do side effects,
; then build the final result.

; Helper to write response and return result
; This minimizes nesting
(define (send-response-and-return response new-state)
  (write-lsp-message response)
  (list new-state #f))

; Process notification - no response to send
(define (process-notification state method params)
  (let ((new-state (full-dispatch-notification state method params)))
    (let ((_ (maybe-publish-diagnostics new-state method params)))
      (let ((should-exit (state-get new-state "exit")))
        (list new-state (eq? should-exit #t))))))

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
                      ; Workaround: use inline display instead of function call
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
