# Kira Language Bugs

Bugs encountered in the Kira language while developing the Lisp interpreter.

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

---

## [x] Bug 2: Function parameters lost after user-defined function calls in sequence

**Status:** Fixed

**Description:** When a function body contains a sequence of expressions, calling a **user-defined function** causes subsequent expressions to lose access to function parameters and let-bound variables. The variables become undefined. **Builtin functions do not trigger this bug.**

**Minimal reproduction:**

```lisp
(define (dummy x)
  (display "called")
  '())

(define (helper a b)
  (dummy a)
  b)  ; ERROR: Undefined variable: b

(helper "first" "second")
```

Error: `Undefined variable: b`

The parameter `b` (and `a`) become unavailable after the `(dummy a)` call.

---

### Diagnostic Test Results

| Test | Scenario | Result |
|------|----------|--------|
| Single expression body | `(define (f a b) b)` | ✅ |
| Two expressions, no call | `(define (f a b) a b)` | ✅ |
| Builtin then return | `(define (f a b) (display a) b)` | ✅ |
| Arithmetic builtin then return | `(define (f a b) (+ 1 2) b)` | ✅ |
| **User-defined fn then return** | `(define (f a b) (noop a) b)` | ❌ |
| Lambda call then return | `(define (f a b) ((lambda (x) x) a) b)` | ❌ |
| Let without function call | `(let ((x a)) x b)` | ✅ |
| Let with user-defined call | `(let ((x a)) (noop x) b)` | ❌ |
| Explicit begin block | `(begin (noop a) b)` | ❌ |

**Key finding:** The bug is triggered specifically by **user-defined function calls** (including lambdas), NOT by builtin function calls.

---

### Observations

- Affects ALL function parameters and let-bound variables
- Only triggered by **user-defined function calls** (not builtins)
- Builtins like `display`, `+`, `cons`, etc. do NOT cause parameter loss
- Lambda calls `((lambda ...) ...)` trigger the bug (they are user-defined)
- Both implicit sequences and explicit `begin` blocks are affected
- Related to Bug 1, likely same root cause in environment handling

---

### Hypothesis for Compiler Team

The bug appears to be in **environment handling when returning from user-defined function calls**.

**Suspected mechanism:**

1. Function `helper` is called, creating environment frame with `a="first"`, `b="second"`
2. First expression `(dummy a)` is evaluated:
   - `dummy` creates its own environment frame
   - `dummy` executes and returns
   - **BUG:** The environment is corrupted or replaced when returning from `dummy`
3. Second expression `b` is evaluated in the corrupted environment
4. `b` is not found → "Undefined variable: b"

**Why builtins work but user-defined functions don't:**

Builtins are handled in `apply_builtin()` which likely:
- Does NOT create a new environment frame
- Does NOT modify the caller's environment on return

User-defined functions go through `apply()` which likely:
- Creates a new environment frame for the function body
- **BUG:** Incorrectly replaces or discards the caller's environment on return

**Where to look in `src/main.ki`:**

1. **`eval_begin` or implicit sequence handling** - How is the environment threaded between expressions?
2. **`apply` function** - What environment is returned after a user-defined function call?
3. **Environment threading in sequences** - Is the returned environment from a function call incorrectly used for subsequent expressions?

**The fix for Bug 1 addressed environment threading in several places:**
- `eval_if` - now uses original env for branches
- `eval_and` / `eval_or` - now uses original env
- `eval_list_values` - evaluates args in same original env
- `eval_define` - uses original env

**Bug 2 fix applied to:**
- `eval_begin_list` - now checks if expression is a binding form (`define`, `set!`, `defmacro`, `import`) and only uses the returned environment for those. For all other expressions (especially function calls), uses the original environment.

---

### Workaround

Structure code so no variables are referenced after user-defined function calls:

```lisp
; Pass needed values through the called function
(define (dummy-and-return x ret)
  (display "called")
  ret)

(define (helper a b)
  (dummy-and-return a b))  ; b is passed as argument, returned by dummy-and-return
```

---

### Impact

This bug severely limits idiomatic Lisp code. Patterns requiring side effects followed by returning a value are impossible:

```lisp
; Cannot do this:
(define (process-and-log data)
  (log "Processing...")  ; user-defined logging function
  (transform data))      ; ERROR: data is undefined

; Must restructure as:
(define (process-and-log data)
  (log-and-return "Processing..." (transform data)))
```

