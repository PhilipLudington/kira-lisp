; Sets
; Unique element collections using sorted lists
; Uses < for ordering, = for equality (numeric elements only)

(provide set-empty set-add set-remove set-contains? set-size
         set-union set-intersection set-difference set-subset?
         list->set set->list set-fold set-map set-filter)

; Create an empty set
(define (set-empty) '())

; Add element to set (maintains sorted order)
(define (set-add s elem)
  (if (null? s)
      (list elem)
      (if (= (car s) elem)
          s  ; Already exists
          (if (< elem (car s))
              (cons elem s)
              (cons (car s) (set-add (cdr s) elem))))))

; Remove element from set
(define (set-remove s elem)
  (if (null? s)
      '()
      (if (= (car s) elem)
          (cdr s)
          (if (< elem (car s))
              s  ; Element not in set
              (cons (car s) (set-remove (cdr s) elem))))))

; Check if element is in set
(define (set-contains? s elem)
  (if (null? s)
      #f
      (if (= (car s) elem)
          #t
          (if (< elem (car s))
              #f  ; Would be here if present
              (set-contains? (cdr s) elem)))))

; Count elements in set
(define (set-size s)
  (if (null? s)
      0
      (+ 1 (set-size (cdr s)))))

; Union of two sets
(define (set-union s1 s2)
  (if (null? s1)
      s2
      (if (null? s2)
          s1
          (if (= (car s1) (car s2))
              (cons (car s1) (set-union (cdr s1) (cdr s2)))
              (if (< (car s1) (car s2))
                  (cons (car s1) (set-union (cdr s1) s2))
                  (cons (car s2) (set-union s1 (cdr s2))))))))

; Intersection of two sets
(define (set-intersection s1 s2)
  (if (null? s1)
      '()
      (if (null? s2)
          '()
          (if (= (car s1) (car s2))
              (cons (car s1) (set-intersection (cdr s1) (cdr s2)))
              (if (< (car s1) (car s2))
                  (set-intersection (cdr s1) s2)
                  (set-intersection s1 (cdr s2)))))))

; Difference: elements in s1 but not in s2
(define (set-difference s1 s2)
  (if (null? s1)
      '()
      (if (null? s2)
          s1
          (if (= (car s1) (car s2))
              (set-difference (cdr s1) (cdr s2))
              (if (< (car s1) (car s2))
                  (cons (car s1) (set-difference (cdr s1) s2))
                  (set-difference s1 (cdr s2)))))))

; Check if s1 is subset of s2
(define (set-subset? s1 s2)
  (if (null? s1)
      #t
      (if (null? s2)
          #f
          (if (= (car s1) (car s2))
              (set-subset? (cdr s1) (cdr s2))
              (if (< (car s1) (car s2))
                  #f  ; Element not in s2
                  (set-subset? s1 (cdr s2)))))))

; Convert list to set
(define (list->set lst)
  (if (null? lst)
      '()
      (set-add (list->set (cdr lst)) (car lst))))

; Convert set to list (already a list, just identity)
(define (set->list s) s)

; Fold over set elements
(define (set-fold f init s)
  (if (null? s)
      init
      (set-fold f (f init (car s)) (cdr s))))

; Map function over set (result is a new set)
(define (set-map f s)
  (if (null? s)
      '()
      (set-add (set-map f (cdr s)) (f (car s)))))

; Filter set by predicate
(define (set-filter pred s)
  (if (null? s)
      '()
      (if (pred (car s))
          (cons (car s) (set-filter pred (cdr s)))
          (set-filter pred (cdr s)))))
