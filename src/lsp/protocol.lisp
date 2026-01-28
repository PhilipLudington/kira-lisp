; LSP Protocol Types
; Task 3.2: Message constructors and accessors for JSON-RPC 2.0 / LSP
;
; JSON-RPC 2.0 Message Format:
;   Request:  {"jsonrpc": "2.0", "id": <id>, "method": <method>, "params": <params>}
;   Response: {"jsonrpc": "2.0", "id": <id>, "result": <result>}
;   Error:    {"jsonrpc": "2.0", "id": <id>, "error": {"code": <code>, "message": <msg>}}
;   Notify:   {"jsonrpc": "2.0", "method": <method>, "params": <params>}

(import "src/json.lisp")

(provide
  ; Response constructors
  make-response make-error make-notification
  ; Request accessors
  rpc-id rpc-method rpc-params
  ; Error codes
  error-parse error-invalid-request error-method-not-found
  error-invalid-params error-internal
  ; LSP-specific error codes
  error-server-not-initialized error-request-cancelled
  ; Type checks
  rpc-request? rpc-notification?)

; ============================================================================
; Standard JSON-RPC 2.0 Error Codes
; ============================================================================

(define error-parse -32700)              ; Invalid JSON
(define error-invalid-request -32600)    ; Not a valid Request object
(define error-method-not-found -32601)   ; Method doesn't exist
(define error-invalid-params -32602)     ; Invalid method parameters
(define error-internal -32603)           ; Internal JSON-RPC error

; LSP-specific error codes (defined by LSP spec)
(define error-server-not-initialized -32002)
(define error-request-cancelled -32800)

; ============================================================================
; Response Constructors
; ============================================================================

; Create a successful response
; (make-response id result) => {"jsonrpc":"2.0","id":id,"result":result}
(define (make-response id result)
  (list (list "jsonrpc" "2.0")
        (list "id" id)
        (list "result" result)))

; Create an error response
; (make-error id code message) => {"jsonrpc":"2.0","id":id,"error":{"code":code,"message":message}}
(define (make-error id code message)
  (list (list "jsonrpc" "2.0")
        (list "id" id)
        (list "error" (list (list "code" code)
                           (list "message" message)))))

; Create a notification (no id, server->client)
; (make-notification method params) => {"jsonrpc":"2.0","method":method,"params":params}
(define (make-notification method params)
  (list (list "jsonrpc" "2.0")
        (list "method" method)
        (list "params" params)))

; ============================================================================
; Request Accessors
; ============================================================================

; Get the id from a request (or #f if notification)
(define (rpc-id msg)
  (json-get msg "id"))

; Get the method from a request/notification
(define (rpc-method msg)
  (json-get msg "method"))

; Get the params from a request/notification
(define (rpc-params msg)
  (let ((p (json-get msg "params")))
    (if (json-null? p)
        '()  ; Return empty list if params is null/missing
        p)))

; ============================================================================
; Type Checks
; ============================================================================

; Check if message is a request (has id and method)
(define (rpc-request? msg)
  (and (not (json-null? (json-get msg "id")))
       (not (json-null? (json-get msg "method")))))

; Check if message is a notification (has method but no id)
(define (rpc-notification? msg)
  (and (json-null? (json-get msg "id"))
       (not (json-null? (json-get msg "method")))))

; ============================================================================
; LSP-Specific Message Constructors
; ============================================================================

; Initialize result - returned for initialize request
(define (make-initialize-result capabilities)
  (list (list "capabilities" capabilities)))

; Server capabilities - declares what the server supports
(define (make-server-capabilities)
  (list
    ; Text document sync - full sync mode
    (list "textDocumentSync" 1)
    ; Hover support
    (list "hoverProvider" #t)
    ; Go to definition
    (list "definitionProvider" #t)))

; Position: {"line": n, "character": c}
(define (make-position line character)
  (list (list "line" line)
        (list "character" character)))

; Range: {"start": pos, "end": pos}
(define (make-range start-line start-char end-line end-char)
  (list (list "start" (make-position start-line start-char))
        (list "end" (make-position end-line end-char))))

; Location: {"uri": uri, "range": range}
(define (make-location uri range)
  (list (list "uri" uri)
        (list "range" range)))

; Diagnostic severity constants
(define diagnostic-error 1)
(define diagnostic-warning 2)
(define diagnostic-information 3)
(define diagnostic-hint 4)

; Diagnostic: {"range": range, "message": msg, "severity": sev}
(define (make-diagnostic range message severity)
  (list (list "range" range)
        (list "message" message)
        (list "severity" severity)))

; PublishDiagnostics params
(define (make-publish-diagnostics uri diagnostics)
  (list (list "uri" uri)
        (list "diagnostics" diagnostics)))

; Hover result: {"contents": content}
(define (make-hover contents)
  (list (list "contents" contents)))

; MarkupContent for hover
(define (make-markup-content kind value)
  (list (list "kind" kind)
        (list "value" value)))

; Text document identifier
(define (text-document-uri params)
  (json-get-in params '("textDocument" "uri")))

; Position from params
(define (position-line params)
  (json-get-in params '("position" "line")))

(define (position-character params)
  (json-get-in params '("position" "character")))
