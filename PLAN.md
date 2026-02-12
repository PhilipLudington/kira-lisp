# Kira Lisp - String Primitives & JSON/LSP Plan

## Goal

Add string manipulation primitives to Kira Lisp, then build a JSON library, then implement an LSP server. This exercises the language across parsing, protocol handling, and AST analysis.

---

## Phase 1: String Primitives
**Repo:** `kira-lisp` (this repo)
**File:** `src/main.ki`

Add missing string operations to enable JSON parsing.

### Task 1.1: `string-ref` - Character Access
**File:** `src/main.ki`

```lisp
(string-ref "hello" 0)  ; => "h" (as single-char string)
(string-ref "hello" 4)  ; => "o"
(string-ref "hello" 5)  ; => #f (out of bounds)
```

**Implementation:**
- Use `std.string.char_at(s, idx)` which returns `Option[char]`
- Return single-character string on success, `#f` on out-of-bounds
- Consider: Return char value or string? (String is simpler, no char type in Lisp)

### Task 1.2: `substring` - Extract Portion
**File:** `src/main.ki`

```lisp
(substring "hello" 1 4)   ; => "ell"
(substring "hello" 0 5)   ; => "hello"
(substring "hello" 2 2)   ; => ""
(substring "hello" 3 100) ; => "lo" (clamp to end)
```

**Implementation:**
- Use `std.string.substring(s, start, end)` which returns `Option[string]`
- Clamp end to string length for convenience
- Return `#f` if start is out of bounds or start > end

### Task 1.3: `string->list` - Convert to Character List
**File:** `src/main.ki`

```lisp
(string->list "abc")  ; => ("a" "b" "c")
```

**Implementation:**
- Iterate with `std.string.chars(s)`
- Build list of single-character strings
- Enables parsing via standard list operations

### Task 1.4: `list->string` - Build String from List
**File:** `src/main.ki`

```lisp
(list->string '("h" "i"))     ; => "hi"
(list->string '("a" "bc" "d")) ; => "abcd" (concatenates all)
```

**Implementation:**
- Use `StringBuilder`
- Append each string element
- Error if list contains non-strings

### Task 1.5: `char->integer` - Character Code
**File:** `src/main.ki`

```lisp
(char->integer "a")   ; => 97
(char->integer "\n")  ; => 10
(char->integer "")    ; => #f
(char->integer "ab")  ; => #f (must be single char)
```

**Implementation:**
- Get first char, return its Unicode code point as integer
- Return `#f` for empty or multi-char strings

### Task 1.6: `integer->char` - Code to Character
**File:** `src/main.ki`

```lisp
(integer->char 97)   ; => "a"
(integer->char 10)   ; => "\n"
(integer->char -1)   ; => #f (invalid)
```

**Implementation:**
- Convert integer to char, then to single-char string
- Return `#f` for invalid code points

### Task 1.7: `string-split` - Split on Delimiter
**File:** `src/main.ki`

```lisp
(string-split "a,b,c" ",")   ; => ("a" "b" "c")
(string-split "hello" "")    ; => ("h" "e" "l" "l" "o")
(string-split "no-match" ",") ; => ("no-match")
```

**Implementation:**
- Scan for delimiter occurrences
- Build list of substrings between delimiters
- Empty delimiter splits into individual chars

### Task 1.8: `string-join` - Join with Delimiter
**File:** `src/main.ki`

```lisp
(string-join '("a" "b" "c") ",")  ; => "a,b,c"
(string-join '("x") "-")          ; => "x"
(string-join '() ",")             ; => ""
```

**Implementation:**
- Use `StringBuilder`
- Insert delimiter between elements (not after last)

---

## Phase 2: JSON Library
**Repo:** `kira-lisp` (this repo)
**Files:** `src/json.lisp`, `examples/testing/json-test.lisp`

Build JSON parser and serializer in Lisp using the new string primitives.

### Task 2.1: JSON Value Representation
**File:** `src/json.lisp`

