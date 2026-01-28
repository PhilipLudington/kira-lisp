; LSP Handlers
; Task 3.3: Lifecycle handlers (initialize, shutdown, exit)
;
; Handlers receive: (state, params) -> (new-state, response)
; For notifications: (state, params) -> new-state

(import "src/lsp/protocol.lisp")

(provide
  ; Lifecycle
  handle-initialize handle-initialized handle-shutdown handle-exit
  ; Dispatching
  dispatch-request dispatch-notification
  ; State management
  make-initial-state state-initialized? state-shutdown? state-get state-set)

; ============================================================================
; Helper Functions (defined first)
; ============================================================================

; Helper: assoc for alists
(define (assoc key alist)
  (if (null? alist)
      #f
      (if (equal? (car (car alist)) key)
          (car alist)
          (assoc key (cdr alist)))))

; Helper: append two lists
(define (append-lists l1 l2)
  (if (null? l1)
      l2
      (cons (car l1) (append-lists (cdr l1) l2))))

; ============================================================================
; Server State
; ============================================================================
;
; State is an alist with:
;   initialized: #t/#f - whether initialize handshake complete
;   shutdown: #t/#f - whether shutdown request received
;   documents: alist of (uri . content) - open documents

(define (make-initial-state)
  (list (list "initialized" #f)
        (list "shutdown" #f)
        (list "documents" '())))

(define (state-get state key)
  (let ((pair (assoc key state)))
    (if pair
        (car (cdr pair))
        #f)))

(define (state-set-acc state key value acc)
  (if (null? state)
      (cons (list key value) acc)
      (let ((pair (car state)))
        (if (equal? (car pair) key)
            (append-lists (cons (list key value) acc) (cdr state))
            (state-set-acc (cdr state) key value (cons pair acc))))))

(define (state-set state key value)
  (state-set-acc state key value '()))

(define (state-initialized? state)
  (eq? #t (state-get state "initialized")))

(define (state-shutdown? state)
  (eq? #t (state-get state "shutdown")))

; ============================================================================
; Initialize Handler
; ============================================================================
;
; Request: initialize
; Params: {capabilities, rootUri, ...}
; Response: {capabilities}

(define (handle-initialize state params)
  (let ((capabilities (make-server-capabilities)))
    (let ((result (make-initialize-result capabilities)))
      (let ((new-state (state-set state "initialized" #t)))
        (list new-state result)))))

; ============================================================================
; Initialized Notification
; ============================================================================
;
; Notification: initialized
; Params: {}
; No response

(define (handle-initialized state params)
  ; Client confirms it received our capabilities
  ; Nothing special to do
  state)

; ============================================================================
; Shutdown Handler
; ============================================================================
;
; Request: shutdown
; Params: null
; Response: null

(define (handle-shutdown state params)
  (let ((new-state (state-set state "shutdown" #t)))
    (list new-state 'null)))

; ============================================================================
; Exit Notification
; ============================================================================
;
; Notification: exit
; Server should exit with code 0 if shutdown was received, 1 otherwise

(define (handle-exit state params)
  ; Signal exit by returning special state
  (state-set state "exit" #t))

; ============================================================================
; Request Dispatcher
; ============================================================================
;
; dispatch-request: (state, method, params, id) -> (new-state, response)
; Returns a full JSON-RPC response object

(define (dispatch-request state method params id)
  (if (not (state-initialized? state))
      ; Before initialize, only initialize request is allowed
      (if (equal? method "initialize")
          (let ((result (handle-initialize state params)))
            (let ((new-state (car result))
                  (response-result (car (cdr result))))
              (list new-state (make-response id response-result))))
          ; Not initialized - error
          (list state (make-error id error-server-not-initialized
                                  "Server not initialized")))
      ; After initialize
      (if (equal? method "shutdown")
          (let ((result (handle-shutdown state params)))
            (let ((new-state (car result))
                  (response-result (car (cdr result))))
              (list new-state (make-response id response-result))))
          ; Unknown method
          (list state (make-error id error-method-not-found
                                  (string-append "Unknown method: " method))))))

; ============================================================================
; Notification Dispatcher
; ============================================================================
;
; dispatch-notification: (state, method, params) -> new-state

(define (dispatch-notification state method params)
  (if (equal? method "initialized")
      (handle-initialized state params)
      (if (equal? method "exit")
          (handle-exit state params)
          ; Unknown notification - ignore
          state)))
