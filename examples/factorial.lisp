; Factorial function - single line version for REPL compatibility
(define (factorial n) (if (<= n 1) 1 (* n (factorial (- n 1)))))
(display "Factorial of 10: ")
(display (factorial 10))
(newline)
