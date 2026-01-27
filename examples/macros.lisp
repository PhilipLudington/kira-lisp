; Macro System Tests

; Test 1: Basic quasiquote with unquote
(define x 10)
(display "Test 1: Basic quasiquote")
(newline)
(display `(a ,x c))
(newline)
; Expected: (a 10 c)

; Test 2: Unquote-splicing
(define items '(1 2 3))
(display "Test 2: Unquote-splicing")
(newline)
(display `(a ,@items b))
(newline)
; Expected: (a 1 2 3 b)

; Test 3: Simple macro - when
(defmacro when (test body)
  `(if ,test ,body))

(display "Test 3: when macro")
(newline)
(when #t (display "yes"))
(newline)
; Should print: yes

; Test 4: unless macro
(defmacro unless (test body)
  `(if (not ,test) ,body))

(display "Test 4: unless macro")
(newline)
(unless #f (display "correct"))
(newline)
; Should print: correct

; Test 5: Multiple unquotes in one expression
(display "Test 5: Multiple unquotes")
(newline)
(define y 20)
(display `(,x ,y ,(+ x y)))
(newline)
; Expected: (10 20 30)

; Test 6: swap macro
(defmacro swap (a b)
  `(let ((temp ,a))
     (set! ,a ,b)
     (set! ,b temp)))

(display "Test 6: swap macro")
(newline)
(define p 1)
(define q 2)
(swap p q)
(display "p=")
(display p)
(display " q=")
(display q)
(newline)
; Expected: p=2 q=1

; Test 7: inc! macro
(defmacro inc! (var)
  `(set! ,var (+ ,var 1)))

(display "Test 7: inc! macro")
(newline)
(define counter 0)
(inc! counter)
(inc! counter)
(display "counter=")
(display counter)
(newline)
; Expected: counter=2

(display "All macro tests completed!")
(newline)