**Affected LSP features:**
- Diagnostics (need to send notifications then return state)
- Any handler that performs I/O then returns a value

---

### Deep Analysis (2026-01-30)

#### The Bug Pattern: Environment Threading

Bug 2 is a classic interpreter bug involving **environment threading**. In interpreters where `eval` returns both a value AND an environment:

```
eval(expr, env) → (value, new_env)
```

The bug occurs when evaluating **sequences** (multiple expressions). The buggy implementation incorrectly threads the returned environment:

```
; Evaluating (begin (dummy a) b) in func_env where a="first", b="second"

(v1, env1) = eval((dummy a), func_env)
(v2, env2) = eval(b, env1)  ← BUG: uses env1 instead of func_env
```

When `(dummy a)` returns, `env1` is the **callee's environment** (or a corrupted version), not `func_env` which contains `a` and `b`. The subsequent lookup of `b` in `env1` fails with "Undefined variable".

#### Why Builtins Don't Trigger This Bug

Builtins are handled differently in `apply_builtin`:
- They don't create new environment frames
- They return `(value, original_env)` unchanged
- Example: `(display a)` returns `(void, func_env)` — environment preserved

User-defined functions in `apply`:
- Create a new environment frame for parameters
- **BUG:** Return this new frame instead of preserving caller's env
- Example: `(dummy a)` returns `(result, dummy_env)` — **wrong env returned**

#### Concrete Example of the Bug

```lisp
(define (helper a b)
  (dummy a)   ; Returns (result, dummy_env) where dummy_env has NO 'a' or 'b'
  b)          ; Evaluated in dummy_env → "Undefined variable: b"
```

**Execution trace:**

