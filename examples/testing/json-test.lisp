; Tests for JSON library

(import "src/json.lisp")

(test-reset)

; ============================================================================
; Tokenizer Tests
; ============================================================================

(test-begin "json-tokenize: empty and whitespace")
(assert-eq '(#t ()) (json-tokenize "") "empty string")
(assert-eq '(#t ()) (json-tokenize "   ") "whitespace only")
(test-end)

(test-begin "json-tokenize: literals")
(assert-eq '(#t ((null))) (json-tokenize "null") "null")
(assert-eq '(#t ((true))) (json-tokenize "true") "true")
(assert-eq '(#t ((false))) (json-tokenize "false") "false")
(test-end)

(test-begin "json-tokenize: numbers")
(assert-eq '(#t ((number 42))) (json-tokenize "42") "integer")
(assert-eq '(#t ((number -17))) (json-tokenize "-17") "negative integer")
; Note: Floats are tested by checking the structure, exact values may vary
(test-end)

(test-begin "json-tokenize: strings")
(assert-eq '(#t ((string "hello"))) (json-tokenize "\"hello\"") "simple string")
(assert-eq '(#t ((string ""))) (json-tokenize "\"\"") "empty string")
(assert-eq '(#t ((string "a\"b"))) (json-tokenize "\"a\\\"b\"") "escaped quote")
(assert-eq '(#t ((string "a\\b"))) (json-tokenize "\"a\\\\b\"") "escaped backslash")
(assert-eq '(#t ((string "a\nb"))) (json-tokenize "\"a\\nb\"") "escaped newline")
(assert-eq '(#t ((string "a\tb"))) (json-tokenize "\"a\\tb\"") "escaped tab")
(test-end)

(test-begin "json-tokenize: structural")
(assert-eq '(#t ((lbrace) (rbrace))) (json-tokenize "{}") "empty object")
(assert-eq '(#t ((lbracket) (rbracket))) (json-tokenize "[]") "empty array")
(assert-eq '(#t ((lbrace) (string "a") (colon) (number 1) (rbrace)))
           (json-tokenize "{\"a\":1}") "simple object tokens")
(test-end)

; ============================================================================
; Parser Tests
; ============================================================================

(test-begin "json-parse: literals")
(assert-eq '(#t null) (json-parse "null") "null")
(assert-eq '(#t #t) (json-parse "true") "true")
(assert-eq '(#t #f) (json-parse "false") "false")
(test-end)

(test-begin "json-parse: numbers")
(assert-eq '(#t 42) (json-parse "42") "integer")
(assert-eq '(#t -17) (json-parse "-17") "negative")
(assert-eq '(#t 0) (json-parse "0") "zero")
(test-end)

(test-begin "json-parse: strings")
(assert-eq '(#t "hello") (json-parse "\"hello\"") "simple string")
(assert-eq '(#t "") (json-parse "\"\"") "empty string")
(assert-eq '(#t "with spaces") (json-parse "\"with spaces\"") "string with spaces")
(test-end)

(test-begin "json-parse: arrays")
(assert-eq '(#t ()) (json-parse "[]") "empty array")
(assert-eq '(#t (1 2 3)) (json-parse "[1, 2, 3]") "number array")
(assert-eq '(#t ("a" "b")) (json-parse "[\"a\", \"b\"]") "string array")
(assert-eq '(#t (1 "two" #t null)) (json-parse "[1, \"two\", true, null]") "mixed array")
(assert-eq '(#t ((1 2) (3 4))) (json-parse "[[1, 2], [3, 4]]") "nested arrays")
(test-end)

(test-begin "json-parse: objects")
(assert-eq '(#t ()) (json-parse "{}") "empty object")
(assert-eq '(#t (("name" "Alice"))) (json-parse "{\"name\": \"Alice\"}") "simple object")
(assert-eq '(#t (("a" 1) ("b" 2))) (json-parse "{\"a\": 1, \"b\": 2}") "multi-key object")
(test-end)

(test-begin "json-parse: nested structures")
(assert-eq '(#t (("items" (1 2 3))))
           (json-parse "{\"items\": [1, 2, 3]}")
           "object with array")
(assert-eq '(#t ((("x" 1)) (("x" 2))))
           (json-parse "[{\"x\": 1}, {\"x\": 2}]")
           "array of objects")
(test-end)

; ============================================================================
; Serializer Tests
; ============================================================================

(test-begin "json-stringify: literals")
(assert-eq "null" (json-stringify 'null) "null")
(assert-eq "true" (json-stringify #t) "true")
(assert-eq "false" (json-stringify #f) "false")
(test-end)

(test-begin "json-stringify: numbers")
(assert-eq "42" (json-stringify 42) "integer")
(assert-eq "-17" (json-stringify -17) "negative")
(assert-eq "0" (json-stringify 0) "zero")
(test-end)

(test-begin "json-stringify: strings")
(assert-eq "\"hello\"" (json-stringify "hello") "simple string")
(assert-eq "\"\"" (json-stringify "") "empty string")
(assert-eq "\"a\\\"b\"" (json-stringify "a\"b") "escaped quote")
(assert-eq "\"a\\\\b\"" (json-stringify "a\\b") "escaped backslash")
(assert-eq "\"a\\nb\"" (json-stringify "a\nb") "escaped newline")
(test-end)

(test-begin "json-stringify: arrays")
(assert-eq "[]" (json-stringify '()) "empty array")
(assert-eq "[1,2,3]" (json-stringify '(1 2 3)) "number array")
(assert-eq "[\"a\",\"b\"]" (json-stringify '("a" "b")) "string array")
(test-end)

(test-begin "json-stringify: objects")
(assert-eq "{\"a\":1}" (json-stringify '(("a" 1))) "simple object")
(assert-eq "{\"a\":1,\"b\":2}" (json-stringify '(("a" 1) ("b" 2))) "multi-key object")
(test-end)

; ============================================================================
; Round-trip Tests
; ============================================================================

; Helper to test round-trip
(define (roundtrip json-str)
  (let ((parsed (json-parse json-str)))
    (if (car parsed)
        (json-stringify (car (cdr parsed)))
        #f)))

(test-begin "round-trip")
(assert-eq "null" (roundtrip "null") "null round-trip")
(assert-eq "true" (roundtrip "true") "true round-trip")
(assert-eq "42" (roundtrip "42") "number round-trip")
(assert-eq "\"hello\"" (roundtrip "\"hello\"") "string round-trip")
(assert-eq "[1,2,3]" (roundtrip "[1, 2, 3]") "array round-trip")
(assert-eq "{\"x\":1}" (roundtrip "{\"x\": 1}") "object round-trip")
(test-end)

; ============================================================================
; Accessor Tests
; ============================================================================

(test-begin "json-get")
(define test-obj '(("name" "Alice") ("age" 30)))
(assert-eq "Alice" (json-get test-obj "name") "get existing key")
(assert-eq 30 (json-get test-obj "age") "get number value")
(assert-eq 'null (json-get test-obj "missing") "get missing key returns null")
(test-end)

(test-begin "json-get-in")
(define nested '(("user" (("name" "Bob") ("address" (("city" "NYC")))))))
(assert-eq "Bob" (json-get-in nested '("user" "name")) "nested get")
(assert-eq "NYC" (json-get-in nested '("user" "address" "city")) "deep nested get")
(define arr-obj '(("items" (1 2 3))))
(assert-eq 2 (json-get-in arr-obj '("items" 1)) "array index access")
(test-end)

; ============================================================================
; Type Predicate Tests
; ============================================================================

(test-begin "json-null?")
(assert-true (json-null? 'null) "null is json-null?")
(assert-false (json-null? #f) "false is not json-null?")
(assert-false (json-null? '()) "empty list is not json-null?")
(test-end)

(test-begin "json-object?")
(assert-true (json-object? '(("a" 1))) "alist is object")
(assert-false (json-object? '(1 2 3)) "number list is not object")
(assert-false (json-object? '()) "empty list is not object")
(test-end)

(test-begin "json-array?")
(assert-true (json-array? '(1 2 3)) "number list is array")
(assert-true (json-array? '()) "empty list is array")
(assert-false (json-array? '(("a" 1))) "alist is not array")
(test-end)

(test-summary)
