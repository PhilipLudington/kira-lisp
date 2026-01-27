# Kira Language Bugs Encountered

These are bugs in the Kira programming language that were encountered while implementing the Lisp interpreter and compiler.

**Last verified:** 2026-01-27

---

## [x] Bug 1: `for` loop crashes on empty `List[RecursiveType]`

**Status:** Fixed

**Description:** When using a `for` loop to iterate over an empty list where the element type is a recursive sum type (like `LispValue` or `IRExpr`), Kira throws a `TypeMismatch` runtime error.

---

## [x] Bug 2: `if` is a statement, not an expression

**Status:** Fixed

**Description:** Kira's `if` construct is a statement and does not return a value. Now fixed - `if` works as an expression.

---

## [x] Bug 3: No command-line argument support

**Status:** Fixed

**Description:** Kira now provides `std.env.args()` to access command-line arguments.

---

## [x] Bug 4: Multi-line string literals not supported

**Status:** Fixed

**Description:** Kira now supports multi-line string literals.

---

## [ ] Bug 5: `std.env.args()` returns list that doesn't support pattern matching

**Status:** Open (workaround in place)

**Description:** The list returned by `std.env.args()` works with `for` loops but fails with pattern matching on `Cons`/`Nil`. The error is `MatchFailed`.

**Reproduction:**
```kira
effect fn main() -> void {
    let args: List[string] = std.env.args()
    match args {
        Nil => { std.io.println("No args") }
        Cons(first, _) => { std.io.println("First: " + first) }
    }
}
```

**Expected:** Should print "First: <arg>" when an argument is provided.

**Actual:** `Runtime error: error.MatchFailed`

**Workaround:** Convert the args list to a standard list before pattern matching:
```kira
fn convert_args(args: List[string]) -> List[string] {
    var result: List[string] = Nil
    for arg in args {
        result = Cons(arg, result)
    }
    return std.list.reverse(result)
}

effect fn main() -> void {
    let raw_args: List[string] = std.env.args()
    let args: List[string] = convert_args(raw_args)
    match args {
        Nil => { std.io.println("No args") }
        Cons(first, _) => { std.io.println("First: " + first) }
    }
}
```

**Affected code:** `main()` function uses `convert_args()` workaround.
