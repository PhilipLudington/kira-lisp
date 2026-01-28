; Leftist Heaps (Priority Queues)
; Min-heap with efficient merge operation
; Uses numeric comparison

(provide heap-empty heap-empty? heap-insert heap-find-min
         heap-delete-min heap-merge heap-size
         list->heap heap->sorted-list heapsort)

; Heap representation: '() or (rank value left right)
; Invariant: value <= values in children
; Leftist property: rank(left) >= rank(right)
; Rank = length of right spine

; Node accessors
(define (heap-rank h) (car h))
(define (heap-value h) (car (cdr h)))
(define (heap-left h) (car (cdr (cdr h))))
(define (heap-right h) (car (cdr (cdr (cdr h)))))

; Get rank of a heap (handles empty)
(define (rank h)
  (if (null? h) 0 (heap-rank h)))

; Create a node, ensuring leftist property
(define (make-heap-node val left right)
  (if (>= (rank left) (rank right))
      (list (+ 1 (rank right)) val left right)
      (list (+ 1 (rank left)) val right left)))

; Create an empty heap
(define (heap-empty) '())

; Check if heap is empty
(define (heap-empty? h)
  (null? h))

; Merge two heaps (key operation)
(define (heap-merge h1 h2)
  (if (null? h1)
      h2
      (if (null? h2)
          h1
          (if (<= (heap-value h1) (heap-value h2))
              (make-heap-node (heap-value h1)
                              (heap-left h1)
                              (heap-merge (heap-right h1) h2))
              (make-heap-node (heap-value h2)
                              (heap-left h2)
                              (heap-merge h1 (heap-right h2)))))))

; Insert a value into the heap
(define (heap-insert h val)
  (heap-merge (list 1 val '() '()) h))

; Get the minimum value (root)
(define (heap-find-min h)
  (if (null? h)
      '()
      (heap-value h)))

; Remove the minimum value
(define (heap-delete-min h)
  (if (null? h)
      '()
      (heap-merge (heap-left h) (heap-right h))))

; Count elements in heap
(define (heap-size h)
  (if (null? h)
      0
      (+ 1 (heap-size (heap-left h)) (heap-size (heap-right h)))))

; Build heap from list
(define (list->heap lst)
  (if (null? lst)
      '()
      (heap-insert (list->heap (cdr lst)) (car lst))))

; Extract sorted list from heap
(define (heap->sorted-list h)
  (if (null? h)
      '()
      (cons (heap-find-min h)
            (heap->sorted-list (heap-delete-min h)))))

; Sort a list using heap
(define (heapsort lst)
  (heap->sorted-list (list->heap lst)))
