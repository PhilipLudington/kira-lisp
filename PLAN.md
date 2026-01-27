# Lisp Compiler in Kira - Implementation Plan

## Project Overview

Build a Lisp compiler in Kira that compiles a subset of Lisp (Scheme-like) to executable code. The compiler will support core Lisp features: S-expressions, symbols, lists, lambdas, and macros.

---

## Phase 1: Core Data Types and Lexer

### Task 1.1: Define Lisp Value Types
**File:** `src/types.ki`

Define the core value representation for Lisp:

```kira
type LispValue =
    | LispNil
    | LispBool(bool)
    | LispInt(i64)
    | LispFloat(f64)
    | LispString(string)
    | LispSymbol(string)
    | LispList(List[LispValue])
    | LispLambda(List[string], LispValue, Env)
    | LispBuiltin(string)

type Env = {
    bindings: HashMap,
    parent: Option[Env]
}
```

### Task 1.2: Define Token Types
**File:** `src/lexer.ki`

```kira
type Token =
    | TokLParen
    | TokRParen
    | TokQuote
    | TokInt(i64)
    | TokFloat(f64)
    | TokString(string)
    | TokSymbol(string)
    | TokBool(bool)
    | TokEOF

type LexResult =
    | LexOk(List[Token])
    | LexErr(string, i32)  // error message, position
```

### Task 1.3: Implement Lexer
**File:** `src/lexer.ki`