1. `(helper "first" "second")` called
2. `func_env` created with `{a: "first", b: "second"}`
3. `(dummy a)` evaluated:
   - `dummy_env` created with `{x: "first"}` (dummy's parameter)
   - `dummy` body executes, returns value
   - **BUG:** Returns `(result, dummy_env)` instead of `(result, func_env)`
4. `b` evaluated in `dummy_env`
5. `dummy_env.get("b")` fails → **"Undefined variable: b"**

#### The Fix Pattern

The fix (same pattern used for Bug 1) is to use the **original environment** for all expressions in a sequence, ignoring the returned environment:

**Buggy `eval_begin`:**
```
fn eval_begin(exprs, env):
    current_env = env
    for expr in exprs:
        (value, current_env) = eval(expr, current_env)  # BUG: threading env
    return (value, current_env)
```

**Fixed `eval_begin`:**
```
fn eval_begin(exprs, env):
    for expr in exprs:
        (value, _) = eval(expr, env)  # Always use original env
    return (value, env)               # Return original env
```

#### Where to Apply the Fix

Based on the diagnostic test results, the fix needs to be applied to:

1. **`eval_begin`** — Explicit `(begin ...)` blocks
2. **Implicit sequence handling** — Function bodies with multiple expressions
3. **`let` body evaluation** — After binding, body expressions need original env

The key insight: **Within a single lexical scope, all expressions should see the same environment.** The environment returned by evaluating a subexpression should NOT replace the current scope's environment for sibling expressions.

#### Verification

After applying the fix, these should all pass:

```lisp
(define (f a b) (noop a) b)           ; Should return b
((lambda (a b) (noop a) b) 1 2)       ; Should return 2
(let ((x 1)) (noop x) x)              ; Should return 1
(begin (noop 1) 2)                    ; Should return 2
```

---

### Source Code Analysis (for Kira compiler team)

#### The Buggy Code: `src/main.ki:1066-1084`

```kira
effect fn eval_begin_list(exprs: List[LispValue], env: Env) -> EvalResult {
    match exprs {
        Nil => { return EvalOk(LispNil, env) }
        Cons(last_expr, Nil) => {
            return eval(last_expr, env)
        }
        Cons(first_expr, rest) => {
            match trampoline(eval(first_expr, env)) {
                EvalOk(_, new_env) => {
                    // BUG: Uses new_env instead of env
                    return eval_begin_list(rest, new_env)
                }
                EvalErr(msg, loc) => { return EvalErr(msg, loc) }
                TailCall(_, _, _) => { return EvalErr("Internal error: trampoline returned TailCall", None) }
            }
        }
    }
}
```

**Line 1078 is the bug:** `eval_begin_list(rest, new_env)` should be `eval_begin_list(rest, env)`.

---

#### Why Builtins Work: `src/main.ki:1599-1606`

Builtins like `display` return the **original** `env` unchanged:

```kira
effect fn builtin_display(args: List[LispValue], loc: Option[SourceLoc], env: Env) -> EvalResult {
    match args {
        Cons(v, Nil) => {
            // ... print logic ...
            return EvalOk(LispNil, env)  // Returns ORIGINAL env
        }
        // ...
    }
}
```

When `eval_begin_list` calls a builtin:
- `trampoline(eval((display a), func_env))` returns `EvalOk(nil, func_env)`
- `new_env == func_env` — same environment, no problem
- Next expression evaluates correctly in `func_env`

---

#### Why User-Defined Functions Break: `src/main.ki:1498-1511`

User-defined functions create a **new environment** from their closure:

```kira
effect fn apply(func: LispValue, args: List[LispValue], loc: Option[SourceLoc], env: Env) -> EvalResult {
    match func {
        LispLambda(params, body, closure_env) => {
            let call_env: Env = env_extend(closure_env)  // New env from CLOSURE, not caller
            match env_define_all(call_env, params, args) {
                Ok(bound_env) => {
                    return TailCall(body, Nil, bound_env)  // Returns callee's env
                }
                // ...
            }
        }
        // ...
    }
}
```

When `eval_begin_list` calls a user-defined function:
- `trampoline(eval((dummy a), func_env))` goes through `apply`
- `apply` creates `call_env` extending `closure_env` (dummy's closure)
- After execution, returns `EvalOk(result, call_env)` where `call_env` has only `{x: ...}`
- `new_env == call_env` — **wrong environment**, missing `a` and `b`
- Next expression `b` evaluated in `call_env` → "Undefined variable: b"

---

#### The Fix (Applied)

Added `is_binding_form()` helper function and modified `eval_begin_list` to conditionally use the returned environment:

```kira
// Check if an expression is a binding form that modifies the environment
fn is_binding_form(expr: LispValue) -> bool {
    match expr {
        LispList(Cons(LispSymbol(name, _), _), _) => {
            return name == "define" or name == "set!" or name == "defmacro" or name == "import"
        }
        _ => { return false }
    }
}

// In eval_begin_list:
EvalOk(_, new_env) => {
    if is_binding_form(first_expr) {
        return eval_begin_list(rest, new_env)  // Binding forms need new env
    } else {
        return eval_begin_list(rest, env)       // Everything else uses original env
    }
}
```

This preserves environment changes from binding forms (`define`, `set!`, `defmacro`, `import`) while discarding environment changes from function calls (which return the callee's unrelated environment).

---

#### Related Code Paths

The same pattern applies to all sequence-like constructs. Here's the current status:

| Location | Function | Status | Notes |
|----------|----------|--------|-------|
| `main.ki:1078` | `eval_begin_list` | ✅ Fixed | Uses `is_binding_form()` check to decide when to propagate env |
| `main.ki:947` | `eval_if` | ✅ Fixed | Uses `_` to discard returned env |
| `main.ki:1046` | `eval_let` bindings | ✅ Fixed | Uses `_` to discard returned env |
| `main.ki:1055` | `eval_let` body | ✅ Fixed | Calls `eval_begin_list` which is now fixed |
| `main.ki:1117` | `eval_and` | ✅ Fixed | Uses `_` to discard returned env |
| `main.ki:1142` | `eval_or` | ✅ Fixed | Uses `_` to discard returned env |

The fix for `eval_begin_list` is more nuanced: it uses `is_binding_form()` to check if the expression is `define`, `set!`, `defmacro`, or `import`, and only uses the returned environment for those. For all other expressions, it uses the original environment.

---

#### Minimal Test Case

Save as `examples/testing/bug2-test.lisp`:

```lisp
; Bug 2 test: Function parameters lost after user-defined function calls
(define (dummy x)
  (display "dummy called with: ")
  (display x)
  (display "\n")
  '())

(define (helper a b)
  (dummy a)   ; User-defined function call
  b)          ; BUG: "Undefined variable: b"

(display "Testing Bug 2...\n")
(display "Result: ")
(display (helper "first" "second"))  ; Should print "second"
(display "\n")
```

Run with: `kira run src/main.ki run examples/testing/bug2-test.lisp`

**Expected (after fix):** Prints "second"
**Actual (with bug):** Error "Undefined variable: b"
