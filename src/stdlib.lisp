; Kira Lisp Standard Library
; Core functional utilities implemented in Lisp

(provide map filter reduce fold foldl foldr
         take drop append reverse nth last
         every? some? none? find member?
         sum product clamp
         compose identity constantly
         zip range flatten)

; ============================================================================
; List Operations
; ============================================================================

; Apply a function to each element of a list
; Implemented via foldr to avoid recursive call issues
(define (map f lst)
  (foldr (lambda (x acc) (cons (f x) acc)) '() lst))

; Keep elements that satisfy predicate
; Implemented via foldr to avoid recursive call issues
(define (filter pred lst)
  (foldr (lambda (x acc) (if (pred x) (cons x acc) acc)) '() lst))

; Left fold: ((((init op e1) op e2) op e3) ...)
(define (foldl f init lst)
  (if (null? lst)
      init
      (foldl f (f init (car lst)) (cdr lst))))

; Right fold: (e1 op (e2 op (e3 op init)))
(define (foldr f init lst)
  (if (null? lst)
      init
      (f (car lst) (foldr f init (cdr lst)))))

; Aliases for fold (reduce = foldl by convention)
(define reduce foldl)
(define fold foldl)

; Take first n elements
(define (take n lst)
  (if (or (<= n 0) (null? lst))
      '()
      (cons (car lst) (take (- n 1) (cdr lst)))))

; Drop first n elements
(define (drop n lst)
  (if (or (<= n 0) (null? lst))
      lst
      (drop (- n 1) (cdr lst))))

; Append two lists
(define (append lst1 lst2)
  (if (null? lst1)
      lst2
      (cons (car lst1) (append (cdr lst1) lst2))))

; Reverse a list (using explicit recursion to avoid closure bug)
(define (reverse lst)
  (define (rev-helper lst acc)
    (if (null? lst)
        acc
        (rev-helper (cdr lst) (cons (car lst) acc))))
  (rev-helper lst '()))

; Get nth element (0-indexed)
(define (nth n lst)
  (if (null? lst)
      '()  ; Return nil for out of bounds
      (if (= n 0)
          (car lst)
          (nth (- n 1) (cdr lst)))))

; Get last element
(define (last lst)
  (if (null? lst)
      '()
      (if (null? (cdr lst))
          (car lst)
          (last (cdr lst)))))

; Flatten nested lists one level
(define (flatten lst)
  (foldr (lambda (x acc)
           (if (pair? x)
               (append x acc)
               (cons x acc)))
         '()
         lst))

; ============================================================================
; Predicates
; ============================================================================

; Check if all elements satisfy predicate
(define (every? pred lst)
  (if (null? lst)
      #t
      (if (pred (car lst))
          (every? pred (cdr lst))
          #f)))

; Check if any element satisfies predicate
(define (some? pred lst)
  (if (null? lst)
      #f
      (if (pred (car lst))
          #t
          (some? pred (cdr lst)))))

; Check if no elements satisfy predicate
(define (none? pred lst)
  (not (some? pred lst)))

; Find first element satisfying predicate (returns '() if not found)
(define (find pred lst)
  (if (null? lst)
      '()
      (if (pred (car lst))
          (car lst)
          (find pred (cdr lst)))))

; Check if element is in list (using explicit recursion)
(define (member? x lst)
  (if (null? lst)
      #f
      (if (equal? (car lst) x)
          #t
          (member? x (cdr lst)))))

; ============================================================================
; Math Utilities
; ============================================================================

; Sum all numbers in a list
(define (sum lst)
  (foldl + 0 lst))

; Product of all numbers in a list
(define (product lst)
  (foldl * 1 lst))

; Clamp value between min and max
(define (clamp lo hi x)
  (min hi (max lo x)))

; ============================================================================
; Higher-Order Utilities
; ============================================================================

; Function composition: (compose f g) returns a function that applies g then f
(define (compose f g)
  (lambda (x) (f (g x))))

; Identity function
(define (identity x) x)

; Return a function that always returns the given value
; Note: This version ignores any single argument passed
(define (constantly x)
  (lambda (ignored) x))

; ============================================================================
; List Generators
; ============================================================================

; Zip two lists into a list of pairs
(define (zip lst1 lst2)
  (if (or (null? lst1) (null? lst2))
      '()
      (cons (list (car lst1) (car lst2))
            (zip (cdr lst1) (cdr lst2)))))

; Generate a range of numbers [start, end)
(define (range start end)
  (if (>= start end)
      '()
      (cons start (range (+ start 1) end))))