- `tokenize(input: string) -> LexResult`
- Handle: parentheses, quotes, numbers (int/float), strings, symbols, booleans (#t, #f)
- Skip whitespace and comments (`;` to end of line)
- Track position for error reporting

**Test cases:**
- `(+ 1 2)` → `[LParen, Symbol("+"), Int(1), Int(2), RParen]`
- `(define x 42)` → `[LParen, Symbol("define"), Symbol("x"), Int(42), RParen]`
- `"hello world"` → `[String("hello world")]`

---

## Phase 2: Parser

### Task 2.1: Define Parse Result Types
**File:** `src/parser.ki`

```kira
type ParseResult =
    | ParseOk(LispValue, List[Token])
    | ParseErr(string)
```

### Task 2.2: Implement S-Expression Parser
**File:** `src/parser.ki`

Implement recursive descent parser:
- `parse(tokens: List[Token]) -> ParseResult`
- `parse_expr(tokens: List[Token]) -> ParseResult`
- `parse_list(tokens: List[Token]) -> ParseResult`
- Handle quote (`'expr` → `(quote expr)`)

**Grammar:**
```
expr   := atom | list | quoted
atom   := INT | FLOAT | STRING | SYMBOL | BOOL
list   := '(' expr* ')'
quoted := '\'' expr
```

---

## Phase 3: Interpreter (Reference Implementation)

### Task 3.1: Environment Operations
**File:** `src/env.ki`

```kira
fn env_new() -> Env
fn env_extend(parent: Env) -> Env
fn env_define(env: Env, name: string, value: LispValue) -> Env
fn env_lookup(env: Env, name: string) -> Option[LispValue]
fn env_set(env: Env, name: string, value: LispValue) -> Result[Env, string]
```

### Task 3.2: Evaluator Core
**File:** `src/eval.ki`

```kira
type EvalResult =
    | EvalOk(LispValue, Env)
    | EvalErr(string)

effect fn eval(expr: LispValue, env: Env) -> EvalResult
```

Implement evaluation for:
- Self-evaluating: numbers, strings, booleans, nil
- Symbol lookup
- Special forms: `quote`, `if`, `define`, `lambda`, `let`, `begin`, `set!`
- Function application (built-in and user-defined)

### Task 3.3: Built-in Functions
**File:** `src/builtins.ki`

Arithmetic: `+`, `-`, `*`, `/`, `mod`
Comparison: `=`, `<`, `>`, `<=`, `>=`
List ops: `cons`, `car`, `cdr`, `list`, `null?`, `pair?`
Type predicates: `number?`, `string?`, `symbol?`, `procedure?`
I/O: `display`, `newline`, `read`
Misc: `eq?`, `equal?`, `not`, `and`, `or`

---

## Phase 4: Compiler Infrastructure

### Task 4.1: Define IR (Intermediate Representation)
**File:** `src/ir.ki`

```kira
type IRExpr =
    | IRConst(LispValue)
    | IRVar(string)
    | IRIf(IRExpr, IRExpr, IRExpr)
    | IRLet(List[(string, IRExpr)], IRExpr)
    | IRLambda(List[string], IRExpr)
    | IRApp(IRExpr, List[IRExpr])
    | IRDefine(string, IRExpr)
    | IRBegin(List[IRExpr])
    | IRSet(string, IRExpr)
    | IRBuiltin(string, List[IRExpr])
```

### Task 4.2: AST to IR Transformation
**File:** `src/transform.ki`

```kira
fn to_ir(expr: LispValue) -> Result[IRExpr, string]
```

- Desugar `let` into lambda application
- Identify built-in calls
- Validate special form syntax

---

## Phase 5: Code Generation

### Task 5.1: Target Selection
Choose compilation target (in order of simplicity):

**Option A: Kira Source Code** (Recommended for first iteration)
- Generate valid Kira code
- Leverage Kira's runtime and type system
- Simple string-based codegen

**Option B: Stack-Based Bytecode**
- Define simple VM instruction set
- Implement bytecode interpreter in Kira

### Task 5.2: Kira Code Generator
**File:** `src/codegen.ki`

```kira
fn compile(ir: IRExpr) -> string
fn compile_program(exprs: List[IRExpr]) -> string
```

Generate Kira code:
- `IRConst(LispInt(42))` → `42i64`
- `IRVar("x")` → `x`
- `IRIf(cond, then, else)` → `if cond { then } else { else }`
- `IRLambda(params, body)` → `fn(params) -> LispValue { body }`
- `IRApp(f, args)` → `f(args)`

### Task 5.3: Runtime Library
**File:** `src/runtime.ki`

Provide runtime support:
- `LispValue` type definition
- Value construction helpers
- List operations
- Type checking functions
- Error handling

---

## Phase 6: REPL and CLI

### Task 6.1: REPL Implementation
**File:** `src/repl.ki`

```kira
effect fn repl() -> void
effect fn read_eval_print(env: Env) -> Env
```

Features:
- Read line, parse, evaluate, print result
- Maintain environment across expressions
- Handle errors gracefully
- Exit on `(exit)` or EOF

### Task 6.2: File Compiler
**File:** `src/main.ki`

```kira
effect fn main() -> void
```

CLI interface:
- `kira run src/main.ki run <file.lisp>` - interpret file
- `kira run src/main.ki compile <file.lisp>` - compile to Kira
- `kira run src/main.ki repl` - start REPL

---

## Phase 7: Advanced Features (Stretch Goals)

### Task 7.1: Tail Call Optimization
- Detect tail position calls
- Transform to iterative loops in codegen

### Task 7.2: Macro System
```kira
type MacroResult =
    | MacroOk(LispValue)
    | MacroErr(string)

fn expand_macros(expr: LispValue, macros: HashMap) -> MacroResult
```

Support `defmacro` and `quasiquote`/`unquote`

### Task 7.3: Module System
- `(import "module.lisp")`
- `(export symbol ...)`

### Task 7.4: Error Messages with Source Locations
```kira
type SourceLoc = { line: i32, column: i32, file: string }
type Located[T] = { value: T, loc: SourceLoc }
```

---

## File Structure

```
src/
├── main.ki          # Entry point and CLI
├── types.ki         # LispValue and core types
├── lexer.ki         # Tokenizer
├── parser.ki        # S-expression parser
├── env.ki           # Environment operations
├── eval.ki          # Interpreter
├── builtins.ki      # Built-in functions
├── ir.ki            # Intermediate representation
├── transform.ki     # AST → IR transformation
├── codegen.ki       # IR → Kira code generator
├── runtime.ki       # Runtime support library
└── repl.ki          # Read-Eval-Print Loop

tests/
├── lexer_test.ki
├── parser_test.ki
├── eval_test.ki
└── codegen_test.ki

examples/
├── factorial.lisp
├── fibonacci.lisp
├── higher-order.lisp
└── macros.lisp
```

---

## Implementation Order

| # | Task | Dependencies | Priority |
|---|------|--------------|----------|
| 1 | Task 1.1: Value Types | None | P0 |
| 2 | Task 1.2: Token Types | None | P0 |
| 3 | Task 1.3: Lexer | 1.1, 1.2 | P0 |
| 4 | Task 2.1: Parse Types | 1.1 | P0 |
| 5 | Task 2.2: Parser | 1.3, 2.1 | P0 |
| 6 | Task 3.1: Environment | 1.1 | P0 |
| 7 | Task 3.2: Evaluator | 2.2, 3.1 | P0 |
| 8 | Task 3.3: Builtins | 3.2 | P0 |
| 9 | Task 6.1: REPL | 3.3 | P1 |
| 10 | Task 4.1: IR Types | 1.1 | P1 |
| 11 | Task 4.2: Transform | 4.1, 2.2 | P1 |
| 12 | Task 5.2: Codegen | 4.2 | P1 |
| 13 | Task 5.3: Runtime | 5.2 | P1 |
| 14 | Task 6.2: CLI | 6.1, 5.3 | P1 |
| 15 | Task 7.1: TCO | 5.2 | P2 |
| 16 | Task 7.2: Macros | 3.3 | P2 |
| 17 | Task 7.3: Modules | 6.2 | P2 |
| 18 | Task 7.4: Source Locs | All | P2 |

---

## Testing Strategy

### Unit Tests
- Lexer: token sequences for various inputs
- Parser: AST structure validation
- Eval: expression evaluation correctness
- Codegen: valid Kira output

### Integration Tests
- End-to-end: source file → compiled output → execution
- REPL: multi-line input handling
- Error cases: syntax errors, runtime errors, type errors

### Example Programs
```lisp
; factorial.lisp
(define (factorial n)
  (if (<= n 1)
      1
      (* n (factorial (- n 1)))))

(display (factorial 10))
(newline)
```

```lisp
; higher-order.lisp
(define (map f lst)
  (if (null? lst)
      '()
      (cons (f (car lst))
            (map f (cdr lst)))))

(display (map (lambda (x) (* x x)) '(1 2 3 4 5)))
(newline)
```

---

## Success Criteria

### Minimum Viable Product (MVP)
- [x] Tokenize Lisp source code
- [x] Parse S-expressions into AST
- [x] Evaluate basic expressions (arithmetic, conditionals)
- [x] Define and call functions (lambda)
- [x] Working REPL

### Full Compiler
- [x] Compile Lisp to Kira source code
- [x] Support let, define, lambda, if, begin
- [x] List operations (cons, car, cdr)
- [x] Standard library of builtins
- [x] File-based compilation (via code modification, no CLI args in Kira)

### Stretch Goals
- [x] Tail call optimization
- [x] Macro system (defmacro, quasiquote)
- [x] Module/import system (basic - see limitations below)
- [ ] Source location tracking for errors

---

## Implementation Status

### Completed (2024-01-26, updated 2026-01-27)

The MVP interpreter is fully functional, and the compiler infrastructure (IR, transform, codegen) has been implemented. All code is consolidated in `src/main.ki` for simplicity.

**2026-01-27 Update (Compiler):** Added compiler infrastructure:
- **IR Types**: Intermediate representation for Lisp code (`IRExpr` sum type)
- **AST to IR Transform**: Converts parsed Lisp to IR with special form handling
- **Code Generator**: Generates Kira source code from IR
- **Runtime Library**: Generates runtime support functions for compiled code
- Added `display` and `newline` builtins for I/O
- Added workarounds for Kira bug with `for` loops on empty `List[RecursiveType]`

**2026-01-27 Update (Stdlib):** Removed workarounds for fixed Kira stdlib bugs:
- `std.string.length()` now returns `i32` directly (was `Result[i32, string]`)
- `std.string.char_at()` now returns `Option[char]` directly (was `Result[Option[char], string]`)

**2026-01-27 Update (TCO):** Added Tail Call Optimization:
- Implemented trampoline-based TCO for proper tail recursion
- Added `TailCall` variant to `EvalResult` for deferred function calls
- Modified `apply` to return `TailCall` instead of recursively evaluating lambda bodies
- Updated `eval_if`, `eval_begin`, `eval_let`, `eval_and`, `eval_or` to propagate tail calls
- Infinite loops like `(define (inf) (inf)) (inf)` now run without stack overflow
- All expressions in non-tail positions are fully evaluated via `trampoline()`
- `std.string.substring()` now returns `Option[string]` (was `Result[string, string]`)
- `std.string.parse_float()` now exists
- `to_string()` now works correctly on pattern-extracted values

**2026-01-27 Update (Macros):** Added Common Lisp-style macro system:
- **Lexer**: Added `TokQuasiquote`, `TokUnquote`, `TokUnquoteSplicing` tokens for `` ` ``, `,`, `,@` syntax
- **Types**: Added `LispMacro(List[string], LispValue, Env)` variant to `LispValue`
- **Parser**: Added `parse_quasiquoted`, `parse_unquoted`, `parse_unquote_spliced` functions
- **Evaluator**: Added `defmacro` special form to define macros
- **Quasiquote**: Full quasiquote implementation with depth tracking for nested quasiquotes
- **Unquote-splicing**: Supports `,@` to splice lists into quasiquoted expressions
- **Macro expansion**: Macros receive unevaluated arguments and return expanded code
- Example macros: `when`, `unless`, `swap`, `inc!` all work correctly

**2026-01-27 Update (Modules):** Added basic module system:
- **Import**: `(import "path/to/module.lisp")` loads and evaluates a module file, importing all its top-level definitions into the current environment
- **Provide**: `(provide sym1 sym2 ...)` declares which symbols a module exports (recorded but not yet enforced)

**2026-01-27 Update (Bug Fixes):** All previously documented Kira language bugs have been fixed:
- Bug 1: `for` loop on empty `List[RecursiveType]` - **Fixed**
- Bug 2: HashMap `any` type round-trip for recursive types - **Fixed**
- Bug 3: Pattern match extraction of `List[RecursiveType]` - **Fixed**
- Module system features (explicit symbol lists, circular import detection) can now be implemented

**Working Features:**
- Lexer: tokenizes integers, strings, symbols, booleans (#t/#f), parentheses, quotes
- Parser: recursive descent parser for S-expressions with quote shorthand
- Evaluator: full evaluation with proper lexical scoping
- Special forms: `quote`, `quasiquote`, `if`, `define`, `defmacro`, `lambda`, `let`, `begin`, `set!`, `and`, `or`, `import`, `provide`
- Builtins: arithmetic (`+`, `-`, `*`, `/`, `mod`), comparison (`=`, `<`, `>`, `<=`, `>=`), list ops (`cons`, `car`, `cdr`, `list`, `null?`, `pair?`, `length`), type predicates, equality, string operations, I/O (`display`, `newline`)
- Recursive functions work correctly
- Higher-order functions (map, filter patterns) work
- Compiler: AST → IR → Kira source code generation

**Example Session:**
```
$ kira run src/main.ki
Kira Lisp Interpreter
Type (exit) or (quit) to exit

lisp> (define (fact n) (if (<= n 1) 1 (* n (fact (- n 1)))))
()
lisp> (fact 10)
3628800
lisp> (define (map f lst) (if (null? lst) (quote ()) (cons (f (car lst)) (map f (cdr lst)))))
()
lisp> (map (lambda (x) (* x x)) (quote (1 2 3 4 5)))
(1 4 9 16 25)
lisp> (display "Hello, ") (display "World!") (newline)
Hello, World!
()
```

**Compiler Usage:**
To compile a Lisp file to Kira, modify the `main()` function in `src/main.ki`:
```kira
// Comment out REPL code and add:
compile_file("examples/factorial.lisp", "examples/factorial_compiled.ki")
```

**Known Limitations:**
- Multi-line REPL input not supported (expressions must be on single lines)

**Files Created:**
- `src/main.ki` - Complete interpreter and compiler (lexer, parser, evaluator, IR, transform, codegen, REPL)
- `src/compile.ki` - Compiler usage instructions
- `src/types.ki` - Standalone type definitions (for reference)
- `src/lexer.ki` - Standalone lexer (for reference)
- `src/parser.ki` - Standalone parser (for reference)
- `src/env.ki` - Standalone environment ops (for reference)
- `src/eval.ki` - Standalone evaluator (for reference)

---

## Notes

### Kira Features to Leverage
- **Sum types**: Perfect for `LispValue` and `Token` representation
- **Pattern matching**: Clean AST traversal and evaluation
- **`List[T]`**: Native support for Lisp lists
- **`HashMap`**: Environment implementation
- **`StringBuilder`**: Efficient code generation
- **`Result[T,E]`**: Error propagation

### Potential Challenges
1. **Recursive types**: Kira's `List[T]` is recursive; `LispValue` containing `List[LispValue]` should work
2. **Closures**: Need to capture environment in lambda values
3. **Mutability**: Lisp's `set!` requires mutable environments; use `var` bindings in Kira
4. **Performance**: Interpreter may be slow; compiler with Kira backend will be faster

### Kira Language Notes
1. **`if` is a statement, not an expression**: Kira's `if` doesn't return a value. Workaround: Use immediately-invoked function expressions (IIFE) with `match` inside: `(fn() -> T { match cond { true => { return x } false => { return y } } })()`
2. **Command-line arguments**: Kira now supports `std.env.args()` which returns `List[string]`.

### References
- [Structure and Interpretation of Computer Programs](https://mitpress.mit.edu/sites/default/files/sicp/index.html)
- [Write Yourself a Scheme in 48 Hours](https://en.wikibooks.org/wiki/Write_Yourself_a_Scheme_in_48_Hours)
- [Crafting Interpreters](https://craftinginterpreters.com/)
