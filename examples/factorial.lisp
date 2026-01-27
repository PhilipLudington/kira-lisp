; Factorial function
(define (factorial n)
  (if (<= n 1)
      1
      (* n (factorial (- n 1)))))

; Test factorial
(factorial 5)
