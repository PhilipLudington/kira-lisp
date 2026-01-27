# Kira Language Bugs

Bugs encountered in the Kira language while developing the Lisp interpreter.

---

## [x] Bug 1: `for` loop on empty `List[RecursiveType]` crashes

**Status:** Fixed

**Description:** When using a `for` loop to iterate over an empty list where the element type is a recursive sum type (like `LispValue` or `IRExpr`), Kira throws a `TypeMismatch` runtime error.

**Steps to reproduce:**
1. Define a recursive sum type: `type LispValue = | LispNil | LispList(List[LispValue])`
2. Create an empty list: `let items: List[LispValue] = Nil`
3. Iterate over it: `for item in items { ... }`

**Expected:** The loop body should not execute (empty list).

**Actual:** Runtime error: `error.TypeMismatch`

**Workaround:** Always check for `Nil` before using `for` loops:
```kira
match list {
    Nil => { /* handle empty */ }
    _ => { for item in list { ... } }
}
```

---

## [x] Bug 2: HashMap `any` type doesn't round-trip for recursive types

**Status:** Fixed

**Description:** When storing a `List[LispValue]` (or other recursive sum type) in a `HashMap` and retrieving it, pattern matching on the retrieved value fails with `TypeMismatch`. The `any` type used by HashMap doesn't properly preserve type information for recursive types.

**Steps to reproduce:**
1. Store a `LispList(Cons(LispString("test"), Nil))` in a HashMap
2. Retrieve it with `std.map.get()`
3. Match on the result to extract the inner list
4. Try to match on or iterate over the extracted `List[LispValue]`

```kira
let map: HashMap = std.map.put(std.map.new(), "key", LispList(Cons(LispString("x"), Nil)))
match std.map.get(map, "key") {
    Some(LispList(items)) => {
        // This match or any operation on `items` fails
        match items {
            Nil => { }
            Cons(_, _) => { }  // TypeMismatch error here
        }
    }
    _ => { }
}
```

**Expected:** Pattern matching on the extracted list should work.

**Actual:** Runtime error: `error.TypeMismatch`

**Workaround:** Avoid storing `List[RecursiveType]` in HashMap, or don't retrieve and match on it. Use alternative data structures or approaches.

**Impact:** This bug prevents implementing:
- Circular import detection (storing loaded module paths)
- Module export filtering (storing export lists)

---

## [x] Bug 3: Pattern match extraction of `List[RecursiveType]` fails on subsequent match

**Status:** Fixed

**Description:** When extracting a `List[LispValue]` from a pattern match (e.g., matching `LispList(items)`), attempting to pattern match on the extracted `items` variable fails, even though it should be a valid `List[LispValue]`.

**Steps to reproduce:**
1. Parse a Lisp expression that contains a list: `(import "file.lisp" (x y))`
2. In eval, match on the argument: `Cons(LispList(syms), Nil)`
3. Try to match on `syms`: `match syms { Nil => ... Cons(_, _) => ... }`

```kira
effect fn eval_import(args: List[LispValue], env: Env) -> EvalResult {
    match args {
        Cons(LispString(path), rest) => {
            match rest {
                Cons(LispList(syms), Nil) => {
                    // `syms` is extracted from pattern match
                    match syms {
                        Nil => { }        // Works
                        Cons(_, _) => { } // MatchFailed error!
                    }
                }
                _ => { }
            }
        }
        _ => { }
    }
}
```

**Expected:** Pattern matching on `syms` should work since it's a valid `List[LispValue]`.

**Actual:** Runtime error: `error.MatchFailed`

**Workaround:** Avoid extracting and re-matching on `List[RecursiveType]` values. Use alternative approaches that don't require nested pattern matching on recursive types.

**Impact:** This bug prevents implementing:
- Explicit symbol lists in import: `(import "file.lisp" (sym1 sym2))`
- Any feature requiring extraction and iteration over nested lists

---

## [x] Bug 4: `if` is a statement, not an expression

**Status:** Workaround in place

**Description:** Kira's `if` statement doesn't return a value, making it impossible to use in expression contexts.

**Workaround:** Use immediately-invoked function expressions (IIFE) with `match`:
```kira
let result: i32 = (fn() -> i32 {
    match condition {
        true => { return 1 }
        false => { return 0 }
    }
})()
```

---

## [x] Bug 5: No command-line argument support

**Status:** Workaround in place

**Description:** Kira doesn't have `std.env.args()` or similar functionality to access command-line arguments.

**Workaround:** ~~Modify source code to switch between modes (REPL, run file, compile).~~

**Fix:** Kira now supports `std.env.args()` which returns `List[string]`. The interpreter uses this for CLI mode selection.

---
