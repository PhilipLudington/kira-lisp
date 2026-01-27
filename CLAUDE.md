# Kira Lisp

A Lisp interpreter and compiler written in Kira.

## Project Structure

- `src/` - Kira source files
  - `main.ki` - Main interpreter, compiler, and REPL
  - `types.ki` - Type definitions
  - `lexer.ki` - Tokenizer
  - `eval.ki` - Evaluator (standalone interpreter module)
- `examples/` - Example Lisp programs
- `BUG.md` - Kira language bugs encountered during development

## Running

```bash
# Start REPL
kira run src/main.ki

# Run a Lisp file
kira run src/main.ki run examples/factorial.lisp

# Compile Lisp to Kira
kira run src/main.ki compile examples/factorial.lisp
```

## Building

Always use the GitStat wrapper script to build:
```bash
./build.sh
```
Do NOT run `kira check` directly - use the wrapper script to preserve GitStat integration.

## Running Tests

Always use the GitStat wrapper script to run tests:
```bash
./run-tests.sh
```
This runs the interpreter through various test cases and writes results for GitStat.

## Kira Language Reference

Kira documentation is at `~/Fun/Kira/docs/README.md`. Key points:

- Types: `i32`, `i64`, `f64`, `bool`, `string`, `char`
- Sum types: `type Foo = | A(i32) | B(string)`
- Effects: Functions with side effects use `effect fn`
- Lists: `List[T]` with `Cons(head, tail)` and `Nil`
