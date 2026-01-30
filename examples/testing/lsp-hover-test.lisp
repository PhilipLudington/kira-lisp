; Test LSP hover support
; Tests symbol extraction and documentation lookup

(import "src/lsp/hover.lisp")
(import "src/json.lisp")

(display "=== LSP Hover Test ===\n\n")

; ============================================================================
; Test 1: get-builtin-docs for known builtins
; ============================================================================
(display "Test 1 - Builtin documentation lookup:\n")

(let ((docs-cons (get-builtin-docs "cons")))
  (if docs-cons
      (display "  PASS: Found docs for 'cons'\n")
      (display "  FAIL: No docs for 'cons'\n")))

(let ((docs-define (get-builtin-docs "define")))
  (if docs-define
      (display "  PASS: Found docs for 'define'\n")
      (display "  FAIL: No docs for 'define'\n")))

(let ((docs-unknown (get-builtin-docs "unknown-function")))
  (if (not docs-unknown)
      (display "  PASS: No docs for unknown function\n")
      (display "  FAIL: Should not find docs for unknown\n")))

; ============================================================================
; Test 2: get-symbol-at-position
; ============================================================================
(display "\nTest 2 - Symbol extraction:\n")

; Simple case: symbol in the middle
(let ((text "(define x 10)"))
  (let ((sym (get-symbol-at-position text 0 1)))
    (if (equal? sym "define")
        (display "  PASS: Found 'define' at position (0,1)\n")
        (let ((_ (display "  FAIL: Expected 'define', got: ")))
          (display sym)
          (display "\n")))))

; Cursor on a number - should return the number
(let ((text "(+ 123 456)"))
  (let ((sym (get-symbol-at-position text 0 4)))
    (if (equal? sym "123")
        (display "  PASS: Found '123' at position (0,4)\n")
        (let ((_ (display "  FAIL: Expected '123', got: ")))
          (display sym)
          (display "\n")))))

; Cursor on parenthesis - should return #f
(let ((text "(+ 1 2)"))
  (let ((sym (get-symbol-at-position text 0 0)))
    (if (eq? sym #f)
        (display "  PASS: No symbol at '(' position\n")
        (display "  FAIL: Should not find symbol at '('\n"))))

; Multi-line text
(let ((text "line0\nline1\nline2"))
  (let ((sym (get-symbol-at-position text 1 0)))
    (if (equal? sym "line1")
        (display "  PASS: Found 'line1' on second line\n")
        (let ((_ (display "  FAIL: Expected 'line1', got: ")))
          (display sym)
          (display "\n")))))

; Symbol with special characters
(let ((text "(null? x)"))
  (let ((sym (get-symbol-at-position text 0 1)))
    (if (equal? sym "null?")
        (display "  PASS: Found 'null?' with special char\n")
        (let ((_ (display "  FAIL: Expected 'null?', got: ")))
          (display sym)
          (display "\n")))))

; ============================================================================
; Test 3: handle-hover integration
; ============================================================================
(display "\nTest 3 - Hover handler integration:\n")

; Set up state with a document
(let ((state (make-initial-state)))
  (let ((state-with-doc (set-document state "file:///test.lisp" "(cons 1 2)")))
    ; Hover over 'cons' at position (0, 1)
    (let ((params (list (list "textDocument" (list (list "uri" "file:///test.lisp")))
                        (list "position" (list (list "line" 0) (list "character" 1))))))
      (let ((result (handle-hover state-with-doc params)))
        (let ((new-state (car result))
              (hover (car (cdr result))))
          (if (eq? hover 'null)
              (display "  FAIL: Expected hover result for 'cons'\n")
              (let ((contents (json-get hover "contents")))
                (if (json-null? contents)
                    (display "  FAIL: Hover missing contents\n")
                    (display "  PASS: Got hover result for 'cons'\n")))))))))

; Hover over unknown symbol
(let ((state (make-initial-state)))
  (let ((state-with-doc (set-document state "file:///test.lisp" "(my-func x)")))
    (let ((params (list (list "textDocument" (list (list "uri" "file:///test.lisp")))
                        (list "position" (list (list "line" 0) (list "character" 1))))))
      (let ((result (handle-hover state-with-doc params)))
        (let ((hover (car (cdr result))))
          (if (eq? hover 'null)
              (display "  PASS: No hover for unknown symbol\n")
              (display "  FAIL: Should not have hover for unknown\n")))))))

(display "\n=== All hover tests completed ===\n")
