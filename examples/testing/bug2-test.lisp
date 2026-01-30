; Bug 2 test: Function parameters lost after user-defined function calls
;
; Expected: Prints "second"
; Actual:   Error "Undefined variable: b"
;
; Run: kira run src/main.ki run examples/testing/bug2-test.lisp

(define (dummy x)
  (display "dummy called with: ")
  (display x)
  (display "\n")
  '())

(define (helper a b)
  (dummy a)   ; User-defined function call
  b)          ; BUG: "Undefined variable: b"

(display "=== Bug 2 Test ===\n\n")

(display "Test 1: User-defined function then return parameter\n")
(display "  (helper \"first\" \"second\") => ")
(display (helper "first" "second"))
(display "\n  Expected: second\n\n")

(display "Test 2: Lambda call then return parameter\n")
(define (test-lambda a b)
  ((lambda (x) x) a)
  b)
(display "  (test-lambda 1 2) => ")
(display (test-lambda 1 2))
(display "\n  Expected: 2\n\n")

(display "Test 3: Let with user-defined call\n")
(define (test-let a)
  (let ((x a))
    (dummy x)
    x))
(display "  (test-let 42) => ")
(display (test-let 42))
(display "\n  Expected: 42\n\n")

(display "Test 4: Explicit begin block\n")
(define (test-begin a)
  (begin
    (dummy a)
    a))
(display "  (test-begin 99) => ")
(display (test-begin 99))
(display "\n  Expected: 99\n\n")

(display "=== All tests passed ===\n")
