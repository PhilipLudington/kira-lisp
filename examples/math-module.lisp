; Math module - provides mathematical helper functions

(provide square cube double)

(define (square x) (* x x))
(define (cube x) (* x (* x x)))
(define (double x) (+ x x))

; This helper is not exported
(define (internal-helper x) (+ x 1))
