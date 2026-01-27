; Utils module - general utility functions

(provide identity compose twice)

; Identity function
(define (identity x) x)

; Function composition: (compose f g) returns a function that applies g then f
(define (compose f g)
  (lambda (x) (f (g x))))

; Apply a function twice
(define (twice f)
  (compose f f))
