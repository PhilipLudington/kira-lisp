; JSON Library for Kira Lisp
; Provides JSON parsing and serialization

(provide json-parse json-stringify
         json-tokenize
         json-get json-get-in
         json-null? json-object? json-array?)

; ============================================================================
; JSON Value Representation
; ============================================================================
; JSON null   => 'null (symbol)
; JSON bool   => #t / #f
; JSON number => Lisp number (i64 or f64)
; JSON string => Lisp string
; JSON array  => Lisp list
; JSON object => Association list: ((key val) (key2 val2) ...)

; Check if value is JSON null
(define (json-null? v)
  (equal? v 'null))

; Check if value is a JSON object (non-empty alist with string keys)
(define (json-object? v)
  (if (null? v)
      #f
      (if (pair? v)
          (if (pair? (car v))
              (string? (car (car v)))
              #f)
          #f)))

; Check if value is a JSON array (list that's not an object)
(define (json-array? v)
  (if (pair? v)
      (not (json-object? v))
      (null? v)))

; Helper: nth element of list (needed for json-get-in)
(define (nth n lst)
  (if (null? lst)
      '()
      (if (= n 0)
          (car lst)
          (nth (- n 1) (cdr lst)))))

; Get value from JSON object by key
(define (json-get obj key)
  (if (null? obj)
      'null
      (if (equal? (car (car obj)) key)
          (car (cdr (car obj)))
          (json-get (cdr obj) key))))

; Get value from nested JSON structure by path (list of keys/indices)
(define (json-get-in obj path)
  (if (null? path)
      obj
      (let ((key (car path)))
        (if (number? key)
            ; Array index
            (json-get-in (nth key obj) (cdr path))
            ; Object key
            (json-get-in (json-get obj key) (cdr path))))))

; Helper: convert value to string (for numbers)
(define (to-string v)
  (if (number? v)
      (number->string v)
      (if (string? v)
          v
          "")))

; Helper: reverse a list (local implementation to avoid stdlib dependency)
(define (json-reverse-acc lst acc)
  (if (null? lst)
      acc
      (json-reverse-acc (cdr lst) (cons (car lst) acc))))

(define (json-reverse lst)
  (json-reverse-acc lst '()))

; ============================================================================
; JSON Lexer (Tokenizer)
; ============================================================================
; Tokens are represented as lists: (type value)
; Types: lbrace, rbrace, lbracket, rbracket, colon, comma,
;        string, number, true, false, null

; Whitespace characters
(define (whitespace? c)
  (or (equal? c " ")
      (or (equal? c "\t")
          (or (equal? c "\n")
              (equal? c "\r")))))

; Digit characters
(define (digit? c)
  (let ((code (char->integer c)))
    (if code
        (and (>= code 48) (<= code 57))
        #f)))

; Skip whitespace and return remaining string
(define (skip-ws s)
  (if (equal? s "")
      ""
      (let ((c (string-ref s 0)))
        (if (whitespace? c)
            (skip-ws (substring s 1 (string-length s)))
            s))))

; Parse hex digit to value
(define (hex-digit-value code)
  (if (and (>= code 48) (<= code 57))
      (- code 48)
      (if (and (>= code 65) (<= code 70))
          (+ 10 (- code 65))
          (if (and (>= code 97) (<= code 102))
              (+ 10 (- code 97))
              #f))))

; Parse hex string to integer
(define (parse-hex-acc chars acc)
  (if (null? chars)
      acc
      (let ((c (car chars)))
        (let ((code (char->integer c)))
          (let ((digit (hex-digit-value code)))
            (if digit
                (parse-hex-acc (cdr chars) (+ (* acc 16) digit))
                #f))))))

(define (parse-hex s)
  (parse-hex-acc (string->list s) 0))

; Get escaped character for escape sequence
(define (get-escaped-char next)
  (if (equal? next "\"") "\""
  (if (equal? next "\\") "\\"
  (if (equal? next "/") "/"
  (if (equal? next "b") "\b"
  (if (equal? next "f") "\f"
  (if (equal? next "n") "\n"
  (if (equal? next "r") "\r"
  (if (equal? next "t") "\t"
  (if (equal? next "u") 'unicode
  #f))))))))))

; Parse a JSON string token (starting after opening quote)
(define (parse-json-string-acc s acc)
  (if (equal? s "")
      (list #f "Unterminated string" "")
      (let ((c (string-ref s 0)))
        (if (equal? c "\"")
            ; End of string
            (list #t acc (substring s 1 (string-length s)))
            (if (equal? c "\\")
                ; Escape sequence
                (if (< (string-length s) 2)
                    (list #f "Unterminated escape" "")
                    (let ((next (string-ref s 1)))
                      (let ((escaped (get-escaped-char next)))
                        (if (not escaped)
                            (list #f "Invalid escape sequence" "")
                            (if (equal? escaped 'unicode)
                                ; Handle \uXXXX
                                (if (< (string-length s) 6)
                                    (list #f "Invalid unicode escape" "")
                                    (let ((hex (substring s 2 6)))
                                      (let ((code (parse-hex hex)))
                                        (if code
                                            (let ((char (integer->char code)))
                                              (if char
                                                  (parse-json-string-acc
                                                   (substring s 6 (string-length s))
                                                   (string-append acc char))
                                                  (list #f "Invalid unicode code point" "")))
                                            (list #f "Invalid hex in unicode escape" "")))))
                                (parse-json-string-acc
                                 (substring s 2 (string-length s))
                                 (string-append acc escaped)))))))
                ; Regular character
                (parse-json-string-acc
                 (substring s 1 (string-length s))
                 (string-append acc c)))))))

(define (parse-json-string s)
  (parse-json-string-acc s ""))

; Parse number: finish helper
(define (finish-number acc rest)
  (if (equal? acc "")
      (list #f "Expected number" rest)
      (let ((n (string->number acc)))
        (if n
            (list #t n rest)
            (list #f "Invalid number" rest)))))

; Parse number characters, tracking if we've seen decimal or exponent
(define (parse-number-chars s acc has-dot has-exp)
  (if (equal? s "")
      (finish-number acc s)
      (let ((c (string-ref s 0)))
        ; Digits always allowed
        (if (digit? c)
            (parse-number-chars (substring s 1 (string-length s))
                                (string-append acc c) has-dot has-exp)
            ; Minus only at start
            (if (and (equal? c "-") (equal? acc ""))
                (parse-number-chars (substring s 1 (string-length s))
                                    "-" has-dot has-exp)
                ; Plus only after exponent
                (if (and (equal? c "+") has-exp)
                    (let ((last-char (string-ref acc (- (string-length acc) 1))))
                      (if (or (equal? last-char "e") (equal? last-char "E"))
                          (parse-number-chars (substring s 1 (string-length s))
                                              (string-append acc c) has-dot has-exp)
                          (finish-number acc s)))
                    ; Decimal point
                    (if (and (equal? c ".") (not has-dot) (not has-exp))
                        (parse-number-chars (substring s 1 (string-length s))
                                            (string-append acc c) #t has-exp)
                        ; Exponent
                        (if (and (or (equal? c "e") (equal? c "E")) (not has-exp))
                            (parse-number-chars (substring s 1 (string-length s))
                                                (string-append acc c) has-dot #t)
                            ; End of number
                            (finish-number acc s)))))))))

; Parse a JSON number
(define (parse-json-number s)
  (parse-number-chars s "" #f #f))

; Check if string starts with prefix
(define (starts-with? s prefix)
  (if (< (string-length s) (string-length prefix))
      #f
      (equal? (substring s 0 (string-length prefix)) prefix)))

; Tokenize accumulator (must be defined before json-tokenize)
(define (tokenize-acc s tokens)
  (if (equal? s "")
      (list #t (json-reverse tokens))
      (let ((c (string-ref s 0)))
        (let ((rest (substring s 1 (string-length s))))
          ; Structural tokens
          (if (equal? c "{")
              (tokenize-acc (skip-ws rest) (cons '(lbrace) tokens))
          (if (equal? c "}")
              (tokenize-acc (skip-ws rest) (cons '(rbrace) tokens))
          (if (equal? c "[")
              (tokenize-acc (skip-ws rest) (cons '(lbracket) tokens))
          (if (equal? c "]")
              (tokenize-acc (skip-ws rest) (cons '(rbracket) tokens))
          (if (equal? c ":")
              (tokenize-acc (skip-ws rest) (cons '(colon) tokens))
          (if (equal? c ",")
              (tokenize-acc (skip-ws rest) (cons '(comma) tokens))
          ; String
          (if (equal? c "\"")
              (let ((result (parse-json-string rest)))
                (if (car result)
                    (tokenize-acc (skip-ws (car (cdr (cdr result))))
                                  (cons (list 'string (car (cdr result))) tokens))
                    (list #f (car (cdr result)))))
          ; Keywords
          (if (starts-with? s "true")
              (tokenize-acc (skip-ws (substring s 4 (string-length s)))
                            (cons '(true) tokens))
          (if (starts-with? s "false")
              (tokenize-acc (skip-ws (substring s 5 (string-length s)))
                            (cons '(false) tokens))
          (if (starts-with? s "null")
              (tokenize-acc (skip-ws (substring s 4 (string-length s)))
                            (cons '(null) tokens))
          ; Number
          (if (or (digit? c) (equal? c "-"))
              (let ((result (parse-json-number s)))
                (if (car result)
                    (tokenize-acc (skip-ws (car (cdr (cdr result))))
                                  (cons (list 'number (car (cdr result))) tokens))
                    (list #f (car (cdr result)))))
          ; Unknown character
          (list #f (string-append "Unexpected character: " c)))))))))))))))))

; Tokenize JSON string into list of tokens
(define (json-tokenize s)
  (tokenize-acc (skip-ws s) '()))

; ============================================================================
; JSON Parser
; ============================================================================
; Recursive descent parser - uses a single combined function for mutual recursion

; Helper to make pair from key and value
(define (make-pair k v)
  (list k v))

; Parse value, array continuation, or object continuation
; mode: 'value, 'array-first, 'array-rest, 'object-first, 'object-rest
; acc: accumulated elements for array/object
; key: current key for object (only used in object modes)
(define (parse-json-impl mode acc key tokens)
  (if (null? tokens)
      (if (equal? mode 'value)
          (list #f "Unexpected end of input")
          (list #f "Unexpected end of structure"))
      (let ((tok (car tokens)))
        (let ((rest (cdr tokens)))
          (let ((type (car tok)))
            ; VALUE mode - parse a single value
            (if (equal? mode 'value)
                (if (equal? type 'null) (list #t 'null rest)
                (if (equal? type 'true) (list #t #t rest)
                (if (equal? type 'false) (list #t #f rest)
                (if (equal? type 'string) (list #t (car (cdr tok)) rest)
                (if (equal? type 'number) (list #t (car (cdr tok)) rest)
                (if (equal? type 'lbracket)
                    ; Start array
                    (if (null? rest)
                        (list #f "Unexpected end of array")
                        (if (equal? (car (car rest)) 'rbracket)
                            (list #t '() (cdr rest))
                            (parse-json-impl 'array-first '() '() rest)))
                (if (equal? type 'lbrace)
                    ; Start object
                    (if (null? rest)
                        (list #f "Unexpected end of object")
                        (if (equal? (car (car rest)) 'rbrace)
                            (list #t '() (cdr rest))
                            (parse-json-impl 'object-first '() '() rest)))
                (list #f (string-append "Unexpected token: " (to-string type))))))))))

            ; ARRAY-FIRST mode - parse first element
            (if (equal? mode 'array-first)
                (let ((result (parse-json-impl 'value '() '() tokens)))
                  (if (car result)
                      (let ((val (car (cdr result))))
                        (let ((remaining (car (cdr (cdr result)))))
                          (parse-json-impl 'array-rest (list val) '() remaining)))
                      result))

            ; ARRAY-REST mode - parse ] or , and more elements
            (if (equal? mode 'array-rest)
                (if (equal? type 'rbracket)
                    (list #t (json-reverse acc) rest)
                    (if (equal? type 'comma)
                        (let ((result (parse-json-impl 'value '() '() rest)))
                          (if (car result)
                              (let ((val (car (cdr result))))
                                (let ((remaining (car (cdr (cdr result)))))
                                  (parse-json-impl 'array-rest (cons val acc) '() remaining)))
                              result))
                        (list #f "Expected , or ] in array")))

            ; OBJECT-FIRST mode - parse first key-value pair
            (if (equal? mode 'object-first)
                (if (not (equal? type 'string))
                    (list #f "Expected string key in object")
                    (let ((k (car (cdr tok))))
                      (if (null? rest)
                          (list #f "Expected : after key")
                          (if (not (equal? (car (car rest)) 'colon))
                              (list #f "Expected : after key")
                              (let ((result (parse-json-impl 'value '() '() (cdr rest))))
                                (if (car result)
                                    (let ((val (car (cdr result))))
                                      (let ((remaining (car (cdr (cdr result)))))
                                        (let ((pair (make-pair k val)))
                                          (parse-json-impl 'object-rest (list pair) '() remaining))))
                                    result))))))

            ; OBJECT-REST mode - parse } or , and more key-value pairs
            (if (equal? mode 'object-rest)
                (if (equal? type 'rbrace)
                    (list #t (json-reverse acc) rest)
                    (if (equal? type 'comma)
                        (if (null? rest)
                            (list #f "Expected key after ,")
                            (let ((next-tok (car rest)))
                              (if (not (equal? (car next-tok) 'string))
                                  (list #f "Expected string key in object")
                                  (let ((k (car (cdr next-tok))))
                                    (let ((after-key (cdr rest)))
                                      (if (null? after-key)
                                          (list #f "Expected : after key")
                                          (if (not (equal? (car (car after-key)) 'colon))
                                              (list #f "Expected : after key")
                                              (let ((result (parse-json-impl 'value '() '() (cdr after-key))))
                                                (if (car result)
                                                    (let ((val (car (cdr result))))
                                                      (let ((remaining (car (cdr (cdr result)))))
                                                        (let ((pair (make-pair k val)))
                                                          (parse-json-impl 'object-rest (cons pair acc) '() remaining))))
                                                    result)))))))))
                        (list #f "Expected , or } in object")))

            ; Unknown mode (should never happen)
            (list #f "Invalid parse mode")))))))))))

; Parse JSON from string
(define (json-parse s)
  (let ((tok-result (json-tokenize s)))
    (if (car tok-result)
        (let ((tokens (car (cdr tok-result))))
          (if (null? tokens)
              (list #f "Empty JSON")
              (let ((result (parse-json-impl 'value '() '() tokens)))
                (if (car result)
                    (let ((value (car (cdr result))))
                      (let ((remaining (car (cdr (cdr result)))))
                        (if (null? remaining)
                            (list #t value)
                            (list #f "Unexpected tokens after value"))))
                    result))))
        tok-result)))

; ============================================================================
; JSON Serializer
; ============================================================================

; Get escaped char for serialization
(define (get-escape-for-char c)
  (if (equal? c "\"") "\\\""
  (if (equal? c "\\") "\\\\"
  (if (equal? c "\n") "\\n"
  (if (equal? c "\r") "\\r"
  (if (equal? c "\t") "\\t"
  c))))))

; Stringify a string with proper escaping
(define (escape-json-chars chars acc)
  (if (null? chars)
      acc
      (let ((c (car chars)))
        (let ((rest (cdr chars)))
          (escape-json-chars rest (string-append acc (get-escape-for-char c)))))))

(define (escape-json-string s)
  (escape-json-chars (string->list s) ""))

(define (stringify-string s)
  (string-append "\"" (string-append (escape-json-string s) "\"")))

; Stringify implementation using a mode-based approach like the parser
; Modes: 'value, 'array-elements, 'object-pairs
; acc: accumulated string result
(define (stringify-impl mode v acc first?)
  (if (equal? mode 'value)
      ; VALUE mode - stringify a single value
      (if (json-null? v) "null"
      (if (equal? v #t) "true"
      (if (equal? v #f) "false"
      (if (number? v) (to-string v)
      (if (string? v) (stringify-string v)
      (if (null? v) "[]"
      (if (pair? v)
          (if (json-object? v)
              (string-append "{" (string-append (stringify-impl 'object-pairs v "" #t) "}"))
              (string-append "[" (string-append (stringify-impl 'array-elements v "" #t) "]")))
          "null")))))))

      (if (equal? mode 'array-elements)
          ; ARRAY-ELEMENTS mode - stringify array elements with commas
          (if (null? v)
              acc
              (let ((elem-str (stringify-impl 'value (car v) "" #t)))
                (if first?
                    (stringify-impl 'array-elements (cdr v) elem-str #f)
                    (stringify-impl 'array-elements (cdr v) (string-append acc (string-append "," elem-str)) #f))))

          ; OBJECT-PAIRS mode - stringify object key-value pairs
          (if (null? v)
              acc
              (let ((pair (car v)))
                (let ((key (car pair)))
                  (let ((val (car (cdr pair))))
                    (let ((key-str (stringify-string key)))
                      (let ((val-str (stringify-impl 'value val "" #t)))
                        (let ((pair-str (string-append key-str (string-append ":" val-str))))
                          (if first?
                              (stringify-impl 'object-pairs (cdr v) pair-str #f)
                              (stringify-impl 'object-pairs (cdr v) (string-append acc (string-append "," pair-str)) #f))))))))))))

; Public interface
(define (json-stringify v)
  (stringify-impl 'value v "" #t))