Design the data representation:
```lisp
; JSON null  => 'null or ()
; JSON bool  => #t / #f
; JSON number => Lisp number (i64 or f64)
; JSON string => Lisp string
; JSON array  => Lisp list
; JSON object => Association list: ((key1 . val1) (key2 . val2) ...)
```

### Task 2.2: JSON Lexer
**File:** `src/json.lisp`

Tokenize JSON input:
- `{` `}` `[` `]` `:` `,`
- Strings (with escape handling: `\"`, `\\`, `\/`, `\b`, `\f`, `\n`, `\r`, `\t`, `\uXXXX`)
- Numbers (integer and floating point, with optional exponent)
- `true`, `false`, `null`

```lisp
(json-tokenize "{\"name\": \"test\"}")
; => ((lbrace) (string "name") (colon) (string "test") (rbrace))
```

### Task 2.3: JSON Parser
**File:** `src/json.lisp`

Recursive descent parser:
```lisp
(json-parse "{\"x\": [1, 2, 3]}")
; => (("x" . (1 2 3)))

(json-parse "[true, false, null]")
; => (#t #f null)
```

### Task 2.4: JSON Serializer
**File:** `src/json.lisp`

Convert Lisp values back to JSON strings:
```lisp
(json-stringify '(("name" . "Alice") ("age" . 30)))
; => "{\"name\":\"Alice\",\"age\":30}"

(json-stringify '(1 2 3))
; => "[1,2,3]"
```

### Task 2.5: JSON Tests
**File:** `examples/testing/json-test.lisp`

Test cases:
- Parse/stringify round-trip
- All JSON types
- Escape sequences
- Nested structures
- Edge cases (empty object/array, unicode)

---

## Phase 3: LSP Server
**Repo:** `kira-lisp` (this repo, in `src/lsp/`)

Implement Language Server Protocol for Kira Lisp.

### Task 3.1: JSON-RPC Message Framing
**File:** `src/lsp/rpc.lisp`

Handle LSP transport:
- Read `Content-Length: N\r\n\r\n` header
- Read N bytes of JSON body
- Parse as JSON-RPC request
- Write response with header

```lisp
(define (read-message)
  (let ((header (read-line)))
    (let ((length (parse-content-length header)))
      (read-line)  ; empty line
      (json-parse (read-bytes length)))))
```

### Task 3.2: LSP Protocol Types
**File:** `src/lsp/protocol.lisp`

Define message constructors/accessors:
```lisp
(define (make-response id result)
  `(("jsonrpc" . "2.0") ("id" . ,id) ("result" . ,result)))

(define (make-error id code message)
  `(("jsonrpc" . "2.0") ("id" . ,id)
    ("error" . (("code" . ,code) ("message" . ,message)))))
```

### Task 3.3: Initialize/Shutdown Handlers
**File:** `src/lsp/handlers.lisp`

Implement lifecycle:
- `initialize` - Return server capabilities
- `initialized` - Notification (no response)
- `shutdown` - Prepare to exit
- `exit` - Terminate process

### Task 3.4: Document Sync
**File:** `src/lsp/documents.lisp`

Track open documents:
- `textDocument/didOpen` - Store document content
- `textDocument/didChange` - Update content
- `textDocument/didClose` - Remove from tracking

Store as alist: `((uri . content) ...)`

### Task 3.5: Diagnostics
**File:** `src/lsp/diagnostics.lisp`

Report parse/eval errors:
- Re-parse document on change
- Collect syntax errors with location
- Publish via `textDocument/publishDiagnostics`

```lisp
(define (make-diagnostic line col message)
  `(("range" . (("start" . (("line" . ,line) ("character" . ,col)))
                ("end" . (("line" . ,line) ("character" . ,(+ col 1))))))
    ("message" . ,message)
    ("severity" . 1)))  ; 1 = Error
