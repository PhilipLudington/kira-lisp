# Kira Language Bugs

Bugs encountered in the Kira language while developing the Lisp interpreter.

---

## [ ] Bug 1: Imported recursive functions fail after builtin+lambda call sequence

**Status:** Open (workaround in place)

**Description:** When a recursive function is imported from a module, calling it with a builtin function (like `+`) followed by calling it with an inline lambda causes the second call to fail with "cdr: requires non-empty list" error, even though the list is not empty.

**Steps to reproduce:**
1. Define a recursive function in a module (e.g., `foldl` in stdlib.lisp)
2. Import the module
3. Call the function with a builtin: `(foldl + 0 '(1 2 3))` - works
4. Call the function with an inline lambda: `(foldl (lambda (acc x) (cons x acc)) '() '(1 2 3))` - fails

```lisp
(import "src/stdlib.lisp")
(foldl + 0 '(1 2 3))           ; returns 6 - OK
(foldl (lambda (acc x) (cons x acc)) '() '(1 2 3))  ; ERROR: cdr: requires non-empty list
```

**Expected:** Both calls should succeed.

**Actual:** Second call fails with error pointing to the recursive call site in the imported function.

**Workaround:**
1. Define lambdas as named functions before use
2. Call functions with lambdas before calling with builtins
3. Use explicit recursion instead of higher-order functions with inline lambdas

```lisp
; Workaround 1: Named function
(define cons-to-front (lambda (acc x) (cons x acc)))
(foldl cons-to-front '() '(1 2 3))  ; works

; Workaround 2: Lambda first
(foldl (lambda (acc x) (cons x acc)) '() '(1 2 3))  ; works if called first
(foldl + 0 '(1 2 3))                                 ; works after
```

**Affected code:** `src/stdlib.lisp` - several functions use explicit recursion instead of fold+lambda to avoid this bug.

**Likely cause:** Environment or closure handling issue in the Kira interpreter when module-imported functions are called with different argument types.

---

## [ ] Bug 2: Nested pattern match with sum type extraction causes TypeMismatch

**Status:** Open (workaround in place)

**Description:** When pattern matching on a `List[LispValue]` with a nested sum type extraction like `Cons(LispString(s), Nil)`, Kira throws a runtime `TypeMismatch` error even when the pattern should match.

**Steps to reproduce:**
```kira
match args {
    Cons(LispString(s), Nil) => {
        // Use s - causes TypeMismatch at runtime
    }
    _ => { }
}
```

**Expected:** Pattern matches and `s` is bound to the string value.

**Actual:** Runtime error: `error.TypeMismatch`

**Workaround:** Use two-level matching:
```kira
match args {
    Cons(first, Nil) => {
        match first {
            LispString(s) => {
                // Use s - works
            }
            _ => { }
        }
    }
    _ => { }
}
```

**Affected code:** `src/main.ki` - test framework builtins (`assert-eq`, `assert-true`, `assert-false`, `assert-throws`, `test-begin`) all use two-level matching.

---

## Limitations

### No variadic functions

The Lisp interpreter does not support variadic/rest parameters.

```lisp
; This syntax is NOT supported:
(define (func . args) ...)
(lambda args ...)
```

**Impact:** Functions like `constantly` cannot ignore arbitrary arguments.

**Workaround:** Define functions with a fixed number of parameters (possibly ignored).

### No string manipulation primitives

The interpreter lacks primitives for string operations beyond:
- `string-append` - concatenate strings
- `string-length` - get length
- `number->string` / `string->number` - conversion

**Missing:** `substring`, `string-ref`, `string-split`, `string-join`, `string-trim`

**Impact:** Standard library cannot implement string utilities.

### Import paths relative to working directory

The `import` function resolves paths relative to the current working directory, not relative to the importing file.

```lisp
; In examples/testing/test-stdlib.lisp:
(import "src/stdlib.lisp")        ; Correct - relative to project root
(import "../src/stdlib.lisp")     ; Wrong - would look for examples/src/stdlib.lisp
```

**Impact:** Tests must be run from the project root directory.
