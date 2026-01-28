; JSON-RPC Message Framing for LSP
; Task 3.1: Handle LSP transport protocol
;
; LSP uses JSON-RPC 2.0 over stdin/stdout with Content-Length headers:
;   Content-Length: <length>\r\n
;   \r\n
;   <JSON body>\n   (note: requires trailing newline for line-based reading)
;
; LIMITATION: Due to using read-line (not read-bytes), this implementation
; requires each JSON body to be on its own line (followed by newline).
; Most LSP clients and test fixtures work this way.

; Import JSON library - path is relative to project root
(import "src/json.lisp")

(provide read-lsp-message write-lsp-message
         parse-content-length strip-cr)

; ============================================================================
; Helper Functions (defined first)
; ============================================================================

; Strip trailing \r from a string (for CRLF line endings)
(define (strip-cr s)
  (let ((len (string-length s)))
    (if (= len 0)
        s
        (let ((last-char (string-ref s (- len 1))))
          (if (equal? last-char "\r")
              (substring s 0 (- len 1))
              s)))))

; ============================================================================
; Reading Messages
; ============================================================================

; Parse "Content-Length: N" header, returning N as integer or #f on error
(define (parse-content-length line)
  (let ((prefix "Content-Length: "))
    (let ((prefix-len (string-length prefix)))
      (if (< (string-length line) prefix-len)
          #f
          (if (equal? (substring line 0 prefix-len) prefix)
              ; Extract the number part (strip \r if present)
              (let ((rest (substring line prefix-len (string-length line))))
                (let ((cleaned (strip-cr rest)))
                  (string->number cleaned)))
              #f)))))

; Read body - expects JSON on a single line
; Since read-line consumes newlines, we can only read line-by-line.
; For multi-line JSON, we'd need read-bytes (not available).
(define (read-body content-length)
  (let ((line (read-line)))
    (if (not line)
        #f  ; EOF
        ; Strip \r if present, then verify length
        (let ((stripped (strip-cr line)))
          (if (< (string-length stripped) content-length)
              ; Line too short - return what we got (may be error)
              stripped
              ; Take exactly content-length chars
              (substring stripped 0 content-length))))))

; Read headers and return Content-Length value
; Reads lines until empty line (end of headers)
(define (read-headers-acc content-length)
  (let ((line (read-line)))
    (if (not line)
        #f  ; EOF
        (let ((stripped (strip-cr line)))
          (if (equal? stripped "")
              ; Empty line = end of headers
              content-length
              ; Parse this header
              (let ((maybe-length (parse-content-length stripped)))
                (if maybe-length
                    (read-headers-acc maybe-length)
                    ; Unknown header, continue
                    (read-headers-acc content-length))))))))

(define (read-headers)
  (read-headers-acc #f))

; Read an LSP message from stdin
; Returns: (ok <json-value>) on success
;          (error <message>) on error
(define (read-lsp-message)
  ; Read headers until empty line
  (let ((content-length (read-headers)))
    (if (not content-length)
        (list 'error "Failed to read Content-Length header")
        (if (< content-length 0)
            (list 'error "Invalid Content-Length")
            ; Read the JSON body
            (let ((body (read-body content-length)))
              (if (not body)
                  (list 'error "Failed to read message body")
                  ; Parse JSON
                  (let ((result (json-parse body)))
                    (if (car result)
                        (list 'ok (car (cdr result)))
                        (list 'error (car (cdr result)))))))))))

; ============================================================================
; Writing Messages
; ============================================================================

; Write an LSP message to stdout
; Takes a JSON value (alist for object) and writes with proper headers
(define (write-lsp-message msg)
  (let ((body (json-stringify msg)))
    (let ((len (string-length body)))
      ; Write header
      (display "Content-Length: ")
      (display len)
      (display "\r\n\r\n")
      ; Write body
      (display body))))

; ============================================================================
; Helper: Error response constructor
; ============================================================================

(define (make-parse-error id message)
  (list (list "jsonrpc" "2.0")
        (list "id" id)
        (list "error" (list (list "code" -32700)
                           (list "message" message)))))

(define (make-invalid-request id message)
  (list (list "jsonrpc" "2.0")
        (list "id" id)
        (list "error" (list (list "code" -32600)
                           (list "message" message)))))
