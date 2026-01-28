; Binary Search Trees
; Ordered maps with O(log n) operations (when balanced)
; Uses < and = for numeric keys

(import "src/stdlib.lisp")

(provide bst-empty bst-put bst-get bst-remove bst-contains?
         bst-size bst-height bst-min bst-max
         bst-keys bst-values bst-fold-inorder)

; Tree representation: '() or (key value left right)

; Node accessors
(define (bst-key node) (car node))
(define (bst-val node) (car (cdr node)))
(define (bst-left node) (car (cdr (cdr node))))
(define (bst-right node) (car (cdr (cdr (cdr node)))))

; Create a node
(define (make-node key val left right)
  (list key val left right))

; Create an empty tree
(define (bst-empty) '())

; Insert or update a key-value pair
(define (bst-put tree key val)
  (if (null? tree)
      (make-node key val '() '())
      (if (= key (bst-key tree))
          (make-node key val (bst-left tree) (bst-right tree))
          (if (< key (bst-key tree))
              (make-node (bst-key tree) (bst-val tree)
                         (bst-put (bst-left tree) key val)
                         (bst-right tree))
              (make-node (bst-key tree) (bst-val tree)
                         (bst-left tree)
                         (bst-put (bst-right tree) key val))))))

; Get value for key, returns '() if not found
(define (bst-get tree key)
  (if (null? tree)
      '()
      (if (= key (bst-key tree))
          (bst-val tree)
          (if (< key (bst-key tree))
              (bst-get (bst-left tree) key)
              (bst-get (bst-right tree) key)))))

; Check if key exists in tree
(define (bst-contains? tree key)
  (if (null? tree)
      #f
      (if (= key (bst-key tree))
          #t
          (if (< key (bst-key tree))
              (bst-contains? (bst-left tree) key)
              (bst-contains? (bst-right tree) key)))))

; Get minimum key in tree
(define (bst-min tree)
  (if (null? tree)
      '()
      (if (null? (bst-left tree))
          (bst-key tree)
          (bst-min (bst-left tree)))))

; Get maximum key in tree
(define (bst-max tree)
  (if (null? tree)
      '()
      (if (null? (bst-right tree))
          (bst-key tree)
          (bst-max (bst-right tree)))))

; Helper: get minimum node (key and value)
(define (bst-min-node tree)
  (if (null? (bst-left tree))
      tree
      (bst-min-node (bst-left tree))))

; Remove a key from tree
(define (bst-remove tree key)
  (if (null? tree)
      '()
      (if (= key (bst-key tree))
          ; Found the node to remove
          (if (null? (bst-left tree))
              (bst-right tree)
              (if (null? (bst-right tree))
                  (bst-left tree)
                  ; Has both children: replace with successor
                  (let ((succ (bst-min-node (bst-right tree))))
                    (make-node (bst-key succ) (bst-val succ)
                               (bst-left tree)
                               (bst-remove (bst-right tree) (bst-key succ))))))
          (if (< key (bst-key tree))
              (make-node (bst-key tree) (bst-val tree)
                         (bst-remove (bst-left tree) key)
                         (bst-right tree))
              (make-node (bst-key tree) (bst-val tree)
                         (bst-left tree)
                         (bst-remove (bst-right tree) key))))))

; Count nodes in tree
(define (bst-size tree)
  (if (null? tree)
      0
      (+ 1 (bst-size (bst-left tree)) (bst-size (bst-right tree)))))

; Get tree height
(define (bst-height tree)
  (if (null? tree)
      0
      (+ 1 (max (bst-height (bst-left tree))
                (bst-height (bst-right tree))))))

; Get all keys in-order
(define (bst-keys tree)
  (if (null? tree)
      '()
      (append (bst-keys (bst-left tree))
              (cons (bst-key tree)
                    (bst-keys (bst-right tree))))))

; Get all values in-order
(define (bst-values tree)
  (if (null? tree)
      '()
      (append (bst-values (bst-left tree))
              (cons (bst-val tree)
                    (bst-values (bst-right tree))))))

; Fold in-order: visits keys in sorted order
(define (bst-fold-inorder f init tree)
  (if (null? tree)
      init
      (bst-fold-inorder f
                        (f (bst-fold-inorder f init (bst-left tree))
                           (bst-key tree)
                           (bst-val tree))
                        (bst-right tree))))
