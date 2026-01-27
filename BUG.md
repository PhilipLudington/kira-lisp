# Kira Language Bugs Encountered

These are bugs in the Kira programming language that were encountered while implementing the Lisp interpreter and compiler. Workarounds are in place in `src/main.ki`.

---

## [ ] Bug 1: `for` loop crashes on empty `List[RecursiveType]`

**Status:** Open (workaround in place)

**Description:** When using a `for` loop to iterate over an empty list where the element type is a recursive sum type (like `LispValue` or `IRExpr`), Kira throws a `TypeMismatch` runtime error.

**Reproduction:**
```kira
type TestValue =
    | TestInt(i64)
    | TestList(List[TestValue])

effect fn main() -> void {
    let empty: List[TestValue] = Nil
    for item in empty {
        std.io.println("item")
    }
    std.io.println("done")
}
```

**Expected:** Should print "done" (loop body never executes).

**Actual:** `Runtime error: error.TypeMismatch`

**Workaround:** Always check for empty list before using `for`:
```kira
match list {
    Nil => { /* handle empty case */ }
    _ => {
        for item in list {
            // safe to iterate
        }
    }
}
```

**Affected code locations in src/main.ki:**
- `lisp_to_string` (line ~493)
- `eval_list_values` (line ~757)
- `eval_begin_list` (line ~695)
- `eval_and`, `eval_or` (lines ~733, ~749)
- `extract_param_names` (line ~625)
- `eval_let` (line ~664)
- `builtin_add`, `builtin_mul`, `builtin_string_append`
- `to_ir_list_exprs`, `to_ir_let_bindings`
- `collect_definitions`, `generate_program`

---

## [ ] Bug 2: `if` is a statement, not an expression

**Status:** Open (workaround in place)

**Description:** Kira's `if` construct is a statement and does not return a value. The branches execute but their values are discarded. This makes it impossible to use `if` in expression position.

**Reproduction:**
```kira
fn test(b: bool) -> i32 {
    return if b { 1 } else { 0 }  // Parse error
}

fn test2(b: bool) -> i32 {
    let result: i32 = if b { 1 } else { 0 }  // Returns ()
    return result
}
```

**Expected:** `if` should be usable as an expression that returns the value of the taken branch.

**Actual:** Parse error when using `if` after `return`, or the value is `()` when assigned.

**Workaround:** Use `match` on a boolean inside an immediately-invoked function expression (IIFE):
```kira
fn test(b: bool) -> i32 {
    return (fn() -> i32 {
        match b {
            true => { return 1 }
            false => { return 0 }
        }
    })()
}
```

**Affected code:** Code generator `codegen_expr` for `IRIf` uses this pattern.

---

## [ ] Bug 3: No command-line argument support

**Status:** Open (workaround in place)

**Description:** Kira does not provide access to command-line arguments. There is no `std.env.args()` or similar function.

**Expected:** A way to access command-line arguments passed to the program.

**Actual:** `std.env` module does not exist.

**Workaround:** Modify source code to switch between modes (REPL vs compile) by commenting/uncommenting code in `main()`.

---

## [x] Bug 4: Multi-line string literals not supported

**Status:** Resolved (workaround in place)

**Description:** Kira does not support multi-line string literals. A string must be on a single line.

**Reproduction:**
```kira
let s: string = "line 1
line 2"  // Parse error
```

**Workaround:** Use `StringBuilder` to construct multi-line strings, or concatenate with `"\n"`:
```kira
let s: string = "line 1" + "\n" + "line 2"
```

**Affected code:** `generate_runtime()` function uses `StringBuilder` to build the runtime library source code.
