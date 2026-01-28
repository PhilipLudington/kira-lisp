; LSP Document Sync
; Task 3.4: Track open documents
;
; Handles:
;   textDocument/didOpen   - Store document content
;   textDocument/didChange - Update content (full sync mode)
;   textDocument/didClose  - Remove from tracking
;
; Documents are stored in state as: ("documents" . ((uri . content) ...))

(import "src/lsp/protocol.lisp")
(import "src/lsp/handlers.lisp")

(provide
  handle-did-open handle-did-change handle-did-close
  get-document set-document remove-document document-exists?
  add-document-handlers dispatch-document-notification)

; ============================================================================
; Helper Functions (defined first for proper ordering)
; ============================================================================

(define (get-document-from-list docs uri)
  (if (null? docs)
      #f
      (let ((pair (car docs)))
        (if (equal? (car pair) uri)
            (car (cdr pair))
            (get-document-from-list (cdr docs) uri)))))

(define (set-doc-in-list docs uri content)
  (if (null? docs)
      (list (list uri content))
      (let ((pair (car docs)))
        (if (equal? (car pair) uri)
            (cons (list uri content) (cdr docs))
            (cons pair (set-doc-in-list (cdr docs) uri content))))))

(define (remove-doc-from-list docs uri)
  (if (null? docs)
      '()
      (let ((pair (car docs)))
        (if (equal? (car pair) uri)
            (cdr docs)
            (cons pair (remove-doc-from-list (cdr docs) uri))))))

; ============================================================================
; Document Storage
; ============================================================================

; Get document content by URI, or #f if not found
(define (get-document state uri)
  (let ((docs (state-get state "documents")))
    (if (not docs)
        #f
        (get-document-from-list docs uri))))

; Check if document is open
(define (document-exists? state uri)
  (not (eq? #f (get-document state uri))))

; Set document content
(define (set-document state uri content)
  (let ((docs (state-get state "documents")))
    (let ((new-docs (set-doc-in-list (if docs docs '()) uri content)))
      (state-set state "documents" new-docs))))

; Remove document
(define (remove-document state uri)
  (let ((docs (state-get state "documents")))
    (if (not docs)
        state
        (state-set state "documents" (remove-doc-from-list docs uri)))))

; ============================================================================
; textDocument/didOpen
; ============================================================================
; Notification params: {textDocument: {uri, languageId, version, text}}

(define (handle-did-open state params)
  (let ((text-doc (json-get params "textDocument")))
    (let ((uri (json-get text-doc "uri"))
          (text (json-get text-doc "text")))
      (if (or (json-null? uri) (json-null? text))
          state  ; Invalid params, ignore
          (set-document state uri text)))))

; ============================================================================
; textDocument/didChange
; ============================================================================
; Notification params: {textDocument: {uri, version}, contentChanges: [{text}]}
; We use full sync mode, so contentChanges has single element with full text

(define (handle-did-change state params)
  (let ((text-doc (json-get params "textDocument"))
        (changes (json-get params "contentChanges")))
    (let ((uri (json-get text-doc "uri")))
      (if (json-null? uri)
          state
          ; Get new content from first change (full sync mode)
          (if (null? changes)
              state
              (let ((new-text (json-get (car changes) "text")))
                (if (json-null? new-text)
                    state
                    (set-document state uri new-text))))))))

; ============================================================================
; textDocument/didClose
; ============================================================================
; Notification params: {textDocument: {uri}}

(define (handle-did-close state params)
  (let ((text-doc (json-get params "textDocument")))
    (let ((uri (json-get text-doc "uri")))
      (if (json-null? uri)
          state
          (remove-document state uri)))))

; ============================================================================
; Integration with Dispatcher
; ============================================================================
; This function extends the notification dispatcher with document handlers

(define (dispatch-document-notification state method params)
  (if (equal? method "textDocument/didOpen")
      (handle-did-open state params)
      (if (equal? method "textDocument/didChange")
          (handle-did-change state params)
          (if (equal? method "textDocument/didClose")
              (handle-did-close state params)
              #f))))  ; Not a document notification

; Extend the dispatch-notification function with document handlers
; Returns: new-state or #f if not handled
(define (add-document-handlers original-dispatch state method params)
  (let ((doc-result (dispatch-document-notification state method params)))
    (if doc-result
        doc-result
        (original-dispatch state method params))))
