; LSP Go to Definition Support
; Task 3.7: Jump to symbol definition
;
; When the user requests "Go to Definition":
; 1. Find the symbol at the cursor position
; 2. Parse the document to find where symbols are defined
; 3. Return the location of the definition
;
; Handles:
; - (define name value)
; - (define (name args) body)
; - (defmacro name (args) body)

(import "src/lsp/protocol.lisp")
(import "src/lsp/documents.lisp")

(provide
  handle-definition find-definitions find-definition-for-symbol
  string-index-of extract-first-symbol)

; ============================================================================
; Symbol Extraction (duplicated from hover.lisp to avoid import cycle)
; ============================================================================

; Helper: check if character is part of a symbol
(define (symbol-char? ch)
  (let ((code (char->integer ch)))
    (if (eq? code #f)
        #f
        ; Allow alphanumeric, -, ?, !, *, +, =, <, >, /
        (or (and (>= code 97) (<= code 122))   ; a-z
            (and (>= code 65) (<= code 90))    ; A-Z
            (and (>= code 48) (<= code 57))    ; 0-9
            (= code 45)    ; -
            (= code 63)    ; ?
            (= code 33)    ; !
            (= code 42)    ; *
            (= code 43)    ; +
            (= code 61)    ; =
            (= code 60)    ; <
            (= code 62)    ; >
            (= code 47)    ; /
            (= code 95))))) ; _

; Get the line at a given line number (0-based)
(define (get-line-at lines line-num)
  (if (null? lines)
      ""
      (if (= line-num 0)
          (car lines)
          (get-line-at (cdr lines) (- line-num 1)))))

; Extract symbol starting from position, going left
(define (extract-symbol-left line col acc)
  (if (< col 0)
      acc
      (let ((ch (string-ref line col)))
        (if (eq? ch #f)
            acc
            (if (symbol-char? ch)
                (extract-symbol-left line (- col 1) (string-append ch acc))
                acc)))))

; Extract symbol starting from position, going right
(define (extract-symbol-right line col acc)
  (let ((ch (string-ref line col)))
    (if (eq? ch #f)
        acc
        (if (symbol-char? ch)
            (extract-symbol-right line (+ col 1) (string-append acc ch))
            acc))))

; Get symbol at position (line, character) in text
; Returns the symbol as a string, or #f if no symbol at position
(define (get-symbol-at-position text line character)
  (let ((lines (string-split text "\n")))
    (let ((current-line (get-line-at lines line)))
      (if (equal? current-line "")
          #f
          ; Check if position has a symbol character
          (let ((ch (string-ref current-line character)))
            (if (eq? ch #f)
                #f
                (if (symbol-char? ch)
                    ; Extract the full symbol
                    (let ((left-part (extract-symbol-left current-line (- character 1) "")))
                      (let ((right-part (extract-symbol-right current-line character "")))
                        (string-append left-part right-part)))
                    #f)))))))

; ============================================================================
; Helper Functions
; ============================================================================

; Find index of substring in string
; Returns: index or -1 if not found
(define (string-index-of-acc str substr idx)
  (let ((remaining-len (- (string-length str) idx)))
    (if (< remaining-len (string-length substr))
        -1
        (let ((candidate (substring str idx (+ idx (string-length substr)))))
          (if (equal? candidate substr)
              idx
              (string-index-of-acc str substr (+ idx 1)))))))

(define (string-index-of str substr)
  (string-index-of-acc str substr 0))

; Extract the first symbol from a string (until whitespace or paren)
(define (extract-first-symbol-acc str idx acc)
  (let ((ch (string-ref str idx)))
    (if (eq? ch #f)
        (if (equal? acc "") #f acc)
        (if (or (equal? ch " ")
                (equal? ch "\t")
                (equal? ch "\n")
                (equal? ch "(")
                (equal? ch ")"))
            (if (equal? acc "") #f acc)
            (extract-first-symbol-acc str (+ idx 1) (string-append acc ch))))))

(define (extract-first-symbol str)
  (extract-first-symbol-acc str 0 ""))

; ============================================================================
; Definition Tracking
; ============================================================================
; Definitions are stored as: (name line character)
; We scan the document to find all (define ...) and (defmacro ...) forms

; Scan a line for 'define' or 'defmacro' patterns
; Returns: (name . col) or #f
(define (scan-line-for-define line)
  ; Look for "(define " or "(defmacro "
  (let ((define-idx (string-index-of line "(define ")))
    (if (>= define-idx 0)
        ; Found "(define " - extract the name
        (let ((after-define (substring line (+ define-idx 8) (string-length line))))
          (if (equal? (string-ref after-define 0) "(")
              ; (define (name ...) ...) form
              (let ((name (extract-first-symbol (substring after-define 1 (string-length after-define)))))
                (if name
                    (list name (+ define-idx 9))
                    #f))
              ; (define name ...) form
              (let ((name (extract-first-symbol after-define)))
                (if name
                    (list name (+ define-idx 8))
                    #f))))
        ; Check for defmacro
        (let ((defmacro-idx (string-index-of line "(defmacro ")))
          (if (>= defmacro-idx 0)
              (let ((after-defmacro (substring line (+ defmacro-idx 10) (string-length line))))
                (let ((name (extract-first-symbol after-defmacro)))
                  (if name
                      (list name (+ defmacro-idx 10))
                      #f)))
              #f)))))

; Scan all lines and collect definitions
; Returns: list of (name line col)
(define (scan-lines-for-definitions-acc lines line-num acc)
  (if (null? lines)
      acc
      (let ((result (scan-line-for-define (car lines))))
        (if result
            ; Found a definition
            (let ((name (car result))
                  (col (car (cdr result))))
              (scan-lines-for-definitions-acc
                (cdr lines)
                (+ line-num 1)
                (cons (list name line-num col) acc)))
            ; No definition on this line
            (scan-lines-for-definitions-acc
              (cdr lines)
              (+ line-num 1)
              acc)))))

(define (scan-lines-for-definitions lines)
  (scan-lines-for-definitions-acc lines 0 '()))

; Find all definitions in a document
; Returns: list of (name line col)
(define (find-definitions content)
  (let ((lines (string-split content "\n")))
    (scan-lines-for-definitions lines)))

; Find the definition for a specific symbol
; Returns: (line col) or #f
(define (find-definition-for-symbol-acc defs name)
  (if (null? defs)
      #f
      (let ((def (car defs)))
        (if (equal? (car def) name)
            (list (car (cdr def)) (car (cdr (cdr def))))
            (find-definition-for-symbol-acc (cdr defs) name)))))

(define (find-definition-for-symbol content name)
  (let ((defs (find-definitions content)))
    (find-definition-for-symbol-acc defs name)))

; ============================================================================
; Definition Handler
; ============================================================================
; textDocument/definition request
; Params: {textDocument: {uri}, position: {line, character}}
; Returns: Location or null

(define (handle-definition state params)
  (let ((uri (text-document-uri params))
        (line (position-line params))
        (character (position-character params)))
    (if (or (json-null? uri) (json-null? line) (json-null? character))
        (list state 'null)
        ; Get document content
        (let ((content (get-document state uri)))
          (if (not content)
              (list state 'null)
              ; Find symbol at position
              (let ((symbol (get-symbol-at-position content line character)))
                (if (not symbol)
                    (list state 'null)
                    ; Find definition for this symbol
                    (let ((def-loc (find-definition-for-symbol content symbol)))
                      (if (not def-loc)
                          (list state 'null)
                          ; Return location
                          (let ((def-line (car def-loc))
                                (def-col (car (cdr def-loc))))
                            (let ((range (make-range def-line def-col def-line (+ def-col (string-length symbol)))))
                              (let ((location (make-location uri range)))
                                (list state location)))))))))))))
