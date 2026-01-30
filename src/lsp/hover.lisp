; LSP Hover Support
; Task 3.6: Show information on hover
;
; When the user hovers over a symbol:
; 1. Find the symbol at the cursor position
; 2. Look up documentation for builtins or user-defined functions
; 3. Return hover content (markdown formatted)

(import "src/lsp/protocol.lisp")
(import "src/lsp/documents.lisp")

(provide
  handle-hover get-symbol-at-position get-builtin-docs)

; ============================================================================
; Builtin Documentation
; ============================================================================
; Documentation strings for builtin functions

(define builtin-docs
  (list
    ; Arithmetic
    (list "+" "(+ n1 n2 ...) - Add numbers")
    (list "-" "(- n1 n2 ...) - Subtract numbers")
    (list "*" "(* n1 n2 ...) - Multiply numbers")
    (list "/" "(/ n1 n2) - Divide numbers")
    (list "mod" "(mod n1 n2) - Modulo (remainder)")
    (list "abs" "(abs n) - Absolute value")
    (list "min" "(min n1 n2) - Minimum of two numbers")
    (list "max" "(max n1 n2) - Maximum of two numbers")

    ; Comparison
    (list "=" "(= n1 n2) - Numeric equality")
    (list "<" "(< n1 n2) - Less than")
    (list ">" "(> n1 n2) - Greater than")
    (list "<=" "(<= n1 n2) - Less than or equal")
    (list ">=" "(>= n1 n2) - Greater than or equal")
    (list "eq?" "(eq? a b) - Identity comparison")
    (list "equal?" "(equal? a b) - Structural equality")
    (list "not" "(not x) - Boolean negation")

    ; Lists
    (list "cons" "(cons head tail) - Construct a pair")
    (list "car" "(car pair) - Get first element of pair")
    (list "cdr" "(cdr pair) - Get rest of pair")
    (list "list" "(list a b c ...) - Create a list")
    (list "null?" "(null? x) - Check if empty list")
    (list "pair?" "(pair? x) - Check if pair/list")
    (list "length" "(length lst) - Get list length")

    ; Type predicates
    (list "number?" "(number? x) - Check if number")
    (list "string?" "(string? x) - Check if string")
    (list "symbol?" "(symbol? x) - Check if symbol")
    (list "procedure?" "(procedure? x) - Check if function")
    (list "boolean?" "(boolean? x) - Check if boolean")

    ; Strings
    (list "string-append" "(string-append s1 s2 ...) - Concatenate strings")
    (list "string-length" "(string-length s) - Get string length")
    (list "string-ref" "(string-ref s idx) - Get character at index (returns string)")
    (list "substring" "(substring s start end) - Extract substring")
    (list "string->list" "(string->list s) - Convert string to list of characters")
    (list "list->string" "(list->string lst) - Convert list of strings to string")
    (list "string-split" "(string-split s delim) - Split string on delimiter")
    (list "string-join" "(string-join lst delim) - Join list with delimiter")
    (list "char->integer" "(char->integer s) - Get character code (first char)")
    (list "integer->char" "(integer->char n) - Convert code to character")
    (list "number->string" "(number->string n) - Convert number to string")
    (list "string->number" "(string->number s) - Parse string as number")

    ; I/O
    (list "display" "(display x) - Print a value")
    (list "newline" "(newline) - Print a newline")
    (list "read-line" "(read-line) - Read a line from stdin")

    ; Testing
    (list "assert-eq" "(assert-eq actual expected msg) - Assert equality")
    (list "assert-true" "(assert-true val msg) - Assert truthy")
    (list "assert-false" "(assert-false val msg) - Assert falsy")
    (list "test-begin" "(test-begin name) - Start a test")
    (list "test-end" "(test-end) - End current test")
    (list "test-summary" "(test-summary) - Print test summary")
    (list "test-reset" "(test-reset) - Reset test state")

    ; Syntax checking
    (list "check-syntax" "(check-syntax code-string) - Check syntax, returns errors")

    ; Special forms
    (list "define" "(define name value) or (define (name args) body) - Define a binding")
    (list "lambda" "(lambda (args) body) - Create a function")
    (list "if" "(if test then else) - Conditional")
    (list "cond" "(cond (test1 expr1) (test2 expr2) ...) - Multi-way conditional")
    (list "let" "(let ((var val) ...) body) - Local bindings")
    (list "let*" "(let* ((var val) ...) body) - Sequential local bindings")
    (list "begin" "(begin expr1 expr2 ...) - Sequence expressions")
    (list "quote" "(quote x) or 'x - Return unevaluated")
    (list "quasiquote" "(quasiquote x) or `x - Quasi-quotation with unquote")
    (list "unquote" "(unquote x) or ,x - Unquote within quasiquote")
    (list "set!" "(set! var value) - Mutate a binding")
    (list "and" "(and a b ...) - Short-circuit and")
    (list "or" "(or a b ...) - Short-circuit or")
    (list "defmacro" "(defmacro name (args) body) - Define a macro")
    (list "import" "(import \"path\") - Import a Lisp file")))

; Look up documentation for a builtin
(define (get-builtin-docs-acc name docs)
  (if (null? docs)
      #f
      (let ((entry (car docs)))
        (if (equal? (car entry) name)
            (car (cdr entry))
            (get-builtin-docs-acc name (cdr docs))))))

(define (get-builtin-docs name)
  (get-builtin-docs-acc name builtin-docs))

; ============================================================================
; Symbol Extraction at Position
; ============================================================================
; Given document text and a position, find the symbol at that position

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
; Hover Handler
; ============================================================================
; textDocument/hover request
; Params: {textDocument: {uri}, position: {line, character}}
; Returns: {contents: string} or null

(define (handle-hover state params)
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
                    ; Look up documentation
                    (let ((docs (get-builtin-docs symbol)))
                      (if docs
                          ; Return hover with documentation
                          (let ((result (make-hover (make-markup-content "markdown"
                                                      (string-append "```lisp\n" docs "\n```")))))
                            (list state result))
                          ; No docs found - just show the symbol
                          (list state 'null))))))))))