```

### Task 3.6: Hover Support
**File:** `src/lsp/hover.lisp`

Show info on hover:
- Find symbol at position
- Look up in environment/builtins
- Return documentation string

### Task 3.7: Go to Definition
**File:** `src/lsp/definition.lisp`

Jump to symbol definition:
- Track where symbols are defined (file, line, column)
- Handle `define`, `defmacro`, `let` bindings
- Return location or null

### Task 3.8: LSP Main Loop
**File:** `src/lsp/main.lisp`

Server entry point:
```lisp
(define (lsp-main)
  (let loop ((state (initial-state)))
    (let ((msg (read-message)))
      (let ((result (dispatch msg state)))
        (when (response? result)
          (write-message (car result)))
        (if (shutdown? result)
            'done
            (loop (cdr result)))))))
```

---

## Implementation Order

| # | Task | Dependencies | Effort |
|---|------|--------------|--------|
| 1 | 1.1 string-ref | None | Small |
| 2 | 1.2 substring | None | Small |
| 3 | 1.5 char->integer | None | Small |
| 4 | 1.6 integer->char | None | Small |
| 5 | 1.3 string->list | 1.1 | Small |
| 6 | 1.4 list->string | None | Small |
| 7 | 1.7 string-split | 1.2 | Medium |
| 8 | 1.8 string-join | None | Small |
| 9 | 2.1 JSON representation | None | Small |
| 10 | 2.2 JSON lexer | 1.1-1.6 | Medium |
| 11 | 2.3 JSON parser | 2.2 | Medium |
| 12 | 2.4 JSON serializer | 1.4 | Medium |
| 13 | 2.5 JSON tests | 2.3, 2.4 | Small |
| 14 | 3.1 JSON-RPC framing | 2.3, 2.4 | Medium |
| 15 | 3.2 Protocol types | 2.1 | Small |
| 16 | 3.3 Lifecycle handlers | 3.1, 3.2 | Small |
| 17 | 3.4 Document sync | 3.3 | Medium |
| 18 | 3.5 Diagnostics | 3.4 | Medium |
| 19 | 3.6 Hover | 3.4 | Medium |
| 20 | 3.7 Go to definition | 3.4 | Large |
| 21 | 3.8 LSP main loop | 3.3-3.7 | Medium |

---

## Current Status

### Phase 1: String Primitives ✓
- [x] 1.1 `string-ref`
- [x] 1.2 `substring`
- [x] 1.3 `string->list`
- [x] 1.4 `list->string`
- [x] 1.5 `char->integer`
- [x] 1.6 `integer->char`
- [x] 1.7 `string-split`
- [x] 1.8 `string-join`

### Phase 2: JSON Library ✓
- [x] 2.1 JSON representation
- [x] 2.2 JSON lexer
- [x] 2.3 JSON parser
- [x] 2.4 JSON serializer
- [x] 2.5 JSON tests

### Phase 3: LSP Server (In Progress)
- [x] 3.1 JSON-RPC framing
- [x] 3.2 Protocol types
- [x] 3.3 Lifecycle handlers
- [x] 3.4 Document sync
- [x] 3.5 Diagnostics
- [x] 3.6 Hover
- [ ] 3.7 Go to definition
- [x] 3.8 LSP main loop

---

## Notes

### Kira Standard Library String Functions
Available in `std.string`:
- `char_at(s, idx) -> Option[char]`
- `substring(s, start, end) -> Option[string]`
- `length(s) -> i32`
- `chars(s) -> Iterator[char]`
- `parse_int(s) -> Option[i32]`
- `parse_float(s) -> Option[f64]`

### LSP Protocol Reference
- [LSP Specification](https://microsoft.github.io/language-server-protocol/specifications/lsp/3.17/specification/)
- Transport: stdin/stdout with `Content-Length` headers
- Message format: JSON-RPC 2.0

### Running the LSP Server
```bash
kira run src/main.ki run src/lsp/server.lisp
```

### LSP Implementation Notes
- Uses line-based I/O (`read-line`) since Kira lacks `read-bytes`
- Each JSON message body must be on its own line (followed by newline)
- Server capabilities: textDocumentSync (full), hoverProvider, definitionProvider
- Added `read-line` primitive to interpreter for stdin reading
