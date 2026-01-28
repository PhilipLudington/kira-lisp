; Association List Maps
; Key-value storage using list of pairs
; Uses equal? for key comparison

(provide alist-empty alist-put alist-get alist-get-or alist-remove
         alist-contains? alist-keys alist-values alist-size alist-merge)

; Entry representation: (key value) - a two-element list
; Alist representation: ((key1 val1) (key2 val2) ...)

; Entry accessors
(define (entry-key e) (car e))
(define (entry-val e) (car (cdr e)))

; Create an entry
(define (make-entry key val) (list key val))

; Create an empty alist
(define (alist-empty) '())

; Remove a key from the alist (defined first for alist-put)
(define (alist-remove alist key)
  (if (null? alist)
      '()
      (if (equal? (entry-key (car alist)) key)
          (alist-remove (cdr alist) key)
          (cons (car alist) (alist-remove (cdr alist) key)))))

; Add or update a key-value pair
; New keys go at front, existing keys are replaced
(define (alist-put alist key val)
  (cons (make-entry key val) (alist-remove alist key)))

; Get value for key, returns '() if not found
(define (alist-get alist key)
  (if (null? alist)
      '()
      (if (equal? (entry-key (car alist)) key)
          (entry-val (car alist))
          (alist-get (cdr alist) key))))

; Get value for key, returns default if not found
(define (alist-get-or alist key default)
  (define result (alist-get alist key))
  (if (null? result)
      default
      result))

; Check if key exists in alist
(define (alist-contains? alist key)
  (if (null? alist)
      #f
      (if (equal? (entry-key (car alist)) key)
          #t
          (alist-contains? (cdr alist) key))))

; Get all keys in the alist
(define (alist-keys alist)
  (if (null? alist)
      '()
      (cons (entry-key (car alist)) (alist-keys (cdr alist)))))

; Get all values in the alist
(define (alist-values alist)
  (if (null? alist)
      '()
      (cons (entry-val (car alist)) (alist-values (cdr alist)))))

; Count entries in the alist
(define (alist-size alist)
  (if (null? alist)
      0
      (+ 1 (alist-size (cdr alist)))))

; Merge two alists, second alist wins on conflicts
(define (alist-merge a1 a2)
  (if (null? a2)
      a1
      (alist-merge (alist-put a1 (entry-key (car a2)) (entry-val (car a2)))
                   (cdr a2))))
