# Kira Lisp Project Ideas

A collection of projects that could be built with or for kira-lisp.

---

## In This Repo

Projects that extend kira-lisp directly or serve as examples.

### Standard Library ✓
**Location:** `src/stdlib.lisp`
**Status:** Implemented

Core functions implemented in Lisp itself:
- ✓ List operations: `map`, `filter`, `reduce`, `foldl`, `foldr`, `take`, `drop`, `append`, `reverse`, `nth`, `last`, `flatten`, `zip`, `range`
- ✓ Predicates: `every?`, `some?`, `none?`, `find`, `member?`
- ✓ Math utilities: `sum`, `product`, `clamp` (note: `abs`, `min`, `max` are builtins)
- ✓ Higher-order: `compose`, `identity`, `constantly`
- Future: String operations (`split`, `join`, `trim`, `format`) - requires string primitives

### Test Suite ✓
**Location:** `examples/testing/`
**Status:** Implemented

Built-in testing framework with interpreter primitives:
- ✓ `assert-eq`, `assert-true`, `assert-false`, `assert-throws`
- ✓ Test grouping: `test-begin`, `test-end`
- ✓ Test reporting: `test-summary`, `test-reset`
- ✓ `try` special form for error handling
- Future: Randomized input generation
- Future: Shrinking for minimal failing cases

### Mini Games
**Location:** `examples/games/`

Simple interactive games demonstrating I/O and state:
- Text adventure engine
- Number guessing game
- Tic-tac-toe
- Hangman

### Data Structures
**Location:** `examples/data-structures/`

Pure functional data structures:
- Hash maps (using association lists or tries)
- Sets
- Binary search trees
- Priority queues / heaps
- Persistent vectors

---

## Separate Application Repos

Standalone applications that use kira-lisp as their scripting/config layer.

### lisp-config
**Repo:** `lisp-config`

Configuration file format using Lisp syntax (similar to EDN/Clojure):
- Human-readable data format
- Comments supported
- Nested structures
- Integration with Kira applications

### lisp-calc
**Repo:** `lisp-calc`

Calculator/spreadsheet with Lisp formulas:
- Cell references as variables
- Custom functions
- Reactive recalculation
- Import/export to CSV

### lisp-shell
**Repo:** `lisp-shell`

Interactive shell with Lisp as the scripting language:
- Pipe-like composition with Lisp functions
- Job control
- Command history with Lisp evaluation
- Customizable prompt via Lisp

### lisp-templating
**Repo:** `lisp-templating`

HTML/text templating engine:
- Embed Lisp expressions in templates
- Macro-based control flow
- Template inheritance
- Auto-escaping for security

### lisp-query
**Repo:** `lisp-query`

S-expression query language:
- Query JSON documents
- Filter and transform data pipelines
- Aggregate functions
- Composable query fragments

---

## Library Repos

Libraries that extend kira-lisp's capabilities.

### kira-lisp-lsp
**Repo:** `kira-lisp-lsp`

Language Server Protocol implementation:
- Syntax highlighting
- Error diagnostics
- Go-to-definition
- Hover documentation
- Auto-completion
- Editor plugins (VS Code, Neovim, Emacs)

### kira-lisp-debug
**Repo:** `kira-lisp-debug`

Step debugger:
- Breakpoints
- Step in/over/out
- Variable inspection
- Call stack display
- Conditional breakpoints
- REPL integration

### kira-lisp-format
**Repo:** `kira-lisp-format`

Code formatter/pretty-printer:
- Consistent indentation
- Line length limits
- Configurable style options
- Diff-friendly output
- Editor integration

### kira-lisp-lint
**Repo:** `kira-lisp-lint`

Static analysis and style checking:
- Unused variable detection
- Undefined symbol warnings
- Style rule enforcement
- Custom rule definitions
- CI integration

---

## Ambitious Projects

Larger projects that demonstrate kira-lisp's potential.

### lisp-os
**Repo:** `lisp-os`

Tiny Lisp-based operating environment:
- Lisp as the shell language
- Process management via Lisp
- File system navigation
- Network utilities
- Could run on bare metal or as a user-space environment

### lisp-web
**Repo:** `lisp-web`

Web framework:
- Routes defined as Lisp data
- Handlers as Lisp functions
- Middleware composition
- Template rendering
- Database query DSL

### lisp-ml
**Repo:** `lisp-ml`

Machine learning DSL:
- Neural network definitions as S-expressions
- Automatic differentiation
- Compiles to efficient Kira code
- Training loop abstractions
- Model serialization

### lisp-music
**Repo:** `lisp-music`

Live-coding music environment:
- Real-time audio synthesis
- Pattern sequencing via Lisp
- MIDI integration
- OSC support
- Hot-reloading during performance

---

## Priority Recommendations

1. **Standard Library** - Foundation for everything else
2. **Test Suite** - Ensures reliability as features grow
3. **kira-lisp-lsp** - Makes the language accessible to others
4. **lisp-config** - Practical, immediately useful application

---

## Contributing

Pick a project, open an issue to discuss the approach, and submit a PR!
