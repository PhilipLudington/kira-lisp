; Test importing multiple modules

(import "examples/math-module.lisp")
(import "examples/utils-module.lisp")

; Test math module
(display "Math module tests:") (newline)
(display "  square 4 = ") (display (square 4)) (newline)
(display "  cube 2 = ") (display (cube 2)) (newline)
(display "  double 10 = ") (display (double 10)) (newline)

; Test utils module
(display "Utils module tests:") (newline)
(display "  (identity 42) = ") (display (identity 42)) (newline)

; Compose double with itself = quadruple
(define quadruple (compose double double))
(display "  (quadruple 3) = ") (display (quadruple 3)) (newline)

; Apply square twice = fourth power
(define fourth-power (twice square))
(display "  (fourth-power 2) = ") (display (fourth-power 2)) (newline)
