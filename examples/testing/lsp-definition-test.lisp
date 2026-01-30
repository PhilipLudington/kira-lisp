; Test LSP Go to Definition support
; Tests definition finding and location tracking

(import "src/lsp/definition.lisp")
(import "src/json.lisp")

(display "=== LSP Definition Test ===\n\n")

; ============================================================================
; Test 1: string-index-of helper
; ============================================================================
(display "Test 1 - string-index-of:\n")

(let ((idx (string-index-of "hello world" "world")))
  (if (= idx 6)
      (display "  PASS: Found 'world' at index 6\n")
      (let ((_ (display "  FAIL: Expected 6, got ")))
        (display idx)
        (display "\n"))))

(let ((idx (string-index-of "hello" "xyz")))
  (if (= idx -1)
      (display "  PASS: 'xyz' not found returns -1\n")
      (display "  FAIL: Should return -1\n")))

; ============================================================================
; Test 2: extract-first-symbol
; ============================================================================
(display "\nTest 2 - extract-first-symbol:\n")

(let ((sym (extract-first-symbol "foo bar")))
  (if (equal? sym "foo")
      (display "  PASS: Extracted 'foo'\n")
      (let ((_ (display "  FAIL: Expected 'foo', got ")))
        (display sym)
        (display "\n"))))

(let ((sym (extract-first-symbol "name) rest")))
  (if (equal? sym "name")
      (display "  PASS: Extracted 'name' before paren\n")
      (let ((_ (display "  FAIL: Expected 'name', got ")))
        (display sym)
        (display "\n"))))

; ============================================================================
; Test 3: find-definitions
; ============================================================================
(display "\nTest 3 - find-definitions:\n")

(let ((content "(define x 10)\n(define (foo y) y)\n(defmacro bar (z) z)"))
  (let ((defs (find-definitions content)))
    (display "  Found ")
    (display (length defs))
    (display " definitions\n")
    ; Should find x, foo, and bar
    (if (= (length defs) 3)
        (display "  PASS: Found 3 definitions\n")
        (display "  FAIL: Expected 3 definitions\n"))))

; ============================================================================
; Test 4: find-definition-for-symbol
; ============================================================================
(display "\nTest 4 - find-definition-for-symbol:\n")

(let ((content "(define helper 1)\n(define (main x) (helper x))"))
  (let ((loc (find-definition-for-symbol content "helper")))
    (if loc
        (let ((line (car loc))
              (col (car (cdr loc))))
          (if (= line 0)
              (display "  PASS: Found 'helper' definition on line 0\n")
              (let ((_ (display "  FAIL: Expected line 0, got ")))
                (display line)
                (display "\n"))))
        (display "  FAIL: Did not find 'helper'\n"))))

(let ((content "(define x 1)\n(define y 2)"))
  (let ((loc (find-definition-for-symbol content "y")))
    (if loc
        (let ((line (car loc)))
          (if (= line 1)
              (display "  PASS: Found 'y' definition on line 1\n")
              (display "  FAIL: Expected line 1\n")))
        (display "  FAIL: Did not find 'y'\n"))))

; Not found case
(let ((content "(define x 1)"))
  (let ((loc (find-definition-for-symbol content "unknown")))
    (if (not loc)
        (display "  PASS: Unknown symbol returns #f\n")
        (display "  FAIL: Should not find unknown\n"))))

; ============================================================================
; Test 5: handle-definition integration
; ============================================================================
(display "\nTest 5 - Definition handler integration:\n")

; Set up state with a document
(let ((state (make-initial-state)))
  (let ((content "(define foo 42)\n(display foo)"))
    (let ((state-with-doc (set-document state "file:///test.lisp" content)))
      ; Request definition of 'foo' at the usage position (line 1, col 9)
      (let ((params (list (list "textDocument" (list (list "uri" "file:///test.lisp")))
                          (list "position" (list (list "line" 1) (list "character" 9))))))
        (let ((result (handle-definition state-with-doc params)))
          (let ((new-state (car result))
                (location (car (cdr result))))
            (if (eq? location 'null)
                (display "  FAIL: Expected definition location\n")
                (let ((range (json-get location "range")))
                  (if (json-null? range)
                      (display "  FAIL: Missing range in location\n")
                      (let ((start (json-get range "start")))
                        (let ((line (json-get start "line")))
                          (if (= line 0)
                              (display "  PASS: Found definition at line 0\n")
                              (display "  FAIL: Expected line 0\n")))))))))))))

; Unknown symbol
(let ((state (make-initial-state)))
  (let ((content "(display unknown)"))
    (let ((state-with-doc (set-document state "file:///test.lisp" content)))
      (let ((params (list (list "textDocument" (list (list "uri" "file:///test.lisp")))
                          (list "position" (list (list "line" 0) (list "character" 9))))))
        (let ((result (handle-definition state-with-doc params)))
          (let ((location (car (cdr result))))
            (if (eq? location 'null)
                (display "  PASS: Unknown symbol returns null\n")
                (display "  FAIL: Should return null for unknown\n"))))))))

(display "\n=== All definition tests completed ===\n")
