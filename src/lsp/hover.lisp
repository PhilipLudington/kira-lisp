; LSP Hover Support
; Task 3.6: textDocument/hover
;
; Resolves symbol under cursor and returns lightweight docs for:
; - known builtins
; - symbols defined in the current document

(import "src/lsp/protocol.lisp")
(import "src/lsp/handlers.lisp")
(import "src/lsp/documents.lisp")
(import "src/json.lisp")

(provide
  handle-hover-request
  symbol-at-position
  lookup-symbol-doc)

; ============================================================================
; Helpers
; ============================================================================

(define (nth n lst)
  (if (null? lst)
      #f
      (if (= n 0)
          (car lst)
          (nth (- n 1) (cdr lst)))))

(define (safe-json-get obj key)
  (if (json-object? obj)
      (json-get obj key)
      'null))

(define extra-symbol-chars
  (list "+" "-" "*" "/" "<" ">" "=" "!" "?" "_" "." ":" "%" "&" "^" "~" "@" "$"))

(define (contains-char? c chars)
  (if (null? chars)
      #f
      (if (equal? c (car chars))
          #t
          (contains-char? c (cdr chars)))))

(define (symbol-char? c)
  (or (and (>= (char->integer c) 48) (<= (char->integer c) 57))
      (or (and (>= (char->integer c) 65) (<= (char->integer c) 90))
          (or (and (>= (char->integer c) 97) (<= (char->integer c) 122))
              (contains-char? c extra-symbol-chars)))))

(define (symbol-start-index line idx)
  (if (<= idx 0)
      0
      (if (symbol-char? (string-ref line (- idx 1)))
          (symbol-start-index line (- idx 1))
          idx)))

(define (symbol-end-index line idx len)
  (if (>= idx len)
      len
      (if (symbol-char? (string-ref line idx))
          (symbol-end-index line (+ idx 1) len)
          idx)))

(define (symbol-at-position text line-num char-num)
  (let ((lines (string-split text "\n")))
    (let ((line (nth line-num lines)))
      (if (not line)
          #f
          (let ((len (string-length line)))
            (if (= len 0)
                #f
                (let ((idx (if (>= char-num len) (- len 1) char-num)))
                  (if (< idx 0)
                      #f
                      (let ((probe
                              (if (symbol-char? (string-ref line idx))
                                  idx
                                  (if (and (> idx 0) (symbol-char? (string-ref line (- idx 1))))
                                      (- idx 1)
                                      -1))))
                        (if (< probe 0)
                            #f
                            (let ((start (symbol-start-index line probe)))
                              (let ((end (symbol-end-index line probe len)))
                                (substring line start end)))))))))))))

; ============================================================================
; Symbol Documentation
; ============================================================================

(define builtin-docs
  (list
    (list "define" "define: Bind a name to a value or function.")
    (list "lambda" "lambda: Create an anonymous function.")
    (list "if" "if: Conditional expression.")
    (list "let" "let: Local bindings.")
    (list "car" "car: Return first element of a list.")
    (list "cdr" "cdr: Return list tail.")
    (list "cons" "cons: Construct a pair/list.")
    (list "list" "list: Construct a list from arguments.")
    (list "null?" "null?: Check whether value is empty list.")
    (list "pair?" "pair?: Check whether value is a pair/list.")
    (list "length" "length: Return list length.")
    (list "display" "display: Print a value.")
    (list "newline" "newline: Print a line break.")
    (list "+" "+: Numeric addition.")
    (list "-" "-: Numeric subtraction.")
    (list "*" "*: Numeric multiplication.")
    (list "/" "/: Numeric division.")))

(define (lookup-in-docs symbol docs)
  (if (null? docs)
      #f
      (if (equal? symbol (car (car docs)))
          (car (cdr (car docs)))
          (lookup-in-docs symbol (cdr docs)))))

(define (starts-with? s prefix)
  (let ((plen (string-length prefix)))
    (if (< (string-length s) plen)
        #f
        (equal? (substring s 0 plen) prefix))))

(define (trim-left s)
  (if (equal? s "")
      s
      (let ((c (string-ref s 0)))
        (if (or (equal? c " ") (equal? c "\t"))
            (trim-left (substring s 1 (string-length s)))
            s))))

(define (extract-define-symbol line)
  (let ((trimmed (trim-left line)))
    (if (starts-with? trimmed "(define ")
        (let ((tail (substring trimmed 8 (string-length trimmed))))
        (if (or (equal? tail "") (equal? tail " "))
            #f
            (if (equal? (string-ref tail 0) "(")
                ; Function definition: (define (name args...) ...)
                (let ((after-paren (substring tail 1 (string-length tail))))
                  (let ((parts (string-split after-paren " ")))
                    (let ((name (car parts)))
                      (if name
                          (if (and (> (string-length name) 0)
                                   (equal? (string-ref name (- (string-length name) 1)) ")"))
                              (substring name 0 (- (string-length name) 1))
                              name)
                          #f))))
                ; Variable definition: (define name value)
                (let ((parts (string-split tail " ")))
                  (car parts)))))
        #f)))

(define (find-symbol-definition-line symbol lines idx)
  (if (null? lines)
      #f
      (let ((defined (extract-define-symbol (car lines))))
        (if (and defined (equal? symbol defined))
            idx
            (find-symbol-definition-line symbol (cdr lines) (+ idx 1))))))

(define (lookup-symbol-doc symbol text)
  (let ((builtin (lookup-in-docs symbol builtin-docs)))
    (if builtin
        builtin
        (let ((line (find-symbol-definition-line symbol (string-split text "\n") 0)))
          (if (eq? line #f)
              (string-append symbol ": symbol")
              (string-append symbol ": defined in current document at line "
                             (number->string (+ line 1))))))))

; ============================================================================
; LSP Handler
; ============================================================================

(define (handle-hover-request state params id)
  (let ((text-doc (safe-json-get params "textDocument")))
    (let ((position (safe-json-get params "position")))
      (let ((uri (safe-json-get text-doc "uri")))
        (let ((line (safe-json-get position "line"))
              (character (safe-json-get position "character")))
          (if (or (json-null? uri) (json-null? line) (json-null? character))
              (list state (make-response id 'null))
              (let ((text (get-document state uri)))
                (if (or (not text) (json-null? text))
                    (list state (make-response id 'null))
                    (let ((symbol (symbol-at-position text line character)))
                      (if (or (not symbol) (equal? symbol ""))
                          (list state (make-response id 'null))
                          (let ((doc (lookup-symbol-doc symbol text)))
                            (list state
                                  (make-response
                                    id
                                    (make-hover (make-markup-content "plaintext" doc)))))))))))))))
