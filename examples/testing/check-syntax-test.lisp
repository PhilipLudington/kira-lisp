; Test check-syntax builtin
(display "Testing check-syntax builtin:\n\n")

; Test 1: Valid code - should return empty list
(display "Test 1 - Valid code: ")
(let ((result (check-syntax "(+ 1 2)")))
  (if (null? result)
      (display "PASS\n")
      (display "FAIL\n")))

; Test 2: Valid multi-expression - should return empty list
(display "Test 2 - Multiple valid expressions: ")
(let ((result (check-syntax "(define x 1)\n(+ x 2)")))
  (if (null? result)
      (display "PASS\n")
      (display "FAIL\n")))

; Test 3: Unclosed paren - should return error with location
(display "Test 3 - Unclosed paren: ")
(let ((result (check-syntax "(+ 1 2")))
  (if (pair? result)
      (let ((err (car result)))
        (let ((line (car err))
              (col (car (cdr err)))
              (msg (car (cdr (cdr err)))))
          (display "PASS (line=")
          (display line)
          (display ", col=")
          (display col)
          (display ", msg='")
          (display msg)
          (display "')\n")))
      (display "FAIL (expected error)\n")))

; Test 4: Unterminated string - should return error
(display "Test 4 - Unterminated string: ")
(let ((result (check-syntax "\"hello")))
  (if (pair? result)
      (let ((err (car result)))
        (display "PASS (msg='")
        (display (car (cdr (cdr err))))
        (display "')\n"))
      (display "FAIL\n")))

; Test 5: Unexpected closing paren
(display "Test 5 - Unexpected closing paren: ")
(let ((result (check-syntax ")")))
  (if (pair? result)
      (let ((err (car result)))
        (display "PASS (msg='")
        (display (car (cdr (cdr err))))
        (display "')\n"))
      (display "FAIL\n")))

; Test 6: Empty string is valid
(display "Test 6 - Empty string: ")
(let ((result (check-syntax "")))
  (if (null? result)
      (display "PASS\n")
      (display "FAIL\n")))

(display "\nAll check-syntax tests completed.\n")
